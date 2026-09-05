import 'dart:math' as math;

import 'package:bestfin/cli/parse_result.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/database/app_database.dart';

/// Parser heurístico determinístico para frases em linguagem natural.
///
/// Extrai valor, tipo, contas e categoria a partir de texto livre e de
/// listas reais de contas/categorias já cadastradas. Não depende de LLM.
class NlParser {
  NlParser({required this.accounts, required this.categories});

  final List<Account> accounts;
  final List<Category> categories;

  ParsedTransaction parse(String phrase) {
    final normalized = phrase.trim();
    final lower = _normalize(normalized);

    final amount = _extractAmount(normalized);
    final type = _detectType(lower);
    final accountMatch = _matchAccount(lower, type);
    final categoryMatch = _matchCategory(lower);

    // Descrição: usa a frase original limpa, removendo valor detectado
    // para não ficar "mercado 50" duplicado se o usuário já tem categoria.
    var description = normalized;
    if (amount != null) {
      // remove a ocorrência do valor da descrição para ficar mais limpa
      // mas mantém se sobrar vazio
      final cleaned = _removeAmountToken(description);
      if (cleaned.trim().isNotEmpty) description = cleaned.trim();
    }
    // Limita descrição
    if (description.length > 100) description = description.substring(0, 100);

    final confidences = <String, FieldConfidence>{};

    // amount
    if (amount != null) {
      confidences['amount'] = FieldConfidence.high;
    } else {
      confidences['amount'] = FieldConfidence.low;
    }

    // type
    confidences['type'] = _typeConfidence(lower, type);

    // account
    if (accountMatch != null) {
      confidences['account'] = accountMatch.confidence; // already computed
    } else {
      // tenta conta padrão: primeira conta não arquivada
      confidences['account'] = FieldConfidence.low;
    }

    // toAccount for transfer
    if (type == TransactionType.transfer) {
      if (accountMatch?.toAccountId != null) {
        confidences['toAccount'] = FieldConfidence.high;
      } else {
        confidences['toAccount'] = FieldConfidence.low;
      }
    }

    // category (transfer não tem categoria)
    if (type == TransactionType.transfer) {
      confidences['category'] = FieldConfidence.high;
    } else if (categoryMatch != null) {
      confidences['category'] = categoryMatch.confidence;
    } else {
      confidences['category'] = FieldConfidence.low;
    }

    // description
    confidences['description'] = description.trim().isNotEmpty
        ? FieldConfidence.high
        : FieldConfidence.low;

    // Resolve account ids via matches or fallback
    String? accountId = accountMatch?.accountId;
    String? toAccountId = accountMatch?.toAccountId;

    // Fallback: se não achou conta, usa primeira conta (para não bloquear)
    // mas mantém confidence low para TUI pedir confirmação
    if (accountId == null && accounts.isNotEmpty) {
      // não preenche automaticamente — deixa null para TUI exigir escolha
      // mas se só há 1 conta, é high confidence implícito
      if (accounts.length == 1) {
        accountId = accounts.first.id;
        // mantém low para forçar confirmação, mas não é bloqueante
      }
    }

    return ParsedTransaction(
      type: type,
      amountCents: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryMatch?.categoryId,
      description: description,
      confidences: confidences,
      rawPhrase: normalized,
    );
  }

  // ── Valor ───────────────────────────────────────────────────────────

  /// Extrai valor em centavos. Suporta formatos: 50, 50.00, 50,00, R$ 50,
  /// 1.500,00, 1500. Retorna null se não encontrar.
  int? _extractAmount(String phrase) {
    // Procura padrões monetários: opcional R$, número com . milhares e , decimal
    final pattern = RegExp(
      r'(?:R\$\s*)?(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:,\d{1,2})?|\d+(?:\.\d{1,2})?)',
    );
    final matches = pattern.allMatches(phrase).toList();
    if (matches.isEmpty) return null;

    // Heurística: pega o último número que parece valor monetário (evita
    // capturar datas ou números irrelevantes no início da frase).
    // Se houver símbolo R$, prioriza esse match.
    RegExpMatch? best;
    for (final m in matches) {
      final full = m.group(0)!;
      if (full.contains('R\$')) {
        best = m;
        break;
      }
    }
    best ??= matches.last;

    var raw = best.group(1)!;
    // Normaliza: remove separador de milhar (.), troca vírgula por ponto
    // Se tem tanto . quanto ,, . é milhar e , é decimal (pt-BR).
    // Se só tem ., pode ser decimal US — trata como decimal se 1-2 casas.
    if (raw.contains('.') && raw.contains(',')) {
      raw = raw.replaceAll('.', '').replaceAll(',', '.');
    } else if (raw.contains(',')) {
      raw = raw.replaceAll(',', '.');
    }
    // Agora raw é formato US: 1500.50
    final value = double.tryParse(raw);
    if (value == null) return null;
    if (value <= 0 || value > 99999999) return null;
    return (value * 100).round();
  }

  String _removeAmountToken(String phrase) {
    final pattern = RegExp(
      r'\s*(?:R\$\s*)?\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?|\s*\d+(?:,\d{1,2})?|\s*\d+(?:\.\d{1,2})?',
    );
    // Remove apenas a última ocorrência (a que foi considerada valor)
    final matches = pattern.allMatches(phrase).toList();
    if (matches.isEmpty) return phrase;
    final last = matches.last;
    return phrase
        .replaceRange(last.start, last.end, ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ');
  }

  // ── Tipo ────────────────────────────────────────────────────────────

  TransactionType _detectType(String lower) {
    const incomeKeywords = [
      'recebi',
      'recebimento',
      'salário',
      'salario',
      'ganhei',
      'receita',
      'entrou',
      'vendi',
      'venda',
      'reembolso',
      'rendimento',
      'provento',
      'bonus',
      'bônus',
    ];
    const transferKeywords = [
      'transferência',
      'transferencia',
      'transferir',
      'transfira',
      'pix',
      'enviei para',
      'mandei para',
      'para a',
      'para o',
      '->',
      '→',
    ];

    // Transferência tem prioridade se mencionar duas contas ou palavras-chave
    // + padrão "X para Y" / "X -> Y"
    final hasTransferKeyword = transferKeywords.any(lower.contains);
    final hasParaPattern =
        RegExp(r'\bpara\b').hasMatch(lower) ||
        lower.contains('->') ||
        lower.contains('→');
    if (hasTransferKeyword && hasParaPattern) return TransactionType.transfer;
    if (lower.contains('pix') && hasParaPattern)
      return TransactionType.transfer;
    // Caso explícito "transferência" sem "para" ainda é transfer
    if (lower.contains('transferência') || lower.contains('transferencia')) {
      return TransactionType.transfer;
    }

    for (final k in incomeKeywords) {
      if (lower.contains(k)) return TransactionType.income;
    }
    return TransactionType.expense;
  }

  FieldConfidence _typeConfidence(String lower, TransactionType type) {
    if (type == TransactionType.expense) {
      // expense é default — confiança média se não há keywords
      const incomeKeywords = [
        'recebi',
        'salário',
        'ganhei',
        'receita',
        'entrou',
      ];
      final hasIncome = incomeKeywords.any(lower.contains);
      if (hasIncome) return FieldConfidence.low;
      // se tem palavras explícitas de despesa, high
      const expenseKeywords = [
        'gastei',
        'gasto',
        'paguei',
        'comprei',
        'despesa',
        'conta',
        'mercado',
        'ifood',
        'uber',
        'farmácia',
        'farmacia',
      ];
      if (expenseKeywords.any(lower.contains)) return FieldConfidence.high;
      return FieldConfidence.medium;
    }
    return FieldConfidence.high;
  }

  // ── Conta (fuzzy) ──────────────────────────────────────────────────

  _AccountMatch? _matchAccount(String lower, TransactionType type) {
    if (accounts.isEmpty) return null;

    // Para transferência, tenta extrair duas contas via "X para Y"
    if (type == TransactionType.transfer) {
      final paraIdx = lower.indexOf(' para ');
      if (paraIdx != -1) {
        final left = lower.substring(0, paraIdx);
        final right = lower.substring(paraIdx + 6);
        final from = _bestAccountMatch(left);
        final to = _bestAccountMatch(right);
        if (from != null && to != null && from.id != to.id) {
          return _AccountMatch(
            accountId: from.id,
            toAccountId: to.id,
            confidence: FieldConfidence.high,
          );
        }
        if (from != null) {
          return _AccountMatch(
            accountId: from.id,
            confidence: FieldConfidence.medium,
          );
        }
        if (to != null) {
          // pode ter só destino mencionado
          final fallbackFrom = accounts.firstWhere(
            (a) => a.id != to.id,
            orElse: () => accounts.first,
          );
          return _AccountMatch(
            accountId: fallbackFrom.id,
            toAccountId: to.id,
            confidence: FieldConfidence.medium,
          );
        }
      }
      // arrow pattern
      final arrow = lower.contains('->')
          ? '->'
          : lower.contains('→')
          ? '→'
          : null;
      if (arrow != null) {
        final parts = lower.split(arrow);
        if (parts.length == 2) {
          final from = _bestAccountMatch(parts[0]);
          final to = _bestAccountMatch(parts[1]);
          if (from != null && to != null) {
            return _AccountMatch(
              accountId: from.id,
              toAccountId: to.id,
              confidence: FieldConfidence.high,
            );
          }
        }
      }
    }

    // Caso geral: procura menção a qualquer conta no texto
    final best = _bestAccountMatch(lower);
    if (best != null) {
      return _AccountMatch(
        accountId: best.id,
        confidence: FieldConfidence.high,
      );
    }

    // Fuzzy por token
    final fuzzy = _fuzzyAccountMatch(lower);
    if (fuzzy != null) {
      return _AccountMatch(
        accountId: fuzzy.id,
        confidence: FieldConfidence.medium,
      );
    }

    return null;
  }

  Account? _bestAccountMatch(String text) {
    final norm = text.trim();
    for (final acc in accounts) {
      final nameNorm = _normalize(acc.name);
      if (norm.contains(nameNorm) && nameNorm.length >= 3) return acc;
      // também tenta match por palavra
      final tokens = nameNorm.split(' ');
      for (final tok in tokens) {
        if (tok.length >= 3 && norm.contains(tok)) return acc;
      }
    }
    return null;
  }

  Account? _fuzzyAccountMatch(String text) {
    Account? best;
    var bestScore = 999;
    for (final acc in accounts) {
      final dist = _levenshtein(text, _normalize(acc.name));
      // normaliza por tamanho
      final threshold = math.max(2, acc.name.length ~/ 3);
      if (dist <= threshold && dist < bestScore) {
        bestScore = dist;
        best = acc;
      }
      // tenta cada token
      for (final tok in acc.name.split(' ')) {
        if (tok.length < 3) continue;
        final d2 = _levenshtein(text, _normalize(tok));
        if (d2 <= 2 && d2 < bestScore) {
          bestScore = d2;
          best = acc;
        }
      }
    }
    return best;
  }

  // ── Categoria (fuzzy) ──────────────────────────────────────────────

  _CategoryMatch? _matchCategory(String lower) {
    if (categories.isEmpty) return null;

    // Match direto: nome da categoria contido no texto
    for (final cat in categories) {
      final nameNorm = _normalize(cat.name);
      if (lower.contains(nameNorm) && nameNorm.length >= 3) {
        return _CategoryMatch(
          categoryId: cat.id,
          confidence: FieldConfidence.high,
        );
      }
    }

    // Token match
    for (final cat in categories) {
      final tokens = _normalize(cat.name).split(' ');
      for (final tok in tokens) {
        if (tok.length >= 3 && lower.contains(tok)) {
          return _CategoryMatch(
            categoryId: cat.id,
            confidence: FieldConfidence.medium,
          );
        }
      }
    }

    // Fuzzy leve
    Category? best;
    var bestDist = 999;
    for (final cat in categories) {
      final catNorm = _normalize(cat.name);
      for (final word in lower.split(RegExp(r'\s+'))) {
        if (word.length < 3) continue;
        final d = _levenshtein(word, catNorm);
        if (d <= 2 && d < bestDist) {
          bestDist = d;
          best = cat;
        }
        for (final tok in catNorm.split(' ')) {
          final d2 = _levenshtein(word, tok);
          if (d2 <= 2 && d2 < bestDist) {
            bestDist = d2;
            best = cat;
          }
        }
      }
    }
    if (best != null) {
      return _CategoryMatch(
        categoryId: best.id,
        confidence: FieldConfidence.medium,
      );
    }

    // Palavras-chave comuns → categoria por descrição (heurística simples)
    const keywordMap = {
      'mercado': ['mercado', 'supermercado', 'hortifruti', 'feira'],
      'ifood': ['ifood', 'restaurante', 'delivery', 'lanche'],
      'transporte': [
        'uber',
        '99',
        'combustível',
        'combustivel',
        'gasolina',
        'ônibus',
        'onibus',
        'metrô',
      ],
      'farmácia': ['farmacia', 'remédio', 'remedio', 'drogaria'],
    };
    for (final cat in categories) {
      final catNorm = _normalize(cat.name);
      for (final entry in keywordMap.entries) {
        if (catNorm.contains(_normalize(entry.key))) {
          for (final kw in entry.value) {
            if (lower.contains(kw)) {
              return _CategoryMatch(
                categoryId: cat.id,
                confidence: FieldConfidence.medium,
              );
            }
          }
        }
      }
    }
    return null;
  }

  // ── Utils ──────────────────────────────────────────────────────────

  String _normalize(String s) {
    var out = s.toLowerCase();
    const map = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length, n = b.length;
    var prev = List.generate(n + 1, (j) => j);
    var curr = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = math.min(
          math.min(prev[j] + 1, curr[j - 1] + 1),
          prev[j - 1] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }
}

class _AccountMatch {
  _AccountMatch({
    required this.accountId,
    this.toAccountId,
    required this.confidence,
  });
  final String accountId;
  final String? toAccountId;
  final FieldConfidence confidence;
}

class _CategoryMatch {
  _CategoryMatch({required this.categoryId, required this.confidence});
  final String categoryId;
  final FieldConfidence confidence;
}

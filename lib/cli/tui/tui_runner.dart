import 'dart:io';

import 'package:bestfin/cli/parse_result.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/transactions/domain/models/quick_suggestion.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/usecases/get_quick_suggestions.dart';

/// TUI simples sem dependências externas (ANSI + stdin/stdout).
///
/// Usado quando `bestfin add` roda sem frase ou para confirmar/corrgir
/// campos de baixa confiança antes de salvar.
class TuiRunner {
  TuiRunner({
    required this.accounts,
    required this.categories,
    this.historyLoader,
  });

  final List<Account> accounts;
  final List<Category> categories;

  /// Histórico recente (180 dias) para sugestões do wizard — injetado por
  /// quem tem acesso ao banco (cli_main). null = sem sugestões.
  final Future<List<TransactionModel>> Function()? historyLoader;

  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _dim = '\x1B[2m';
  static const _cyan = '\x1B[36m';
  static const _yellow = '\x1B[33m';
  static const _green = '\x1B[32m';
  static const _red = '\x1B[31m';

  void _writeln(String s) => stdout.writeln(s);
  void _write(String s) => stdout.write(s);
  String? _readLine() => stdin.readLineSync();

  void _clear() => Term.clear();

  void _header(String title) {
    _writeln('$_cyan$_bold── $title ──$_reset');
  }

  // ── Confirmação de parsed ──────────────────────────────────────────

  /// Mostra campos já preenchidos e deixa o usuário editar os de baixa confiança.
  /// Retorna o ParsedTransaction ajustado ou null se cancelado.
  Future<ParsedTransaction?> confirmParsed(ParsedTransaction parsed) async {
    _clear();
    _header('Lançamento Rápido — confirmar');
    _writeln('');
    _writeln('Frase: "${parsed.rawPhrase ?? ''}"');
    _writeln('');

    _printField('Tipo', parsed.type.label, parsed.confidences['type']!);
    _printField(
      'Descrição',
      parsed.description ?? '-',
      parsed.confidences['description']!,
    );
    _printAmount(parsed.amountCents, parsed.confidences['amount']!);
    _printAccount('Conta', parsed.accountId, parsed.confidences['account']!);
    if (parsed.type == TransactionType.transfer) {
      _printAccount(
        'Destino',
        parsed.toAccountId,
        parsed.confidences['toAccount']!,
      );
    } else {
      _printCategory(parsed.categoryId, parsed.confidences['category']!);
    }

    final lows = parsed.lowConfidenceFields;
    if (lows.isNotEmpty) {
      _writeln('');
      _writeln(
        '$_yellow⚠ Campos com baixa confiança: ${lows.join(', ')} $_reset',
      );
      _writeln(
        '$_dim Você poderá corrigir a seguir. Deixe em branco para manter. $_reset',
      );
    }

    _writeln('');
    _writeln('Opções: [Enter] salvar  [e] editar  [c] cancelar');
    _write('> ');
    final choice = _readLine()?.trim().toLowerCase();
    if (choice == 'c') return null;
    if (choice == 'e' || lows.isNotEmpty) {
      return _editAll(parsed);
    }
    return parsed;
  }

  void _printField(String label, String value, FieldConfidence c) {
    final marker = c == FieldConfidence.low
        ? '$_red●$_reset'
        : c == FieldConfidence.medium
        ? '$_yellow●$_reset'
        : '$_green●$_reset';
    _writeln(' $marker $label: $value ${_dim}(${c.name})$_reset');
  }

  void _printAmount(int? cents, FieldConfidence c) {
    final marker = c == FieldConfidence.low
        ? '$_red●$_reset'
        : c == FieldConfidence.medium
        ? '$_yellow●$_reset'
        : '$_green●$_reset';
    final val = cents != null
        ? 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}'
        : '-';
    _writeln(' $marker Valor: $val ${_dim}(${c.name})$_reset');
  }

  void _printAccount(String label, String? id, FieldConfidence c) {
    final marker = c == FieldConfidence.low
        ? '$_red●$_reset'
        : c == FieldConfidence.medium
        ? '$_yellow●$_reset'
        : '$_green●$_reset';
    final name = id != null ? _accountName(id) ?? id : '-';
    _writeln(' $marker $label: $name ${_dim}(${c.name})$_reset');
  }

  void _printCategory(String? id, FieldConfidence c) {
    final marker = c == FieldConfidence.low
        ? '$_red●$_reset'
        : c == FieldConfidence.medium
        ? '$_yellow●$_reset'
        : '$_green●$_reset';
    final name = id != null ? _categoryName(id) ?? id : '-';
    _writeln(' $marker Categoria: $name ${_dim}(${c.name})$_reset');
  }

  String? _accountName(String id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  String? _categoryName(String id) {
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return null;
  }

  // ── Wizard completo ────────────────────────────────────────────────

  Future<ParsedTransaction?> runWizard({ParsedTransaction? initial}) async {
    _clear();
    _header('Lançamento Rápido — assistente');
    _writeln('');

    // Tipo
    var type = initial?.type ?? await _pickType();

    // Descrição (antes do valor, para poder sugerir pelo histórico)
    var description = initial?.description ?? await _pickDescription();
    if (description == null) return null;

    // Sugestão estatística (task 58): mesma recomendação do Lançamento
    // Rápido da GUI, aceita com ↵ e sobrescrevível digitando.
    QuickSuggestion? sugg;
    if (initial == null && historyLoader != null) {
      try {
        final history = await historyLoader!();
        final needle = description.trim().toLowerCase();
        for (final s in rankQuickSuggestions(
          history,
          now: DateTime.now(),
          typeFilter: type,
        )) {
          if (s.description.trim().toLowerCase() == needle) {
            sugg = s;
            break;
          }
        }
      } catch (_) {}
      if (sugg != null) {
        final accName = _accountName(sugg.accountId) ?? sugg.accountId;
        final catName = sugg.categoryId != null
            ? (_categoryName(sugg.categoryId!) ?? sugg.categoryId)
            : null;
        _writeln('');
        _writeln(
          '$_cyan Sugestão do histórico:$_reset $description • '
          '${(sugg.amount.abs() / 100).toStringAsFixed(2)} • conta $accName'
          '${catName != null ? ' • categoria $catName' : ''}',
        );
        _write('Usar valor/conta/categoria da sugestão? [S/n]: ');
        final in_ = _readLine()?.trim().toLowerCase();
        if (in_ == 'n' || in_ == 'nao' || in_ == 'não') sugg = null;
      }
    }
    final useSugg = sugg != null;

    // Valor
    var amount =
        initial?.amountCents ??
        (useSugg ? sugg.amount.abs() : await _pickAmount());
    if (amount == null) return null;
    // Conta origem
    var accountId =
        initial?.accountId ??
        (useSugg ? sugg.accountId : await _pickAccount('Conta de origem'));
    if (accountId == null) return null;
    String? toAccountId = initial?.toAccountId;
    if (type == TransactionType.transfer) {
      toAccountId = await _pickAccount(
        'Conta de destino',
        excludeId: accountId,
      );
      if (toAccountId == null) return null;
    }
    // Categoria (só expense/income)
    String? categoryId = initial?.categoryId;
    if (type != TransactionType.transfer) {
      categoryId = await _pickCategory(
        initialCategoryId: useSugg && categoryId == null
            ? sugg.categoryId
            : categoryId,
        // categoria opcional — permite null
      );
    }

    // Se veio de initial com campos editáveis, deixa corrigir tudo
    if (initial != null) {
      final edited = await _editAll(
        ParsedTransaction(
          type: type,
          amountCents: amount,
          accountId: accountId,
          toAccountId: toAccountId,
          categoryId: categoryId,
          description: description,
          confidences: {
            'type': FieldConfidence.high,
            'amount': FieldConfidence.high,
            'account': FieldConfidence.high,
            'toAccount': FieldConfidence.high,
            'category': FieldConfidence.high,
            'description': FieldConfidence.high,
          },
          rawPhrase: initial.rawPhrase,
        ),
      );
      return edited;
    }

    return ParsedTransaction(
      type: type,
      amountCents: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      description: description,
      confidences: {
        'type': FieldConfidence.high,
        'amount': FieldConfidence.high,
        'account': FieldConfidence.high,
        'toAccount': FieldConfidence.high,
        'category': FieldConfidence.high,
        'description': FieldConfidence.high,
      },
    );
  }

  Future<ParsedTransaction> _editAll(ParsedTransaction p) async {
    _writeln('');
    _header('Editar campos (Enter para manter)');
    _writeln('');

    // Tipo
    _writeln('Tipo atual: ${p.type.label} [expense/income/transfer]');
    _write('Novo tipo: ');
    final tIn = _readLine()?.trim().toLowerCase();
    var type = p.type;
    if (tIn != null && tIn.isNotEmpty) {
      if (tIn.startsWith('inc') || tIn == 'receita')
        type = TransactionType.income;
      else if (tIn.startsWith('trans'))
        type = TransactionType.transfer;
      else if (tIn.startsWith('exp') || tIn == 'despesa')
        type = TransactionType.expense;
    }

    // Valor
    _writeln(
      'Valor atual: ${p.amountCents != null ? (p.amountCents! / 100).toStringAsFixed(2) : '-'}',
    );
    _write('Novo valor (ex: 50,00): ');
    var amount = p.amountCents;
    final aIn = _readLine()?.trim();
    if (aIn != null && aIn.isNotEmpty) {
      final parsed = _parseAmountInput(aIn);
      if (parsed != null) amount = parsed;
    }

    // Descrição
    _writeln('Descrição atual: ${p.description ?? '-'}');
    _write('Nova descrição: ');
    var desc = p.description;
    final dIn = _readLine();
    if (dIn != null && dIn.trim().isNotEmpty) desc = dIn.trim();

    // Conta
    _writeln(
      'Conta atual: ${p.accountId != null ? _accountName(p.accountId!) ?? p.accountId! : '-'}',
    );
    final newAcc = await _pickAccount(
      'Nova conta (Enter manter)',
      allowSkip: true,
    );
    var accId = p.accountId;
    if (newAcc != null) accId = newAcc;

    String? toAccId = p.toAccountId;
    if (type == TransactionType.transfer) {
      _writeln(
        'Destino atual: ${p.toAccountId != null ? _accountName(p.toAccountId!) ?? p.toAccountId! : '-'}',
      );
      final newTo = await _pickAccount(
        'Novo destino (Enter manter)',
        allowSkip: true,
        excludeId: accId,
      );
      if (newTo != null) toAccId = newTo;
    }

    String? catId = p.categoryId;
    if (type != TransactionType.transfer) {
      _writeln(
        'Categoria atual: ${p.categoryId != null ? _categoryName(p.categoryId!) ?? p.categoryId! : '-'}',
      );
      final newCat = await _pickCategory(
        allowSkip: true,
        initialCategoryId: catId,
      );
      if (newCat != null) catId = newCat;
      // permite limpar categoria: digite "-"
    }

    return ParsedTransaction(
      type: type,
      amountCents: amount,
      accountId: accId,
      toAccountId: toAccId,
      categoryId: type == TransactionType.transfer ? null : catId,
      description: desc,
      confidences: p.confidences,
      rawPhrase: p.rawPhrase,
    );
  }

  Future<TransactionType> _pickType() async {
    _writeln('Tipo:');
    _writeln('  1) Despesa (expense)');
    _writeln('  2) Receita (income)');
    _writeln('  3) Transferência (transfer)');
    while (true) {
      _write('Escolha [1-3, padrão 1]: ');
      final in_ = _readLine()?.trim();
      if (in_ == null || in_.isEmpty || in_ == '1')
        return TransactionType.expense;
      if (in_ == '2') return TransactionType.income;
      if (in_ == '3') return TransactionType.transfer;
      // também aceita nome
      final lower = in_.toLowerCase();
      if (lower.startsWith('exp')) return TransactionType.expense;
      if (lower.startsWith('inc') || lower == 'receita')
        return TransactionType.income;
      if (lower.startsWith('trans')) return TransactionType.transfer;
      _writeln('$_red Opção inválida $_reset');
    }
  }

  Future<int?> _pickAmount() async {
    while (true) {
      _write('Valor (ex: 50,00 ou 1500): ');
      final in_ = _readLine()?.trim();
      if (in_ == null || in_.isEmpty) {
        _writeln('$_red Valor é obrigatório $_reset');
        continue;
      }
      final parsed = _parseAmountInput(in_);
      if (parsed == null || parsed <= 0) {
        _writeln('$_red Valor inválido $_reset');
        continue;
      }
      return parsed;
    }
  }

  Future<String?> _pickDescription() async {
    _write('Descrição: ');
    final in_ = _readLine()?.trim();
    if (in_ == null || in_.isEmpty) return null;
    return in_;
  }

  Future<String?> _pickAccount(
    String label, {
    String? excludeId,
    bool allowSkip = false,
  }) async {
    final filtered = excludeId == null
        ? accounts
        : accounts.where((a) => a.id != excludeId).toList();
    if (filtered.isEmpty) {
      if (allowSkip) return null;
      _writeln('$_red Nenhuma conta disponível $_reset');
      return null;
    }
    _writeln('$label:');
    for (var i = 0; i < filtered.length; i++) {
      _writeln('  ${i + 1}) ${filtered[i].name} [${filtered[i].type}]');
    }
    while (true) {
      _write(
        'Escolha [1-${filtered.length}${allowSkip ? ', Enter manter' : ''}]: ',
      );
      final in_ = _readLine()?.trim();
      if (allowSkip && (in_ == null || in_.isEmpty)) return null;
      final idx = int.tryParse(in_ ?? '');
      if (idx != null && idx >= 1 && idx <= filtered.length) {
        return filtered[idx - 1].id;
      }
      _writeln('$_red Opção inválida $_reset');
    }
  }

  Future<String?> _pickCategory({
    String? initialCategoryId,
    bool allowSkip = false,
  }) async {
    if (categories.isEmpty) return null;
    _writeln('Categoria (opcional):');
    for (var i = 0; i < categories.length; i++) {
      final marker = categories[i].id == initialCategoryId ? ' *' : '';
      _writeln(
        '  ${i + 1}) ${categories[i].name} [${categories[i].type}]$marker',
      );
    }
    _writeln('  0) (sem categoria)');
    while (true) {
      _write(
        'Escolha [0-${categories.length}${allowSkip ? ', Enter manter' : ''}]: ',
      );
      final in_ = _readLine()?.trim();
      if (allowSkip && (in_ == null || in_.isEmpty)) return null;
      if (in_ == '0') return null;
      final idx = int.tryParse(in_ ?? '');
      if (idx != null && idx >= 1 && idx <= categories.length) {
        return categories[idx - 1].id;
      }
      _writeln('$_red Opção inválida $_reset');
    }
  }

  int? _parseAmountInput(String s) {
    var raw = s.trim().replaceAll('R\$', '').trim().replaceAll(' ', '');
    if (raw.contains('.') && raw.contains(',')) {
      raw = raw.replaceAll('.', '').replaceAll(',', '.');
    } else if (raw.contains(',')) {
      raw = raw.replaceAll(',', '.');
    }
    final v = double.tryParse(raw);
    if (v == null) return null;
    return (v * 100).round();
  }

  void showSuccess(String id, ParsedTransaction p) {
    _writeln('');
    _writeln('$_green$_bold✓ Transação criada com sucesso!$_reset');
    _writeln('  ID: $id');
    _writeln(
      '  ${p.type.label} • R\$ ${(p.amountCents! / 100).toStringAsFixed(2).replaceAll('.', ',')} • ${p.description}',
    );
    _writeln('  Conta: ${_accountName(p.accountId!) ?? p.accountId!}');
    if (p.toAccountId != null)
      _writeln('  Destino: ${_accountName(p.toAccountId!) ?? p.toAccountId!}');
    if (p.categoryId != null)
      _writeln('  Categoria: ${_categoryName(p.categoryId!) ?? p.categoryId!}');
    _writeln('');
    _writeln(
      _dim +
          'Sincronização enfileirada — será publicada nos relays Nostr na próxima sync.' +
          _reset,
    );
  }

  void showError(String msg) {
    _writeln('$_red✗ Erro: $msg$_reset');
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bestfin/cli/parse_result.dart';
import 'package:bestfin/core/constants/transaction_types.dart';

/// Ponte opcional para o LLM on-device (llama-server em :8087 no Linux).
///
/// Nunca dispara download/carregamento do modelo — só consulta se já
/// estiver pronto. Timeout curto (2s). Em qualquer falha, retorna null
/// e o chamador segue com a heurística pura.
class LlmBridge {
  LlmBridge({this.host = _defaultHost, this.port = _defaultPort});

  static const _defaultHost = '127.0.0.1';
  static const _defaultPort = 8087;

  /// Endereço do llama-server — injetável para testes com servidor fake.
  final String host;
  final int port;

  /// Verifica se o llama-server está respondendo.
  Future<bool> isReady({
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = timeout;
      final req = await client.get(host, port, '/health').timeout(timeout);
      final resp = await req.close().timeout(timeout);
      client.close();
      // llama.cpp retorna 200 mesmo sem modelo? Checa body.
      if (resp.statusCode == 200) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Tenta refinar um [ParsedTransaction] via LLM. Retorna um novo parsed
  /// com campos corrigidos quando o LLM tem alta confiança, ou null se
  /// indisponível.
  Future<ParsedTransaction?> refine(
    ParsedTransaction base,
    String phrase, {
    List<String>? accountNames,
    List<String>? categoryNames,
  }) async {
    if (!await isReady()) return null;
    try {
      final prompt = _buildPrompt(phrase, base, accountNames, categoryNames);
      final json = await _chat(prompt);
      if (json == null) return null;
      return _merge(base, json);
    } catch (_) {
      return null;
    }
  }

  String _buildPrompt(
    String phrase,
    ParsedTransaction base,
    List<String>? accountNames,
    List<String>? categoryNames,
  ) {
    final accounts = (accountNames ?? []).join(', ');
    final categories = (categoryNames ?? []).join(', ');
    return '''
Extraia campos de uma transação financeira a partir da frase.
Responda APENAS com JSON válido, sem markdown, com as chaves:
{"type":"expense|income|transfer","amount_cents":1234,"description":"...","account":"nome aproximado","to_account":"nome","category":"nome"}

Frase: "$phrase"
Tipo atual: ${base.type.name}
Valor atual (centavos): ${base.amountCents}
Contas disponíveis: [$accounts]
Categorias disponíveis: [$categories]

Regras:
- amount_cents é valor em centavos (ex: 50 reais = 5000)
- Se não conseguir extrair com confiança, use null para o campo
- type deve ser expense, income ou transfer
''';
  }

  Future<Map<String, dynamic>?> _chat(String prompt) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client
          .post(host, port, '/v1/chat/completions')
          .timeout(const Duration(seconds: 2));
      req.headers.set('Content-Type', 'application/json');
      final body = jsonEncode({
        'model': 'bestfin',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.2,
        'max_tokens': 300,
        'stream': false,
      });
      req.write(body);
      final resp = await req.close().timeout(const Duration(seconds: 4));
      if (resp.statusCode != 200) return null;
      final respBody = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 2));
      final decoded = jsonDecode(respBody) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final content = (choices.first as Map)['message']?['content'] as String?;
      if (content == null) return null;
      // Tenta extrair JSON do conteúdo (pode vir com texto extra)
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start == -1 || end == -1) return null;
      final jsonStr = content.substring(start, end + 1);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  ParsedTransaction _merge(ParsedTransaction base, Map<String, dynamic> json) {
    var type = base.type;
    final typeStr = json['type'] as String?;
    if (typeStr != null) {
      final t = TransactionType.values.where((e) => e.name == typeStr);
      if (t.isNotEmpty) type = t.first;
    }
    final amount = json['amount_cents'] is int
        ? json['amount_cents'] as int
        : base.amountCents;
    // description/category/account refinement via LLM is best-effort — we keep
    // heurística IDs for account/category, only refine description/type/amount.
    final desc = (json['description'] as String?)?.trim();
    return ParsedTransaction(
      type: type,
      amountCents: amount,
      accountId: base.accountId,
      toAccountId: base.toAccountId,
      categoryId: base.categoryId,
      description: (desc != null && desc.isNotEmpty) ? desc : base.description,
      confidences: base.confidences,
      rawPhrase: base.rawPhrase,
    );
  }

  // ── Chat / insights na TUI (task 60) ────────────────────────────────

  /// Conversa com o LLM local, token a token (SSE do llama-server).
  /// Em qualquer falha, o stream termina com evento de erro — o chamador
  /// degrada com mensagem clara (regra de ouro: LLM opcional, nunca
  /// bloqueante).
  Stream<String> chatStream(
    List<LlmMessage> messages, {
    String? system,
    double temperature = 0.4,
  }) async* {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client
          .post(host, port, '/v1/chat/completions')
          .timeout(const Duration(seconds: 3));
      req.headers.set('Content-Type', 'application/json');
      req.write(
        jsonEncode({
          'model': 'bestfin',
          'messages': [
            if (system != null) {'role': 'system', 'content': system},
            ...messages.map((m) => {'role': m.role, 'content': m.content}),
          ],
          'temperature': temperature,
          'stream': true,
        }),
      );
      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        yield '\x00ERRO: llama-server respondeu ${resp.statusCode}';
        return;
      }
      await for (final line
          in resp.transform(utf8.decoder).transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') return;
        try {
          final decoded = jsonDecode(data) as Map<String, dynamic>;
          final choices = decoded['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = (choices.first as Map)['delta']?['content'] as String?;
          if (delta != null && delta.isNotEmpty) yield delta;
        } catch (_) {
          // Linha parcial/keep-alive — ignora.
        }
      }
    } catch (e) {
      yield '\x00ERRO: $e';
    } finally {
      client.close();
    }
  }

  /// Resposta completa (sem streaming) — usada pelos insights on-demand.
  Future<String?> chatOnce(
    List<LlmMessage> messages, {
    String? system,
    int maxTokens = 500,
  }) async {
    if (!await isReady()) return null;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client
          .post(host, port, '/v1/chat/completions')
          .timeout(const Duration(seconds: 2));
      req.headers.set('Content-Type', 'application/json');
      req.write(
        jsonEncode({
          'model': 'bestfin',
          'messages': [
            if (system != null) {'role': 'system', 'content': system},
            ...messages.map((m) => {'role': m.role, 'content': m.content}),
          ],
          'temperature': 0.4,
          'max_tokens': maxTokens,
          'stream': false,
        }),
      );
      final resp = await req.close().timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return null;
      final respBody = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(respBody) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      return (choices.first as Map)['message']?['content'] as String?;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}

/// Uma mensagem da conversa com o LLM.
class LlmMessage {
  const LlmMessage(this.role, this.content);

  final String role; // 'system' | 'user' | 'assistant'
  final String content;
}

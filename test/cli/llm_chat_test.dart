import 'dart:convert';
import 'dart:io';

import 'package:bestfin/cli/llm_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sobe um servidor fake com o mesmo contrato do llama-server
/// (`/health`, `/v1/chat/completions` com stream SSE e sem streaming).
Future<HttpServer> _startFakeServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (request.uri.path == '/health') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }
    if (request.uri.path == '/v1/chat/completions') {
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final wantsStream = decoded['stream'] == true;
      request.response.headers.contentType = ContentType.json;
      if (wantsStream) {
        request.response.headers.set('Content-Type', 'text/event-stream');
        request.response.write(
          'data: {"choices":[{"delta":{"content":"Ol"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"a!"}}]}\n\n'
          'data: [DONE]\n\n',
        );
        await request.response.close();
      } else {
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Resposta do LLM fake.'},
              },
            ],
          }),
        );
        await request.response.close();
      }
      return;
    }
    request.response.statusCode = 404;
    await request.response.close();
  });
  return server;
}

void main() {
  late HttpServer server;
  late LlmBridge bridge;

  setUp(() async {
    server = await _startFakeServer();
    bridge = LlmBridge(host: '127.0.0.1', port: server.port);
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('isReady e chatOnce contra servidor fake', () async {
    expect(await bridge.isReady(), isTrue);
    final answer = await bridge.chatOnce([
      const LlmMessage('user', 'meus insights'),
    ]);
    expect(answer, 'Resposta do LLM fake.');
  });

  test('chatStream emite tokens em streaming (task 60)', () async {
    final tokens = await bridge.chatStream(const [
      LlmMessage('user', 'oi'),
    ]).toList();
    expect(tokens.join(), 'Ola!');
  });

  test(
    'fallback: sem servidor, chatOnce é null e stream termina com erro',
    () async {
      final dead = LlmBridge(host: '127.0.0.1', port: 1);
      expect(await dead.chatOnce(const [LlmMessage('user', 'oi')]), isNull);
      final tokens = await dead.chatStream(const [
        LlmMessage('user', 'oi'),
      ]).toList();
      expect(tokens.join(), startsWith('\x00ERRO'));
    },
  );
}

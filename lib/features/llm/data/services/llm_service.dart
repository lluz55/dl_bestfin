import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:llama_cpp_dart/llama_cpp_dart.dart' as ffi;
import 'package:bestfin/features/llm/domain/models/llm_metrics.dart';

// Sampling defaults — tuned for a focused financial assistant.
// Lower temperature = fewer hallucinations, more factual responses.
const _kChatTemp = 0.55;
const _kOneShotTemp = 0.30; // categorization/insights: more deterministic
const _kTopP = 0.90;
const _kMinP =
    0.05; // min-p cuts low-probability tokens; better than top-p alone
const _kRepeatPenalty = 1.05; // mild; avoids word repetition in long answers

class LlmService {
  // Linux: background llama-server process + persistent HTTP client
  Process? _serverProcess;
  HttpClient? _httpClient;
  StreamSubscription<String>?
  _stderrSub; // kept alive to surface server crashes
  List<Map<String, String>> _linuxMessages = [];

  // Android/others: native FFI via isolate engine
  ffi.LlamaEngine? _engine;
  ffi.EngineChat? _chat;

  String _systemPrompt = '';
  String _modelName = 'desconhecido';
  // Path to the mmproj file for vision support (Linux only)
  String? _mmProjPath;

  bool get isLoaded =>
      Platform.isLinux ? (_serverProcess != null) : (_engine != null);

  bool get supportsVision => Platform.isLinux && _mmProjPath != null;

  Future<void> load(
    String modelPath, {
    String systemPrompt = '',
    String? mmProjPath,
  }) async {
    _systemPrompt = systemPrompt;
    _modelName = p.basename(modelPath);
    _mmProjPath = mmProjPath;

    if (Platform.isLinux) {
      await dispose();

      // Kill any stale process still holding port 8087 (crash / hot-restart).
      // Use ss (iproute2) to find the PID by socket, then pkill as fallback.
      try {
        await Process.run('sh', [
          '-c',
          'ss -tlnp | grep :8087 | grep -o "pid=[0-9]*" | cut -d= -f2 | xargs -r kill -9',
        ]);
      } catch (_) {}
      try {
        await Process.run('pkill', ['-9', '-f', 'llama-server']);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 700));

      final serverBin =
          Platform.environment['LLAMA_SERVER_BIN'] ?? 'llama-server';
      final logicalCpus = Platform.numberOfProcessors;
      // Cap generation threads at 6 to prevent cache-thrashing on hyperthreaded/high-core CPUs.
      final genThreads = logicalCpus > 8 ? 6 : max(1, logicalCpus - 1);
      // Cap batch/prefill threads at 8.
      final batchThreads = logicalCpus > 8 ? 8 : logicalCpus;
      debugPrint(
        '[LLM] Iniciando $serverBin (gen=$genThreads t, batch=$batchThreads t, vision=${mmProjPath != null})',
      );

      final args = <String>[
        '-m', modelPath,
        '--port', '8087',
        // GPU Offload — fully offload layers to Vulkan GPU if compiled
        '-ngl', '99',
        // Context — use larger context when vision is enabled (image tokens)
        '-c', mmProjPath != null ? '8192' : '4096',
        // Threading
        '-t', '$genThreads',
        '-tb', '$batchThreads',
        // NOTE: -fa (Flash Attention) and -ctk/-ctv (KV quant) omitted:
        // both are unsupported on AMD RADV Vulkan and cause server crashes.
        // Batching
        '--cont-batching',
        '-b', '2048',
        '-ub', '256',
        // Single-user: 1 slot avoids memory duplication across parallel slots
        '-np', '1',
        // Raise server process priority (no root required for level 1)
        '--prio', '1',
      ];

      // Add mmproj for vision support if provided
      if (mmProjPath != null) {
        args.addAll(['--mmproj', mmProjPath]);
      }

      _serverProcess = await Process.start(serverBin, args);

      _httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(seconds: 120);

      final completer = Completer<void>();

      // Keep subscription alive for the lifetime of the process so crashes
      // after model load are visible in the terminal.
      _stderrSub = _serverProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            debugPrint('[LLM Server] $line');
            if (!completer.isCompleted &&
                (line.contains('server is listening') ||
                    line.contains('all slots are idle') ||
                    line.contains('all slots are ready') ||
                    line.contains('starting the main loop'))) {
              completer.complete();
            }
          });

      unawaited(
        _serverProcess!.exitCode.then((code) {
          debugPrint('[LLM] llama-server encerrou com código $code');
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('llama-server terminou com código $code'),
            );
          }
        }),
      );

      try {
        await completer.future.timeout(const Duration(seconds: 60));
        clearHistory();
      } catch (e, st) {
        debugPrint('[LLM] Falha ao iniciar llama-server: $e\n$st');
        await dispose();
        rethrow;
      }
    } else {
      // Try loading with GPU offload first; fall back to CPU-only if it fails.
      // On Android, GPU availability depends on the device's OpenCL/Vulkan driver.
      final gpuLayerCandidates = Platform.isAndroid ? [99, 0] : [99];
      for (final nGpuLayers in gpuLayerCandidates) {
        try {
          final modelParams = ffi.ModelParams(
            path: modelPath,
            gpuLayers: nGpuLayers,
          );
          const contextParams = ffi.ContextParams(nCtx: 4096);

          if (Platform.isMacOS || Platform.isIOS) {
            _engine = await ffi.LlamaEngine.spawnFromProcess(
              modelParams: modelParams,
              contextParams: contextParams,
            );
          } else {
            // Android: libllama.so directly exports all llama_* symbols.
            _engine = await ffi.LlamaEngine.spawn(
              libraryPath: 'libllama.so',
              modelParams: modelParams,
              contextParams: contextParams,
            );
          }

          _chat = await _engine!.createChat();
          if (_systemPrompt.isNotEmpty) {
            _chat!.addSystem(_systemPrompt);
          }
          debugPrint('[LLM] Modelo carregado (nGpuLayers=$nGpuLayers)');
          break;
        } catch (e) {
          await _chat?.dispose();
          _chat = null;
          await _engine?.dispose();
          _engine = null;
          if (nGpuLayers == 0) rethrow; // CPU also failed — propagate
          debugPrint('[LLM] GPU falhou ($e), tentando CPU puro...');
        }
      }
    }
  }

  /// POSTs [body] to the llama-server, retrying once with a fresh HttpClient
  /// on broken-pipe errors (errno 32) which happen when the server recycles
  /// an idle connection.
  Future<HttpClientResponse> _post(Map<String, dynamic> body) async {
    for (int attempt = 0; attempt <= 1; attempt++) {
      try {
        final req = await _httpClient!.postUrl(
          Uri.parse('http://127.0.0.1:8087/v1/chat/completions'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
        return await req.close();
      } on SocketException catch (e) {
        debugPrint('[LLM] SocketException (tentativa ${attempt + 1}): $e');
        if (attempt == 0) {
          _httpClient?.close(force: true);
          _httpClient = HttpClient()
            ..connectionTimeout = const Duration(seconds: 10)
            ..idleTimeout = const Duration(seconds: 120);
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        rethrow;
      }
    }
    throw StateError('unreachable');
  }

  /// Sends [userMessage] and returns a stream of regular token strings.
  /// [onMetrics] is called once after generation completes.
  /// [onThinkingToken] receives reasoning_content tokens separately (when [enableThinking] is true).
  /// [enableThinking] controls whether the model uses chain-of-thought reasoning per request.
  Stream<String> sendMessage(
    String userMessage, {
    void Function(LlmMetrics)? onMetrics,
    void Function(String)? onThinkingToken,
    bool enableThinking = false,
  }) {
    if (Platform.isLinux) {
      if (_serverProcess == null) {
        throw StateError('LlmService nao carregado no Linux');
      }

      final controller = StreamController<String>();
      final buffer = StringBuffer();
      final startTime = DateTime.now();
      DateTime? firstTokenTime;
      int tokenCount = 0;
      int? serverCompletionTokens;

      _linuxMessages.add({'role': 'user', 'content': userMessage});

      final body = <String, dynamic>{
        'messages': _linuxMessages,
        'stream': true,
        'temperature': _kChatTemp,
        'top_p': _kTopP,
        'min_p': _kMinP,
        'repeat_penalty': _kRepeatPenalty,
        'stream_options': {'include_usage': true},
        // Thinking control: per-request via chat_template_kwargs + budget
        'chat_template_kwargs': {'enable_thinking': enableThinking},
        if (!enableThinking) 'thinking_budget_tokens': 0,
      };

      _post(body)
          .then((response) {
            if (response.statusCode != 200) {
              controller.addError(
                Exception(
                  'Erro no servidor LLM: Codigo ${response.statusCode}',
                ),
              );
              controller.close();
              return;
            }

            StreamSubscription? sub;
            sub = response
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .listen(
                  (line) {
                    if (line.startsWith('data: ')) {
                      final dataStr = line.substring(6).trim();
                      if (dataStr == '[DONE]') return;
                      try {
                        final decoded = jsonDecode(dataStr);
                        // Collect server-reported usage from the final stats chunk
                        final usage = decoded['usage'];
                        if (usage != null) {
                          serverCompletionTokens =
                              usage['completion_tokens'] as int?;
                        }
                        final choices = decoded['choices'] as List? ?? [];
                        if (choices.isNotEmpty) {
                          final delta = choices[0]['delta'];
                          if (delta != null) {
                            // reasoning_content → thinking callback (not added to main stream)
                            final thinking = delta['reasoning_content'];
                            if (thinking != null && onThinkingToken != null) {
                              onThinkingToken(thinking as String);
                            }
                            // content → main stream
                            if (delta['content'] != null) {
                              final content = delta['content'] as String;
                              controller.add(content);
                              buffer.write(content);
                              tokenCount++;
                              firstTokenTime ??= DateTime.now();
                            }
                          }
                        }
                      } catch (_) {}
                    }
                  },
                  onError: (error) {
                    controller.addError(error);
                    controller.close();
                    sub?.cancel();
                  },
                  onDone: () {
                    if (buffer.isNotEmpty) {
                      _linuxMessages.add({
                        'role': 'assistant',
                        'content': buffer.toString(),
                      });
                    }
                    _trimHistory();
                    if (onMetrics != null) {
                      final endTime = DateTime.now();
                      final total = endTime.difference(startTime);
                      final ttft = firstTokenTime != null
                          ? firstTokenTime!.difference(startTime)
                          : Duration.zero;
                      final tokens = serverCompletionTokens ?? tokenCount;
                      final tps = tokens > 0 && total.inMilliseconds > 0
                          ? tokens / (total.inMilliseconds / 1000)
                          : 0.0;
                      onMetrics(
                        LlmMetrics(
                          timeToFirstToken: ttft,
                          totalTime: total,
                          tokensGenerated: tokens,
                          tokensPerSecond: tps,
                          modelName: _modelName,
                        ),
                      );
                    }
                    controller.close();
                    sub?.cancel();
                  },
                  cancelOnError: true,
                );
          })
          .catchError((error) {
            controller.addError(error);
            controller.close();
          });

      return controller.stream;
    } else {
      if (_chat == null) throw StateError('LlmService not loaded');

      final chat = _chat!;
      chat.addUser(userMessage);

      final ctrl = StreamController<String>();
      final startTime = DateTime.now();
      DateTime? firstTokenTime;
      int tokenCount = 0;

      () async {
        try {
          await for (final event in chat.generate(
            sampler: ffi.SamplerParams(
              temperature: _kChatTemp,
              topP: _kTopP,
              minP: _kMinP,
              repeatPenalty: _kRepeatPenalty,
            ),
          )) {
            if (event is ffi.TokenEvent && event.text.isNotEmpty) {
              ctrl.add(event.text);
              tokenCount++;
              firstTokenTime ??= DateTime.now();
            } else if (event is ffi.DoneEvent &&
                event.trailingText.isNotEmpty) {
              ctrl.add(event.trailingText);
            }
          }
          _trimHistory();
          if (onMetrics != null && tokenCount > 0) {
            final endTime = DateTime.now();
            final total = endTime.difference(startTime);
            final ttft = firstTokenTime != null
                ? firstTokenTime!.difference(startTime)
                : Duration.zero;
            final tps = total.inMilliseconds > 0
                ? tokenCount / (total.inMilliseconds / 1000)
                : 0.0;
            onMetrics(
              LlmMetrics(
                timeToFirstToken: ttft,
                totalTime: total,
                tokensGenerated: tokenCount,
                tokensPerSecond: tps,
                modelName: _modelName,
              ),
            );
          }
        } catch (e) {
          ctrl.addError(e);
        } finally {
          if (!ctrl.isClosed) ctrl.close();
        }
      }();

      return ctrl.stream;
    }
  }

  /// One-shot generation without chat history (for insights/categorization).
  /// [maxTokens] bounds output length — pass a small value (e.g. 20) for
  /// categorization prompts to avoid unnecessary generation.
  /// [enableThinking] is always false for one-shot calls (insights, categorization, OCR)
  /// since thinking would add latency without benefit for structured outputs.
  Future<String> generateOnce(String prompt, {int maxTokens = 512}) async {
    if (Platform.isLinux) {
      if (_serverProcess == null) {
        throw StateError('LlmService nao carregado no Linux');
      }

      final response = await _post({
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'stream': false,
        'temperature': _kOneShotTemp,
        'top_p': _kTopP,
        'min_p': _kMinP,
        'max_tokens': maxTokens,
        // Always disable thinking for one-shot calls (faster, deterministic)
        'chat_template_kwargs': {'enable_thinking': false},
        'thinking_budget_tokens': 0,
      });
      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao gerar resposta: Codigo ${response.statusCode}',
        );
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(responseBody);
      final choices = decoded['choices'] as List;
      if (choices.isNotEmpty) {
        final message = choices[0]['message'];
        if (message != null && message['content'] != null) {
          return (message['content'] as String).trim();
        }
      }
      throw Exception('Resposta vazia do servidor LLM');
    } else {
      if (_chat == null) throw StateError('LlmService not loaded');

      final chat = _chat!;
      // Save current conversation, run an isolated single-turn, then restore.
      final savedMessages = chat.messages.toList();
      chat.clearHistory();
      chat.addUser(prompt);

      final buffer = StringBuffer();
      try {
        await for (final event
            in chat
                .generate(
                  sampler: ffi.SamplerParams(
                    temperature: _kOneShotTemp,
                    topP: _kTopP,
                    minP: _kMinP,
                  ),
                  maxTokens: maxTokens,
                )
                .timeout(const Duration(seconds: 90))) {
          if (event is ffi.TokenEvent && event.text.isNotEmpty) {
            buffer.write(event.text);
          } else if (event is ffi.DoneEvent && event.trailingText.isNotEmpty) {
            buffer.write(event.trailingText);
          }
        }
      } finally {
        // Restore conversation regardless of success/failure.
        chat.clearHistory();
        for (final m in savedMessages) {
          chat.addMessage(m);
        }
      }
      return buffer.toString().trim();
    }
  }

  /// Analyzes an image with an optional text prompt using the vision model.
  /// Only available on Linux when the mmproj file is loaded.
  /// Throws [UnsupportedError] on non-Linux or when mmproj is not loaded.
  Future<String> analyzeImage(
    Uint8List imageBytes,
    String prompt, {
    int maxTokens = 400,
  }) async {
    if (!Platform.isLinux || _serverProcess == null) {
      throw UnsupportedError('analyzeImage requer llama-server no Linux.');
    }
    if (_mmProjPath == null) {
      throw UnsupportedError(
        'analyzeImage requer o arquivo mmproj para visão. Baixe o módulo de visão nas configurações.',
      );
    }

    final base64Image = base64Encode(imageBytes);
    final response = await _post({
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
            },
            {'type': 'text', 'text': prompt},
          ],
        },
      ],
      'stream': false,
      'temperature': _kOneShotTemp,
      'top_p': _kTopP,
      'min_p': _kMinP,
      'max_tokens': maxTokens,
    });

    if (response.statusCode != 200) {
      throw Exception('Erro ao analisar imagem: HTTP ${response.statusCode}');
    }

    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    final choices = decoded['choices'] as List;
    if (choices.isNotEmpty) {
      final message = choices[0]['message'];
      if (message != null && message['content'] != null) {
        return (message['content'] as String).trim();
      }
    }
    throw Exception('Resposta vazia do servidor LLM para análise de imagem');
  }

  void _trimHistory() {
    if (Platform.isLinux) {
      if (_linuxMessages.isEmpty) return;
      final system = _linuxMessages
          .where((m) => m['role'] == 'system')
          .toList();
      final conversation = _linuxMessages
          .where((m) => m['role'] != 'system')
          .toList();
      if (conversation.length > 20) {
        _linuxMessages = [
          ...system,
          ...conversation.sublist(conversation.length - 20),
        ];
      }
    } else {
      if (_chat == null) return;
      final msgs = _chat!.messages;
      if (msgs.isEmpty) return;
      final system = msgs.where((m) => m.role == 'system').toList();
      final conversation = msgs.where((m) => m.role != 'system').toList();
      if (conversation.length > 20) {
        _chat!.clearHistory();
        for (final m in system) _chat!.addMessage(m);
        for (final m in conversation.sublist(conversation.length - 20)) {
          _chat!.addMessage(m);
        }
      }
    }
  }

  void clearHistory() {
    if (Platform.isLinux) {
      _linuxMessages = _systemPrompt.isNotEmpty
          ? [
              {'role': 'system', 'content': _systemPrompt},
            ]
          : [];
    } else {
      if (_chat == null) return;
      _chat!.clearHistory();
      if (_systemPrompt.isNotEmpty) {
        _chat!.addSystem(_systemPrompt);
      }
    }
  }

  void updateSystemPrompt(String systemPrompt) {
    if (systemPrompt == _systemPrompt) return;
    _systemPrompt = systemPrompt;
    if (Platform.isLinux) {
      if (_linuxMessages.isNotEmpty && _linuxMessages[0]['role'] == 'system') {
        _linuxMessages[0]['content'] = systemPrompt;
      } else if (_systemPrompt.isNotEmpty) {
        _linuxMessages.insert(0, {'role': 'system', 'content': systemPrompt});
      }
    } else {
      if (_chat != null) {
        final msgs = _chat!.messages;
        final hasSystem = msgs.isNotEmpty && msgs.first.role == 'system';
        final nonSystem = hasSystem ? msgs.skip(1) : msgs;

        _chat!.clearHistory();
        if (systemPrompt.isNotEmpty) {
          _chat!.addSystem(systemPrompt);
        }
        for (final m in nonSystem) {
          _chat!.addMessage(m);
        }
      }
    }
  }

  Future<void> dispose() async {
    if (Platform.isLinux) {
      await _stderrSub?.cancel();
      _stderrSub = null;
      _httpClient?.close(force: true);
      _httpClient = null;
      if (_serverProcess != null) {
        debugPrint('[LLM] Finalizando Llama-Server...');
        _serverProcess!.kill(ProcessSignal.sigterm);
        try {
          await _serverProcess!.exitCode.timeout(const Duration(seconds: 4));
        } on TimeoutException {
          debugPrint('[LLM] SIGTERM ignorado, enviando SIGKILL...');
          _serverProcess!.kill(ProcessSignal.sigkill);
          await _serverProcess!.exitCode.timeout(
            const Duration(seconds: 2),
            onTimeout: () => 0,
          );
        }
        _serverProcess = null;
        // Brief pause so the OS releases the port before a potential restart.
        await Future.delayed(const Duration(milliseconds: 200));
      }
      _linuxMessages.clear();
    } else {
      await _chat?.dispose();
      _chat = null;
      await _engine?.dispose();
      _engine = null;
    }
  }
}

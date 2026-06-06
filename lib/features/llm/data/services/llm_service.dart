import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:llama_cpp_dart/llama_cpp_dart.dart' as ffi;
import 'package:bestfin/features/llm/domain/models/ai_model_type.dart';
import 'package:bestfin/features/llm/domain/models/llm_metrics.dart';

// Sampling defaults — tuned for a focused financial assistant.
const _kChatTemp = 0.55;
const _kOneShotTemp = 0.30; // router/categorization: more deterministic
const _kTopP = 0.90;
const _kMinP = 0.05;
const _kRepeatPenalty = 1.05;

class LlmService {
  static const _liteRtMethodChannel = MethodChannel(
    'com.bestfin.bestfin/litert_lm',
  );
  static const _liteRtStreamChannel = EventChannel(
    'com.bestfin.bestfin/litert_lm_stream',
  );

  // Linux: background llama-server process + persistent HTTP client
  Process? _serverProcess;
  HttpClient? _httpClient;
  StreamSubscription<String>? _stderrSub;
  List<Map<String, String>> _linuxMessages = [];

  // Android/others: new isolate-based LlamaEngine + EngineChat
  ffi.LlamaEngine? _engine;
  ffi.EngineChat? _chat;
  bool _androidLiteRtLoaded = false;

  // Serializes concurrent calls on non-Linux
  final _LlmLock _lock = _LlmLock();

  String _systemPrompt = '';
  String _modelName = 'desconhecido';
  String? _mmProjPath;
  AiModelRuntime? _runtime;

  bool get isLoaded => Platform.isLinux
      ? (_serverProcess != null)
      : (_androidLiteRtLoaded || _engine != null);

  bool get supportsVision => Platform.isLinux
      ? _mmProjPath != null
      : (_runtime == AiModelRuntime.liteRtLm
            ? false
            : (_engine?.multimodalLoaded ?? false));

  Future<void> load(
    String modelPath, {
    AiModelType? modelType,
    String systemPrompt = '',
    String? mmProjPath,
  }) async {
    _systemPrompt = systemPrompt;
    _modelName = p.basename(modelPath);
    _mmProjPath = mmProjPath;
    _runtime = modelType?.runtime;

    if (Platform.isLinux) {
      await dispose();

      // Kill any stale process still holding port 8087.
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
      final genThreads = logicalCpus > 8 ? 6 : max(1, logicalCpus - 1);
      final batchThreads = logicalCpus > 8 ? 8 : logicalCpus;
      debugPrint(
        '[LLM] Iniciando $serverBin (gen=$genThreads t, batch=$batchThreads t, vision=${mmProjPath != null})',
      );

      final args = <String>[
        '-m',
        modelPath,
        '--port',
        '8087',
        '-ngl',
        '99',
        '-c',
        mmProjPath != null ? '8192' : '4096',
        '-t',
        '$genThreads',
        '-tb',
        '$batchThreads',
        '--cont-batching',
        '-b',
        '2048',
        '-ub',
        '256',
        '-np',
        '1',
        '--prio',
        '1',
      ];

      if (mmProjPath != null) {
        args.addAll(['--mmproj', mmProjPath]);
      }

      _serverProcess = await Process.start(serverBin, args);

      _httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(seconds: 120);

      final completer = Completer<void>();

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
        await clearHistory();
      } catch (e, st) {
        debugPrint('[LLM] Falha ao iniciar llama-server: $e\n$st');
        await dispose();
        rethrow;
      }
    } else if (Platform.isAndroid &&
        (modelType?.runtime == AiModelRuntime.liteRtLm ||
            modelPath.endsWith('.litertlm'))) {
      await _loadAndroidLiteRt(modelPath, modelType: modelType);
    } else {
      // Android / macOS / iOS: LlamaEngine (isolate-based, new API)
      await _lock.synchronized(() async {
        await _disposeEngine();

        final libraryPath = Platform.isAndroid
            ? 'libllama.so'
            : 'libllama.dylib'; // macOS / iOS

        final contextSize = Platform.isAndroid
            ? (mmProjPath != null ? 4096 : 2048)
            : (mmProjPath != null ? 8192 : 4096);
        final multimodalParams = mmProjPath != null
            ? ffi.MultimodalParams(mmprojPath: mmProjPath)
            : null;

        // Android OpenCL/GGML can crash inside llama_decode after the model
        // loads successfully, so load CPU-only there instead of relying on a
        // load-time GPU fallback.
        final gpuLayerCandidates = Platform.isAndroid ? [0] : [99];
        for (final nGpuLayers in gpuLayerCandidates) {
          try {
            final androidThreads = max(
              1,
              Platform.numberOfProcessors > 6
                  ? 4
                  : Platform.numberOfProcessors - 1,
            );
            _engine = await ffi.LlamaEngine.spawn(
              libraryPath: libraryPath,
              modelParams: ffi.ModelParams(
                path: modelPath,
                gpuLayers: nGpuLayers,
              ),
              contextParams: Platform.isAndroid
                  ? ffi.ContextParams(
                      nCtx: contextSize,
                      nBatch: 512,
                      nUbatch: 256,
                      nThreads: androidThreads,
                      nThreadsBatch: androidThreads,
                    )
                  : ffi.ContextParams(nCtx: contextSize),
              multimodalParams: multimodalParams,
            );
            debugPrint('[LLM] Modelo carregado (nGpuLayers=$nGpuLayers)');
            break;
          } catch (e) {
            await _engine?.dispose();
            _engine = null;
            if (nGpuLayers == 0) rethrow;
            debugPrint('[LLM] GPU falhou ($e), tentando CPU puro...');
          }
        }

        _chat = await _engine!.createChat();
        if (_systemPrompt.isNotEmpty) {
          _chat!.addSystem(_systemPrompt);
        }
      });
    }
  }

  String _cleanStructuredResponse(String response) {
    final trimmed = response.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    final lines = trimmed.split('\n').toList();
    if (lines.isNotEmpty && lines.first.trim().startsWith('```')) {
      lines.removeAt(0);
    }
    if (lines.isNotEmpty && lines.last.trim() == '```') {
      lines.removeLast();
    }
    return lines.join('\n').trim();
  }

  String _withThinkingDirective(String userMessage, bool enableThinking) {
    final lowerModel = _modelName.toLowerCase();
    final isQwen3 = lowerModel.contains('qwen3');
    if (!isQwen3) return userMessage;

    // Qwen3 supports a hard chat-template switch when the runtime exposes it.
    // LiteRT-LM currently receives plain prompts through the platform channel,
    // so use Qwen's documented per-turn soft switch.
    final directive = enableThinking ? '/think' : '/no_think';
    return '$directive\n$userMessage';
  }

  _ThinkingSplit _splitThinkingResponse(String response) {
    const openTag = '<think>';
    const closeTag = '</think>';

    final close = response.indexOf(closeTag);
    if (close >= 0) {
      final open = response.indexOf(openTag);
      final thinkingStart = open >= 0 && open < close
          ? open + openTag.length
          : 0;
      final answerStart = close + closeTag.length;
      return _ThinkingSplit(
        thinking: response.substring(thinkingStart, close).trim(),
        answer: response.substring(answerStart).trimLeft(),
      );
    }

    final open = response.indexOf(openTag);
    if (open >= 0) {
      return _ThinkingSplit(
        thinking: response.substring(open + openTag.length).trimLeft(),
        answer: '',
      );
    }

    final trimmedLeft = response.trimLeft();
    if (_isPartialThinkTag(trimmedLeft)) {
      return const _ThinkingSplit(thinking: '', answer: '');
    }

    return _ThinkingSplit(thinking: '', answer: response);
  }

  bool _isPartialThinkTag(String text) {
    if (text.isEmpty) return true;
    const openTag = '<think>';
    return openTag.startsWith(text) && text.length < openTag.length;
  }

  Stream<String> _sendAndroidLiteRtMessage(
    String userMessage, {
    void Function(LlmMetrics)? onMetrics,
    void Function(String)? onThinkingToken,
    bool enableThinking = false,
  }) {
    return _lock.synchronizedStream(() {
      if (!_androidLiteRtLoaded) throw StateError('LiteRT-LM not loaded');

      final prompt = _withThinkingDirective(userMessage, enableThinking);
      final requestId = DateTime.now().microsecondsSinceEpoch.toString();
      final ctrl = StreamController<String>();
      final buffer = StringBuffer();
      final rawBuffer = StringBuffer();
      var visibleLength = 0;
      var thinkingLength = 0;
      final startTime = DateTime.now();
      DateTime? firstTokenTime;
      int tokenCount = 0;
      StreamSubscription<dynamic>? sub;

      ctrl.onListen = () async {
        sub = _liteRtStreamChannel.receiveBroadcastStream().listen(
          (event) {
            if (event is! Map) return;
            if (event['requestId'] != requestId) return;

            final type = event['type'];
            if (type == 'token') {
              final text = event['text'] as String? ?? '';
              if (text.isEmpty) return;
              tokenCount++;
              firstTokenTime ??= DateTime.now();
              rawBuffer.write(text);
              final parsed = _splitThinkingResponse(rawBuffer.toString());
              if (parsed.thinking.length > thinkingLength &&
                  onThinkingToken != null) {
                onThinkingToken(parsed.thinking.substring(thinkingLength));
                thinkingLength = parsed.thinking.length;
              }
              if (parsed.answer.length > visibleLength) {
                final visibleToken = parsed.answer.substring(visibleLength);
                visibleLength = parsed.answer.length;
                buffer.write(visibleToken);
                ctrl.add(visibleToken);
              }
            } else if (type == 'error') {
              ctrl.addError(Exception(event['message'] ?? 'Erro LiteRT-LM'));
              unawaited(ctrl.close());
            } else if (type == 'done') {
              if (buffer.isNotEmpty) {
                _trimHistory();
              }
              if (onMetrics != null) {
                final endTime = DateTime.now();
                final total = endTime.difference(startTime);
                final ttft = firstTokenTime != null
                    ? firstTokenTime!.difference(startTime)
                    : Duration.zero;
                final tps = tokenCount > 0 && total.inMilliseconds > 0
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
              unawaited(ctrl.close());
            }
          },
          onError: (error) {
            ctrl.addError(error);
            unawaited(ctrl.close());
          },
        );

        try {
          await _liteRtMethodChannel.invokeMethod<bool>('sendMessage', {
            'prompt': prompt,
            'requestId': requestId,
          });
        } catch (e, st) {
          ctrl.addError(e, st);
          await ctrl.close();
        }
      };

      ctrl.onCancel = () async {
        await _liteRtMethodChannel
            .invokeMethod<bool>('cancel', {'requestId': requestId})
            .catchError((_) => false);
        await sub?.cancel();
      };

      ctrl.onPause = () => sub?.pause();
      ctrl.onResume = () => sub?.resume();

      return ctrl.stream;
    });
  }

  Future<void> _loadAndroidLiteRt(
    String modelPath, {
    AiModelType? modelType,
  }) async {
    await _lock.synchronized(() async {
      await _disposeAndroidLiteRt();
      await _disposeEngine();
      _androidLiteRtLoaded = false;
      final loaded = await _liteRtMethodChannel
          .invokeMethod<bool>('loadModel', {
            'modelPath': modelPath,
            'systemPrompt': _systemPrompt,
            'temperature': _kChatTemp,
            'topP': _kTopP,
            'maxTokens': 768,
            'useGpu': modelType?.preferGpu ?? false,
          });
      _androidLiteRtLoaded = loaded ?? false;
      if (!_androidLiteRtLoaded) {
        throw Exception('LiteRT-LM nao confirmou o carregamento do modelo');
      }
    });
  }

  /// POSTs [body] to the llama-server, retrying once on broken-pipe errors.
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

  /// Sends [userMessage] and returns a stream of token strings.
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
                        final usage = decoded['usage'];
                        if (usage != null) {
                          serverCompletionTokens =
                              usage['completion_tokens'] as int?;
                        }
                        final choices = decoded['choices'] as List? ?? [];
                        if (choices.isNotEmpty) {
                          final delta = choices[0]['delta'];
                          if (delta != null) {
                            final thinking = delta['reasoning_content'];
                            if (thinking != null && onThinkingToken != null) {
                              onThinkingToken(thinking as String);
                            }
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
    } else if (Platform.isAndroid && _androidLiteRtLoaded) {
      return _sendAndroidLiteRtMessage(
        userMessage,
        onMetrics: onMetrics,
        onThinkingToken: onThinkingToken,
        enableThinking: enableThinking,
      );
    } else {
      // Android/non-Linux: EngineChat
      return _lock.synchronizedStream(() {
        if (_chat == null) throw StateError('LlmService not loaded');

        final ctrl = StreamController<String>();
        final buffer = StringBuffer();
        final startTime = DateTime.now();
        DateTime? firstTokenTime;
        int tokenCount = 0;

        _chat!.addUser(_withThinkingDirective(userMessage, enableThinking));

        const sampler = ffi.SamplerParams(
          temperature: _kChatTemp,
          topP: _kTopP,
          minP: _kMinP,
          repeatPenalty: _kRepeatPenalty,
        );

        final maxChatTokens = Platform.isAndroid ? 768 : 4096;

        final rawBuffer = StringBuffer();
        var visibleLength = 0;
        var thinkingLength = 0;

        _chat!
            .generate(sampler: sampler, maxTokens: maxChatTokens)
            .listen(
              (event) {
                if (event is ffi.TokenEvent) {
                  rawBuffer.write(event.text);
                  final parsed = _splitThinkingResponse(rawBuffer.toString());
                  if (parsed.thinking.length > thinkingLength &&
                      onThinkingToken != null) {
                    onThinkingToken(parsed.thinking.substring(thinkingLength));
                    thinkingLength = parsed.thinking.length;
                  }
                  if (parsed.answer.length > visibleLength) {
                    final visibleToken = parsed.answer.substring(visibleLength);
                    visibleLength = parsed.answer.length;
                    ctrl.add(visibleToken);
                    buffer.write(visibleToken);
                  }
                  tokenCount++;
                  firstTokenTime ??= DateTime.now();
                }
                // ShiftEvent / DoneEvent: no extra action needed
              },
              onDone: () {
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
                if (!ctrl.isClosed) ctrl.close();
              },
              onError: (error) {
                ctrl.addError(error);
                if (!ctrl.isClosed) ctrl.close();
              },
            );

        return ctrl.stream;
      });
    }
  }

  /// One-shot generation without chat history (router/insights/categorization).
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
    } else if (Platform.isAndroid && _androidLiteRtLoaded) {
      return _lock.synchronized(() async {
        final response = await _liteRtMethodChannel
            .invokeMethod<String>('generateOnce', {
              'prompt': _withThinkingDirective(prompt, false),
              'requestId': DateTime.now().microsecondsSinceEpoch.toString(),
              'maxTokens': maxTokens,
              'temperature': _kOneShotTemp,
              'topP': _kTopP,
            });
        return _cleanStructuredResponse(
          _splitThinkingResponse(response ?? '').answer,
        );
      });
    } else {
      if (_engine == null) throw StateError('LlmService not loaded');

      return _lock.synchronized(() async {
        final chat = _chat;
        if (chat == null) throw StateError('Chat not initialized');

        // Save current messages, excluding the system prompt
        final savedMessages = chat.messages
            .where((m) => m.role != 'system')
            .toList();

        // Clear history to run stateless generation
        chat.clearHistory();

        // Add the prompt
        chat.addUser(_withThinkingDirective(prompt, false));

        const sampler = ffi.SamplerParams(
          temperature: _kOneShotTemp,
          topP: _kTopP,
          minP: _kMinP,
        );

        final buffer = StringBuffer();
        try {
          await for (final event in chat.generate(
            sampler: sampler,
            maxTokens: maxTokens,
          )) {
            if (event is ffi.TokenEvent) {
              buffer.write(event.text);
            }
          }
          return _splitThinkingResponse(buffer.toString()).answer.trim();
        } finally {
          // Restore the system prompt and saved history
          chat.clearHistory();
          if (_systemPrompt.isNotEmpty) {
            chat.addSystem(_systemPrompt);
          }
          for (final m in savedMessages) {
            chat.addMessage(m);
          }
        }
      });
    }
  }

  /// Analyzes an image using the vision model (Linux + mmproj only).
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
        'analyzeImage requer o arquivo mmproj. Baixe o módulo de visão nas configurações.',
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
      final conv = _linuxMessages.where((m) => m['role'] != 'system').toList();
      if (conv.length > 20) {
        _linuxMessages = [...system, ...conv.sublist(conv.length - 20)];
      }
    } else {
      final chat = _chat;
      if (chat == null) return;
      final msgs = chat.messages.toList();
      final systemMsgs = msgs.where((m) => m.role == 'system').toList();
      final conv = msgs.where((m) => m.role != 'system').toList();
      if (conv.length > 20) {
        final trimmed = conv.sublist(conv.length - 20);
        chat.clearHistory();
        for (final m in systemMsgs) {
          chat.addMessage(m);
        }
        for (final m in trimmed) {
          chat.addMessage(m);
        }
      }
    }
  }

  void _clearHistoryUnlocked() {
    if (Platform.isLinux) {
      _linuxMessages = _systemPrompt.isNotEmpty
          ? [
              {'role': 'system', 'content': _systemPrompt},
            ]
          : [];
    } else if (Platform.isAndroid && _androidLiteRtLoaded) {
      unawaited(
        _liteRtMethodChannel.invokeMethod<bool>('clearHistory', {
          'systemPrompt': _systemPrompt,
        }),
      );
    } else {
      _chat?.clearHistory();
      if (_systemPrompt.isNotEmpty) {
        _chat?.addSystem(_systemPrompt);
      }
    }
  }

  Future<void> clearHistory() async {
    if (Platform.isLinux) {
      _clearHistoryUnlocked();
    } else if (Platform.isAndroid && _androidLiteRtLoaded) {
      await _liteRtMethodChannel.invokeMethod<bool>('clearHistory', {
        'systemPrompt': _systemPrompt,
      });
    } else {
      await _lock.synchronized(() async {
        _clearHistoryUnlocked();
      });
    }
  }

  void _updateSystemPromptUnlocked(String systemPrompt) {
    _systemPrompt = systemPrompt;
    if (Platform.isLinux) {
      if (_linuxMessages.isNotEmpty && _linuxMessages[0]['role'] == 'system') {
        _linuxMessages[0]['content'] = systemPrompt;
      } else if (_systemPrompt.isNotEmpty) {
        _linuxMessages.insert(0, {'role': 'system', 'content': systemPrompt});
      }
    } else if (Platform.isAndroid && _androidLiteRtLoaded) {
      unawaited(
        _liteRtMethodChannel.invokeMethod<bool>('clearHistory', {
          'systemPrompt': _systemPrompt,
        }),
      );
    } else {
      final chat = _chat;
      if (chat == null) return;
      // Preserve non-system messages while replacing the system prompt
      final conv = chat.messages.where((m) => m.role != 'system').toList();
      chat.clearHistory();
      if (_systemPrompt.isNotEmpty) {
        chat.addSystem(_systemPrompt);
      }
      for (final m in conv) {
        chat.addMessage(m);
      }
    }
  }

  Future<void> updateSystemPrompt(String systemPrompt) async {
    if (Platform.isLinux) {
      _updateSystemPromptUnlocked(systemPrompt);
    } else if (Platform.isAndroid && _androidLiteRtLoaded) {
      _systemPrompt = systemPrompt;
      await _liteRtMethodChannel.invokeMethod<bool>('clearHistory', {
        'systemPrompt': _systemPrompt,
      });
    } else {
      await _lock.synchronized(() async {
        _updateSystemPromptUnlocked(systemPrompt);
      });
    }
  }

  Future<void> _disposeEngine() async {
    await _chat?.dispose().catchError((_) {});
    _chat = null;
    await _engine?.dispose().catchError((_) {});
    _engine = null;
  }

  Future<void> _disposeAndroidLiteRt() async {
    if (!_androidLiteRtLoaded) return;
    await _liteRtMethodChannel
        .invokeMethod<bool>('dispose')
        .catchError((_) => false);
    _androidLiteRtLoaded = false;
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
        await Future.delayed(const Duration(milliseconds: 200));
      }
      _linuxMessages.clear();
    } else {
      await _lock.synchronized(() async {
        await _disposeAndroidLiteRt();
        await _disposeEngine();
      });
    }
  }
}

class _LlmLock {
  Future<void> _last = Future.value();

  Future<T> synchronized<T>(Future<T> Function() action) async {
    final previous = _last;
    final completer = Completer<void>();
    _last = completer.future;
    try {
      await previous;
      return await action();
    } finally {
      completer.complete();
    }
  }

  Stream<T> synchronizedStream<T>(Stream<T> Function() streamCreator) {
    final controller = StreamController<T>(sync: true);
    StreamSubscription<T>? subscription;
    Completer<void>? lockCompleter;

    controller.onListen = () async {
      final previous = _last;
      lockCompleter = Completer<void>();
      _last = lockCompleter!.future;

      try {
        await previous;
        if (controller.isClosed) {
          lockCompleter?.complete();
          return;
        }

        final sourceStream = streamCreator();
        subscription = sourceStream.listen(
          (data) {
            if (!controller.isClosed) {
              controller.add(data);
            }
          },
          onError: (err, stack) {
            if (!controller.isClosed) {
              controller.addError(err, stack);
            }
            unawaited(subscription?.cancel());
            if (!controller.isClosed) {
              controller.close();
            }
            lockCompleter?.complete();
          },
          onDone: () {
            if (!controller.isClosed) {
              controller.close();
            }
            lockCompleter?.complete();
          },
        );
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
          await controller.close();
        }
        lockCompleter?.complete();
      }
    };

    controller.onCancel = () async {
      await subscription?.cancel();
      lockCompleter?.complete();
    };

    controller.onPause = () => subscription?.pause();
    controller.onResume = () => subscription?.resume();

    return controller.stream;
  }
}

class _ThinkingSplit {
  final String thinking;
  final String answer;

  const _ThinkingSplit({required this.thinking, required this.answer});
}

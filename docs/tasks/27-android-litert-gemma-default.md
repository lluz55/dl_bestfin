# Tarefa 27 - Gemma 3n via LiteRT-LM como LLM Padrao no Android

> **Fase:** 4 - AI & Sync
> **Prioridade:** Vermelha / Alta
> **Estimativa:** Grande
> **Pre-requisitos:** 18-ai-features, 25-ai-expansion, 26-android-native-llm
> **Plataforma alvo:** Android

## Descricao

Implementar uma rota alternativa ao backend Android atual de LLM, usando **Google LiteRT-LM** para executar o modelo **`google/gemma-3n-E2B-it-litert-lm`** em formato `.litertlm`, preferencialmente o artefato **int4** (`gemma-3n-E2B-it-int4.litertlm`) quando disponivel, e tornar essa rota o **padrao no Android**.

O Linux deve continuar usando o fluxo atual com `llama-server`/Vulkan. O backend Android baseado em `llama_cpp_dart`, bibliotecas GGML/llama e o caminho nativo planejado na Tarefa 26 passam a ser fallback ou caminho de compatibilidade, nao a experiencia principal.

Fontes tecnicas verificadas:

- LiteRT GenAI: https://developers.google.com/edge/litert/genai/overview
- LiteRT-LM Kotlin API: https://github.com/google-ai-edge/LiteRT-LM/blob/main/docs/api/kotlin/getting_started.md
- Modelo Gemma 3n E2B LiteRT-LM: https://huggingface.co/google/gemma-3n-E2B-it-litert-lm

## Motivacao

O Android atual carrega `libllama.so`/GGML via FFI e bibliotecas nativas empacotadas manualmente. Isso ja exigiu tratamento de linker, ordem de carregamento de `.so`, fallback CPU-only e ajustes de estabilidade. LiteRT-LM e a familia Gemma 3n foram desenhadas especificamente para inferencia GenAI on-device com backends CPU/GPU/NPU, cache, conversas, streaming e suporte multimodal.

Usar Gemma 3n E2B via LiteRT-LM no Android reduz o acoplamento com `llama.cpp`, aproxima o app da stack oficial Google AI Edge e melhora a chance de suporte futuro para aceleradores Android.

## Decisoes de Arquitetura

- Android usa **LiteRT-LM Kotlin API** diretamente por `MethodChannel` e `EventChannel`.
- Dart continua expondo a mesma API publica de `LlmService`: `load`, `sendMessage`, `generateOnce`, `dispose`, `isLoaded` e metricas.
- Linux permanece inalterado com `llama-server`.
- O modelo Android padrao passa a ser `Gemma 3n E2B IT LiteRT-LM`.
- O download Android passa a aceitar `.litertlm`, com validacao por tamanho esperado e armazenamento em `getExternalStorageDirectory()/llm`.
- O backend Android deve ser selecionavel internamente por enum/configuracao para manter fallback `llama_cpp_dart` durante a migracao.
- Prompts financeiros continuam sendo construidos no Dart por `FinancialContextBuilder`; Kotlin recebe apenas prompt/sistema ja sanitizados.
- Dados financeiros nao saem do dispositivo. Nao adicionar API cloud como fallback silencioso.

## T1 - Model Registry e Modelo Padrao Android

- [ ] Estender `lib/features/llm/domain/models/ai_model_type.dart` com `gemma3nE2bLiteRt`.
- [ ] Definir:
  - `displayName`: `Gemma 3n E2B (LiteRT, Android)`
  - `fileName`: `gemma-3n-E2B-it-int4.litertlm`
  - `url`: URL oficial/resolvida do Hugging Face para `google/gemma-3n-E2B-it-litert-lm`.
  - `sizeBytes`: tamanho esperado do artefato escolhido.
  - `runtime`: novo campo/extension indicando `llamaCpp`, `llamaServer` ou `liteRtLm`.
- [ ] Tornar `gemma3nE2bLiteRt` o default de `SelectedModelNotifier.build()` quando `Platform.isAndroid`.
- [ ] Impedir selecao de modelos `.gguf` no Android quando o runtime padrao estiver configurado para LiteRT-LM, exceto se o usuario ativar fallback/debug.
- [ ] Atualizar textos de UI que mencionem MiniCPM5 como padrao Android.

## T2 - Download, Licenca e Integridade do `.litertlm`

- [ ] Atualizar `ModelDownloadService` para lidar explicitamente com arquivos `.litertlm`.
- [ ] Manter o uso do `DownloadManager` no Android, mas revisar o nome do arquivo final e a validacao de completude para o novo tamanho.
- [ ] Tratar o modelo Hugging Face como possivelmente gated: se o download retornar erro por licenca/autenticacao, mostrar mensagem clara pedindo aceite da licenca Gemma ou uso de artefato distribuido aprovado.
- [ ] Nao embutir token Hugging Face no app nem no repositorio.
- [ ] Adicionar um ponto de configuracao para build privada/distribuicao interna apontar para um mirror proprio do `.litertlm`, via `--dart-define` ou arquivo `.env` ignorado.
- [ ] Garantir que downloads incompletos sejam removidos ou retomados sem deixar arquivo parcial marcado como valido.

## T3 - Dependencias Android LiteRT-LM

- [ ] Adicionar a dependencia Gradle no `android/app/build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.google.ai.edge.litertlm:litertlm-android:<versao-fixada>")
}
```

- [ ] Evitar `latest.release` no projeto final; usar uma versao fixada validada em build reproducivel.
- [ ] Adicionar dependencias Kotlin/coroutines necessarias para streaming por `Flow`, se ainda nao estiverem transitivas.
- [ ] Revisar `minSdk`: LiteRT-LM/LiteRT moderno pode exigir API minima superior ao `flutter.minSdkVersion`. Ajustar somente se confirmado pelo build.
- [ ] Adicionar no `AndroidManifest.xml`, dentro de `<application>`, as bibliotecas opcionais quando GPU for habilitado:

```xml
<uses-native-library android:name="libvndksupport.so" android:required="false" />
<uses-native-library android:name="libOpenCL.so" android:required="false" />
```

- [ ] Comecar com `Backend.CPU()` para estabilidade; GPU/NPU entram como etapa posterior com feature flag.

## T4 - Bridge Kotlin LiteRT-LM

- [ ] Criar `android/app/src/main/kotlin/com/bestfin/bestfin/llm/LiteRtLlmBridge.kt`.
- [ ] Implementar uma classe responsavel por:
  - manter `Engine?` e `Conversation?`;
  - inicializar `EngineConfig(modelPath, backend = Backend.CPU(), cacheDir = context.cacheDir.path)`;
  - criar `ConversationConfig` com `systemInstruction` e `SamplerConfig`;
  - executar `sendMessageAsync(...).collect { ... }` em coroutine de background;
  - serializar chamadas para evitar duas geracoes concorrentes no mesmo `Conversation`;
  - cancelar geracao ativa;
  - fechar `Conversation` e `Engine` em `dispose`.
- [ ] Nao colocar toda a logica em `MainActivity.kt`; `MainActivity` deve apenas registrar canais e delegar.
- [ ] Usar `Dispatchers.Default`/`Dispatchers.IO` para carga e inferencia; nunca bloquear a UI thread.
- [ ] Enviar logs via `debugPrint`/logcat apenas com metadados tecnicos, nunca prompts completos ou dados financeiros.

## T5 - Platform Channels

- [ ] Criar canais separados dos canais de download:
  - `com.bestfin.bestfin/litert_lm` (`MethodChannel`)
  - `com.bestfin.bestfin/litert_lm_stream` (`EventChannel`)
- [ ] Implementar metodos:
  - `loadModel(modelPath, systemPrompt, temperature, topP, maxTokens)`
  - `sendMessage(prompt, requestId)`
  - `generateOnce(prompt, maxTokens, requestId)`
  - `cancel(requestId)`
  - `clearHistory()`
  - `dispose()`
  - `backendInfo()`
- [ ] Eventos do stream devem ter envelope estruturado:

```json
{"requestId":"...", "type":"token", "text":"..."}
{"requestId":"...", "type":"done"}
{"requestId":"...", "type":"error", "message":"..."}
{"requestId":"...", "type":"metrics", "tokens":123, "elapsedMs":4567}
```

- [ ] Garantir que eventos de uma requisicao antiga sejam ignorados pelo Dart quando `requestId` nao bater.

## T6 - Adaptacao do `LlmService` no Dart

- [ ] Introduzir uma abstracao interna de backend:
  - `LinuxLlamaServerBackend`
  - `AndroidLiteRtLmBackend`
  - `LlamaCppFallbackBackend` (temporario)
- [ ] Manter a API publica do `LlmService` estavel para providers e telas existentes.
- [ ] Em `load`, usar LiteRT-LM quando `Platform.isAndroid && modelType.runtime == liteRtLm`.
- [ ] Em `sendMessage`, consumir o `EventChannel` e expor `Stream<String>` igual ao comportamento atual.
- [ ] Em `generateOnce`, usar `MethodChannel` com resposta completa ou stream bufferizado, mantendo temperatura deterministica.
- [ ] Em `clearHistory`, delegar para o backend Android para recriar/limpar `Conversation`.
- [ ] Em `supportsVision`, retornar `true` no Android somente depois de uma etapa especifica multimodal ser implementada e validada.
- [ ] Preservar metricas `LlmMetrics` com TTFT, tempo total, tokens e tokens/s.

## T7 - Prompting, Historico e Saida Estruturada

- [ ] Testar o prompt financeiro atual com Gemma 3n E2B e ajustar somente o necessario.
- [ ] Validar os fluxos que exigem JSON curto (`generateOnce` para roteamento, categorizacao e parsers).
- [ ] Aplicar pos-processamento robusto para JSON:
  - remover fences Markdown;
  - extrair primeiro objeto/array JSON valido;
  - limitar max tokens em tarefas estruturadas.
- [ ] Definir tamanho de historico maximo por conversa no Dart/Kotlin para evitar estouro de contexto e uso excessivo de RAM.
- [ ] Nao habilitar chain-of-thought visivel por padrao; se houver modo debug, tratar como recurso tecnico e nao como UX final.

## T8 - Performance, Recursos e Fallback

- [ ] Medir carga inicial, TTFT e tokens/s em dispositivo real arm64.
- [ ] Comecar com CPU/XNNPACK e 4 threads se a API permitir controle explicito.
- [ ] Adicionar feature flag local para GPU:
  - padrao: CPU;
  - opcional: GPU quando dispositivo e manifest estiverem prontos;
  - fallback automatico para CPU se GPU falhar ao inicializar.
- [ ] Avaliar NPU apenas depois da rota CPU estar estavel.
- [ ] Em erro de LiteRT-LM no Android, oferecer fallback controlado para o backend antigo se o modelo GGUF estiver presente; nao baixar outro modelo sem consentimento do usuario.
- [ ] Garantir `dispose` em background/app lifecycle para liberar memoria nativa.

## T9 - UI e Estados

- [ ] Atualizar a tela de IA/chat para exibir o modelo Android como Gemma 3n LiteRT.
- [ ] Mostrar estado de download grande com progresso real e tamanho aproximado.
- [ ] Mostrar erro acionavel quando o modelo for gated ou a licenca nao tiver sido aceita.
- [ ] Se o aparelho nao suportar o runtime validado, mostrar fallback ou mensagem de incompatibilidade sem crash.
- [ ] Manter a experiencia offline apos o download do modelo.

## T10 - Limpeza Gradual do Caminho Antigo

- [ ] Depois da validacao, remover o carregamento obrigatorio de `libllama.so`, `ggml-*`, `OpenCL` e `mtmd` do `MainActivity.kt` para o fluxo padrao Android.
- [ ] Manter as bibliotecas antigas somente se o fallback `llama_cpp_dart` continuar oficialmente suportado.
- [ ] Revisar `android/app/src/main/jniLibs/arm64-v8a/` e remover binarios nao utilizados em uma tarefa separada, para reduzir tamanho do APK.
- [ ] Atualizar ou arquivar a Tarefa 26 como fallback JNI/llama.cpp, nao como plano principal.

## T11 - Validacao

- [ ] Rodar formatacao: `nix develop -c dart format .`
- [ ] Rodar analise estatica: `nix develop -c flutter analyze`
- [ ] Rodar testes: `nix develop -c flutter test`
- [ ] Compilar Android debug: `nix develop -c flutter build apk --debug`
- [ ] Testar em dispositivo real arm64:
  - baixar `.litertlm`;
  - carregar modelo sem travar UI;
  - enviar mensagem comum no chat;
  - gerar resposta com streaming;
  - executar `generateOnce` com JSON financeiro;
  - cancelar geracao;
  - descarregar e recarregar modelo 3 vezes;
  - colocar app em background e voltar apos 1 minuto;
  - confirmar que memoria nativa nao cresce indefinidamente.

## Criterios de Aceitacao

1. No Android, o modelo selecionado por padrao e `Gemma 3n E2B (LiteRT, Android)`.
2. O app baixa e valida um arquivo `.litertlm` int4 do Gemma 3n E2B ou exibe erro claro quando a licenca/acesso impedir o download.
3. O chat Android roda via LiteRT-LM Kotlin API, nao via `llama_cpp_dart`, quando o modelo padrao esta selecionado.
4. `sendMessage` entrega tokens em streaming para a UI existente.
5. `generateOnce` continua funcionando para fluxos de JSON curto.
6. Linux permanece funcional com `llama-server` e sem mudanca de comportamento.
7. Nenhum prompt, transacao, extrato ou dado financeiro e enviado a servidor externo.
8. O build Android debug compila sem erros e a analise Flutter nao apresenta novos problemas.

## Riscos e Mitigacoes

- **Modelo gated no Hugging Face:** usar mensagem explicita de licenca e permitir URL alternativa por build config, sem token versionado.
- **Tamanho do modelo maior que MiniCPM5-1B:** tratar download longo, espaco em disco e validacao de arquivo parcial.
- **Instabilidade GPU/OpenCL:** iniciar com CPU; GPU fica atras de feature flag.
- **API LiteRT-LM em evolucao:** fixar versao Maven validada e registrar no plano de upgrade.
- **Diferencas de prompt entre MiniCPM e Gemma:** testar rotas JSON e ajustar prompts de forma localizada.
- **Concorrencia de streaming:** usar `requestId`, mutex/coroutine job unico e cancelamento explicito.

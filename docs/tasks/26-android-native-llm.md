# Tarefa 26 — Motor LLM Nativo no Android (Caminho B)

> **Fase:** 4 — AI & Sync
> **Prioridade:** 🔴 Alta / Urgente
> **Estimativa:** Grande
> **Pré-requisitos:** 18-ai-features, 25-ai-expansion (em andamento/opcional)

## Descrição

Substituir o plugin FFI do Flutter (`llama_cpp_dart`) no **Android** por um motor nativo robusto em **C++/JNI + Kotlin**, mantendo a arquitetura atual baseada em `llama-server` (Vulkan) no **Linux**. 

Ao rodar o `llama.cpp` diretamente na camada nativa do Android (JNI) e expor suas funcionalidades ao Flutter através de **Platform Channels** (`MethodChannel` para comandos síncronos e `EventChannel` para streaming), eliminamos completamente as falhas silenciosas de linker (`libllama.so` não encontrada), problemas de visibilidade de símbolos (`RTLD_GLOBAL` / `RTLD_LOCAL`) e instabilidades de memória decorrentes da ponte Dart-FFI direta.

Isso garante estabilidade absoluta na execução do modelo **MiniCPM5-1B** no celular, compartilhando a mesma base GGUF usada no Desktop.

---

## 🛠️ Detalhamento das Etapas de Implementação

### T1 — Configuração do Build System e Suporte C++ no Android
> Configurar o suporte a código nativo via CMake no projeto Android para empacotar o llama.cpp.

- [ ] Criar o diretório para o código nativo: `android/app/src/main/cpp/`
- [ ] Baixar/clonar os fontes essenciais da versão estável do `llama.cpp` (ou extrair os arquivos principais de cabeçalho `llama.h`, `ggml.h` e implementações associadas) e colocá-los sob `android/app/src/main/cpp/llama.cpp/`
- [ ] Criar o arquivo `android/app/src/main/cpp/CMakeLists.txt` contendo a definição da compilação da biblioteca nativa `libllama_jni.so`:
  ```cmake
  cmake_minimum_required(VERSION 3.22.1)
  project("bestfin_llama_jni")

  # Adiciona arquivos do llama.cpp
  add_subdirectory(llama.cpp)

  # Adiciona nossa biblioteca JNI
  add_library(llama_jni SHARED llama_jni.cpp)

  target_link_libraries(llama_jni llama ggml)
  ```
- [ ] Atualizar o arquivo `android/app/build.gradle` para habilitar a compilação externa via CMake e configurar as arquiteturas de destino (`arm64-v8a` obrigatório para celulares modernos):
  ```groovy
  android {
      ...
      defaultConfig {
          ...
          externalNativeBuild {
              cmake {
                  cppFlags "-std=c++17 -O3 -flto"
                  arguments "-DGGML_OPENCL=OFF", "-DGGML_VULKAN=OFF" // CPU/NEON otimizado por padrão
              }
          }
          ndk {
              abiFilters "arm64-v8a" // Foco principal em performance 64-bit
          }
      }
      externalNativeBuild {
          cmake {
              path "src/main/cpp/CMakeLists.txt"
              version "3.22.1"
          }
      }
  }
  ```

---

### T2 — Desenvolvimento do Bridge JNI (`llama_jni.cpp`)
> Escrever a ponte C++ (JNI) que expõe as principais funções do `llama.cpp` (inicializar modelo, carregar contexto, gerar tokens e liberar recursos) para o Java/Kotlin.

- [ ] Criar o arquivo de cabeçalho e ponte `android/app/src/main/cpp/llama_jni.cpp`
- [ ] Implementar a função JNI para carregamento do modelo (`Java_com_bestfin_bestfin_MainActivity_loadModelNative`):
  - Recebe o caminho do arquivo GGUF.
  - Inicializa o `llama_model` e `llama_context` com parâmetros otimizados para celular (ex: 4 threads, contexto de 2048 ou 4096 tokens).
  - Mantém ponteiros estáticos globais do modelo e contexto ou retorna um ponteiro long (handle) para o Kotlin gerenciar.
- [ ] Implementar a função JNI para tokenização e inferência assíncrona/streaming (`Java_com_bestfin_bestfin_MainActivity_generateTokenNative`):
  - Aceita o texto de entrada (prompt).
  - Executa uma iteração do loop de inferência (`llama_decode`).
  - Amostra o próximo token usando o sampler básico (respeitando temperatura ~0.55 e top_p ~0.90).
  - Retorna a string do token ou invoca um callback JNI de volta para o Java/Kotlin.
- [ ] Implementar a função JNI para desalocação de memória e encerramento (`Java_com_bestfin_bestfin_MainActivity_unloadModelNative`):
  - Limpa com segurança o `llama_context`, `llama_model` e samplers criados, liberando a memória do Heap nativo de forma limpa.

---

### T3 — Implementação dos Platform Channels no Kotlin (`MainActivity.kt`)
> Consumir a ponte nativa no Kotlin e criar os canais `MethodChannel` e `EventChannel` para comunicação estável e assíncrona com o Flutter.

- [ ] Modificar o arquivo `android/app/src/main/kotlin/com/bestfin/bestfin/MainActivity.kt` para declarar e carregar a biblioteca nativa compilada:
  ```kotlin
  companion object {
      init {
          System.loadLibrary("llama_jni")
      }
  }
  ```
- [ ] Declarar as assinaturas das funções externas (nativas):
  ```kotlin
  private external fun loadModelNative(modelPath: String, nCtx: Int): Long
  private external fun generateOnceNative(handle: Long, prompt: String, maxTokens: Int): String
  private external fun startStreamNative(handle: Long, prompt: String)
  private external fun unloadModelNative(handle: Long)
  ```
- [ ] Configurar o `MethodChannel` com o ID `com.bestfin.app/llm` para receber as chamadas Dart:
  - `loadModel`: Chama `loadModelNative` em uma thread de background (`Kotlin Coroutines` ou `Thread`), salvando o handle retornado e respondendo com sucesso/erro.
  - `generateOnce`: Executa a inferência não-streamada e responde com a string completa.
  - `sendMessage`: Inicia a inferência em streaming no background.
  - `unload`: Chama `unloadModelNative` e invalida o handle.
- [ ] Configurar o `EventChannel` com o ID `com.bestfin.app/llm_stream`:
  - Salva a referência de `EventChannel.EventSink`.
  - Conforme os tokens são decodificados na thread nativa em background, envia-os para o Flutter em tempo real usando `sink.success(token)`.
  - Quando a inferência terminar (encontrar `EOS` ou atingir limite de tokens), envia o token especial `[DONE]` para fechar o stream logicamente no Dart.

---

### T4 — Integração e Adaptação do Dart (`LlmService`)
> Modificar o LlmService para realizar o despacho condicional de plataforma de forma limpa.

- [ ] Modificar o arquivo `lib/features/llm/data/services/llm_service.dart`:
  - Declarar as constantes `MethodChannel` e `EventChannel` específicas para a integração Android.
  - Atualizar a propriedade `isLoaded` para retornar `_isAndroidLoaded` no Android e verificar o `_serverProcess != null` no Linux.
  - Implementar os ramos específicos no método `load(...)`:
    ```dart
    if (Platform.isLinux) {
      // Executa inicialização atual do llama-server
    } else if (Platform.isAndroid) {
      final success = await _methodChannel.invokeMethod<bool>('loadModel', {
        'modelPath': modelPath,
      });
      _isAndroidLoaded = success ?? false;
    }
    ```
  - Implementar os ramos específicos no método `sendMessage(...)`:
    - No Linux, consome o `HttpClient` enviando o JSON de chat ao `llama-server`.
    - No Android, abre um listener sobre a stream do `EventChannel`, incrementa métricas (`onMetrics`), e dispara o prompt estruturado de chat via `_methodChannel.invokeMethod('sendMessage', {'prompt': formattedPrompt})`.
  - Implementar os ramos específicos no método `generateOnce(...)` e `dispose(...)` respeitando o comportamento nativo do Android.
- [ ] Remover a dependência direta de `import 'package:llama_cpp_dart/llama_cpp_dart.dart' as ffi;` da execução do Android. (O plugin `llama_cpp_dart` pode continuar declarado no `pubspec.yaml` apenas para outras plataformas não-Linux/não-Android se necessário, ou removido se pudermos migrar totalmente a interface).

---

### T5 — Testes de Estabilidade e Validação Estática
> Validar que a solução nativa resolve os problemas de linker e OOM e não possui problemas estáticos ou de concorrência.

- [ ] Executar a análise de linter do Flutter: `nix develop -c flutter analyze`
- [ ] Compilar o app Android em modo Release/Debug para testar a integração: `nix develop -c flutter build apk --debug`
- [ ] Instrumentar testes manuais em um emulador ou dispositivo físico real (`arm64-v8a`):
  - Verificar se o carregamento do modelo MiniCPM5-1B ocorre em menos de 5 segundos.
  - Verificar que o streaming de tokens funciona suavemente na UI do Chat.
  - Colocar o app em segundo plano durante a geração de texto e retornar após 1 minuto para certificar-se de que o sistema operacional não eliminou o processo devido ao vazamento ou estouro de RAM nativa.
  - Executar a liberação de recursos repetidas vezes (`load` seguido de `unload`) e verificar via Profiler do Android Studio se a memória RAM nativa volta ao baseline, confirmando a inexistência de memory leaks.

---

## 🎯 Critérios de Aceitação

1. **Compilação sem Erros:** A compilação do Android (`flutter run` ou `flutter build apk`) deve embutir e compilar os fontes nativos sem nenhuma falha do compilador CMake ou NDK.
2. **Carregamento Seguro:** O aplicativo deve inicializar e carregar o modelo **MiniCPM5-1B** sem lançar exceções de linker ou falha catastrófica de carregamento de biblioteca (`libllama_jni.so`).
3. **Comunicação por Canal Estável:** O fluxo completo do Chat no celular deve operar utilizando `MethodChannel` e `EventChannel`, com respostas parciais (streaming) visíveis token a token na tela.
4. **Sem Vazamento de Memória (Memory Leaks):** Múltiplos ciclos de carregar e descarregar modelos na tela de configurações não devem causar consumo incremental indefinido de RAM.
5. **Preservação de Plataforma:** O comportamento, scripts de início do `llama-server` Vulkan, e desempenho no **Linux** devem permanecer 100% inalterados e funcionais.

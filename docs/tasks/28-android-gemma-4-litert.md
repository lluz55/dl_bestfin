# Tarefa 28 - Integração do Gemma 4 E2B QAT via LiteRT-LM no Android

> **Fase:** 4 - AI & Sync
> **Prioridade:** Vermelha / Alta
> **Estimativa:** Média
> **Pré-requisitos:** 18-ai-features, 25-ai-expansion, 27-android-litert-gemma-default
> **Plataforma alvo:** Android / Linux

## Descrição

Implementar e validar o novo modelo **Gemma 4 E2B QAT** (Quantization-Aware Training) no projeto BestFin. 
No **Android**, a execução deve ocorrer através da stack do **Google LiteRT-LM** (antigo TensorFlow Lite GenAI) com o arquivo `.litertlm` quantizado a 4 bits (`gemma-4-E2B-it.litertlm`), promovendo-o como o modelo padrão do sistema no dispositivo móvel devido a sua eficiência superior e tamanho reduzido (~2.6 GB) se comparado à versão anterior Gemma 3n (~3.6 GB).
No **Linux**, o modelo correspondente em formato **GGUF** continuará a ser executado via `llama-server` nativo para preservar o suporte offline do ambiente desktop.

---

## Fontes e Referências Técnicas

Para guiar o desenvolvimento e futuras manutenções, consulte os seguintes links:

1. **Repositório do Modelo Gemma 4 E2B LiteRT-LM (Hugging Face):**
   - [litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm)
   - Contém o arquivo `gemma-4-E2B-it.litertlm` pré-compilado e otimizado para o runtime LiteRT-LM.

2. **Repositório do Modelo Gemma 4 E2B QAT GGUF (para Linux/llama.cpp):**
   - [lmstudio-community/gemma-4-E2B-it-GGUF](https://huggingface.co/lmstudio-community/gemma-4-E2B-it-GGUF)
   - Contém os quantizadores GGUF (recomendado usar `Q4_K_M` ou similar).

3. **Documentação Oficial do Google LiteRT GenAI:**
   - [LiteRT Large Models (Google AI Edge)](https://developers.google.com/edge/litert/genai/overview)
   - Visão geral sobre o ciclo de vida e a arquitetura do motor de inferência local.

4. **Guia da API Kotlin do LiteRT-LM:**
   - [LiteRT-LM Kotlin API Getting Started](https://github.com/google-ai-edge/LiteRT-LM/blob/main/docs/api/kotlin/getting_started.md)
   - Exemplos de inicialização do `Engine`, configuração de contexto e coleta de respostas via streaming com `Flow`.

---

## Detalhamento de Implementação

### T1 - Configuração do Registry de Modelos (`AiModelType`)
O modelo já possui sua assinatura no enum Dart, mas necessita de validações adicionais.
- [ ] Validar e atualizar em `lib/features/llm/domain/models/ai_model_type.dart` a entrada `gemma4E2bLiteRt`:
  - **Tamanho esperado:** `sizeBytes` ajustado para `2_710_000_000` (ou o tamanho preciso em bytes do arquivo baixado).
  - **Identificador de runtime:** Garantir que esteja associado a `AiModelRuntime.liteRtLm`.
  - **URL de Download:** Garantir a URL correta apontando para o arquivo no Hugging Face:
    `https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm`

### T2 - Configuração do Download e Bypass Gated
Modelos da família Gemma costumam exigir aceitação de termos na plataforma Hugging Face.
- [ ] No `ModelDownloadService` do Android, certificar que a requisição de download trate adequadamente falhas de autenticação de URLs do Hugging Face.
- [ ] Implementar uma configuração via `--dart-define` (ex: `BESTFIN_GEMMA4_LITERT_URL`) ou variável de ambiente no `.env` para permitir apontar o download do modelo para um espelho (mirror) privado/local, evitando restrições de autenticação em builds internas.
- [ ] Mostrar um alerta na UI se o download falhar por restrição de licença, instruindo o usuário sobre como configurar a URL alternativa ou aceitar os termos do modelo no site do Hugging Face.

### T3 - Configurações Gradle do Android
- [ ] Certificar que a dependência oficial do SDK LiteRT-LM esteja declarada no arquivo `android/app/build.gradle.kts`:
  ```kotlin
  dependencies {
      implementation("com.google.ai.edge.litertlm:litertlm-android:0.1.0") // Substituir pela versão estável recomendada
  }
  ```
- [ ] Garantir no `AndroidManifest.xml` a declaração para carregamento de bibliotecas dinâmicas nativas para futura aceleração GPU/NPU se necessário:
  ```xml
  <uses-native-library android:name="libvndksupport.so" android:required="false" />
  <uses-native-library android:name="libOpenCL.so" android:required="false" />
  ```

### T4 - Bridge Kotlin e Fluxo de Streaming
- [ ] Implementar o canal de comunicação em `android/app/src/main/kotlin/com/bestfin/bestfin/llm/LiteRtLlmBridge.kt` conectando com a API do LiteRT-LM.
- [ ] Carregar o modelo Gemma 4 em background usando coroutines Kotlin (`Dispatchers.Default`/`IO`) e coletar o fluxo de tokens gerados com segurança utilizando `Flow.collect`.
- [ ] Tratar de maneira robusta os estados da conversa e cancelar qualquer inferência ativa caso o usuário saia do chat ou envie uma nova mensagem enquanto a anterior está sendo gerada.

---

## Critérios de Aceitação

1. O modelo selecionado por padrão no Android deve ser o **Gemma 4 E2B (LiteRT, Android)**.
2. O aplicativo deve baixar e verificar com sucesso o arquivo `.litertlm` do Gemma 4 E2B.
3. O chat deve fluir em streaming de forma estável no Android, sem travar a thread de interface gráfica (UI Thread).
4. O consumo de RAM nativa no Android não deve crescer indefinidamente ao recarregar a conversação.
5. No Linux, a execução com o modelo Gemma 4 em formato **GGUF** via `llama-server` deve continuar operante e sem regressões.

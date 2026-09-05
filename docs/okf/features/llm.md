---
type: Feature
title: LLM On-device
description: Motor llama.cpp integrado ao app para chat, insights, narrativas e categorização — sem dados na nuvem.
tags: [llm, ia, on-device, llama.cpp, chat, insights]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Integra um LLM local (llama.cpp) ao app para funcionalidades de IA sem enviar dados financeiros a servidores externos. Suporta dois backends: llama-server HTTP (Linux) e FFI nativa (Android).

## Arquitetura Dual de Backend

| Plataforma | Backend | Detalhes |
|---|---|---|
| Linux | `llama-server` HTTP na porta 8087 | Suporte a GPU Vulkan; suporte a visão (mmproj) |
| Android | `llama_cpp_dart` via Dart FFI + isolate | Download background via DownloadManager |

Lógica de seleção em: `lib/features/llm/data/services/llm_service.dart`

## Modelos Disponíveis

Definidos em `lib/features/llm/domain/models/ai_model_type.dart`:

| Modelo | Plataforma | Propósito |
|---|---|---|
| `minicpm5_1b` | Android | Chat e categorização on-device |
| `minicpmV4_6` | Linux | Chat + visão (OCR/imagens) via mmproj |

## Funcionalidades Implementadas

| Funcionalidade | Provider / Arquivo |
|---|---|
| Chat interativo | `presentation/screens/ai_chat_screen.dart` + `chat_provider.dart` |
| Auto-categorização de transações | `presentation/providers/llm_categorize_provider.dart` |
| Insights do período | `presentation/providers/llm_insights_provider.dart` (cache 8h) |
| Narrativa financeira | `presentation/providers/llm_narrative_provider.dart` (cache 8h) |
| Download do modelo | `data/services/model_download_service.dart` |
| Contexto financeiro | `domain/services/financial_context_builder.dart` |
| Ferramentas LLM (tool use) | `domain/services/llm_tools_service.dart` |
| Avaliador matemático | `domain/services/math_evaluator.dart` |

## Funcionalidades Implementadas (cont.)

| Funcionalidade | Arquivo / Task |
|---|---|
| Entrada por linguagem natural (CLI/TUI) | `lib/cli/` — Task 55 (`bestfin add "frase"`) — parser heurístico + refinamento opcional via LLM (`:8087`) |

## Funcionalidades Planejadas (Task 25 — pendentes)

- **A1** — Entrada de transação por linguagem natural ("Gastei 47 no iFood") — ✅ implementada via CLI/TUI (Task 55)
- **A2** — Detector de redundância em assinaturas
- **A3** — Parser PDF com fallback LLM
- **A4** — Narrador de relatório mensal

## Estados do LLM

Definidos em `lib/features/llm/domain/models/llm_state.dart`:

`initial` → `downloading` → `loading` → `ready` ↔ `generating`
                                                    ↓
                                                 `error`

## Parâmetros de Sampling

| Parâmetro | Valor | Propósito |
|---|---|---|
| `_kChatTemp` | 0.55 | Chat — equilíbrio criatividade/factualidade |
| `_kOneShotTemp` | 0.30 | Categorização/insights — mais determinístico |
| `_kTopP` | 0.90 | Nucleus sampling |
| `_kMinP` | 0.05 | Corta tokens de baixa probabilidade |
| `_kRepeatPenalty` | 1.05 | Evita repetição em respostas longas |

## Sistema de Cache

Insights e narrativas têm cache de 8 horas em `SharedPreferences`. Invalidados automaticamente ao retornar ao app com LLM pronto (`didChangeAppLifecycleState` em `main.dart`).

## Fallback sem LLM (Template NLG — Task 27)

A geração de texto do LLM é apenas uma camada de *fala* sobre números já computados de forma determinística em `ai_provider.dart`. Por isso, os insights do dashboard de IA funcionam mesmo sem nenhum modelo carregado:

| Texto | Origem quando LLM ausente |
|---|---|
| Insights do período (3 frases) | `templateInsightsProvider` → `InsightNlgService.periodInsights` |
| Narrativa de saúde | `health.primaryRecommendation` (sempre algorítmico) |
| Insights de sentimento | `sentiment.psychologicalInsights` (sempre algorítmico) |
| Categorização | heurística + Naive Bayes antes do fallback LLM |

`InsightNlgService` (`lib/features/ai/domain/services/insight_nlg_service.dart`) é puro: recebe primitivos e devolve frases por template, mantendo a camada de domínio desacoplada da apresentação.

## Dependências

- [Transações](transactions.md) — contexto para insights e categorização
- [Contas](accounts.md) — contexto financeiro
- [Categorias](categories.md) — lista para auto-categorização
- [Metas](goals.md) — contexto para narrativas
- [Importação PDF](pdf-import.md) — fallback LLM planejado (A3)

# Citations

[1] [Task 25 — Expansão de IA](../../tasks/25-ai-expansion.md)
[2] [Task 26 — Motor LLM Nativo Android](../../tasks/26-android-native-llm.md)

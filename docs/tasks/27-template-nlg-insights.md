# Tarefa 27 — Insights via Template NLG (sem LLM)

**Fase:** 4 — AI & Sync
**Prioridade:** 🟢 Em andamento
**Pré-requisitos:** 18-ai-features, 25-ai-expansion

Descrição: Reduzir a dependência do LLM na geração de texto em linguagem natural,
substituindo-a por NLG (Natural Language Generation) baseada em templates sobre os
dados algorítmicos já computados em `ai_provider.dart`. O LLM no app é uma camada de
*fala* sobre números determinísticos — esses números já existem sem ele.

## Contexto

Levantamento dos usos do LLM e suas alternativas sem modelo:

| Uso do LLM | Alternativa sem LLM | Status |
|---|---|---|
| Insights do período (3 frases) | Template NLG | ✅ Esta task |
| Narrativa de saúde financeira | `health.primaryRecommendation` (já existia) | ✅ Já recaía |
| Insights de sentimento | `sentiment.psychologicalInsights` (já existia) | ✅ Já recaía |
| Categorização | heurística + Naive Bayes | ✅ Já existia |
| Chat conversacional | NLU pipeline (intent + slot filling) | ⬜ Futuro |
| OCR de comprovantes | ML Kit + regex | ⬜ Futuro |

## Subtarefas

- [x] Serviço de domínio puro `InsightNlgService.periodInsights` (primitivos → frases)
- [x] Provider `templateInsightsProvider` em `ai_provider.dart`
- [x] `_buildLlmInsightsCard` nunca some: usa template quando não há LLM e em erro
- [x] Testes unitários do serviço NLG (6 casos)
- [ ] Chat conversacional via NLU pipeline (intent fastText/cosseno + slots por regex)
- [ ] OCR de comprovantes via `google_mlkit_text_recognition` + regex

## Arquivos

- `lib/features/ai/domain/services/insight_nlg_service.dart` — serviço puro
- `lib/features/ai/presentation/providers/ai_provider.dart` — `templateInsightsProvider`
- `lib/features/ai/presentation/screens/ai_dashboard_screen.dart` — fallback do card
- `test/features/ai/insight_nlg_service_test.dart` — testes

## Aceitação

- Card "Análise Financeira" aparece mesmo sem nenhum modelo LLM carregado
- Valores monetários respeitam o modo privacidade
- Texto determinístico, sem alucinação, on-device, custo zero

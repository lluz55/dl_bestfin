# Tarefa 25 — Expansão de IA: Ativa e Passiva

> **Fase:** 4 — AI & Sync
> **Prioridade:** 🔵 Futura
> **Estimativa:** Grande
> **Pré-requisitos:** 06-transactions, 11-recurring, 12-goals, 15-notifications, 18-ai-features, 21-pdf-statement-receipt-import

## Descrição

Expandir a inteligência artificial do BestFin em dois eixos: **IA Ativa** (usuário aciona explicitamente) e **IA Passiva** (app age automaticamente em background). O objetivo é reduzir fricção no ciclo diário de uso e criar momentos "mágicos" onde o app antecipa as necessidades do usuário — tudo rodando localmente, sem enviar dados a servidores externos.

Base existente: auto-categorização híbrida, cash flow forecasting, detecção de anomalias, health score, chat LLM com ferramentas, OCR de recibos, narrativas/insights com cache 8h.

---

## IA Ativa (usuário aciona)

### A1 — Entrada de Transação por Linguagem Natural ⭐
> Reduz o wizard de 5 páginas para uma única frase.

- [ ] Criar `lib/features/transactions/domain/models/transaction_draft.dart` — modelo com `amountInCents`, `description`, `categoryId`, `entityName`, `date`, `type`
- [ ] Criar `lib/features/llm/presentation/providers/llm_transaction_parser_provider.dart` — `FutureProvider.family<TransactionDraft?, String>`; chama `generateOnce` (máx 80 tokens); resolve `categoryId` por nome contra `allFlatCategoriesProvider`
- [ ] Criar `lib/features/transactions/presentation/widgets/smart_entry_bar.dart` — campo de texto + botão "Entender"; mostra loading; chama callback `onDraftReady(TransactionDraft)`
- [ ] Modificar `lib/features/transactions/presentation/screens/transaction_form_screen.dart` — adicionar `SmartEntryBar` acima do teclado numérico (page 0); método `_applyDraft()` que preenche todos os campos e salta direto para page 4 (Review)

**Prompt chave:**
```
Data de hoje: {{hoje}}. Categorias disponíveis: {{lista}}.
Frase: "{{input}}"
Responda APENAS JSON válido:
{"amount_cents":0,"description":"","category":"","entity":"","date":"YYYY-MM-DD","type":"expense|income|transfer"}
```

**Critérios de aceitação:**
- [ ] Digitar "Gastei 47,50 no iFood hoje" preenche amount=4750, description="iFood", category="Alimentação", date=hoje, type=expense
- [ ] Digitar "Recebi 3200 de salário" preenche type=income corretamente
- [ ] Quando LLM não está pronto, o campo é ocultado (sem erro)

---

### A2 — Detector de Redundância em Assinaturas
> Mostra sobreposições de serviços e estima economia mensal.

- [ ] Criar `lib/features/ai/presentation/providers/subscription_analysis_provider.dart` — agrupa `activeRecurringProvider` por categoria de serviço (streaming, telecom, fitness…) usando keywords; calcula total mensal por grupo; gera recomendação via LLM (1 frase/grupo, cache 24h)
- [ ] Criar `lib/features/recurring/presentation/widgets/subscription_analysis_sheet.dart` — bottom sheet listando grupos com total e recomendação

**Critérios de aceitação:**
- [ ] Com Netflix + Disney+ cadastrados como recorrentes, o detector os agrupa e exibe total do grupo
- [ ] Botão "Analisar com IA" aparece em `RecurringListScreen` ou `SubscriptionsScreen`

---

### A3 — Parser de PDF com Fallback LLM
> Qualquer extrato de banco passa a ser importável, mesmo sem parser dedicado.

- [ ] Criar `lib/features/pdf_import/data/parsers/llm_fallback_parser.dart` — implementa `PdfBankParser`; `canHandle()` retorna `true` (último na cadeia); `parseAsync()` envia os primeiros 2000 chars do texto ao LLM e parseia o array JSON retornado
- [ ] Modificar `lib/features/pdf_import/domain/usecases/import_pdf_usecase.dart` — tornar async; registrar `LlmFallbackParser` como último parser da cadeia
- [ ] Modificar `lib/features/pdf_import/presentation/providers/pdf_import_provider.dart` — adicionar flag `isLlmFallbackActive` para exibir "Analisando com IA..." enquanto o LLM processa
- [ ] Modificar `lib/features/pdf_import/presentation/screens/pdf_import_screen.dart` — mostrar indicador de loading quando `isLlmFallbackActive` for true

**Prompt chave:**
```
Analise o texto de extrato bancário abaixo e extraia as transações.
Retorne APENAS um array JSON:
[{"date":"YYYY-MM-DD","description":"","amount_cents":0,"type":"expense|income"}]
Ignore totais, cabeçalhos e textos que não sejam transações.
Texto: {{pdf_text}}
```

**Critérios de aceitação:**
- [ ] PDF de banco sem parser nativo: transações aparecem em `PdfReviewScreen`
- [ ] PDF com parser nativo: fallback LLM não é acionado
- [ ] Indicador "Analisando com IA…" visível durante processamento

---

### A4 — Narrador de Relatório Mensal
> Transforma gráficos em decisões com 3 parágrafos em português.

- [ ] Criar `lib/features/llm/presentation/providers/llm_report_narrator_provider.dart` — `StateNotifier<AsyncValue<String>>`; lê `monthlyReportProvider`; chama `sendMessage` em streaming; cache por `ano-mês` em SharedPreferences
- [ ] Criar `lib/features/reports/presentation/widgets/report_narrator_card.dart` — shimmer durante geração; texto streamado via `StreamBuilder`; botão "Resumo com IA" que aciona geração

**Critérios de aceitação:**
- [ ] Narrativa gerada com: (1) o que aconteceu vs mês anterior, (2) maior movimento de categoria, (3) sugestão para o próximo mês
- [ ] Texto aparece token a token (streaming visível)
- [ ] Cache evita regeneração para o mesmo mês

---

### A5 — Conselheiro de Meta (Goal Strategy Advisor)
> Converte metas abstratas em táticas semanais concretas.

- [ ] Criar `lib/features/llm/presentation/providers/llm_goal_advisor_provider.dart` — `FutureProvider.family<GoalAdvice, String>` (keyed por goal ID); lê `goalAchievabilityProvider` + `budgetRecommendationsProvider`; cache 12h por goal ID
- [ ] Criar `lib/features/goals/presentation/widgets/goal_advisor_sheet.dart` — bottom sheet com: avaliação da trajetória, 2-3 táticas, cenário alternativo com aporte extra
- [ ] Adicionar botão "Estratégia com IA" na tela de detalhe de meta

**Critérios de aceitação:**
- [ ] Sheet exibe 2-3 táticas concretas em português
- [ ] Para meta atrasada, tom é de urgência; para meta no prazo, tom é de encorajamento
- [ ] Cache respeita 12h sem regenerar

---

### A6 — Criação de Recorrente por Linguagem Natural
> Remove o fluxo mais tedioso do app.

- [ ] Estender `llm_transaction_parser_provider.dart` com novo schema: `frequency` (daily/weekly/biweekly/monthly/yearly), `day_of_month`, `interval`
- [ ] Adicionar campo "Criar com linguagem natural" em `RecurringFormScreen` com botão "Entender" que popula o formulário

**Critérios de aceitação:**
- [ ] "Netflix todo dia 5, R$39,90" → preenche amount=3990, frequency=monthly, day_of_month=5, entity="Netflix"

---

### A7 — Simulador "E se?" de Quitação de Dívida
> Mostra o valor real de pagamentos extras em financiamentos.

- [ ] Criar `lib/features/financing/domain/usecases/simulate_payoff.dart` — cálculo SAC/PRICE puro com cenários de aporte extra
- [ ] Adicionar slider de "pagamento extra mensal" em `FinancingDetailScreen`
- [ ] LLM traduz resultado numérico para narrativa em português (1-2 frases, maxTokens=30)

**Critérios de aceitação:**
- [ ] Slider de extra mensal atualiza narrativa em tempo real (debounce 800ms)
- [ ] Narrativa mostra meses economizados e juros poupados

---

## IA Passiva (background, automático)

### P1 — Classificação Automática de Notificações Bancárias ⭐
> Cada notificação bancária vira transação em 1 tap.

- [ ] Criar `lib/features/notifications/data/services/suggestion_enrichment_service.dart` — ao receber `TransactionSuggestion`, resolve: `categoryId` via `autoCategorizeProvider`, `entityId` via fuzzy match em `EntitiesDao`, `isRecurring` via `activeRecurringProvider`
- [ ] Estender `lib/features/notifications/domain/models/transaction_suggestion.dart` — campos opcionais: `categoryId`, `categoryName`, `categoryColor`, `categoryIcon`, `entityId`, `entityName`, `isRecurring`
- [ ] Modificar `lib/features/notifications/presentation/providers/notification_provider.dart` — pipeline: `AndroidNotificationService.stream` → `SuggestionEnrichmentService.enrich()` → queue
- [ ] Modificar `lib/features/notifications/presentation/widgets/suggestion_card.dart` — exibir chip de categoria, nome da entidade e badge "Recorrente"; botão confirmar cria transação diretamente via `TransactionsDao` (sem abrir formulário)

**Critérios de aceitação:**
- [ ] Notificação "Compra aprovada: iFood R$47,50" chega na fila com categoria "Alimentação" e entidade "iFood" pré-preenchidos
- [ ] Confirmação em 1 tap sem abrir formulário
- [ ] Se enriquecimento falhar, card mantém comportamento original (degradação graciosa)

---

### P2 — Auto-Descoberta de Regras Recorrentes ⭐
> O app aprende sozinho os padrões de gastos do usuário.

- [ ] Criar `lib/features/ai/presentation/providers/recurring_discovery_provider.dart` — `Provider<List<RecurringDraftRule>>`; algoritmo: agrupar transações dos últimos 90 dias por `(description, categoryId, entityId)`; para grupos com 3+ ocorrências, calcular gaps entre datas; se desvio padrão < 3 dias para período 7/14/30/365, marcar como padrão recorrente; descartar se regra equivalente já existe em `activeRecurringProvider`
- [ ] Criar modelo `RecurringDraftRule` com: `description`, `inferredFrequency`, `amountInCents`, `categoryId`, `entityId`, `nextDate`, `confidence`
- [ ] Modificar `lib/features/recurring/presentation/screens/recurring_list_screen.dart` — adicionar `RecurringDiscoveryBanner` no topo quando `recurringDiscoveryProvider` retornar lista não vazia
- [ ] Criar `lib/features/recurring/presentation/widgets/recurring_discovery_banner.dart` — card com "Detectamos N padrões recorrentes"; cada item tem botões "Criar regra" (pré-preenche `RecurringFormScreen`) e "Ignorar"

**Critérios de aceitação:**
- [ ] Após 3 transações mensais com mesma descrição, banner aparece na tela de recorrentes
- [ ] Clicar "Criar regra" abre `RecurringFormScreen` pré-preenchido
- [ ] Regras já existentes não geram sugestão duplicada

---

### P3 — Alerta de Ritmo de Orçamento ⭐
> Alerta proativo antes do overspend acontecer.

- [ ] Criar `lib/features/ai/presentation/providers/budget_pacing_provider.dart` — `Provider<List<BudgetPaceAlert>>`; para cada categoria: `dailyRate = currentMonthSpend / daysElapsed`; `projected = currentSpend + dailyRate * daysRemaining`; alerta se `projected > historicalAverage * 1.15`
- [ ] Criar modelo `BudgetPaceAlert` com: `categoryName`, `categoryColor`, `currentMonthSpend`, `projectedMonthTotal`, `historicalAverage`, `overspendPercent`, `daysRemaining`
- [ ] Modificar `lib/features/dashboard/presentation/widgets/insight_card.dart` (ou equivalente) — adicionar `budgetPacingProvider` na cascata de prioridade de insights do dashboard

**Critérios de aceitação:**
- [ ] Após adicionar gastos que projetam >115% da média histórica numa categoria, card aparece no dashboard
- [ ] Mensagem inclui valor projetado, percentual acima da média e dias restantes no mês

---

### P4 — Barreira Anti-Impulso (Compras Noturnas)
> Intervém no momento exato de maior risco usando os próprios dados do usuário.

- [ ] Criar `lib/features/transactions/presentation/widgets/impulse_guardrail_card.dart` — card não-bloqueante com mensagem personalizada e botão "Lembrar amanhã"
- [ ] Modificar `lib/features/transactions/presentation/screens/transaction_form_screen.dart` — em `_goNext()` (page 0→1): verificar se valor > R$200 AND horário entre 22h–04h AND `sentimentCorrelationProvider` indica histórico negativo nesse padrão; se sim, exibir `ImpulseGuardrailCard` no topo de page 1
- [ ] Integrar `flutter_local_notifications` (já presente) para agendar lembrete matinal quando usuário aceitar

**Critérios de aceitação:**
- [ ] Card aparece ao registrar gasto noturno (22h-04h) acima de R$200 quando histórico aponta padrão negativo
- [ ] Card é não-bloqueante: usuário pode ignorar e continuar
- [ ] Botão "Lembrar amanhã" agenda notificação local para 9h do dia seguinte

---

### P5 — Sugestor de Aporte em Meta ao Receber Renda
> Converte intenção passiva em aporte real no momento de maior liquidez.

- [ ] Criar `lib/features/ai/presentation/providers/income_contribution_suggestor_provider.dart` — detecta transação de renda recém-salva; lê `goalAchievabilityProvider` para encontrar meta mais crítica (menor `isOnTrack` com prazo mais próximo); sugere 10% do valor da renda; LLM opcional para texto personalizado (30 tokens, cache por evento de renda)
- [ ] Adicionar `ref.listen` no dashboard sobre `filteredTransactionsProvider` para detectar novas rendas e acionar bottom sheet
- [ ] Criar bottom sheet com: valor sugerido editável, nome da meta, botão de contribuição rápida que chama use case de adição de contribuição

**Critérios de aceitação:**
- [ ] Ao salvar renda de R$3.200 com meta ativa, bottom sheet aparece sugerindo R$320 para a meta mais crítica
- [ ] Contribuição rápida funciona sem abrir tela de meta
- [ ] Se não houver meta ativa, bottom sheet não aparece

---

### P6 — Detector de Duplicatas
> Previne dupla contagem em importações e notificações.

- [ ] Criar `lib/features/ai/presentation/providers/duplicate_detector_provider.dart` — query Drift: transações com ±50 cents, ±2h, mesmo `categoryId`; score ≥ 0.80 emite `DuplicateAlert`
- [ ] Criar widget reutilizável `DuplicateAlertBanner` — exibe "Possível duplicata de '[descrição] R$X.XX registrado há Y min'" com botões "Manter ambos" / "Remover duplicado"
- [ ] Integrar banner em: `TransactionListScreen` (para transações recém-adicionadas) e `PdfReviewScreen` (durante importação em lote)

**Critérios de aceitação:**
- [ ] Ao salvar transação idêntica a uma já existente (mesma desc, valor, categoria, dentro de 2h), banner aparece
- [ ] "Remover duplicado" deleta a transação mais recente
- [ ] Banner desaparece se usuário escolher "Manter ambos"

---

### P7 — Scorer de Risco de Fatura do Cartão
> Visibilidade de limite em tempo real antes do fechamento.

- [ ] Criar `lib/features/ai/presentation/providers/invoice_risk_provider.dart` — para cada cartão: soma total da fatura aberta + recorrências previstas antes do fechamento (via `activeRecurringProvider` filtrado por `creditCardId`); calcula `projectedUsagePercent = total / limit`; score: verde <50%, amarelo 50-80%, vermelho >80%
- [ ] Adicionar chip colorido de risco em `CreditCardDetailScreen` e `CreditCardListScreen`

**Critérios de aceitação:**
- [ ] Chip mostra cor correta conforme percentual de uso projetado
- [ ] Ao adicionar transação no cartão, chip atualiza imediatamente
- [ ] Exibe "Fatura fechará em N dias com R$X previstos — Y% do limite"

---

## Critérios de Aceitação Gerais

- Todas as features de LLM degradam graciosamente quando o modelo não está carregado (sem crash, sem tela em branco)
- Nenhum dado financeiro é enviado para servidores externos
- Features passivas não consomem recursos excessivos em background (algoritmos síncronos, sem polling)
- Interfaces seguem o design system Material 3 Expressive do projeto

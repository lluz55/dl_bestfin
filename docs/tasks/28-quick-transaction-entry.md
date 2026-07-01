# Tarefa 28 — Lançamento Rápido com sugestões por ML estatístico

**Fase:** 3 — Transações & UX
**Prioridade:** 🟢 Em andamento
**Pré-requisitos:** 06-transactions, 04-accounts, 05-categories

Descrição: Criar um caminho rápido (1–2 toques) para registrar **qualquer** transação
(despesa, receita, transferência) sem passar pelo wizard completo. O FAB passa a abrir um
bottom sheet único de "Lançamento Rápido" com chips de sugestão vindos de um recomendador
estatístico on-device (frequência × decaimento de recência) que autopreenche conta,
categoria e valor a partir do histórico. O wizard completo continua disponível em
"Mais opções" para edição detalhada.

## Contexto

O caso de uso mais comum é repetir um lançamento parecido com algo já feito ("Mercado R$50",
"Salário", "Corrente → Poupança R$200"). O wizard de `transaction_form_screen.dart` (1824
linhas) é caro para isso. A "IA" aqui é um recomendador estatístico determinístico — o mesmo
princípio que apps de fintech chamam de "lançamento/transferência inteligente" — sem LLM no
caminho principal. Não há mudança de schema: a feature apenas lê transações existentes.

## Subtarefas

- [x] Modelo de domínio `QuickSuggestion`
- [x] Use case puro `rankQuickSuggestions` (frequência × recência, meia-vida 30d)
- [x] Provider `quickSuggestionsProvider` (StreamProvider.family por tipo)
- [x] Bottom sheet `QuickTransactionSheet` (abas + chips + valor + conta/categoria)
- [x] Wiring do `GlobalFAB` em `app_shell.dart` para abrir o sheet
- [x] Testes unitários do ranqueamento (4 casos)
- [ ] Verificação manual no app (criação real + saldos + double-entry)

## Arquivos

- `lib/features/transactions/domain/models/quick_suggestion.dart` — modelo da sugestão
- `lib/features/transactions/domain/usecases/get_quick_suggestions.dart` — motor de ranqueamento (puro)
- `lib/features/transactions/presentation/providers/quick_suggestions_provider.dart` — provider
- `lib/features/transactions/presentation/widgets/quick_transaction_sheet.dart` — bottom sheet
- `lib/core/shell/app_shell.dart` — FAB abre o sheet
- `test/features/transactions/get_quick_suggestions_test.dart` — testes

## Aceitação

- FAB → cada ação abre o "Lançamento Rápido" com o tipo correto pré-selecionado
- Chips refletem o histórico recente; tocar um chip preenche valor/conta/categoria/(destino)
- "Salvar" cria a transação via `CreateTransaction` (double-entry preservado; saldos corretos)
- Transferência gera débito/crédito nas contas certas; "Mais opções" abre o wizard completo
- Ranqueamento determinístico, on-device, custo zero

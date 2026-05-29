# Tarefa 06 — Transações

**Fase:** 1 — Fundação
**Prioridade:** 🔴 Crítica
**Pré-requisitos:** 04-accounts, 05-categories

Descrição: Implementar CRUD completo de transações (despesa, receita, transferência) com partida dobrada, autocomplete de entities, sentiment selector, parcelamento e recorrência (opcionais nesta tarefa — stubs para Fase 2).

Subtarefas:
 - [x] Criar `lib/core/constants/transaction_types.dart`: enum income/expense/transfer
 - [x] Criar `lib/core/constants/sentiment_types.dart`: enum com 5 níveis + emoji + cor
 - [x] Criar `lib/features/transactions/domain/models/transaction.dart`: model completo
 - [x] Criar `lib/features/transactions/domain/models/entry.dart`: model de entry (debit/credit)
 - [x] Criar `lib/features/transactions/data/repositories/transaction_repository.dart`: CRUD com partida dobrada automática
 - [x] Criar `lib/features/transactions/domain/usecases/`: create_transaction, update_transaction, delete_transaction, get_transactions (com filtros)
 - [x] Implementar lógica de partida dobrada:
  - Despesa: debit na categoria → credit na conta
  - Receita: debit na conta → credit na categoria
  - Transferência: debit no destino → credit na origem
  - Cartão: debit na fatura → credit na conta da fatura
 - [x] Criar `lib/features/transactions/presentation/providers/transactions_provider.dart`
 - [x] Criar `lib/features/transactions/presentation/screens/transactions_list_screen.dart`: lista agrupada por dia, swipe actions (editar/deletar)
 - [x] Criar `lib/features/transactions/presentation/screens/transaction_form_screen.dart`: formulário completo com tabs (Despesa/Receita/Transferência)
 - [x] Criar `lib/features/transactions/presentation/widgets/transaction_tile.dart`: tile com ícone de categoria, descrição, valor colorido, sentiment emoji, hora
 - [x] Criar `lib/features/transactions/presentation/widgets/amount_input.dart`: teclado numérico custom para valor
 - [x] Criar `lib/features/transactions/presentation/widgets/transaction_type_tabs.dart`: tabs Despesa/Receita/Transferência
 - [x] Criar `lib/features/transactions/presentation/widgets/transaction_filters.dart`: filtros por período, categoria, conta, tipo
 - [x] Criar `lib/core/widgets/entity_autocomplete.dart`: autocomplete de pagadores/recebedores + contas, com criação inline de nova entity
 - [x] Criar `lib/core/widgets/sentiment_selector.dart`: seletor de 5 emojis (😡😞😐🙂😄) com animação de seleção
 - [x] Criar `lib/core/widgets/numeric_keypad.dart`: teclado numérico customizado
 - [x] Criar `lib/core/utils/currency_formatter.dart`: formatação BRL (R$ 1.234,56)
 - [x] Criar `lib/core/utils/date_formatter.dart`: formatação de datas em pt-BR
 - [x] Incrementar `use_count` da entity ao usar
 - [x] Stubs para parcelamento e recorrência (botões desabilitados ou com modal "em breve")

Aceitação:
- CRUD completo para os 3 tipos de transação
- Partida dobrada correta (SUM debits == SUM credits por transação)
- Saldos das contas atualizados corretamente após transações
- Autocomplete de entities funcionando com ranking por uso
- Sentiment selector funcional com animação
- Teclado numérico funcional
- Lista agrupada por dia com swipe actions
- Filtros funcionais
- Formatação BRL correta

Arquivos:
- `lib/core/constants/transaction_types.dart`
- `lib/core/constants/sentiment_types.dart`
- `lib/features/transactions/**/*.dart`
- `lib/core/widgets/entity_autocomplete.dart`
- `lib/core/widgets/sentiment_selector.dart`
- `lib/core/widgets/numeric_keypad.dart`
- `lib/core/utils/currency_formatter.dart`
- `lib/core/utils/date_formatter.dart`

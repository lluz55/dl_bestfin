# Tarefa 03 — Database (Drift/SQLite)

> [!IMPORTANT]
> O banco de dados é o coração do BestFin. A modelagem correta com partida dobrada é essencial — erros aqui se propagam para todas as features.

**Fase:** 1 — Fundação
**Prioridade:** 🔴 Crítica
**Pré-requisitos:** [01-project-setup](./01-project-setup.md)

---

## Descrição

Configurar o banco de dados SQLite via Drift com todas as tabelas core do sistema, DAOs (Data Access Objects) com queries reativas, sistema de migrations, seed data (categorias padrão e feriados nacionais) e validação da integridade contábil (partida dobrada).

---

## Subtarefas

### Tabelas Drift

 - [x] Criar tabelas em `lib/core/database/tables/` (conforme SPEC seção 4.2):
  - `accounts.dart` — Contas (corrente, poupança, carteira, investimento, reserva)
  - `transactions.dart` — Transações (header: data, descrição, tipo, sentiment, etc.)
  - `entries.dart` — Lançamentos contábeis (partida dobrada: account_id, type debit/credit, amount)
  - `categories.dart` — Categorias hierárquicas (parent_id self-reference, is_system, icon, color)
  - `entities.dart` — Pagadores/Recebedores (nome, tipo, use_count para ranking)
  - `credit_cards.dart` — Cartões de crédito (limite, dia fechamento, dia vencimento, conta vinculada)
  - `invoices.dart` — Faturas de cartão (mês/ano, status: aberta/fechada/paga)
  - `installment_plans.dart` — Planos de parcelamento (total parcelas, valor parcela, transação origem)
  - `recurring_rules.dart` — Regras de recorrência (frequência, próxima data, ativa/inativa)
  - `goals.dart` — Objetivos financeiros (nome, valor alvo, valor atual, prazo, conta vinculada)
  - `investments.dart` — Investimentos (tipo, valor aplicado, rendimento, vencimento)
  - `financings.dart` — Financiamentos (valor total, taxa, parcelas, sistema amortização)
  - `financing_installments.dart` — Parcelas de financiamento (número, amortização, juros, saldo)
  - `attachments.dart` — Anexos (path, tipo, transação vinculada)
  - `notification_patterns.dart` — Padrões de notificação SMS/push (regex, categoria, conta)
  - `holidays.dart` — Feriados nacionais (data, nome, recorrente)
  - `app_settings.dart` — Configurações do app (key-value: tema, segurança, onboarding, etc.)

### Database Principal

 - [x] Criar `lib/core/database/app_database.dart`:
  - Classe `AppDatabase extends _$AppDatabase`
  - Registrar todas as tabelas
  - Configurar `schemaVersion`
  - Implementar `migration` strategy com `onCreate` (seed data) e `onUpgrade`
  - Singleton pattern ou provider Riverpod

### DAOs (Data Access Objects)

 - [x] Criar DAOs em `lib/core/database/daos/`:
  - `accounts_dao.dart` — CRUD + saldo calculado via entries + listar ativas
  - `transactions_dao.dart` — CRUD com partida dobrada + queries com filtros + paginação
  - `categories_dao.dart` — CRUD + tree building (parent/children) + listar por tipo
  - `entities_dao.dart` — CRUD + busca por nome + ordenar por use_count
  - `credit_cards_dao.dart` — CRUD + fatura atual + próxima fatura
  - `invoices_dao.dart` — CRUD + transações da fatura + fechar/pagar fatura
  - `goals_dao.dart` — CRUD + progresso (valor_atual / valor_alvo)
  - `investments_dao.dart` — CRUD + rendimento acumulado
  - `financings_dao.dart` — CRUD + parcelas + saldo devedor
  - `notification_patterns_dao.dart` — CRUD + match de padrão

### Lógica de Partida Dobrada

 - [x] Implementar no `transactions_dao.dart`:
  - **Despesa:** `debit` na categoria de despesa → `credit` na conta de pagamento
  - **Receita:** `debit` na conta de recebimento → `credit` na categoria de receita
  - **Transferência:** `debit` na conta destino → `credit` na conta origem
  - Toda transação **sempre** gera exatamente 2 entries
  - `SUM(debits) == SUM(credits)` por transação (invariante)

### Seed Data

 - [x] Implementar seed data inserida no `onCreate`:
  - Categorias padrão (conforme SPEC seção 4.2.4): Alimentação, Transporte, Moradia, Saúde, Educação, Lazer, Vestuário, Salário, Freelance, etc.
  - Feriados nacionais brasileiros (conforme SPEC seção 4.2.16): Ano Novo, Carnaval, Tiradentes, etc.
 - [x] Criar `lib/core/constants/default_categories.dart` com lista de categorias padrão (nome, ícone, cor, tipo, is_system)

### Queries Reativas

 - [x] Implementar `.watch()` em todos os DAOs para queries reativas (retornar `Stream`)
 - [x] Queries de lista: `watchAllAccounts()`, `watchTransactionsByPeriod()`, `watchCategoriesTree()`, etc.
 - [x] Queries de detalhe: `watchAccountById()`, `watchTransactionWithEntries()`, etc.

### Code Generation

 - [x] Rodar `nix develop -c dart run build_runner build` para gerar código Drift
 - [x] Verificar que todos os arquivos `.g.dart` são gerados sem erros

### Testes

 - [x] Criar testes unitários em `test/database/`:
  - `accounts_dao_test.dart` — CRUD + saldo via entries
  - `transactions_dao_test.dart` — CRUD + partida dobrada + filtros
  - `categories_dao_test.dart` — CRUD + hierarquia
  - `seed_data_test.dart` — verificar seed data inserida
  - `integrity_test.dart` — verificar `SUM(debits) == SUM(credits)` após operações

---

## Critérios de Aceitação

 - [x] Code generation (`build_runner build`) roda sem erros
 - [x] Seed data (categorias + feriados) inserida automaticamente na primeira execução
 - [x] Partida dobrada: toda transação gera exatamente 2 entries equilibrados
 - [x] Invariante: `SUM(amount WHERE type=debit) == SUM(amount WHERE type=credit)` para cada transação
 - [x] Queries reativas retornam `Stream` e emitem atualizações em tempo real
 - [x] Todos os testes unitários passam para CRUD de todas as entidades
 - [x] Saldo de conta calculado corretamente: `SUM(debits) - SUM(credits)` dos entries

---

## Arquivos Principais

| Arquivo | Ação |
|---------|------|
| `lib/core/database/tables/*.dart` (17 arquivos) | Criar |
| `lib/core/database/app_database.dart` | Criar |
| `lib/core/database/daos/*.dart` (10 arquivos) | Criar |
| `lib/core/constants/default_categories.dart` | Criar |
| `test/database/*_test.dart` (5+ arquivos) | Criar |

---

## Notas e Considerações

> [!NOTE]
> - O Drift gera código fortemente tipado. Usar `@DataClassName` para nomear as classes geradas de forma legível.
> - Entries usam `BigInt` ou `int` com centavos (R$ 10,50 = 1050) para evitar problemas de ponto flutuante. **Nunca usar `double` para valores monetários.**
> - Self-reference em categories (parent_id) requer cuidado com cascading deletes.

> [!TIP]
> - Usar `DatabaseConnection.delayed()` para lazy initialization do banco.
> - Implementar `toString()` nos DAOs para facilitar debugging.
> - Criar um DAO base com operações comuns (CRUD genérico) para reduzir boilerplate.

> [!WARNING]
> - A partida dobrada é a base contábil do app. Qualquer bug aqui causa inconsistência de saldos. Testar exaustivamente.
> - Migrations devem ser incrementais e nunca destrutivas. Planejar o `schemaVersion` desde o início.

> [!CAUTION]
> - **Nunca deletar entries diretamente.** Sempre deletar/atualizar via transação para manter a integridade.
> - Valores monetários em **centavos (int)**. A conversão para display (R$ com vírgula) é feita apenas na camada de apresentação.

# Tarefa 04 — Contas

**Fase:** 1 — Fundação
**Prioridade:** 🔴 Crítica
**Pré-requisitos:** [02-design-system](./02-design-system.md), [03-database-setup](./03-database-setup.md)

---

## Descrição

Implementar a feature completa de contas financeiras (Corrente, Poupança, Carteira, Investimento, Reserva) com CRUD, saldo calculado via entries (partida dobrada), pickers de ícone e cor, e UI com design M3 Expressive. O saldo de cada conta é **derivado** — calculado a partir dos entries contábeis, nunca armazenado diretamente.

---

## Subtarefas

### Constantes e Models

 - [x] Criar `lib/core/constants/account_types.dart`:
  - Enum `AccountType`: corrente, poupanca, carteira, investimento, reserva
  - Ícone padrão por tipo (ex: corrente → `Icons.account_balance`, carteira → `Icons.wallet`)
  - Cor padrão por tipo
  - Label em pt-BR por tipo

 - [x] Criar `lib/features/accounts/domain/models/account.dart`:
  - Model com campos: id, nome, tipo, ícone, cor, ativa, saldo (calculado)
  - Factory from database entity + saldo
  - `copyWith()`

### Data Layer

 - [x] Criar `lib/features/accounts/data/repositories/account_repository.dart`:
  - CRUD via `AccountsDao`
  - `watchAllAccounts()` → `Stream<List<Account>>` (com saldo calculado)
  - `watchAccountById(int id)` → `Stream<Account>`
  - `getAccountBalance(int id)` → saldo via `SUM` de entries
  - `createWithInitialBalance()` → criar conta + entry de saldo inicial
  - `canDelete(int id)` → verificar se tem transações vinculadas

### Domain Layer (Use Cases)

 - [x] Criar `lib/features/accounts/domain/usecases/`:
  - `create_account.dart` — criar conta com saldo inicial (gera entry de abertura)
  - `update_account.dart` — atualizar dados da conta (nome, ícone, cor)
  - `delete_account.dart` — deletar (soft delete/inativar se tem transações) + validar que não é a última ativa
  - `get_account_balance.dart` — calcular saldo via entries

### Presentation Layer — Providers

 - [x] Criar `lib/features/accounts/presentation/providers/accounts_provider.dart`:
  - `accountsProvider` — lista reativa de todas as contas com saldo
  - `accountByIdProvider(int id)` — conta individual reativa
  - `totalBalanceProvider` — soma de todos os saldos
  - `activeAccountsProvider` — apenas contas ativas

### Presentation Layer — Telas

 - [x] Criar `lib/features/accounts/presentation/screens/accounts_list_screen.dart`:
  - Lista de contas com card por conta (ícone, nome, tipo, saldo)
  - Saldo total no topo
  - FAB para adicionar nova conta
  - Contas inativas em seção separada (colapsável)
  - Pull-to-refresh

 - [x] Criar `lib/features/accounts/presentation/screens/account_form_screen.dart`:
  - Formulário com campos: nome (required), tipo (dropdown), ícone (picker), cor (picker), saldo inicial (numeric input)
  - Modo criação e modo edição
  - Validação de campos
  - Preview do card da conta em tempo real no topo

 - [x] Criar `lib/features/accounts/presentation/screens/account_detail_screen.dart`:
  - Header com card da conta (ícone, nome, saldo animado)
  - Extrato: lista de transações da conta (últimos 30 dias)
  - Gráfico de evolução de saldo (line chart via fl_chart)
  - Ações: editar, inativar/ativar, deletar

### Presentation Layer — Widgets

 - [x] Criar `lib/features/accounts/presentation/widgets/account_card.dart`:
  - Card expressivo com shape assimétrica
  - Ícone colorido, nome, tipo, saldo com `AmountDisplay`
  - Spring animation ao aparecer
  - Tap para ir ao detalhe

### Widgets Core Compartilhados

 - [x] Criar `lib/core/widgets/icon_picker.dart`:
  - Grid de Material icons organizados por categoria
  - Busca por nome do ícone
  - Seleção com highlight
  - Bottom sheet ou dialog

 - [x] Criar `lib/core/widgets/color_picker.dart`:
  - Paleta de cores pré-definidas (12-16 cores harmoniosas)
  - Seleção com checkmark
  - Preview do ícone com a cor selecionada

 - [x] Criar `lib/core/widgets/account_selector.dart`:
  - Dropdown ou bottom sheet para selecionar conta
  - Mostra ícone, nome e saldo de cada conta
  - Filtra apenas contas ativas
  - Usado nos formulários de transação

### Regras de Negócio

 - [x] Impedir deleção de conta com transações vinculadas — apenas inativar (soft delete)
 - [x] Garantir que pelo menos 1 conta ativa existe sempre (validação antes de inativar/deletar)
 - [x] Saldo inicial gera um entry contábil de abertura (não é um campo estático)

---

## Critérios de Aceitação

 - [x] CRUD completo de contas funcionando (criar, ler, atualizar, deletar/inativar)
 - [x] Saldo correto calculado via entries (partida dobrada), não armazenado diretamente
 - [x] Saldo inicial cria entry contábil de abertura
 - [x] 5 tipos de conta com ícones e cores distintos
 - [x] Animações M3 Expressive nos cards (spring, shapes assimétricas)
 - [x] Picker de ícone funcional com busca
 - [x] Picker de cor funcional com preview
 - [x] Conta não pode ser deletada se tem transações (apenas inativada)
 - [x] App impede que todas as contas sejam removidas/inativadas
 - [x] Gráfico de evolução de saldo funcional
 - [x] Saldo total consolidado correto

---

## Arquivos Principais

| Arquivo | Ação |
|---------|------|
| `lib/core/constants/account_types.dart` | Criar |
| `lib/features/accounts/domain/models/account.dart` | Criar |
| `lib/features/accounts/data/repositories/account_repository.dart` | Criar |
| `lib/features/accounts/domain/usecases/create_account.dart` | Criar |
| `lib/features/accounts/domain/usecases/update_account.dart` | Criar |
| `lib/features/accounts/domain/usecases/delete_account.dart` | Criar |
| `lib/features/accounts/domain/usecases/get_account_balance.dart` | Criar |
| `lib/features/accounts/presentation/providers/accounts_provider.dart` | Criar |
| `lib/features/accounts/presentation/screens/accounts_list_screen.dart` | Criar |
| `lib/features/accounts/presentation/screens/account_form_screen.dart` | Criar |
| `lib/features/accounts/presentation/screens/account_detail_screen.dart` | Criar |
| `lib/features/accounts/presentation/widgets/account_card.dart` | Criar |
| `lib/core/widgets/icon_picker.dart` | Criar |
| `lib/core/widgets/color_picker.dart` | Criar |
| `lib/core/widgets/account_selector.dart` | Criar |

---

## Notas e Considerações

> [!NOTE]
> - O saldo é sempre **calculado**, nunca armazenado. Isso garante consistência com a partida dobrada.
> - O saldo inicial é modelado como um entry de abertura (debit na conta, credit em "Saldo Inicial" — categoria especial do sistema).
> - O `account_selector` será amplamente reutilizado nas telas de transação, transferência e cartão de crédito.

> [!TIP]
> - Cachear o saldo calculado no provider (com invalidação reativa) para evitar queries pesadas a cada rebuild.
> - Usar `AnimatedSwitcher` para transições suaves ao alternar entre contas.

> [!WARNING]
> - A inativação de conta deve preservar todos os dados históricos. Contas inativas não aparecem nos seletores, mas seus entries continuam existindo para fins de relatório.

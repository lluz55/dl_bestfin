# Tarefa 22 — Controles Reais do Dashboard (Livre para Gastar, Lançamentos Futuros e Objetivos) ✅

> **Fase:** 2 — Recursos Financeiros
> **Prioridade:** 🟡 Alta
> **Estimativa:** Média
> **Última atualização:** 2026-05-28

## Descrição

Implementar a lógica real e a integração de dados para os três cards da tela principal (Dashboard) que atualmente funcionam como stubs estáticos com a marcação "Fase 2":
1. **Livre para gastar:** Cálculo dinâmico do saldo disponível descontando despesas pendentes e metas de poupança do mês.
2. **Próximos Lançamentos:** Lista dinâmica de transações futuras/agendadas pendentes (`isCompleted = false`), ordenadas por data de vencimento.
3. **Metas e Objetivos:** Exibição do progresso reativo e real dos objetivos financeiros ativos do usuário.

Isso removerá os mocks estáticos e as marcações temporárias, tornando a Home Page 100% dinâmica e integrada com o Drift ORM e Riverpod.

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [07-dashboard](./07-dashboard.md) | Estrutura básica do Dashboard | 🟢 Concluído |
| [11-recurring](./11-recurring.md) | Transações recorrentes e agendamento | 🟢 Concluído |
| [12-goals](./12-goals.md) | Objetivos Financeiros | 🟢 Concluído |

---

## Subtarefas

### 1. Camada de Domínio e Agregação (Models & Use Case) ✅

- [x] **Atualizar o modelo `DashboardData`** (`lib/features/dashboard/domain/models/dashboard_data.dart`)
- [x] **Modificar o use case `GetDashboardData`** (`lib/features/dashboard/domain/usecases/get_dashboard_data.dart`):
  - [x] Adicionar injeção do `GoalRepository` no construtor.
  - [x] Atualizar a assinatura do stream principal para escutar de forma agregada as atualizações reativas de transações, contas, investimentos, financiamentos e objetivos ativos via `goalsRepository.watchActiveGoals()`.
  - [x] **Implementar o cálculo do "Livre para gastar"**
  - [x] **Filtrar próximos lançamentos**
  - [x] **Obter objetivos ativos**

### 2. Camada de Apresentação e Refatoração dos Cards ✅

- [x] **Refatorar o card "Livre para gastar"** (`lib/features/dashboard/presentation/widgets/free_to_spend_card.dart`)
- [x] **Refatorar o card "Próximos Lançamentos"** (`lib/features/dashboard/presentation/widgets/upcoming_bills.dart`)
- [x] **Refatorar o card "Metas e Objetivos"** (`lib/features/dashboard/presentation/widgets/goals_progress.dart`)
- [x] **Atualizar a tela do Dashboard** (`lib/features/dashboard/dashboard_screen.dart`)

### 3. Testes e Validação ✅

- [x] **Implementar Testes Unitários:**
  - [x] Validar a lógica de agregação do `GetDashboardData` com mocks de transações pendentes, objetivos ativos e saldos de contas.
  - [x] Garantir o correto cálculo matemático e tratamento de cenários extremos.
- [x] **Análise de Linter:**
  - [x] Executar `nix develop -c flutter analyze`

---

## Critérios de Aceitação

- [x] O card "Livre para gastar" exibe o saldo calculado de forma correta e sem mocks em sua progress ring.
- [x] O card "Próximos Lançamentos" exibe apenas transações futuras não confirmadas/não liquidadas.
- [x] O card "Metas e Objetivos" carrega os dados em tempo real dos objetivos salvos no Drift ORM.
- [x] Os badges de "Fase 2" e opacidades de stubs foram completamente removidos da tela inicial.
- [x] Todos os testes unitários do Dashboard passam sem erros no ambiente Nix.

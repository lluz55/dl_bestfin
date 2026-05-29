# Tarefa 07 — Dashboard

**Fase:** 1 — Fundação
**Prioridade:** 🟡 Alta
**Pré-requisitos:** 04-accounts, 05-categories, 06-transactions

Descrição: Implementar a tela principal (Dashboard) com saldo consolidado, receita vs despesa, gráfico donut de categorias, próximas contas e progresso de objetivos.

Subtarefas:
 - [x] Criar `lib/features/dashboard/domain/models/dashboard_data.dart`: model agregando dados do dashboard
 - [x] Criar `lib/features/dashboard/domain/usecases/get_dashboard_data.dart`: use case que agrega saldo total, receita/despesa do mês, top categorias, próximas contas
 - [x] Criar `lib/features/dashboard/presentation/providers/dashboard_provider.dart`: provider reativo
 - [x] Criar `lib/features/dashboard/presentation/screens/dashboard_screen.dart`: tela principal scrollável
 - [x] Criar `lib/features/dashboard/presentation/widgets/balance_card.dart`: saldo total com animated counter + shape expressiva (cantos assimétricos)
 - [x] Criar `lib/features/dashboard/presentation/widgets/free_to_spend_card.dart`: "Livre para gastar" (stub — cálculo completo na Fase 2)
 - [x] Criar `lib/features/dashboard/presentation/widgets/spending_donut.dart`: donut chart com top 5 categorias + "Outros" via fl_chart
 - [x] Criar `lib/features/dashboard/presentation/widgets/income_expense_bar.dart`: mini bar chart receita vs despesa do mês
 - [x] Criar `lib/features/dashboard/presentation/widgets/upcoming_bills.dart`: lista das próximas despesas/faturas (stub — completo na Fase 2)
 - [x] Criar `lib/features/dashboard/presentation/widgets/goals_progress.dart`: rings de progresso dos objetivos (stub — completo na Fase 2)
 - [x] Criar `lib/features/dashboard/presentation/widgets/insight_card.dart`: card de insight contextual (stub — completo na Fase 3)
 - [x] Aplicar staggered animations nos cards do dashboard
 - [x] Pull-to-refresh para atualizar dados

Aceitação:
- Dashboard mostra saldo consolidado correto (soma de todas as contas)
- Animated counter no saldo
- Donut chart com categorias do mês corretas
- Mini bar chart receita vs despesa
- Cards com shapes expressivas e spring animations
- Pull-to-refresh funcional
- Stubs para features da Fase 2 presentes mas desabilitados

Arquivos:
- `lib/features/dashboard/domain/models/dashboard_data.dart`
- `lib/features/dashboard/domain/usecases/get_dashboard_data.dart`
- `lib/features/dashboard/presentation/**/*.dart`

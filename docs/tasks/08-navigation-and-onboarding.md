# Tarefa 08 — Navegação e Onboarding

**Fase:** 1 — Fundação
**Prioridade:** 🟡 Alta
**Pré-requisitos:** 02-design-system, 07-dashboard

Descrição: Implementar a navegação principal (Bottom Navigation Bar + GoRouter + FAB global) e o wizard de onboarding.

Subtarefas:
 - [x] Configurar GoRouter em `lib/app.dart`: rotas para todas as telas, guards (onboarding completed? auth?)
 - [x] Criar shell route com Bottom Navigation Bar: Dashboard, Transações, Relatórios, Mais
 - [x] Criar FAB flutuante global (nova transação) com menu expandido: +Despesa, +Receita, +Transferência
 - [x] Criar `lib/features/onboarding/presentation/screens/onboarding_screen.dart`: PageView com 5 passos
 - [x] Criar `lib/features/onboarding/presentation/widgets/welcome_step.dart`: logo + animação Lottie + descrição + botão
 - [x] Criar `lib/features/onboarding/presentation/widgets/create_account_step.dart`: formulário de primeira conta
 - [x] Criar `lib/features/onboarding/presentation/widgets/select_categories_step.dart`: seleção de categorias padrão
 - [x] Criar `lib/features/onboarding/presentation/widgets/notification_permission_step.dart`: solicitar permissão (Android) ou skip
 - [x] Criar step de segurança: configurar biometria/PIN ou skip
 - [x] Criar `lib/features/onboarding/presentation/providers/onboarding_provider.dart`
 - [x] Salvar `onboarding_completed=true` em app_settings após concluir
 - [x] Guard de rota: redirecionar para onboarding se não completado
 - [x] Criar `lib/features/settings/presentation/screens/settings_screen.dart` (básico): tema, segurança, sobre
 - [x] Implementar segurança com local_auth: biometria na abertura do app + fallback PIN
 - [x] Criar tela "Mais" com menu de navegação para features

Aceitação:
- Bottom Navigation Bar funcional com 4 tabs
- FAB global visível em todas as tabs
- FAB expandido com 3 opções (Despesa/Receita/Transferência)
- Onboarding wizard funcional com 5 passos
- Primeira conta criada no onboarding
- Categorias padrão inseridas
- GoRouter guards funcionando (redirect para onboarding/auth)
- Biometria/PIN funcional
- Navegação fluida com transições M3 Expressive

Arquivos:
- `lib/app.dart` (atualizar)
- `lib/features/onboarding/presentation/**/*.dart`
- `lib/features/settings/presentation/screens/settings_screen.dart`
- Configuração GoRouter
- FAB widget global

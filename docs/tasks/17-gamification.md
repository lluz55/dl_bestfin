# Tarefa 17 — Gamificação ✅

> Implementar elementos de gamificação: streaks de orçamento, badges/conquistas, celebrações animadas e insights contextuais no dashboard.

**Fase:** 3 — Automação & Avançado  
**Prioridade:** 🟢 Média  
**Pré-requisitos:** [06-transactions](06-transactions.md), [12-goals](12-goals.md)

---

## Subtarefas

### 17.1 — Sistema de Streaks ✅

- [x] Criar tabela `streaks_table.dart` no Drift
- [x] Criar `streaks_dao.dart` com queries para incrementar, resetar e consultar streaks
- [x] Implementar lógica de streak "dias consecutivos registrando transações"
- [x] Implementar lógica de streak "dias sob orçamento"
- [x] Criar `StreakProvider` (Riverpod) para expor dados reativamente
- [x] Persistir `longestStreak` para histórico

### 17.2 — Sistema de Badges/Conquistas ✅

- [x] Criar tabela `badges_table.dart`
- [x] Criar `badges_dao.dart` para consultar e desbloquear badges
- [x] Implementar verificação de condições para cada badge
- [x] Criar `BadgeProvider` com stream reativo para notificar desbloqueios
- [x] Implementar sistema de hooks: verificar badges relevantes após cada ação
- [x] Criar assets de ícones para cada badge

### 17.3 — Celebrações Animadas ✅

- [x] Criar widget `BadgeUnlockOverlay` que exibe diálogo ao desbloquear badge
- [x] Integrar celebrações aos eventos: Badge desbloqueado → Diálogo com animação
- [x] Garantir que celebrações não interrompam fluxos críticos

### 17.4 — Widget de Streak no Dashboard ✅

- [x] Criar widget `StreaksDashboardWidget` para exibir no dashboard
- [x] Integrar no `DashboardScreen` como card na seção superior
- [x] Tap no card → navegar para tela de conquistas

### 17.5 — Tela de Conquistas ✅

- [x] Criar `GamificationHubScreen` em `lib/features/gamification/presentation/screens/`
- [x] Layout em grid com cards de badges e streaks
- [x] Adicionar rota no `GoRouter` e link no menu "Mais"

### 17.6 — Insights Contextuais no Dashboard ✅

- [x] Criar `InsightsService` em `lib/features/gamification/domain/`
- [x] Implementar tipos de insights: sentimentos, economia, categorias
- [x] Atualizar `InsightCard` no dashboard para exibir insights reais

### 17.7 — Notificações Motivacionais (Pendente/Opcional)

- [ ] Criar sistema de notificações periódicas motivacionais (Fase futura)

---

## Critérios de Aceitação

- [x] Streaks calculados corretamente
- [x] Badges desbloqueiam automaticamente
- [x] Celebrações exibidas ao desbloquear
- [x] Widget de streak visível no dashboard
- [x] Tela de conquistas funcional
- [x] Insights contextuais baseados em dados reais

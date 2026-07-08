---
type: Task
id: "35"
title: Lote de Correções UX — Julho 2026
status: completed
timestamp: 2026-07-07T00:00:00Z
---

# Tarefa 35 — Lote de Correções UX (Julho 2026)

**Fase:** 3 — UX Polish
**Prioridade:** 🟡 Alta
**Pré-requisitos:** [04-accounts](./04-accounts.md), [08-navigation-and-onboarding](./08-navigation-and-onboarding.md), [02-design-system](./02-design-system.md)

---

## Descrição

Seis correções/melhorias pontuais pedidas pelo usuário:

1. Bloquear criação/renomeação de contas com nome duplicado.
2. Persistir o progresso do onboarding — se o SO matar o processo antes de
   completar o setup, o wizard retoma do step onde parou em vez de recomeçar.
3. Remover as cores pré-definidas do tema (`ThemePreset`), deixando apenas
   cor personalizada (seed) e cores do papel de parede (Material You).
4. Expor o sheet completo de Aparência nas Configurações (antes só existia
   no botão da home).
5. Consertar o teclado do PIN: numpad congelava na etapa de confirmação do
   `PinSetupScreen` (`_pin` ficava cheio) e não havia suporte a teclado
   físico (Linux desktop).
6. Novos tipos de conta: `foodVoucher` (Alimentação/VA) e `mealVoucher`
   (Refeição/VR), incluídos nos `liquidTypes` do dashboard.

---

## Subtarefas

 - [x] `AccountRepositoryImpl._ensureUniqueName` (case-insensitive, trim,
   ignora `credit_card_bill`, `excludeId` no update) +
   `DuplicateAccountNameException` com mensagem amigável
 - [x] Exibir o erro de duplicidade no `AccountFormScreen` e no
   `CreateAccountStep` do onboarding (que antes engolia erros em silêncio)
 - [x] `OnboardingActions.saveStep/readStep` + chave `onboarding_step`;
   `initialOnboardingStep` lido antes de `runApp()`; `PageController`
   retoma do step salvo; chave removida em `complete()` e no clear-all
 - [x] Remover `ThemePreset` (arquivo deletado), campo `preset` do
   `ThemeState` e branch de preset em `main.dart`; `CustomSeedState`
   simplificado (`effectiveSeed`, sem flag `useCustomSeed`)
 - [x] Sheet de Aparência sem seletor Predefinidas/Personalizada — cor
   personalizada aparece direto quando cor dinâmica está desligada
 - [x] Tile "Tema" nas Configurações abre `showThemeSettingsSheet`
   (substituiu os tiles antigos de modo de brilho e cor dinâmica)
 - [x] `PinInputWidget.clear()` chamado na transição para confirmação e no
   lockout; `Focus` com `onKeyEvent` para dígitos/backspace de teclado físico
 - [x] `AccountType.foodVoucher` e `AccountType.mealVoucher` (label, ícone,
   cor) + inclusão nos dois conjuntos `liquidTypes` de `get_dashboard_data.dart`
 - [x] `flutter analyze` sem novos erros/warnings; suite de testes passa
   (única falha pré-existente: `sync_queue_integration_test` afetado por
   mudança local não commitada em `transaction_repository.dart`)

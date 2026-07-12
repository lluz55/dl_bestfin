---
type: Task
id: "53"
title: "Padronização do SectionHeader e Theme nos menus e configurações"
status: completed
priority: medium
tags: [ux, padronizacao, design-system, refatoracao]
timestamp: 2026-07-12T00:00:00Z
---

# Tarefa 53 — Padronização do SectionHeader e Theme nos menus e configurações

**Fase:** UX / Design System
**Prioridade:** 🟡 Média
**Estimativa:** Pequena
**Última atualização:** 2026-07-12

## Descrição

Padronizar o widget `SectionHeader` (cabeçalho de seção) que estava duplicado em 5
arquivos diferentes com implementações ligeiramente distintas, e uniformizar o uso
de `context.colorScheme`/`context.textTheme` via extension methods em vez de
`Theme.of(context)`.

## Mudanças Realizadas

### 1. Widget compartilhado `SectionHeader`

Criado em `lib/core/widgets/section_header.dart` — widget `const` que aceita
`title` (obrigatório) e `isFirst` (opcional, para padding diferenciado). Usa
`titleSmall` com `onSurfaceVariant` conforme padrão M3 para headers de seção.

### 2. Refatoração do `more_screen.dart`

- `_SectionHeader` substituído pelo `SectionHeader` compartilhado (+ import)
- Cores hardcoded substituídas por cores do `ColorScheme`:
  - `Colors.orange` → `cs.primary` (Conquistas)
  - `Color(0xFF4CAF50)` → `cs.tertiary` (Orçamento)
- `Theme.of(context).colorScheme/textTheme` → `context.colorScheme`/`context.textTheme`
  (extension `context_extensions.dart`)
- Classe `_SectionHeader` removida

### 3. Refatoração do `settings_screen.dart`

- `_SectionHeader` substituído pelo `SectionHeader` compartilhado (+ import)
- Parâmetros `cs`/`tt` removidos do `_SettingsSection` (não mais necessários)
- `Theme.of(ctx).colorScheme/textTheme` → `ctx.colorScheme`/`ctx.textTheme`
- Classe `_SectionHeader` removida

### 4. Refatoração do `sync_settings_screen.dart`

- `_SectionHeader` substituído pelo `SectionHeader` compartilhado (+ import)
- Import do `context_extensions.dart` adicionado
- `Theme.of(context).colorScheme/textTheme` → `context.colorScheme`/`context.textTheme`
- Classe `_SectionHeader` removida

## Checklist

- [x] Criar widget compartilhado `SectionHeader` em `lib/core/widgets/`
- [x] Substituir `_SectionHeader` no `more_screen.dart`
- [x] Substituir cores hardcoded por scheme colors no `more_screen.dart`
- [x] Padronizar `Theme.of(context)` → `context` extension no `more_screen.dart`
- [x] Substituir `_SectionHeader` no `settings_screen.dart`
- [x] Remover `cs`/`tt` do `_SettingsSection`
- [x] Substituir `_SectionHeader` no `sync_settings_screen.dart`
- [x] Adicionar `context_extensions.dart` no `sync_settings_screen.dart`
- [x] Padronizar `Theme.of(context)` → `context` extension no `sync_settings_screen.dart`
- [x] Rodar `flutter analyze` — 0 erros

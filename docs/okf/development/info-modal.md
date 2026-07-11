---
type: Concept
title: Modal Informativo (Info Modal)
description: "Exceção ao padrão de modais do app: os modais descritivos de páginas usam Dialog fixo e centralizado, não showAdaptiveModal."
tags: [ui, modal, info, dialogo]
related: [development/conventions]
timestamp: 2026-07-11T00:00:00Z
---

## O Que É

Os **modais informativos** são janelas de diálogo acionadas pelo botão `info_outline_rounded`
no header de cada tela do app. Eles explicam o propósito da página e listam suas funcionalidades
principais.

## Exceção ao Padrão de Modais

Diferente do resto do app, que usa `showAdaptiveModal` (bottom sheet no mobile / painel flutuante
no desktop), **os modais informativos usam `showDialog` com `Dialog`** — um diálogo centralizado
e de tamanho fixo em **todas as plataformas**.

### Motivação

| Razão | Detalhe |
|---|---|
| **Proximidade** | O botão está no AppBar (topo da tela); um `Dialog` centrado fica naturalmente próximo. |
| **Leveza** | Conteúdo puramente descritivo (sem formulários ou ações complexas) — não justifica um bottom sheet. |
| **Consistência** | Mesma apresentação em mobile e desktop, diferentemente do `showAdaptiveModal` que alterna entre bottom sheet e painel. |

## Implementação

**Arquivo:** `lib/core/widgets/page_info_modal.dart`

### Widgets

- `PageInfoButton` — `IconButton` com `Icons.info_outline_rounded` que abre o modal.
- `PageInfoContent` — corpo do diálogo com ícone, título, descrição e lista de funcionalidades.

### Função utilitária

`showPageInfoModal()` — abre o `Dialog` com `PageInfoContent` de qualquer lugar do código
(usada no Dashboard, que tem header customizado).

### Como usar em uma tela

```dart
// Em telas que usam AppPageAppBar — basta passar infoDescription:
appBar: AppPageAppBar(
  title: 'Minhas Contas',
  infoDescription: 'Descrição da página...',
  infoFeatures: [
    'Funcionalidade 1',
    'Funcionalidade 2',
  ],
),

// Em telas com header customizado (ex: Dashboard):
showPageInfoModal(
  context: context,
  title: 'Título',
  description: 'Descrição...',
  features: ['Funcionalidade 1'],
);
```

## Regras

1. **Sempre usar `showDialog`** — nunca `showAdaptiveModal` ou `showModalBottomSheet`.
2. **Texto em português (BR)**, consistente com o idioma do app.
3. **Descrições concisas** — 2-3 frases explicando o propósito da tela.
4. **Features opcionais** — lista de bullets com `check_circle_rounded` para funcionalidades.
5. **Apenas telas "relevantes"** recebem o botão:
   - Telas de listagem, hub e detalhe → sim.
   - Telas de formulário (add/edit) → não (são autoexplicativas).
   - Telas utilitárias de fluxo (onboarding, PIN, sync login) → não.
6. **Import `page_info_modal.dart`** (ou via `AppPageAppBar` que já o importa indiretamente).

## Referências

- [Convenções de Código — Padrões de UI](conventions.md)
- `lib/core/widgets/page_info_modal.dart`
- `lib/core/widgets/app_page_appbar.dart` (parâmetros `infoDescription` / `infoFeatures`)

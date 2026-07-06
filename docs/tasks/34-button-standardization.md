---
type: Task
id: "34"
title: Padronização Visual de Botões
status: completed
timestamp: 2026-07-05T12:00:00Z
---

# Tarefa 34 — Padronização Visual de Botões

**Fase:** 3 — UX Polish
**Prioridade:** 🟡 Alta
**Pré-requisitos:** [02-design-system](./02-design-system.md)

---

## Descrição

Unificar o padrão visual dos botões em todo o app: antes havia ~90 usos de
`styleFrom(...)` inline misturando raios (12/14/16/20) e alturas (44/48/52/56),
três estilos de FAB competindo e nenhum componente genérico de botão.

Decisões: altura padrão **52** (compacta 44), raio único **16**
(`ExpressiveShapes.button`), FABs unificados no `ExpressiveFAB`.

---

## Subtarefas

 - [x] Criar `lib/core/theme/dimens.dart` (`AppDimens`: buttonHeight 52,
   buttonHeightCompact 44, fabHeight 56, minTapTarget 44)
 - [x] Completar `app_theme.dart`: minimumSize/padding/textStyle nos temas
   filled/elevated/outlined + novos textButtonTheme, iconButtonTheme,
   segmentedButtonTheme e floatingActionButtonTheme
 - [x] Criar `lib/core/widgets/app_button.dart` (`AppButton` com variantes
   primary/tonal/outlined/text/destructive/destructiveOutlined, tamanhos
   standard/compact, `expanded`, `loading`, `color` de domínio)
 - [x] Estender `ExpressiveFAB` com construtor `.extended` (sempre expandido,
   toque único, largura intrínseca em vez dos 196px fixos)
 - [x] Migrar os 9 `FloatingActionButton.extended` para `ExpressiveFAB.extended`
 - [x] Migrar ~85 sites de `styleFrom` inline para `AppButton`/tema
   (transactions, backup, goals, onboarding, sync, credit_cards, investments,
   financing, budgets, accounts, categories, dashboard, notifications,
   pdf_import, recurring, settings, security, installments, reports, core)
 - [x] Testes: `test/core/widgets/app_button_test.dart` e
   `test/core/widgets/expressive_fab_test.dart`
 - [x] Formulário de transação: "Dividir entre categorias" deixou de ser um
   `ActionChip` solto e virou estado do próprio campo Categoria — ícone
   `call_split` como ação interna do campo (despesas) e, quando dividida, o
   mesmo campo mostra "Categoria · dividida: N — nomes" com ✕ para desfazer

---

## Critérios de Aceitação

 - [x] `flutter analyze` sem erros/warnings novos
 - [x] `flutter test` — 109 testes passando (12 novos)
 - [x] Zero `styleFrom` com shape/raio fora de `app_theme.dart`/`app_button.dart`
 - [x] Zero `FloatingActionButton.extended` em `lib/`

---

## Arquivos Principais

| Arquivo | Ação |
|---------|------|
| `lib/core/theme/dimens.dart` | Criar |
| `lib/core/theme/app_theme.dart` | Estender temas de botão |
| `lib/core/widgets/app_button.dart` | Criar |
| `lib/core/widgets/expressive_fab.dart` | Adicionar modo `.extended` |
| `lib/features/**` (~55 arquivos) | Migrar styleFrom → AppButton/tema |

---

## Notas e Considerações

> [!NOTE]
> Restam 3 `styleFrom` intencionais em features: dois botões densos "Criar"
> (`goals_progress.dart`, `budgets_overview_card.dart`) e o botão de importação
> do `pdf_review_screen.dart` (label dinâmico + spinner no ícone, padrão que o
> `AppButton(loading:)` não cobre). Todos usam apenas minimumSize/padding — o
> shape vem sempre do tema.

> [!NOTE]
> Fora de escopo (follow-up): os ~85 botões custom em InkWell/GestureDetector
> e os internals do `GlobalFAB`.

---
type: Task
title: "Cobertura de testes de widget/UI"
description: "Adicionar widget/golden tests para fluxos críticos — hoje só há 3 widget tests para 21 features."
tags: [quality, tests, ui, widget-test]
timestamp: 2026-07-26T00:00:00Z
status: not_started
progress: 0/4
---

## Descrição

A suíte tem 37 arquivos de teste, forte em domain/data (DAOs, backup, sync, reports) mas fraca em
UI: apenas `app_button_test.dart`, `expressive_fab_test.dart` e `lock_overlay_test.dart`.
Fluxos críticos de UI não têm rede de segurança.

## Checklist

- [ ] Widget test do formulário de transação (`transaction_form_screen.dart`)
- [ ] Widget test do lançamento rápido (`quick_transaction_sheet.dart`)
- [ ] Widget test do fluxo de onboarding
- [ ] (Opcional) Golden tests dos principais widgets do design system

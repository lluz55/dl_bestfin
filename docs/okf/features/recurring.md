---
type: Feature
title: Recorrências
description: Regras de transações recorrentes com geração automática e hub de assinaturas.
tags: [recorrência, assinaturas, automação, agendado]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Permite criar regras de recorrência (mensal, semanal, etc.) que geram transações automaticamente quando o app é aberto.

## Geração Automática

Em `main.dart` (`initState`), o provider `generateRecurringProvider` é lido. Ele verifica todas as regras ativas e cria as transações pendentes desde a última execução.

## Modelos

- `RecurringRule` — `lib/features/recurring/domain/models/recurring_rule.dart`

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/recurring_list_screen.dart` | Lista de regras |
| `screens/recurring_form_screen.dart` | Criação/edição de regra |
| `screens/subscriptions_hub_screen.dart` | Hub de assinaturas com total mensal |

## Frequências Suportadas

`daily`, `weekly`, `biweekly`, `monthly`, `bimonthly`, `quarterly`, `semiannual`, `annual`

## Dependências

- [Transações](transactions.md) — gera `Transaction` para cada ocorrência
- [Contas](accounts.md) — conta de débito da regra
- [Categorias](categories.md) — categoria da transação gerada
- [LLM](llm.md) — detector de redundância planejado (Task 25 A2)

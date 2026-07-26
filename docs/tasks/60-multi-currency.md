---
type: Task
title: "Suporte a multi-moeda"
description: "Permitir contas/transações em múltiplas moedas com conversão de câmbio, saindo do BRL-only hardcoded."
tags: [feature, currency, i18n, accounts]
timestamp: 2026-07-26T00:00:00Z
status: not_started
progress: 0/5
---

## Descrição

Hoje o app é BRL-only e a moeda está hardcoded (SPEC 1.3, `currency_formatter.dart`). Suporte a
múltiplas moedas abre uso para viagens e usuários fora do Brasil.

Escopo mínimo: moeda por conta, exibição correta por locale, e conversão para uma moeda de
referência nos relatórios/dashboard (taxa manual ou fonte de câmbio).

## Checklist

- [ ] Adicionar campo de moeda em contas (tabela + migration Drift)
- [ ] Generalizar `currency_formatter.dart` para moeda/locale configuráveis
- [ ] Definir moeda de referência e mecanismo de câmbio (manual vs. fonte externa)
- [ ] Converter agregações de dashboard/relatórios para a moeda de referência
- [ ] Testes de formatação e conversão

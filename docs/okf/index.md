---
okf_version: "0.1"
type: Bundle Index
title: BestFin — Knowledge Bundle
description: Curated context about the BestFin Flutter app for AI agents and developers.
tags: [bestfin, flutter, finance, android, linux]
timestamp: 2026-06-29T00:00:00Z
---

BestFin é um aplicativo de finanças pessoais multiplataforma (Android, Linux) com Material Design 3 Expressive, contabilidade de partida dobrada, LLM on-device e sincronização E2E criptografada.

# Arquitetura & Padrões

* [Visão Geral da Arquitetura](architecture/overview.md) - Feature-First + Clean Architecture, stack técnico
* [Contabilidade de Partida Dobrada](architecture/double-entry.md) - Invariante central do domínio financeiro
* [Padrões Riverpod](architecture/riverpod-patterns.md) - Como providers são organizados e usados
* [Padrões Drift](architecture/drift-patterns.md) - DAOs, tabelas e migrations

# Desenvolvimento

* [Ambiente Nix](development/environment.md) - Comandos obrigatórios via `nix develop -c`
* [Geração de Código](development/code-generation.md) - build_runner, Drift e Riverpod
* [Convenções de Código](development/conventions.md) - Estilo Dart, imports, segurança
* [Modal Informativo](development/info-modal.md) - Exceção ao padrão de modais — `Dialog` centralizado para info de páginas
* [Releases e Versão no App](development/releases.md) - Versão (`kAppVersion`) exibida e atualizada a cada release; fluxo de binários
* [Workflow OKF para Agentes](development/okf-workflow.md) - Protocolo de 6 passos e integração com Claude Code e opencode

# Domínio Financeiro

* [Transação](domain/transaction.md) - Entidade raiz do domínio
* [Lançamento (Entry)](domain/entry.md) - Pernas de débito/crédito da partida dobrada
* [Conta](domain/account.md) - Contas financeiras (corrente, poupança, carteira)
* [Categoria](domain/category.md) - Árvore hierárquica de categorias

# Features

* [Dashboard](features/dashboard.md) - Tela principal com widgets configuráveis
* [Transações](features/transactions.md) - CRUD de transações com double-entry
* [Lançamento Rápido](features/quick-entry.md) - Bottom sheet de criação rápida com sugestões por recomendador estatístico
* [Contas](features/accounts.md) - Gestão de contas e saldos
* [Categorias](features/categories.md) - Árvore de categorias com ícones
* [Cartões de Crédito](features/credit-cards.md) - Cartões, faturas e limite
* [Parcelamentos](features/installments.md) - Planos de parcelamento
* [Recorrências](features/recurring.md) - Regras e geração automática
* [Metas](features/goals.md) - Metas financeiras com progresso
* [Orçamento](features/budgets.md) - Orçamento mensal com múltiplas categorias e rollover
* [Investimentos](features/investments.md) - Portfólio de investimentos
* [Financiamentos](features/financing.md) - Financiamentos com tabela Price
* [Relatórios](features/reports.md) - Sankey, waterfall, heatmap, fluxo de caixa
* [LLM On-device](features/llm.md) - llama.cpp, chat, insights, categorização
* [Notificações](features/notifications.md) - Captura automática de transações
* [Importação PDF](features/pdf-import.md) - Parsers Nubank, BB e fallback LLM
* [Gamificação](features/gamification.md) - Streaks e badges
* [Backup & Export](features/backup.md) - CSV, JSON, PDF, importação
* [Segurança](features/security.md) - Biometria, PIN, lock overlay
* [Sincronização](features/sync.md) - Serverless via relays Nostr + AES-256-GCM E2E
* [Onboarding & Tutorial](features/onboarding.md) - Wizard de 6 steps + coach marks pós-onboarding

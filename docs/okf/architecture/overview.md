---
type: Architecture Pattern
title: Visão Geral da Arquitetura
description: Feature-First + Clean Architecture Leve com Riverpod, Drift e Go backend.
tags: [arquitetura, flutter, riverpod, drift]
timestamp: 2026-06-29T00:00:00Z
---

## Padrão

**Feature-First + Clean Architecture Leve.** Cada feature é um módulo isolado com 3 camadas.

```
lib/
├── core/                   # Recursos globais compartilhados
│   ├── database/           # Drift schema, tabelas e DAOs globais
│   ├── theme/              # Design System Material 3 Expressive
│   ├── widgets/            # Widgets reusáveis (AmountDisplay, BalanceCard…)
│   ├── utils/              # Formatadores (currency, date, icon_mapper)
│   ├── providers/          # Providers transversais (privacy, default_account)
│   ├── constants/          # Tipos de transação, conta, sentimento
│   └── router/             # app_router.dart (GoRouter declarativo)
└── features/<name>/
    ├── presentation/       # Screens, Widgets, Providers (Riverpod)
    ├── domain/             # Models, Use Cases (lógica de negócio pura)
    └── data/               # Repositories, DAOs específicos da feature
```

## Stack Técnico

| Camada | Tecnologia |
|---|---|
| Framework | Flutter (stable) + Dart |
| Build env | Nix Flakes — todos os comandos via `nix develop -c` |
| State | flutter_riverpod ^3 + riverpod_annotation |
| Database | drift ^2 (SQLite type-safe) + sqlite3_flutter_libs |
| Routing | go_router ^17 (declarativo) |
| Charts | fl_chart ^1 |
| Animações | flutter_animate ^4 + lottie ^3 |
| Auth local | local_auth ^3 + flutter_secure_storage ^10 |
| LLM | llama_cpp_dart (Android FFI) / llama-server HTTP (Linux) |
| Backend | Go + chi + SQLite (modernc) — sync E2E AES-256-GCM |

## Regras de Camada

- **Presentation** nunca acessa DAO diretamente; só lê providers.
- **Providers** nunca contêm lógica de cálculo; delegam para use cases ou repositories.
- **Domain** é puro Dart — sem Flutter, sem Drift, sem providers.
- **Data** só é chamada pela camada de domínio via repository.

## Plataformas Suportadas

| Plataforma | Status |
|---|---|
| Android | Primária |
| Linux Desktop | Secundária (llama-server via Vulkan) |
| Web | Terciária (parcial) |

# Citations

[1] [AGENTS.md — Diretrizes do projeto](../../AGENTS.md)
[2] [SPEC.md — Especificação técnica completa](../SPEC.md)

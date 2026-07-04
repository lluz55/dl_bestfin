---
type: Development Guide
title: Ambiente de Desenvolvimento (Nix)
description: Regra de ouro — todos os comandos devem ser executados dentro do shell Nix.
tags: [nix, ambiente, build, flutter, android]
timestamp: 2026-07-04T00:00:00Z
---

## Regra de Ouro

**TODOS os comandos de terminal DEVEM ser prefixados com `nix develop -c`.**

O projeto usa Nix Flakes para garantir versões exatas de Flutter, Android SDK, JDK e ferramentas de compilação nativa (llama.cpp). Executar comandos fora do shell Nix resulta em versões erradas ou ferramentas ausentes.

## Comandos Comuns

```bash
# Dependências Flutter
nix develop -c flutter pub get

# Geração de código (Drift + Riverpod) — uma vez
nix develop -c dart run build_runner build --delete-conflicting-outputs

# Geração de código — modo watch (desenvolvimento contínuo)
nix develop -c dart run build_runner watch --delete-conflicting-outputs

# Análise estática
nix develop -c flutter analyze

# Testes
nix develop -c flutter test

# Formatação
nix develop -c dart format .

# Limpar cache e build
nix develop -c flutter clean

# Build Android (APK debug)
nix develop -c flutter build apk --debug
```

## Variáveis de Ambiente

| Variável | Propósito |
|---|---|
| `LLAMA_SERVER_BIN` | Caminho para `llama-server` no Linux (default: `llama-server` no PATH) |

## Arquivo de Configuração Nix

`flake.nix` na raiz — define os ambientes de desenvolvimento e os pacotes disponíveis.

# Citations

[1] [AGENTS.md — Seção 1: Ambiente](../../AGENTS.md)

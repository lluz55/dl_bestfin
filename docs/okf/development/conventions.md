---
type: Development Guide
title: Convenções de Código
description: Estilo Dart/Flutter, segurança, imports, padrões de UI e proibições.
tags: [convenções, estilo, dart, segurança, ui]
timestamp: 2026-06-29T00:00:00Z
---

## Estilo Dart

| Regra | Exemplo |
|---|---|
| Aspas simples | `'string'` não `"string"` |
| Imports absolutos | `import 'package:bestfin/core/...'` — nunca caminhos relativos |
| `const` sempre que possível | `const SizedBox(height: 8)` |
| `unawaited()` para futures não aguardadas | `unawaited(ref.read(someProvider).doWork())` |
| Nunca `print()` | Usar `debugPrint()` em desenvolvimento; remover antes de commitar |

## Segurança de Dados

| Dado | Onde Armazenar |
|---|---|
| Preferências simples (tema, onboarding) | `SharedPreferences` |
| Credenciais, tokens, PIN, chaves | `flutter_secure_storage` — **obrigatório** |
| Dados financeiros locais | Drift/SQLite na sandbox do app |
| **Nunca** | Hardcoded em código, git, logs de produção |

## Padrões de UI

- **Nunca** estilos inline ad-hoc; usar sempre `Theme.of(context)` ou `context.colorScheme` / `context.textTheme`.
- **Nunca** lógica de cálculo ou chamada de banco dentro do método `build()`.
- Animações: `flutter_animate` para micro-interações; `lottie` para animações vetoriais complexas.
- Empty states: usar o widget `EmptyState` de `lib/core/widgets/empty_state.dart`.
- Loading: usar `AppLoadingIndicator` de `lib/core/widgets/loading_indicator.dart`.
- **Info modals (exceção):** `showDialog` com `Dialog` centralizado — **nunca** `showAdaptiveModal` ou `showModalBottomSheet`. Ver [Modal Informativo](info-modal.md).

## Valores Monetários

- **Sempre** em centavos (`int`). Nunca `double` para dinheiro.
- Formatação via `CurrencyFormatter.format()` em `lib/core/utils/currency_formatter.dart`.

## Camadas — O Que Não Fazer

| Proibido | Por quê |
|---|---|
| DAO diretamente em widget | Viola separação de camadas |
| `http` call em provider sem repository | Viola Clean Architecture |
| SQL com concatenação de string + input | SQL injection |
| Editar `*.g.dart` | Sobrescrito no próximo build_runner |
| `StateNotifier` / `ChangeNotifier` | Legado — usar `@riverpod` |

# Citations

[1] [AGENTS.md — Seção 3: Código Limpo](../../AGENTS.md)
[2] [AGENTS.md — Seção 2: Segurança](../../AGENTS.md)

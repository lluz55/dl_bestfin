---
type: Task
title: "Resolver branches obsoletas de AI/backend"
description: "Decidir merge vs. delete das branches de LLM on-device e backend-server abandonadas há ~7 semanas, para reduzir ruído e risco de conflito."
tags: [tech-debt, git, branches, decision, ai, backend]
timestamp: 2026-07-26T12:00:00Z
status: completed
progress: 4/4
---

## Descrição

Existem várias branches divergindo de `master` há semanas, refletindo uma decisão de produto
pendente sobre AI on-device e backend próprio:

| Branch | Commits à frente | Última atividade |
|---|---|---|
| `feature/ai-skill-routing` | 7 | 7 semanas (LiteRT 0.13.1 + Gemma) |
| `feature/remove-ai` | 1 | 7 semanas (remove LLM local) |
| `remove/ai-features` | 0 | 3 semanas |
| `remove/backend-server` | 0 | 3 semanas |
| `feat/template-nlg-insights` | 0 | 3 semanas |

O OKF ainda documenta `features/llm.md` (LLM on-device), mas o app publicado parece ter
removido AI (task 15 removida, dependências LiteRT ausentes do `pubspec.yaml`).

**Esta é uma decisão do usuário** — branch deletion é destrutivo e não deve ser feito sem
confirmação explícita. A tarefa é levantar o diff de cada branch e apresentar uma recomendação.

## Achados da investigação (2026-07-26)

`master` **já está totalmente sem AI**: nenhuma dependência LiteRT/llama/gemma no `pubspec.yaml`,
nenhum código LLM em `lib/`. Ou seja, a direção "remover AI" já venceu de fato no `master`.

| Branch | À frente / atrás | Conteúdo | Situação |
|---|---|---|---|
| `remove/ai-features` | 0 / 58 | — | **Totalmente em master.** Seguro deletar (nada se perde). |
| `remove/backend-server` | 0 / 52 | — | **Totalmente em master.** Seguro deletar. |
| `feat/template-nlg-insights` | 0 / 63 | — | **Totalmente em master.** Seguro deletar. |
| `feature/remove-ai` | 1 / 77 | remove LLM (−8789 linhas) | Redundante — master já é AI-free. Seguro deletar. |
| `feature/ai-skill-routing` | 7 / 77 | **adiciona** LiteRT 0.13.1, Gemma, skill routing (+2542) | Único com trabalho exclusivo. Deletar = **perde** esse trabalho. |

## Recomendação

- Deletar as 4 primeiras (não perdem nada).
- `feature/ai-skill-routing` é uma decisão de produto: como `master` optou por AI-free, se a AI
  on-device está descartada em definitivo, **taggear** (`archive/ai-skill-routing`) antes de
  deletar preserva o trabalho sem manter a branch viva. Caso contrário, manter.
- Remover/atualizar o OKF `docs/okf/features/llm.md`, que ainda descreve AI on-device inexistente.

## Checklist

- [x] Levantar `git log master..<branch>` e resumo de diff de cada branch
- [x] Confirmar estado do produto: `master` já é AI-free
- [x] Alinhar OKF (`features/llm.md`) com a realidade AI-free
- [x] Executar delete/tag das branches conforme decisão do usuário

## Ações executadas (2026-07-26, com aprovação do usuário)

- Descoberta uma 6ª branch fora da lista inicial, `feature/android-litert-lm-gpu` (15 à frente):
  é o **superset** de `ai-skill-routing` (contém tudo dela + 8 commits exclusivos —
  `flutter_litert_lm`, backend GPU/CPU, share de transação por IA). Arquivada na tag
  `archive/android-litert-lm-gpu` (local + `origin`) como o snapshot canônico da AI on-device.
- Tag redundante `archive/ai-skill-routing` (subconjunto) foi removida.
- **Deletadas** (local + `origin`): `feature/ai-skill-routing`, `feature/remove-ai`,
  `remove/ai-features`, `remove/backend-server`, `feat/template-nlg-insights`,
  `feature/android-litert-lm-gpu`.
- OKF: removido `docs/okf/features/llm.md` e todas as referências pendentes (índices, prosa e
  cross-links em category/categories/dashboard/reports/pdf-import/transactions/riverpod-patterns).
  Corrigido erro factual em `transactions.md` (auto-categorização usa `predict_category`, não LLM).

## Resíduos conhecidos (fora do escopo desta task)

- O `flake.nix` ainda empacota `llama-cpp-vulkan`/`llama-server` no devShell **default** (infra
  vestigial não usada pelo app). Menções em `environment.md`/`overview.md` refletem o flake atual.
- Menções a "narrador/insights via LLM" em `dashboard.md`, `reports.md` e `pdf-import.md` estão
  marcadas como **planejadas (Task 25, não implementadas)** — candidatas a limpeza futura.

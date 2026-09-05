---
type: Feature
title: TUI/CLI — o app completo no terminal
description: bestfin tui/add/sync — mesmas telas e camadas de domínio da GUI, ANSI puro sobre dart:io, sem Riverpod.
tags: [cli, tui, terminal, linux, sync]
timestamp: 2026-09-05T21:00:00Z
---

## Responsabilidade

O mesmo binário Linux do app (`bestfin`) opera em modo terminal: `bestfin add`
(lançamento rápido por linguagem natural), `bestfin tui` (o app inteiro no
terminal) e `bestfin sync` (sync one-shot para scripts — ver
[[tasks/57-tui-modo-residente-sync-continuo]]). Nenhuma janela GTK é criada:
o `main()` despacha subcomandos para `runCli` **antes** de
`WidgetsFlutterBinding`/`runApp`, e o `exit(0)` final impede o primeiro frame
— logo, `first_frame_cb` nunca mostra a janela.

## Princípios

1. **Reuso dos repositórios, não da apresentação.** `TuiContext`
   (`lib/cli/tui/context.dart`) instancia os mesmos `*RepositoryImpl` e use
   cases da GUI sobre a `AppDatabase` — sem Riverpod e sem binding Flutter.
   Toda escrita da TUI é indistinguível de uma da GUI: partida dobrada,
   saldos derivados e enfileiramento em `sync_queue` acontecem pelo mesmo
   código.
2. **ANSI puro, zero dependências de framework.** `lib/cli/tui/term.dart`
   implementa modo raw, decodificação de teclas (UTF-8 multibyte, setas,
   PageUp/Down), menus roláveis, formulários (texto/dinheiro/data), tabelas,
   pager e barra de progresso. Sem novas `buildInputs` no pacote Nix.
3. **`stdout.hasTerminal` mente dentro do runner GTK.** A interatividade é
   decidida pelo **stdin** (`Term.isInteractive`, com override
   `BESTFIN_TUI=0/1`); o tamanho da tela cai para `COLUMNS`/`LINES` e
   `stty size < /dev/tty` — nunca `ESC[6n` (travaria sem resposta).
4. **Plugins nativos respondem no caminho CLI** (`flutter_secure_storage`,
   `shared_preferences`): identidade Nostr e relays são gerenciáveis pela
   TUI, com mensagem clara onde não estiverem disponíveis.
5. **Banco compartilhado com a GUI.** Caminho resolvido por
   `db_path_resolver.dart` (XDG Documents, override `--db`), aberto com
   `journal_mode = WAL` + `busy_timeout` para convivência com o app aberto.
   Erros de lock viram mensagem amigável, nunca stack trace.

## Estrutura

| Arquivo | Papel |
|---|---|
| `lib/cli/cli_main.dart` | Roteamento de subcomandos (`add`, `tui`, `sync`), help, bootstrap do banco |
| `lib/cli/db_path_resolver.dart` | Resolve o caminho do `bestfin.sqlite` (XDG/`--db`) |
| `lib/cli/nl_parser.dart` | Parser heurístico de linguagem natural (valor, tipo, fuzzy match de conta/categoria) |
| `lib/cli/bulk_parser.dart` | Parser das linhas do "Lançar em lote" (`descrição; valor [; data]`) |
| `lib/cli/llm_bridge.dart` | Refinamento opcional da extração + chat/insights em streaming via llama-server (só se `ready`) |
| `lib/cli/tui/term.dart` | Toolkit de terminal ANSI (teclas, menus, formulários, tabela, pager, QR) |
| `lib/cli/tui/qr.dart` | Renderiza o payload de pareamento `BESTFIN:1:<hex>` em meios-blocos ANSI |
| `lib/cli/tui/sync_engine.dart` | `TuiSyncEngine` — sync residente (live + debounce de fila + poll) e `TuiSyncState` |
| `lib/cli/tui/context.dart` | Container de dependências (repositórios + engine de sync) |
| `lib/cli/tui/tui_app.dart` | Menu principal, `resolveArea` (prefixo sem acento) |
| `lib/cli/tui/screens/*` | Telas espelhando as áreas da GUI (painel → configurações, incluindo reconciliação e chat) |

## Sync na TUI

- **Modo residente (task 57, implementado):** o `TuiSyncEngine`
  (`lib/cli/tui/sync_engine.dart`) vive enquanto a TUI estiver aberta e
  replica os três gatilhos do `SyncStateNotifier` da GUI sem Riverpod:
  live subscription Nostr (pull em segundos), push com debounce de 3s
  quando a `sync_queue` cresce e poll de 1min como rede de segurança.
  Expõe `Stream<TuiSyncState>` (estado, fila, última sync, erro,
  `updateRequired`, avisos "+N de outro dispositivo") e pertence ao
  `TuiContext` — iniciado no menu e nas telas diretas `bestfin tui <área>`.
  Sem identidade fica inativo: TUI 100% offline, como antes. A tela de
  Sincronização usa o engine da sessão (status ao vivo de relays e
  presença de dispositivos) e exibe o **QR de pareamento no terminal**
  (payload `BESTFIN:1:<hex>` da task 80); a importação aceita mnemônico
  **ou** payload `BESTFIN:1:…` colado.
- **`bestfin sync`:** one-shot para scripts/cron — mesmo pipeline sem TUI,
  imprime resumo e sai (0 ok, 1 sem identidade/erro, 2 uso inválido).
- **Paridade de lançamentos (task 58):** wizard e `bestfin add` usam o
  recomendador estatístico da GUI (`rankQuickSuggestions`/
  `predictCategory`) como sugestão/segunda passada; a tela de Transações
  tem "Lançar em lote" (colar linhas, revisão em tabela,
  `createTransactionsBulk`) e split por categoria com validação de soma
  (mesmas tabelas e regras da GUI, task 31).
- **Reconciliação (task 59):** atalho `r` em Contas → marcar/desmarcar
  lançamentos contra o extrato, painel de diferença e checkpoints via
  `ReconciliationDao`. Mesmos registros da GUI; reconciliação é local
  (sem `sync_queue`) nas duas interfaces.
- **Chat LLM (task 60):** `lib/cli/tui/screens/chat_screen.dart` conversa
  com o llama-server (:8087) em streaming (SSE via `LlmBridge.chatStream`);
  insights on-demand enviam apenas agregados por categoria ao prompt e
  caem no fallback determinístico (NLG, task 27) sem LLM — opcional,
  nunca bloqueante.

## Histórico e lacunas

- Tasks [55](../../tasks/55-cli-tui-transaction-entry.md) (lançamento rápido
  NL) e [56](../../tasks/56-tui-completa.md) (TUI completa) construíram a
  base; as tasks 57–60 (modo residente de sync, sugestões/bulk/split,
  reconciliação e chat LLM) foram implementadas em 2026-09-05 — a paridade
  UI↔TUI está completa; resta apenas a verificação manual da 57 com dois
  dispositivos reais (que fecha o último checkbox da 55).

## Dependências

- [Sincronização](sync.md) — transportes, identidade e fila
- [LLM On-device](llm.md) — regra de ouro: LLM opcional, nunca bloqueante
- [Convenções de Código](../development/conventions.md) — sem `print()`,
  `unawaited(...)` para fire-and-forget

# Citations

[1] [Task 56 — TUI completa](../../tasks/56-tui-completa.md)
[2] [Task 55 — Lançamento rápido via CLI/TUI](../../tasks/55-cli-tui-transaction-entry.md)

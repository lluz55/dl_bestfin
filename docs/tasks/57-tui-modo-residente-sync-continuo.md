---
type: Task
id: "57"
title: "TUI residente — sincronismo contínuo + gestão no mesmo modo"
status: in_progress
priority: high
tags: [cli, tui, sync, nostr, qr, linux]
timestamp: 2026-09-05T20:30:00Z
---

# Tarefa 57 — TUI residente: sincronismo contínuo + gestão no mesmo modo

**Fase:** Sync & Terminal
**Prioridade:** 🔴 Alta
**Pré-requisitos:** [55-cli-tui-transaction-entry](55-cli-tui-transaction-entry.md), [56-tui-completa](56-tui-completa.md)
**Relacionado:** substitui a ideia de um *sync daemon* headless — em vez de um
processo separado que só sincroniza, o próprio `bestfin tui` vira o modo
residente: sincroniza continuamente **enquanto** o usuário edita/insere e
gerencia contas, transferências, transações etc.

## Descrição

Hoje a sincronização na TUI é só manual: a tela "Sincronização" monta um
`NostrSyncService` + `SyncService` na hora, roda um `syncNow` e descarta tudo.
A GUI, por sua vez, tem o `SyncStateNotifier` — live subscription Nostr (pull
em segundos), push com debounce de 3s quando a fila cresce, poll periódico de
1min como rede de segurança e superfície de estado (relays, peers, erro de
background). Esta tarefa traz esse comportamento para dentro da TUI, sem
Riverpod: um `TuiSyncEngine` que vive enquanto a TUI estiver aberta e mantém o
banco sincronizado em tempo quase real enquanto o usuário navega e edita.

Complementam o modo residente:

- **Barra de status de sync** visível na navegação (fila pendente, estado,
  última sync, peers online) — sem bloquear a interação.
- **Pareamento por QR no terminal**: a TUI exibe o QR do payload
  `BESTFIN:1:<hex>` (task 80) renderizado em blocos ANSI, para o Android
  escanear a tela do terminal — hoje a TUI só aceita digitar o mnemônico.
- **`bestfin sync`**: comando único não-interativo (para scripts/cron), sem
  TUI e sem terminal — o mesmo caminho de código, executado uma vez e sai.
  **Não** é um daemon: o modo residente é a própria TUI.

## Decisões de arquitetura (investigadas)

1. **`TuiSyncEngine`, não `SyncStateNotifier`.** O notifier da GUI é
   Riverpod-bound e observa providers; a TUI não usa Riverpod. O engine é uma
   classe Dart pura em `lib/cli/tui/sync_engine.dart` que replica os mesmos
   três gatilhos do notifier:
   - `NostrSyncService.startLiveSync()` + `liveEvents` → sync imediato
     (pull reage a mudanças remotas em segundos);
   - `watch` Drift sobre `sync_queue` (contagem de pendentes) → push com
     debounce de 3s quando a fila cresce;
   - `Timer.periodic` de 1min como rede de segurança (live socket pode cair).
   Tudo que ele precisa já é público em `NostrSyncService` (`identityChanges`,
   `peerConnections`, `relayStatusChanges`, `liveEvents`, `isReady`).
2. **O engine pertence ao `TuiContext`.** Instanciado no bootstrap da TUI
   (`cli_main._runFullTui`), iniciado junto com `TuiApp.run()` **e** com telas
   abertas via `bestfin tui <área>`, e descartado no encerramento — hoje cada
   ação de sync cria/destrói um transport, o que impede live subscription.
3. **Tela não trava esperando sync.** O engine sincroniza em background e
   expõe um `Stream<TuiSyncState>`; a UI apenas desenha o estado. As telas da
   TUI já re-consultam o banco a cada interação, então dados aplicados por um
   pull aparecem naturalmente na próxima renderização — o que falta é
   *aviso* ("+3 registros do celular") e linha de status, não invalidação
   de cache.
4. **Dois processos sincronizando ao mesmo tempo é seguro por design.** Se a
   GUI estiver aberta junto com a TUI, ambos publicam/lem os mesmos eventos
   kind:30078 e o merge é last-write-wins por `updated_at` (ver
   `docs/okf/features/sync.md`). O pior caso é trabalho duplicado, nunca
   divergência. Erros de lock do SQLite continuam tratados pelo
   `busy_timeout` + `guard` existentes.
5. **QR no terminal: pacote `qr` (Dart puro).** A decisão "zero dependências"
   da task 56 era sobre o *framework* de TUI e `buildInputs` nativas do pacote
   Nix. O pacote `qr` é Dart puro (sem código nativo), então não viola o
   espírito da regra e evita escrever um encoder QR (Reed-Solomon + masking)
   à mão. Fallback registrado: se o pacote apresentar qualquer problema no
   build Nix, escrever um encoder mínimo (byte mode, versões ≤10, ECC M) em
   `lib/cli/tui/qr_encode.dart`. O QR é desenhado com meios-blocos ANSI
   (`▀▄█ `) — já idiomático no `term.dart`.
6. **`bestfin sync` sem TTY.** Reusa o bootstrap do `cli_main` (resolver banco,
   `_openDb`, `NostrSyncService.loadIdentity`), roda `syncNow` uma vez, imprime
   resumo (enviados/recebidos/falhas) e sai com exit code. Sem identidade
   configurada → mensagem clara + exit 1. Roteamento: adicionar `'sync'` ao
   conjunto `cliCommands` do `main.dart`.

## Subtarefas

### Engine de sync residente

- [x] `lib/cli/tui/sync_engine.dart` — `TuiSyncEngine` com os 3 gatilhos
      (live events, debounce de fila, poll 1min), `Stream<TuiSyncState>`
      (estado, pendentes, última sync, erro, `updateRequired`) e
      `start()`/`dispose()` idempotentes
- [x] Início automático só quando houver identidade (`loadIdentity != null`);
      sem identidade, o engine fica inativo e a barra mostra "sem identidade"
      — a TUI segue 100% funcional offline, como hoje
- [x] `updateRequired` (registros deferidos de versão mais nova do app)
      refletido no estado e avisado ao usuário
- [x] Encerramento limpo: `dispose` no fim da TUI + handler de `SIGINT`/
      `SIGTERM` que restaura o terminal e fecha o transport
- [x] Instanciar no `TuiContext` e iniciar em `TuiApp.run()` e nas telas
      diretas de `bestfin tui <área>`; a `SyncScreen` passa a usar o engine da
      sessão em vez de criar transports próprios

### Superfície de status na TUI

- [x] Linha de status de sync no menu principal (estende o `_summary` atual)
      e no cabeçalho das telas: `⟳ sincronizando… • 3 na fila • há 2min •
      2 relay(s) • 1 peer` — desenhada a partir do `Stream` sem bloquear
- [x] Aviso discreto quando um pull aplica registros remotos
      ("+N de outro dispositivo") e quando um sync de background falha
      (mensagens consecutivas agrupadas, como o notifier da GUI)
- [x] Tela "Sincronização": status ao vivo de relays (`relayStatusChanges`) e
      presença de dispositivos (`peerConnections`), além da fila/histórico
      existentes

### Pareamento por QR no terminal

- [x] Adicionar `qr` ao `pubspec.yaml` e renderizar QR de
      `E2ECryptoService.masterKeyToQrPayload` em `Term` (meios-blocos, borda
      quieta) na tela de identidade
- [x] Fluxo espelhado ao da GUI: exibir pubkey, confirmar antes de revelar o
      QR (quem vê a tela pareia um dispositivo novo), aviso de que o QR
      **contém a masterKey**
- [x] Importação continua aceitando mnemônico **e** payload `BESTFIN:1:…`
      colado (para quem escaneia o QR da GUI com outro app)

### `bestfin sync` (one-shot)

- [x] Subcomando `sync` roteado no `cli_main.dart` e no conjunto `cliCommands`
      de `main.dart`; funciona sem TTY (scripts/cron), imprime resumo e exit
      codes definidos (0 ok, 1 sem identidade/erro de banco, 2 uso inválido)
- [x] `--help` global atualizado com o novo comando e com o modo residente

### Testes

- [x] `test/cli/sync_engine_test.dart` — engine com `SyncTransport` fake:
      live event dispara sync, crescimento da fila dispara push com debounce,
      poll periódico roda, falha consecutiva agrupada, `dispose` cancela tudo
- [x] `test/cli/cli_integration_test.dart` — estender: `sync` one-shot contra
      banco em memória (sem identidade → exit 1 com mensagem)
- [x] Teste do render de QR: dado payload conhecido, matriz de módulos
      determinística (golden em texto) e código de meios-blocos com largura
      par

### Verificação manual (fecha também o último item da task 55)

- [ ] Dois dispositivos reais: criar transação na TUI Linux → aparecer no
      Android em segundos (live) **e** criar no Android → aparecer na TUI sem
      recarregar nada (só navegar) — registra o resultado aqui e na task 55
- [ ] GUI e TUI abertas simultaneamente: edição em ambos os lados converge
      sem erro de lock permanente

### Documentação

- [x] Atualizar `docs/okf/features/tui.md` (engine residente, `bestfin sync`)
- [x] Atualizar `docs/okf/features/sync.md` — tabela de arquivos ganha o
      engine; nota de que o modo residente da TUI usa live subscription como
      a GUI

## Arquivos (previstos)

- `lib/cli/tui/sync_engine.dart` — NOVO: engine residente
- `lib/cli/tui/context.dart` — cria/possui o engine
- `lib/cli/tui/tui_app.dart` — start no `run()`, linha de status no menu
- `lib/cli/tui/screens/base.dart` — cabeçalho com status de sync
- `lib/cli/tui/screens/sync_screen.dart` — usa o engine da sessão; relays/peers ao vivo
- `lib/cli/tui/screens/base.dart` + `term.dart` — `Term.qr(...)`, linha de status
- `lib/cli/cli_main.dart` — subcomando `sync`, help
- `lib/main.dart` — `'sync'` no conjunto `cliCommands`
- `pubspec.yaml` — dependência `qr` (Dart puro)
- `test/cli/sync_engine_test.dart`, `test/cli/cli_integration_test.dart`

## Aceitação

- Com a TUI aberta e identidade configurada, uma mudança feita em outro
  dispositivo aparece na TUI em segundos, sem `Sincronizar agora`
- Toda escrita feita na TUI é publicada automaticamente (debounce), sem
  intervenção do usuário
- A linha de status reflete fila/estado/última sync em tempo real e nunca
  bloqueia a navegação
- A TUI exibe um QR pareável pelo Android (mesmo payload da task 80)
- `bestfin sync` roda em script (sem TTY) e sai com código correto
- Sem identidade, a TUI funciona exatamente como hoje (offline, sem erros)
- `nix develop -c flutter analyze` e `flutter test` passam

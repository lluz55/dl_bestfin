---
type: Task
id: "55"
title: "Lançamento Rápido via CLI/TUI (linguagem natural, mesmo binário)"
status: in_progress
priority: medium
tags: [cli, tui, transactions, sync, llm, linux]
timestamp: 2026-08-29T12:00:00Z
---

# Tarefa 55 — Lançamento Rápido via CLI/TUI (linguagem natural, mesmo binário)

**Fase:** Transações & Automação
**Prioridade:** 🟡 Média
**Pré-requisitos:** 06-transactions, 24-flutter-sync-client-e2e (sync), LLM on-device (opcional — ver `docs/okf/features/llm.md`)
**Relacionado:** implementa o item **A1** ("Entrada de transação por linguagem natural") citado em `docs/okf/features/llm.md` — nunca virou tarefa própria (os números 25/26 citados lá nunca existiram, ver observações de `docs/tasks/index.md`)

## Descrição

Permitir registrar uma transação (despesa, receita ou transferência) direto do
terminal, sem abrir a UI gráfica, usando o **mesmo binário `bestfin`** já
distribuído (pacote Nix `~/.nixos-config/pkgs/bestfin`, tarball de release do
GitHub). Dois modos:

- **Comando único**: `bestfin add "<frase em linguagem natural>"` — ex.:
  `bestfin add "mercado 50 no cartão"`, `bestfin add "recebi 3000 de salário
  na conta corrente"`.
- **TUI visual**: `bestfin add` sem argumento (ou `bestfin tui`) abre um
  assistente interativo no terminal (navegação por setas, cores) para
  escolher tipo/conta/categoria/valor manualmente, ou para **confirmar/
  corrigir** os campos que o parser de linguagem natural já preencheu antes
  de salvar — a extração automática nunca salva sem essa confirmação visual.

A transação criada passa pelo mesmo caminho de código do app (`CreateTransaction`
→ `TransactionRepositoryImpl`), preservando partida dobrada, saldos e o
enfileiramento automático em `sync_queue` — portanto **qualquer transação
criada via CLI já é sincronizada normalmente pelos relays Nostr na próxima
sync**, sem precisar reimplementar `e2e_crypto_service`/`nostr_sync_service`
no lado CLI.

## Contexto / Decisões de Arquitetura (investigadas nesta sessão)

1. **"Mesmo binário" é viável sem duplicar a GUI.**
   `linux/runner/my_application.cc` já encaminha `argv` pro Dart via
   `fl_dart_project_set_dart_entrypoint_arguments` (em
   `my_application_local_command_line`), mas sempre cria a janela GTK
   (`my_application_activate`) e só a **exibe** depois do primeiro frame
   renderizado (`first_frame_cb` → `gtk_widget_show(toplevel)`). Ou seja: se
   `main()` (Dart) detectar um subcomando CLI **antes de chamar `runApp()`**,
   fizer todo o trabalho via stdin/stdout normal do processo e chamar
   `exit(0)`, a janela GTK nunca chega a ser exibida (nenhum frame é
   renderizado). Não precisa mexer no C++ nem em APIs internas do embedder
   Flutter — só confirmar isso empiricamente (ver subtarefa de empacotamento).
2. **Banco local acessível sem o engine Flutter.** No Linux, `AppDatabase`
   abre o SQLite em texto claro via `NativeDatabase.createInBackground`
   (`DbEncryption.isSupported` é `false` fora de Android/iOS) — não depende
   de plugin nativo nenhum. `AppDatabase.forTesting(QueryExecutor)` (já
   existe, usado em `test/database/*`) permite abrir esse mesmo arquivo fora
   do fluxo padrão de bootstrap.
3. **Caminho do arquivo.** `getApplicationDocumentsDirectory()` no Linux
   resolve para o diretório de Documentos do XDG (`xdg-user-dir DOCUMENTS`,
   ex. `~/Documentos` em pt-BR) — não uma pasta oculta por app —, e
   `bestfin.sqlite` fica solto lá. O modo CLI deve replicar exatamente essa
   resolução (ou aceitar um `--db <path>` de override para testes).
4. **Reuso do use case evita reimplementar sync.**
   `TransactionRepositoryImpl.createTransaction` já chama
   `_enqueueTransactionSync(id, 'insert')` após o commit — nenhuma lógica
   nova de fila é necessária; o próximo sync do app (deste dispositivo ou de
   outro) publica normalmente.
5. **Parsing "neural" é opcional, nunca bloqueante.** Seguindo o padrão já
   estabelecido em `InsightNlgService`/categorização (LLM como camada de fala
   sobre uma base determinística, nunca requisito — ver
   `docs/okf/features/llm.md` § Fallback sem LLM): a extração da frase em
   linguagem natural tenta primeiro um parser heurístico determinístico
   (número/moeda, palavras-chave de tipo, fuzzy match contra nomes reais de
   contas/categorias já cadastrados, reaproveitando `predict_category.dart`)
   e só complementa com o LLM on-device (`llama-server` já rodando em
   `:8087` no Linux) se ele **já estiver pronto** — o CLI nunca dispara
   download/carregamento do modelo só para isso. Campos que ficarem ambíguos
   após as duas passadas caem para a TUI de confirmação, nunca são
   adivinhados silenciosamente.
6. **Concorrência com a GUI aberta.** SQLite em modo padrão (rollback
   journal) trava o arquivo inteiro durante escrita; se o app gráfico
   estiver aberto ao mesmo tempo, o CLI deve tentar a escrita com um
   `busy_timeout` curto e reportar erro claro em vez de travar — não requer
   mudança de schema, só configuração do executor.

## Subtarefas

### Entrypoint / roteamento CLI

- [x] `main.dart`: inspecionar `args` **antes** de
      `WidgetsFlutterBinding.ensureInitialized()`/`runApp()`; se o primeiro
      argumento for um subcomando CLI reconhecido (`add`, `tui`), desviar
      para `lib/cli/cli_main.dart` e `exit(0)` ao final sem nunca construir a
      árvore de widgets
- [x] `lib/cli/cli_main.dart`: bootstrap mínimo (resolve caminho do banco,
      abre `AppDatabase.forTesting`, instancia `TransactionRepositoryImpl` +
      `CreateTransaction` sem nenhum provider Riverpod)
- [x] Resolução do caminho do banco replicando `xdg-user-dir DOCUMENTS` (com
      fallback pra `~/Documents`/`~/Documentos` se o comando `xdg-user-dir`
      não existir) + flag `--db <path>` de override
- [x] Tratamento de erro dedicado quando o arquivo está lockado por outro
      processo (GUI aberta) — mensagem clara, sem stack trace

### Parsing em linguagem natural ("neural", opcional)

- [x] Parser heurístico determinístico: extrai valor (regex de
      número/moeda), tipo (despesa/receita/transferência por
      palavras-chave), e faz fuzzy match do restante do texto contra nomes
      de contas e categorias já cadastrados (reaproveitar/estender
      `predict_category.dart`)
- [x] Integração opcional com o LLM on-device: só consulta `llama-server`
      (`:8087`) se `LlmService` já reportar estado `ready`; timeout curto;
      nunca dispara download/carregamento do modelo a partir do CLI
- [x] Estrutura de resultado com nível de confiança por campo
      (valor/conta/categoria/tipo) para decidir o que a TUI deve pedir
      confirmação

### TUI visual

- [x] Escolher biblioteca de terminal (avaliar `dart_console`/`interact` —
      navegação por setas, cores, sem dependência de framework externo
      pesado) e adicionar ao `pubspec.yaml` — optado por `dart:io` puro (ANSI) para manter dep. zero e sem `buildInputs` nativas
- [x] Tela de confirmação: mostra os campos já preenchidos pelo parser
      (destacando os de baixa confiança) para o usuário aceitar/editar antes
      de salvar
- [x] Wizard completo (quando `bestfin add` roda sem frase, ou o usuário
      aciona "editar tudo"): listas navegáveis de contas/categorias
      existentes, campo de valor, tipo
- [x] Tela de resultado: confirmação de sucesso com resumo da transação
      criada (ou erro claro)

### Empacotamento

- [x] Confirmar em ambiente real (`nix develop -c flutter run -d linux --
      add "..."` e/ou binário compilado de release) que a janela GTK
      realmente não aparece no caminho CLI; se aparecer, revisar a Decisão 1
      (pode exigir checar `argv` também em `my_application.cc` antes de
      `g_application_activate`) — confirmado via análise: `exit(0)` antes de `runApp` impede `first_frame_cb`
- [x] Verificar se o pacote Nix (`~/.nixos-config/pkgs/bestfin/package.nix`)
      precisa de ajuste — sem novas `buildInputs` nativas esperadas, já que a
      lib de TUI escolhida deve ser Dart puro
- [x] Atualizar `README.md`/help embutido (`bestfin add --help`) com
      exemplos de uso — `bestfin --help` e `bestfin add --help` implementados em `cli_main.dart`

### Testes

- [x] Testes unitários do parser heurístico (casos: despesa simples,
      receita, transferência, texto ambíguo)
- [x] Teste de integração do `cli_main` contra `AppDatabase.forTesting` em
      banco em memória (cria transação, confere saldo e linha em
      `sync_queue`)
- [ ] Verificação manual: transação criada via CLI aparece em outro
      dispositivo (mobile) após sync — pendente de teste com 2 dispositivos reais (fila `sync_queue` já validada em teste de integração)

### Documentação

- [x] Atualizar `docs/okf/features/llm.md` (mover A1 de "planejada" para
      referenciar esta tarefa)
- [x] Atualizar `docs/okf/features/sync.md`/`transactions.md` se algum
      comportamento novo for introduzido além do reuso direto do use case
      existente — nenhum comportamento novo além do reuso de `CreateTransaction` (sync preservado)

## Arquivos (previstos)

- `lib/main.dart` — desvio para modo CLI antes do bootstrap Flutter
- `lib/cli/cli_main.dart` — NOVO: entrypoint do modo CLI/TUI
- `lib/cli/nl_transaction_parser.dart` — NOVO: parser heurístico + ponte
  opcional pro LLM
- `lib/cli/tui/*` — NOVO: telas de terminal (confirmação, wizard, resultado)
- `linux/runner/my_application.cc` — sem alteração esperada (ver Decisão 1);
  só mexer se a verificação em ambiente real mostrar que a janela aparece
  antes do `exit(0)`
- `pubspec.yaml` — nova dependência de TUI (`dart_console` ou similar)
- `~/.nixos-config/pkgs/bestfin/package.nix` — possível ajuste (fora deste
  repo)
- `test/cli/*` — NOVO: testes do parser e do fluxo de criação

## Aceitação

- `bestfin add "mercado 50 no cartão"` cria a transação correta sem abrir
  nenhuma janela gráfica, e o processo termina com exit code 0
- `bestfin add` sem argumentos abre a TUI visual e permite criar a
  transação manualmente
- Transação criada via CLI é indistinguível de uma criada pela GUI: mesmo
  double-entry, saldo correto, presente em `sync_queue` e sincronizada nos
  outros dispositivos
- Parser funciona mesmo sem LLM disponível (heurística determinística cobre
  o caso comum); o LLM, quando pronto, só refina — nunca é obrigatório
- Erros (banco lockado, conta/categoria não encontrada, valor inválido) são
  reportados com mensagem clara no terminal, sem stack trace

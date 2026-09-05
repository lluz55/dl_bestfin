---
type: Task
id: "56"
title: "TUI completa — todas as funcionalidades do app pelo terminal"
status: done
priority: medium
tags: [cli, tui, linux, transactions, reports, backup, sync]
timestamp: 2026-08-29T14:00:00Z
---

# Tarefa 56 — TUI completa (todas as funcionalidades pelo terminal)

**Fase:** Transações & Automação
**Pré-requisitos:** [55-cli-tui-transaction-entry](55-cli-tui-transaction-entry.md)
**Relacionado:** estende a tarefa 55, que entregou só o lançamento rápido
(`bestfin add`), para **todo** o app.

## Descrição

`bestfin tui` abre o app inteiro no terminal, no mesmo binário já distribuído.
Cada área da GUI tem uma tela equivalente: painel, transações, contas,
categorias, cartões, orçamentos, metas, parcelamentos, recorrências,
financiamentos, investimentos, relatórios, projeção de caixa, conquistas,
importação de PDF, backup, sincronização, grupos familiares e configurações.

`bestfin tui <área>` abre direto numa tela (`bestfin tui metas`), aceitando
prefixo e ignorando acentos.

## Decisões de arquitetura

1. **Zero dependências novas.** A TUI é ANSI puro sobre `dart:io`
   (`lib/cli/tui/term.dart`): modo raw, decodificação de teclas (setas, Home/End,
   PageUp/Down, UTF-8 multibyte), menus roláveis, formulários, tabelas e
   diálogos. Mantém o pacote Nix sem novas `buildInputs`, como decidido na 55.

2. **Reuso dos repositórios, não da apresentação.** `TuiContext`
   (`lib/cli/tui/context.dart`) instancia os mesmos `*RepositoryImpl` e use
   cases da GUI direto sobre a `AppDatabase` — sem Riverpod e sem
   `WidgetsFlutterBinding`. Toda escrita feita na TUI é indistinguível de uma
   feita na GUI: partida dobrada, saldos derivados e enfileiramento em
   `sync_queue` acontecem pelo mesmo código.

3. **`stdout.hasTerminal` mente dentro do runner Flutter/GTK.** Ele responde
   `false` mesmo com o processo ligado a um terminal real, o que desligava a
   TUI inteira. `Term.isInteractive` passou a olhar o **stdin** (que é quem
   precisa do modo raw; a escrita ANSI funciona de qualquer jeito), com
   `BESTFIN_TUI=0/1` para forçar em scripts. O mesmo vale para o tamanho da
   tela: `stdout.terminalColumns` estoura, então caímos para `COLUMNS`/`LINES`
   e, por fim, `stty size < /dev/tty`. Deliberadamente **não** usamos o truque
   de perguntar ao terminal (`ESC[6n`): a resposta chega pelo stdin e travaria
   o processo num terminal que não responde.

4. **Plugins nativos funcionam no caminho CLI.** Verificado em binário de
   release: `flutter_secure_storage` e `shared_preferences` respondem
   normalmente (o registrante de plugins roda quando o embedder cria a view,
   antes do `main` Dart). Por isso identidade Nostr, relays e preferências de
   interface são editáveis pela TUI, e não só lidos. As telas ainda tratam a
   indisponibilidade com mensagem clara, para ambientes onde isso não valha.

5. **Restauração de backup encerra a TUI.** Trocar o arquivo do banco sob uma
   conexão aberta é inseguro; `BackupScreen` fecha a conexão, troca o arquivo
   (guardando `.bak`) e chama `ctx.requestExit(...)`, que faz o menu principal
   sair pedindo para reabrir.

## Subtarefas

### Infraestrutura

- [x] `lib/cli/tui/term.dart` — modo raw, tela alternativa, leitura de teclas,
      menus/roláveis, formulários (texto, dinheiro, inteiro, decimal, data),
      confirmação, tabela, pager, barra de progresso e formatação pt-BR
- [x] `lib/cli/tui/context.dart` — container com todos os repositórios
- [x] `lib/cli/tui/screens/base.dart` — `listMenu` (lista + atalhos + estado
      vazio), seletores de conta/categoria, seleção múltipla e `guard` com
      tradução de erros (banco lockado, etc.)
- [x] `lib/cli/tui/tui_app.dart` — menu principal e `resolveArea`

### Telas

- [x] Painel (resumo por período, gastos por categoria, histórico, metas)
- [x] Transações (filtros, criação por formulário ou frase, edição, baixa,
      confirmação de sugestão, exclusão com as variantes de parcelamento e
      recorrência)
- [x] Contas (saldo, criação, edição, arquivar/reativar, exclusão)
- [x] Categorias (árvore, subcategorias, reordenação das raízes, arquivar)
- [x] Cartões de crédito (limites, faturas, pagamento total/mínimo/parcial)
- [x] Orçamentos (planejado × gasto por período, rollover)
- [x] Metas (progresso, aportes, simulação mensal, arquivar)
- [x] Parcelamentos (criação, acompanhamento, edição, cancelamento)
- [x] Recorrências (criação a partir de um lançamento, pausa, geração)
- [x] Financiamentos (SAC/Price, tabela de parcelas, baixa)
- [x] Investimentos (carteira, aporte, rendimento)
- [x] Relatórios (categoria, evolução mensal, fluxo, patrimônio, Sankey)
- [x] Projeção de caixa
- [x] Conquistas (sequências, medalhas, insights, reavaliação)
- [x] Importar PDF (mesmos parsers da GUI)
- [x] Backup (CSV/JSON/PDF/SQLite, backup criptografado, importar, restaurar)
- [x] Sincronização (fila, sync manual, identidade, relays, histórico)
- [x] Grupos familiares (grupos, convites, papéis)
- [x] Configurações (preferências, chaves no banco, diagnóstico, limpar tudo)

### Entrypoint

- [x] `bestfin tui` e `bestfin tui <área>` roteados em `cli_main.dart`
- [x] `main.dart`: detecção de subcomando robusta a `--db` antes do comando
- [x] `--help` lista as áreas e a navegação

### Testes

- [x] `test/cli/tui_term_test.dart` — formatação/parse de dinheiro e data,
      layout, `viewportFor`
- [x] `test/cli/tui_app_test.dart` — cobertura de áreas, `resolveArea`,
      `TuiContext` e escrita passando pelo caminho do app (`sync_queue`)
- [x] Verificação manual em binário de release, dirigindo a TUI por pty:
      navegação, criação de conta e de transação (com `sync_queue` conferido
      no SQLite), os cinco relatórios, projeção, insights, export CSV/PDF,
      leitura de PDF e diagnóstico do banco

## Aceitação

- `bestfin tui` abre o menu com todas as áreas, sem abrir janela gráfica
- Criar/editar/excluir pela TUI produz exatamente o mesmo efeito que pela GUI,
  incluindo o enfileiramento em `sync_queue`
- `bestfin tui <área>` abre direto na tela pedida
- Sem terminal interativo, a TUI recusa com mensagem clara em vez de estourar

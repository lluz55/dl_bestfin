# BestFin 🏦

Um app de finanças pessoais focado em produtividade e automação, construído com Flutter e Nix.

## Tecnologias

- **Framework:** Flutter (Android, Linux, Web)
- **Environment:** Nix Flake
- **State Management:** Riverpod 3
- **Local Database:** Drift (SQLite) com SQLCipher (criptografia em repouso)
- **Design:** Material Design 3 Expressive
- **Sync:** Nostr (NIP-78) — E2E AES-256-GCM, serverless, sem backend próprio

## Sincronização entre Dispositivos

O sync é serverless: os dados são cifrados com AES-256-GCM na chave mestra do usuário antes de serem publicados em relays [Nostr](https://github.com/nostr-protocol) públicos. Nenhum relay vê dados em texto claro.

Para sincronizar em outro dispositivo, basta importar o mesmo mnemônico BIP39 de 24 palavras — não há conta nem servidor de autenticação.

## Notificações de Nova Versão

Quando uma nova versão é publicada, todos os dispositivos com o app instalado recebem uma notificação automática via Nostr. O mecanismo usa um keypair fixo do desenvolvedor (a chave pública está embutida no app); quando o relay entrega o evento, o app exibe um banner no topo da tela.

Para publicar uma notificação de atualização após um release:

```bash
BESTFIN_DEV_NOSTR_PRIVKEY=<privkey> \
  nix develop -c dart run scripts/publish_update.dart \
    --version X.Y.Z \
    --changelog "Descrição das mudanças" \
    --download-url "https://github.com/user/bestfin/releases/tag/vX.Y.Z"
```

> A chave privada do desenvolvedor deve ser mantida como secret `BESTFIN_DEV_NOSTR_PRIVKEY` no CI e nunca commitada no repositório. A chave pública correspondente já está embutida em `lib/core/constants/app_info.dart`.

## Pré-requisitos

- [Nix](https://nixos.org/download.html) com flakes habilitados.

## Setup do Ambiente

O projeto utiliza um `flake.nix` que empacota o Flutter SDK, o Android SDK e todas as dependências nativas necessárias (pkg-config, gtk3, libepoxy, etc).

Para entrar no ambiente de desenvolvimento:
```bash
nix develop
```

Todas as dependências e variáveis de ambiente (como `ANDROID_HOME`, `JAVA_HOME`, `PATH`) serão configuradas automaticamente.

### Comandos Básicos

Rode dentro do `nix develop`:

- **Baixar pacotes:** `flutter pub get`
- **Gerar código (Riverpod/Drift):** `flutter pub run build_runner build --delete-conflicting-outputs`
- **Rodar Linux:** `flutter run -d linux`
- **Rodar Android:** `flutter run -d emulator-5554` (após iniciar o emulador Android)
- **Rodar Web:** `flutter run -d chrome`

## Interface de Terminal (TUI)

O mesmo binário `bestfin` também roda inteiro no terminal, sem abrir janela
gráfica — útil para lançar despesas rápido, consultar relatórios por SSH ou
gerar backups em script.

```bash
bestfin tui                 # menu com todas as áreas do app (sync contínuo)
bestfin tui metas           # abre direto numa área (aceita prefixo e sem acento)
bestfin add "mercado 50 no cartão"   # lançamento por linguagem natural
bestfin sync                # sincroniza uma vez e sai (para scripts/cron)
bestfin --help              # lista as áreas e os atalhos
```

Todas as áreas da interface gráfica estão disponíveis: painel, transações
(com sugestões do histórico, lote e split), contas (com reconciliação),
categorias, cartões, orçamentos, metas, parcelamentos, recorrências,
financiamentos, investimentos, relatórios, projeção de caixa, conquistas,
chat com o LLM local, importação de PDF, backup, sincronização (com QR de
pareamento no terminal), grupos familiares e configurações. Com a TUI
aberta o sincronismo é contínuo — mudanças dos outros dispositivos chegam
em segundos e o que você grava é publicado automaticamente.

Navegação: `↑↓`/`j k` movem, `↵` abre, `1`-`9` selecionam direto, `q` volta;
os atalhos de cada tela aparecem no rodapé. As escritas passam pelos mesmos
use cases da GUI, então entram normalmente na fila de sincronização.

Opções úteis: `--db <caminho>` aponta para outro `bestfin.sqlite`;
`BESTFIN_TUI=0` força o modo não interativo em scripts.

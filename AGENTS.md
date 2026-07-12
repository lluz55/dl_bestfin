# 🏦 BestFin — Diretrizes de Desenvolvimento (AGENTS.md)

Este documento estabelece as diretrizes arquiteturais, de segurança, de estilo e de fluxo de trabalho que **todos os agentes de IA** e desenvolvedores devem seguir estritamente ao trabalhar no projeto **BestFin**.

---

## 📚 0. Protocolo OKF (OBRIGATÓRIO antes de codar)

O conhecimento do projeto está organizado em **OKF (Open Knowledge Format)** —
arquivos de conceito curados em `docs/okf/`. Antes de escrever qualquer código,
siga o protocolo de 6 passos (skill `okf-workflow`; alguns agentes expõem isso como comando `/okf <tarefa>`):

1. **Ler** `docs/okf/index.md` — índice de todos os conceitos.
2. **Escolher** 1-2 arquivos de conceito relevantes (máximo 3 por tarefa).
3. **Checar** `docs/tasks/index.md` — tarefa existente, status e dependências.
4. **Ler** este AGENTS.md (regras e proibições das seções abaixo).
5. **Implementar** e validar (`nix develop -c flutter analyze` / `flutter test`).
6. **Atualizar** o tracking: checkboxes + `timestamp` no arquivo da tarefa e a
   linha (Progresso/Status) em `docs/tasks/index.md`.

> **Nunca** abra `docs/SPEC.md` sem passar pelo índice OKF antes — os conceitos
> são curados e cirúrgicos; a spec é referência, não ponto de partida.

---

## 🚀 1. Ambiente de Desenvolvimento (Nix Environment)

O projeto utiliza **Nix Flakes** para garantir um ambiente consistente e reprodutível contendo as ferramentas exatas (Flutter, Android SDK, JDK e dependências de compilação Linux).

> [!IMPORTANT]
> **REGRA DE OURO PARA AGENTES:** Todos os comandos de terminal/shell **DEVEM** ser executados dentro do shell do Nix. Você deve prefixar todos os comandos com `nix develop -c`. **NÃO** execute comandos diretamente sem o prefixo.

### Comandos Frequentes:
*   **Obter dependências do Flutter:**
    ```bash
    nix develop -c flutter pub get
    ```
*   **Executar geração de código (Drift/Riverpod):**
    ```bash
    nix develop -c dart run build_runner build --delete-conflicting-outputs
    ```
*   **Executar geração de código em modo contínuo (Watch):**
    ```bash
    nix develop -c dart run build_runner watch --delete-conflicting-outputs
    ```
*   **Rodar os testes unitários/instrumentados:**
    ```bash
    nix develop -c flutter test
    ```
*   **Análise estática de código (Linter):**
    ```bash
    nix develop -c flutter analyze
    ```
*   **Formatação automática do código:**
    ```bash
    nix develop -c dart format .
    ```
*   **Limpar cache e build artifacts:**
    ```bash
    nix develop -c flutter clean
    ```

---

## 🔒 2. Segurança e Privacidade

Sendo o BestFin um aplicativo de finanças pessoais multiplataforma, a segurança dos dados financeiros e pessoais do usuário é a prioridade número um.

### 2.1 Armazenamento de Dados Sensíveis
*   **Dados Comuns (Não-sensíveis):** Utilize `shared_preferences` apenas para preferências de interface básicas (ex: escolha do tema escuro/claro, status do onboarding).
*   **Dados Sensíveis (Credenciais, Chaves de API, PINs, Tokens):** Use obrigatoriamente `flutter_secure_storage`. Nunca salve essas informações no SQLite em formato aberto ou em preferências globais normais.
*   **Banco de Dados Local (SQLite/Drift):** O banco de dados local deve ser mantido de forma segura na sandbox do aplicativo. Certifique-se de que caminhos sensíveis do banco de dados não sejam impressos em logs de produção.

### 2.2 Autenticação Biométrica e PIN
*   Telas confidenciais (ex: abertura do app, configurações de segurança) devem suportar autenticação biométrica via `local_auth` com fallback seguro para PIN local de 4 dígitos.
*   A verificação de segurança deve ser reavaliada se o app for para segundo plano (background) por mais de **1 minuto**.

### 2.3 Proteção Contra Injeção e Integridade do Banco
*   Use a API do **Drift ORM** para consultas seguras e tipadas. Evite, a todo custo, escrever consultas SQL puras com concatenação manual de strings contendo input do usuário.
*   Valide rigorosamente qualquer arquivo externo de importação (CSV/JSON) antes de inseri-lo no banco local para evitar injeções ou corrupção de tabelas.

### 2.4 Vazamento de Credenciais
*   **NUNCA** adicione chaves de API, senhas, tokens de build ou credenciais no repositório Git. Use arquivos `.env` ignorados no `.gitignore` ou injete-os na compilação usando `--dart-define`.

### 2.5 Arquivos que os Agentes NUNCA Devem Ler
*   **NUNCA** leia o conteúdo de `$HOME/.ssh` (chaves privadas, `known_hosts`, `config`, etc.).
*   **NUNCA** leia arquivos `.env`.

---

## 🧼 3. Código Limpo e Compartilhável (Clean & Shareable)

Para garantir que o código seja legível, modular e fácil de manter por humanos e por outros agentes, siga as convenções abaixo.

### 3.1 Geração de Código (`build_runner`)
*   O projeto usa geradores de código extensivamente para Drift e Riverpod.
*   **NUNCA** edite arquivos gerados (`*.g.dart`, `*.freezed.dart`) diretamente. Suas alterações serão perdidas na próxima execução do `build_runner`.
*   Sempre configure o analisador estático para excluir esses arquivos (`analysis_options.yaml` já está configurado para isso).

### 3.2 Padrões de Estilo do Código (Dart & Flutter)
*   **Strings:** Use aspas simples preferencialmente (`prefer_single_quotes`).
*   **Imports:** Use caminhos de pacote absolutos (`always_use_package_imports`), ex: `import 'package:bestfin/core/theme/app_theme.dart';`. Evite caminhos relativos como `import '../../core/theme/...`.
*   **Constantes:** Use o construtor `const` onde for possível para otimizar a renderização de widgets (`prefer_const_constructors`).
*   **Operações Assíncronas:** Se chamar uma função assíncrona cujo resultado não precisa ser aguardado diretamente, anote a chamada explicitamente com `unawaited(...)` da biblioteca `dart:async` para sinalizar a intenção (`unawaited_futures`).
*   **Prints:** Nunca use `print()` no código de produção. Para logs rápidos de depuração, use `debugPrint()` ou uma ferramenta apropriada de logs do projeto, eliminando-os antes de commitar.

### 3.3 Preservação de Comentários
*   **Mantenha a integridade da documentação existente.** Nunca remova docstrings ou comentários explicativos a menos que a lógica subjacente seja alterada ou explicitamente pedido.

---

## ⚡ 3.4 Otimização de Performance

Ao editar ou criar componentes UI, leve em conta as seguintes práticas para manter a performance do aplicativo:

### 3.4.1 Widgets e Build Methods
*   **Prefira `const` widgets sempre que possível:** `const Text('...')`, `const SizedBox()`, `const EdgeInsets.all(8)`. Isso evita rebuilds desnecessários.
*   **Use `StatelessWidget` em vez de `StatefulWidget`** quando não precisar de estado interno.
*   **Evite criar objetos dentro do método `build`:** Strings, listas, `TextStyle`, `BoxDecoration` ou funções anônimas criados em cada build geram novas referências e forçam rebuilds de filhos.
*   **Use `AutomaticKeepAliveClientMixin`** para telas que devem preservar estado quando navegação não é desejada (ex: `TearDownScreen`, `TransactionListScreen`).

### 3.4.2 ListView / Column com muitos itens
*   **Para listas longas:** Use `ListView.builder` com `itemExtent` fixo quando possível, ou `ListView.custom` com `SliverChildBuilderDelegate`. Isso evita criar todos os itens de uma vez.
*   **Para `Column` com muitos filhos dinâmicos:** Use `ListView` em vez de `Column` para evitar renderizar todos os itens na árvore.
*   **Limite o número de itens renderizados:** Em listas de transações, limite a visualização inicial a ~50 itens e carregue mais sob demanda (pagination/infini-scroll).

### 3.4.3 Evite rebuilds desnecessários
*   **Use `ConsumerWidget` ou `Consumer`** apenas nos trechos que precisam reagir a mudanças de provider, não em toda a árvore.
*   **Separe lógica pesada em métodos fora do build:** Formatação de datas, cálculos de porcentagem, filtragem de listas — execute fora do `build` ou use `ref.watch(...).select((e) => e.neededValue)`.
*   **Use `_memoized` ou variáveis de instância** para valores calculados que não mudam entre builds (ex: formatação de strings que dependem de parâmetros imutáveis).

### 3.4.4 Animações e Efeitos Visuais
*   **Limite animações em listas longas:** Cada item animado adiciona overhead. Use `AnimatedList` ou `Dismissible` apenas quando necessário.
*   **Evite `AnimatedContainer` em itens de lista:** Prefira `AnimatedSwitcher` ou `SmoothShadow` (do `flutter_animate`) para efeitos mais leves.
*   **Use `const` em widgets de animação:** `const AnimatedOpacity(...)`, `const AnimatedPositioned(...)`.

### 3.4.5 Imagens e Assets
*   **Use `cached_network_image`** para imagens da web com cache automático.
*   **Para ícones locais:** Use `IconTheme` e `Icon` com `size` definido, evitando `Image.asset` para ícones simples.
*   **Prefira SVG via `flutter_svg`** para ícones escaláveis, mas cacheie-os com `CachedNetworkImage` quando usado dinamicamente.

### 3.4.6 Context Watch e Providers
*   **Nunca chame `context.watch` ou `ref.watch` dentro de loops ou métodos executados no build.** Isso cria listeners extras para cada iteração.
*   **Use `ref.listen` em `initState` ou `useEffect`** para efeitos colaterais, não dentro do `build`.
*   **Para valores que não mudam comunicação:** Use `ref.read` em vez de `ref.watch` para evitar rebuilds automáticos.

### 3.4.7 Testes de Performance
*   **Use o Flutter DevTools (Performance tab)** para identificar frames com tempo de build > 16ms (60 FPS).
*   **Marque widgets pesados com `RepaintBoundary`** quando houver animações ou mudanças frequentes que não devem invalidar toda a árvore.
*   **Evite `Opacity` com alpha < 1.0 em widgets complexos:** Use `FadeTransition` com `AnimationController` ou `AnimatedOpacity` com `vsync` para melhor performance.

---

## 🏛️ 4. Diretrizes Arquiteturais do Projeto (BestFin Specific)

O BestFin utiliza uma arquitetura **Feature-First** integrada a uma estrutura de **Clean Architecture Leve**.

```
lib/
├── core/                   # Recursos globais e compartilhados
│   ├── database/           # Drift schema principal, tabelas e DAOs globais
│   ├── theme/              # Design System M3 Expressive
│   ├── widgets/            # UI Elements reusáveis globais (ex: amount_display.dart)
│   └── utils/              # Formatadores de moeda, validadores, etc.
└── features/               # Módulos funcionais e independentes (Ex: accounts)
    ├── <feature_name>/
        ├── presentation/   # Widgets, Views, Screens e Riverpod Providers
        ├── domain/         # Entidades, Models puros e Regras de Negócio
        └── data/           # DAOs específicos de features e implementações de repositório
```

### 4.1 Separação Rígida de Camadas
1.  **Camada de Apresentação (Presentation):**
    *   Widgets devem ser `StatelessWidget` ou `ConsumerWidget`/`ConsumerStatefulWidget` do Riverpod.
    *   **Proibido:** Colocar lógica de cálculo financeiro ou chamadas de banco de dados diretamente dentro do método `build` de widgets. A UI deve apenas ler o estado e disparar eventos para os Providers.
2.  **Camada de Estado (Riverpod Providers):**
    *   Use a sintaxe moderna do **Riverpod Generator** com a anotação `@riverpod`. Evite os métodos legados `ChangeNotifier` ou `StateNotifier`.
    *   Sempre verifique se o widget ainda está montado (`ref.mounted`) antes de aplicar o resultado de chamadas assíncronas no Notifier.
3.  **Camada de Dados (Data & Drift):**
    *   Interações de leitura e escrita no SQLite devem ocorrer apenas por meio de DAOs (`lib/core/database/daos/`) e expostas via Repositórios estruturados.

### 4.2 Partida Dobrada (Double-Entry Bookkeeping)
*   Como o aplicativo opera com contabilidade de partida dobrada, transações financeiras devem manter o equilíbrio contábil.
*   Uma transação é composta de pelo menos duas entradas (`Entry`): um débito e um crédito.
*   A soma dos valores de débito deve ser estritamente igual à soma dos valores de crédito. Valide essa equivalência no domínio antes de persistir no Drift.

### 4.3 Design System (Material Design 3 Expressive)
*   Siga fielmente as definições visuais especificadas em `lib/core/theme/`. Use cores dinâmicas adaptativas (`dynamic_color`), tipografia expressiva e curvas de animação harmônicas definidas no projeto.
*   Não aplique estilos Inline de forma ad-hoc. Sempre consuma tokens do `Theme.of(context)`.
*   **Padrões de Design:** Siga estritamente os padrões de design já estabelecidos neste arquivo (AGENTS.md) e no Design System do projeto para assegurar consistência visual e de experiência de usuário em todas as telas e componentes.

---

## 🛠️ 5. Fluxo de Trabalho Recomendado para Agentes

Ao receber uma tarefa de codificação no BestFin, siga este fluxo passo a passo para minimizar erros de geração e dependências cruzadas:

1.  **Planejar a Estrutura de Dados:**
    *   Defina as novas tabelas Drift ou campos necessários em `lib/core/database/tables/`.
    *   Execute o `build_runner` via `nix develop -c dart run build_runner build --delete-conflicting-outputs` para atualizar o banco de dados.
2.  **Desenvolver a Lógica de Acesso aos Dados:**
    *   Crie ou modifique o DAO correspondente e exponha os métodos necessários para a persistência.
3.  **Criar a Camada de Estado (Riverpod Notifiers):**
    *   Crie os providers necessários para gerenciar o estado da tela/regra de negócio. Use `@riverpod` e rode o build_runner novamente.
4.  **Implementar a Interface de Usuário (UI):**
    *   Crie os componentes visuais utilizando os tokens do `Theme` e consuma os providers Riverpod, seguindo os padrões de design estabelecidos.
5.  **Verificar e Validar:**
    *   Rode os linters (`nix develop -c flutter analyze`) e os testes (`nix develop -c flutter test`) para validar se tudo está funcionando como esperado e sem violações de estilo.

---

## 📦 6. Releases e Publicação de Binários

> [!IMPORTANT]
> **REGRA DE OURO DE RELEASE:** **Todo release DEVE incluir os binários compilados** anexados ao GitHub Release. Um release sem os binários de **Linux** e **Android** é considerado incompleto.

Desde que o CI/CD foi introduzido, o fluxo é dividido em duas metades:

* **Local** (`scripts/release.sh`): só bump de versão + commit + tag anotada + push. Não precisa mais do keystore Android nem da chave privada Nostr.
* **CI** (`.github/workflows/release.yml`, disparado pelo push da tag `vX.Y.Z`): compila Android + Linux via Nix, cria o GitHub Release com os binários anexados e publica a notificação Nostr. Todos os secrets sensíveis vivem só no GitHub Actions — nunca no disco do dev.

```
release.sh (local)              GitHub Actions (push da tag v*.*.*)
──────────────────              ─────────────────────────────────
1. bump versão                  build-android ─┐
2. commit + tag + push  ──tag──▶                ├─▶ release (gh release create)
                                 build-linux   ─┘        │
                                                          ▼
                                                   publish-nostr
```

### 6.1 Rodar um release

```bash
./scripts/release.sh X.Y.Z --changelog "Descrição das mudanças"
# ou deixando o script extrair as notas da seção "## Unreleased"/"## vX.Y.Z" do CHANGELOG.md:
./scripts/release.sh X.Y.Z
# ou com bump automático:
./scripts/release.sh minor --auto-bump --changelog "Novas funcionalidades menores"
```

O script cuida de:
1.  **Versão** em `pubspec.yaml` (`version: X.Y.Z+build`).
1b. **`kAppVersion`** em `lib/core/constants/app_info.dart`, sincronizado com o mesmo `X.Y.Z` (Configurações › Sobre lê essa constante — release sem isso é incompleto).
2.  Rename `## Unreleased` → `## vX.Y.Z (data)` no `CHANGELOG.md`, se aplicável.
3.  Commit + **tag anotada** `vX.Y.Z` + `git push` do commit e da tag. A mensagem da tag (`"critical"` ou `"release"`) é o sinal que o CI lê para decidir se o release é crítico.

Flags opcionais:

| Flag | Efeito |
|---|---|
| `--changelog <texto>` / `--changelog-file <path>` | Sobrepõe a extração automática do CHANGELOG.md |
| `--critical` | Marca a tag como crítica → banner vermelho no GitHub Release e `--critical` no evento Nostr |
| `--auto-bump` | Combinado com `patch\|minor\|major` em vez de X.Y.Z, calcula a versão a partir do `pubspec.yaml` atual |
| `--dry-run` | Imprime os passos sem executar nada |

O push da tag dispara o workflow. Acompanhe com `gh run watch` ou pela aba **Actions** no GitHub.

### 6.2 O que o CI faz (`.github/workflows/release.yml`)

Disparado por `push: tags: ["v*.*.*"]`. Jobs, em ordem de dependência:

1.  **`build-android`** e **`build-linux`** (paralelos): compilam via `nix develop .#ci -c flutter build apk|linux --release`. O keystore é reconstruído a partir dos secrets `ANDROID_KEYSTORE_BASE64` (base64 do `.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`.
2.  **`release`**: baixa os dois artefatos, extrai as notas da seção `## vX.Y.Z` do `CHANGELOG.md` (via `scripts/extract_changelog.sh`), lê a mensagem da tag para saber se é crítico, e roda `gh release create` anexando o APK e o `.tar.gz` do Linux.
3.  **`publish-nostr`**: roda `nix develop .#ci -c dart run scripts/publish_update.dart` com a chave do secret `BESTFIN_DEV_NOSTR_PRIVKEY`, usando as notas e a flag `--critical` vindas do job anterior.

`devShells.ci` (`flake.nix`) é uma variante enxuta do devShell de desenvolvimento — sem emulator Android, zenity, llama-cpp, python ou o toolkit de MCP — usada só pelo CI para manter o cache do Nix Store pequeno. O cache do `/nix/store` entre execuções usa `nix-community/cache-nix-action` (wrapper sobre `actions/cache`, sem serviço externo), chaveado pelo hash de `flake.lock`.

> O evento Nostr é `kind:30078 d-tag:app_update` (NIP-33, replaceable) — reexecutar o job `publish-nostr` (ex: após uma falha) não duplica nada, só substitui o evento anterior nos relays.

### 6.3 Secrets necessários no GitHub

Configure com `gh secret set <NOME>` (ou pela aba Settings › Secrets and variables › Actions do repo):

| Secret | Conteúdo |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 android/bestfin-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` do `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` do `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` do `android/key.properties` (`bestfin`) |
| `BESTFIN_DEV_NOSTR_PRIVKEY` | Chave privada Nostr (hex ou nsec) — a mesma cuja pubkey está em `kDeveloperNostrPubkey` |

`GITHUB_TOKEN`/`github.token` já é automático — não precisa de secret próprio para `gh release create`.

### 6.4 Checklist Manual (quando não usar o script/CI)

1. [ ] Bumpar `version` em `pubspec.yaml` (X.Y.Z+build)
2. [ ] Atualizar `kAppVersion` em `lib/core/constants/app_info.dart`
3. [ ] Commit + tag anotada `vX.Y.Z` + push do commit e da tag
4. [ ] `nix develop .#ci -c flutter build apk --release`
5. [ ] `nix develop .#ci -c flutter build linux --release`
6. [ ] `tar -czf bestfin-vX.Y.Z-linux-x64.tar.gz -C build/linux/x64/release/bundle .`
7. [ ] `gh release create vX.Y.Z ...` com APK e `.tar.gz` anexados
8. [ ] Publicar notificação Nostr via `scripts/publish_update.dart`

### 6.5 Observações
*   `android/key.properties` e `*.jks` estão no `.gitignore` — nunca commitar. Necessários só localmente se você quiser compilar um APK assinado fora do CI.
*   Nomeie os artefatos com a versão e a plataforma (ex: `bestfin-v1.0.6-android.apk`, `bestfin-v1.0.6-linux-x64.tar.gz`) — o workflow cuida disso automaticamente.
*   A chave privada Nostr (`BESTFIN_DEV_NOSTR_PRIVKEY`) nunca deve ser commitada nem exportada localmente — vive só como secret do GitHub Actions (ver 6.3).

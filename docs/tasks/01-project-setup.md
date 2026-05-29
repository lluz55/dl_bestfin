# Tarefa 01 — Setup do Projeto

> [!IMPORTANT]
> Esta é a primeira tarefa e bloqueia todas as demais. Nenhuma outra tarefa pode ser iniciada antes desta ser concluída.

**Fase:** 1 — Fundação
**Prioridade:** 🔴 Crítica (bloqueante)
**Pré-requisitos:** Nenhum

---

## Descrição

Configurar o projeto Flutter com Nix Flake, estrutura de pastas feature-first, dependências iniciais e configuração de ferramentas de desenvolvimento. Esta tarefa estabelece a base sobre a qual todas as outras serão construídas.

---

## Subtarefas

### Ambiente Nix

 - [x] Criar `flake.nix` com Flutter SDK + Android SDK + Linux desktop dependencies (conforme SPEC seção 8)
 - [x] Verificar que `nix develop` entra no shell corretamente com Flutter disponível

### Scaffold do Projeto

 - [x] Rodar `nix develop -c flutter create --org com.bestfin --project-name bestfin --platforms android,linux,web ./`
 - [x] Criar estrutura de pastas feature-first (conforme SPEC seção 3.2):
  ```
  lib/
  ├── core/
  │   ├── database/
  │   │   ├── tables/
  │   │   └── daos/
  │   ├── theme/
  │   ├── widgets/
  │   ├── constants/
  │   ├── extensions/
  │   └── utils/
  ├── features/
  │   ├── accounts/
  │   │   ├── data/repositories/
  │   │   ├── domain/models/
  │   │   ├── domain/usecases/
  │   │   └── presentation/
  │   │       ├── providers/
  │   │       ├── screens/
  │   │       └── widgets/
  │   ├── transactions/
  │   ├── categories/
  │   ├── dashboard/
  │   ├── onboarding/
  │   └── settings/
  └── app.dart
  ```

### Dependências

 - [x] Configurar `pubspec.yaml` com todas as dependências da Fase 1:
  - **Database:** `drift`, `sqlite3_flutter_libs`
  - **State management:** `flutter_riverpod`, `riverpod_annotation`
  - **Navegação:** `go_router`
  - **Gráficos:** `fl_chart`
  - **Animação:** `flutter_animate`, `lottie`
  - **Segurança:** `local_auth`, `flutter_secure_storage`
  - **Utilitários:** `path_provider`, `image_picker`, `file_picker`, `share_plus`, `google_fonts`
  - **Dev dependencies:** `drift_dev`, `build_runner`, `riverpod_generator`, `custom_lint`, `riverpod_lint`

### Configuração de Ferramentas

 - [x] Configurar `analysis_options.yaml` com regras de lint rigorosas
 - [x] Configurar `build.yaml` para code generation (drift + riverpod)
 - [x] Criar `.gitignore` adequado (incluir `*.g.dart`, `*.freezed.dart`, etc. ou não — decidir estratégia de commit de gerados)

### Validação

 - [x] Rodar `nix develop -c flutter pub get`
 - [x] Verificar build Android: `nix develop -c flutter build apk --debug`
 - [x] Verificar build Linux: `nix develop -c flutter build linux --debug`
 - [x] Verificar build Web: `nix develop -c flutter build web`
 - [x] Criar `README.md` básico com instruções de setup

---

## Critérios de Aceitação

 - [x] `nix develop -c flutter analyze` executa sem erros nem warnings
 - [x] `nix develop -c flutter build apk --debug` compila com sucesso
 - [x] `nix develop -c flutter build linux --debug` compila com sucesso
 - [x] `nix develop -c flutter build web` compila com sucesso
 - [x] Estrutura de pastas feature-first criada conforme SPEC seção 3.2
 - [x] Todas as dependências da Fase 1 resolvidas no `pubspec.lock`
 - [x] Code generation configurado e funcional (`build_runner build` roda sem erro)

---

## Arquivos Principais

| Arquivo | Ação |
|---------|------|
| `flake.nix` | Criar |
| `pubspec.yaml` | Criar/Configurar |
| `analysis_options.yaml` | Criar |
| `build.yaml` | Criar |
| `lib/main.dart` | Criar |
| `lib/app.dart` | Criar |
| `.gitignore` | Criar |
| `README.md` | Criar |

---

## Notas e Considerações

> [!NOTE]
> - O `flake.nix` deve incluir `flutter`, `android-sdk` (com build-tools, platform-tools e platforms adequados), e dependências de Linux desktop (`gtk3`, `pkg-config`, etc.).
> - Decidir se arquivos `.g.dart` serão commitados ou gerados no CI. Recomendação: **não commitar** e gerar via `build_runner` no CI/local.
> - O `lib/app.dart` nesta fase pode ser um `MaterialApp` básico com placeholder. O tema será implementado na Tarefa 02.

> [!TIP]
> Testar o Nix Flake em um ambiente limpo para garantir reprodutibilidade.

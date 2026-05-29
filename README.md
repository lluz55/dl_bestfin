# BestFin 🏦

Um app de finanças pessoais focado em produtividade e automação, construído com Flutter e Nix.

## Tecnologias

- **Framework:** Flutter (Android, Linux, Web)
- **Environment:** Nix Flake
- **State Management:** Riverpod 3
- **Local Database:** Drift (SQLite)
- **Design:** Material Design 3 Expressive

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

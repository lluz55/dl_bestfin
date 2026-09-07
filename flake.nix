{
  description = "BestFin - Personal Finance App";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, android-nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        androidSdk = android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
          cmdline-tools-latest
          platform-tools
          build-tools-34-0-0
          build-tools-35-0-0
          platforms-android-33
          platforms-android-34
          platforms-android-35
          platforms-android-36
          emulator
          ndk-28-2-13676358
          cmake-3-22-1
        ]);

        # Mesma composição do androidSdk, sem o emulator -- não é necessário
        # para `flutter build apk` e é, de longe, o maior componente do SDK.
        # Usado só pelo devShells.ci (mantém o cache do Nix Store no CI menor).
        androidSdkCi = android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
          cmdline-tools-latest
          platform-tools
          build-tools-34-0-0
          build-tools-35-0-0
          platforms-android-33
          platforms-android-34
          platforms-android-35
          platforms-android-36
          ndk-28-2-13676358
          cmake-3-22-1
        ]);

        llama-cpp-vulkan = pkgs.llama-cpp.override { vulkanSupport = true; };

        flutterMcpToolkit = pkgs.stdenv.mkDerivation {
          pname = "flutter-mcp-toolkit";
          version = "3.1.0";

          src = pkgs.fetchurl {
            url = "https://github.com/Arenukvern/mcp_flutter/releases/download/v3.1.0/flutter_mcp_3.1.0_linux-x64.tar.gz";
            hash = "sha256-LbBk/CLD6tTJh6bSntIEyZ7BjGO8AMjyb3WmcbJavKc=";
          };

          nativeBuildInputs = [ pkgs.autoPatchelfHook ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib ];

          unpackPhase = ''
            tar -xzf $src
          '';

          installPhase = ''
            mkdir -p $out/bin
            install -m 0755 flutter_mcp_3.1.0_linux-x64/bin/flutter-mcp-toolkit $out/bin/flutter-mcp-toolkit
            install -m 0755 flutter_mcp_3.1.0_linux-x64/bin/flutter-mcp-toolkit-server $out/bin/flutter-mcp-toolkit-server
          '';
        };

        linuxDesktopDeps = [ pkgs.gtk3 pkgs.pcre2 pkgs.libepoxy pkgs.libsecret pkgs.libsysprof-capture ];

        # sqlcipher_flutter_libs compila o SQLCipher no Linux e faz
        # `find_package(OpenSSL REQUIRED)` com OPENSSL_USE_STATIC_LIBS=ON,
        # exigindo libcrypto.a. Unimos headers (.dev) e libs estáticas (.out)
        # num único prefixo para o CMake achar via OPENSSL_ROOT_DIR.
        opensslStatic = pkgs.openssl.override { static = true; };
        opensslJoined = pkgs.symlinkJoin {
          name = "openssl-static-joined";
          paths = [ opensslStatic.out opensslStatic.dev ];
        };

        # ── Pacote consumível como flake input (task 61) ────────────────────
        # `packages.bestfin` é uma derivação real (sandbox, offline) — diferente
        # dos apps.* acima, que compilam dentro do checkout local. Consumo:
        #   inputs.bestfin.url = "github:<user>/bestfin";
        #   environment.systemPackages = [ inputs.bestfin.packages.${system}.bestfin ];

        bestfinVersion = let
          yaml = builtins.readFile ./pubspec.yaml;
          versionLine = pkgs.lib.findFirst
            (l: pkgs.lib.hasPrefix "version:" l)
            "version: 0.0.0"
            (pkgs.lib.splitString "\n" yaml);
        in builtins.head (pkgs.lib.splitString "+"
          (pkgs.lib.trim (pkgs.lib.removePrefix "version:" versionLine)));

        bestfinSrc = pkgs.lib.cleanSourceWith {
          src = pkgs.lib.cleanSource ./.;
          filter = path: type:
            !pkgs.lib.hasPrefix "${toString ./.}/build" path
            && !pkgs.lib.hasInfix "linux/flutter/ephemeral" path;
        };

        # FOD (fixed-output derivation) do pub cache: `flutter pub get` com
        # rede, hashado por pubspec.lock. O build principal roda depois com
        # `--offline` contra este cache — nunca baixa nada no sandbox.
        bestfinPubCacheDebug = pkgs.stdenv.mkDerivation {
          pname = "bestfin-pub-cache-debug";
          version = bestfinVersion;
          src = bestfinSrc;
          nativeBuildInputs = [ pkgs.flutter ];
          buildPhase = ''
            export HOME=$PWD
            export PUB_CACHE=$PWD/pub-cache
            flutter pub get --no-example
          '';
          installPhase = ''
            mkdir -p $out
            cp -r pub-cache/hosted/pub.dev $out/ 2>/dev/null || true
            (grep -rl '/nix/store/' pub-cache/hosted/pub.dev || true) > $out/refs.txt
            echo "---symlinks---" >> $out/refs.txt
            (find pub-cache -type l -printf '%p -> %l\n' || true) >> $out/refs.txt
            echo "---newfiles---" >> $out/refs.txt
            (find pub-cache -newer pubspec.lock -type f 2>/dev/null | head -50 || true) >> $out/refs.txt
          '';
        };

        # Diagnóstico: replica o pub get da FOD já sandboxed (cache semeado
        # pela derivação debug anterior, com rede) e mostra o que muda.
        bestfinPubCacheDebug2 = pkgs.stdenv.mkDerivation {
          pname = "bestfin-pub-cache-debug2";
          version = bestfinVersion;
          src = bestfinSrc;
          nativeBuildInputs = [ pkgs.flutter ];
          buildPhase = ''
            export HOME=$PWD
            cp -r ${/tmp/pc-test/pc} ./pub-cache
            chmod -R u+w pub-cache
            export PUB_CACHE=$PWD/pub-cache
            flutter pub get --offline || true
          '';
          installPhase = ''
            mkdir -p $out
            (grep -rl '/nix/store/' pub-cache/hosted/pub.dev || true) > $out/refs.txt
            echo "---symlinks---" >> $out/refs.txt
            (find pub-cache -type l -printf '%p -> %l\n' || true) >> $out/refs.txt
          '';
        };

        bestfinPubCache = pkgs.stdenv.mkDerivation {
          pname = "bestfin-pub-cache";
          version = bestfinVersion;
          src = bestfinSrc;
          nativeBuildInputs = [ pkgs.flutter ];
          impureEnvVars = pkgs.lib.fetchers.proxyImpureEnvVars;
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          # Hash inicial placeholder — o primeiro `nix build` falha com o
          # mismatch e reporta o hash real; substituir aqui e rebuildar.
          outputHash = pkgs.lib.fakeSha256;
          buildPhase = ''
            export HOME=$PWD
            export PUB_CACHE=$PWD/pub-cache
            flutter pub get --no-example
          '';
          installPhase = ''
            mkdir -p $out/hosted
            # Só os pacotes extraídos — `.cache` guarda locks/índices com
            # timestamps e quebraria a reprodutibilidade do hash.
            cp -r pub-cache/hosted/pub.dev $out/hosted/
            rm -rf $out/hosted/pub.dev/.cache
            echo "=== DEBUG refs ===" >&2
            (grep -rl '/nix/store/' $out || echo NO_REFS_IN_OUT) >&2
            (find $out -type l -printf '%p -> %l\n' || true) >&2
            echo "=== END DEBUG ===" >&2
          '';
        };

        # Build offline do bundle Linux dentro do sandbox do Nix.
        bestfinPackage = pkgs.stdenv.mkDerivation {
          pname = "bestfin";
          version = bestfinVersion;
          src = bestfinSrc;

          nativeBuildInputs = with pkgs; [
            flutter
            cmake
            ninja
            clang
            pkg-config
            makeWrapper
          ];
          buildInputs = linuxDesktopDeps ++ [ pkgs.sqlite ];

          # Necessário para o CMake do plugin sqlcipher_flutter_libs achar o
          # OpenSSL estático (libcrypto.a) e para o linker achar gtk3/sqlite.
          preConfigure = ''
            export OPENSSL_ROOT_DIR="${opensslJoined}"
            export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" linuxDesktopDeps}"
          '';
          preBuild = ''
            export HOME=$PWD
            export PUB_CACHE=${bestfinPubCache}
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath ([ pkgs.sqlite ] ++ linuxDesktopDeps)}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          '';

          buildPhase = ''
            runHook preBuild
            flutter build linux --release --offline
            runHook postBuild
          '';

          installPhase = ''
            mkdir -p $out/lib/bestfin $out/bin
            cp -r build/linux/x64/release/bundle/. $out/lib/bestfin/
            ln -s $out/lib/bestfin/bestfin $out/bin/bestfin
            wrapProgram $out/lib/bestfin/bestfin \
              --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}" \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath ([ pkgs.sqlite ] ++ linuxDesktopDeps)}:$out/lib/bestfin/lib"
          '';

          passthru.exePath = "/bin/bestfin";
          meta = with pkgs.lib; {
            description = "BestFin — Personal Finance App (GUI, TUI e CLI no mesmo binário)";
            license = licenses.unfree;
            platforms = platforms.linux;
            mainProgram = "bestfin";
          };
        };

        flutterBuildEnv = pkgs.writeShellScriptBin "flutter-build" ''
          set -euo pipefail
          export ANDROID_HOME="${androidSdk}/share/android-sdk"
          export ANDROID_SDK_ROOT="${androidSdk}/share/android-sdk"
          export JAVA_HOME="${pkgs.jdk17}"
          export GRADLE_USER_HOME="$HOME/.gradle"
          export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_SDK_ROOT/build-tools/35.0.0/aapt2"
          # xdg-utils fornece `xdg-user-dir`, usado pelo path_provider_linux
          # para resolver o diretório de documentos. Sem ele, getApplicationDocumentsDirectory
          # lança MissingPlatformDirectoryException.
          export PATH="${pkgs.lib.makeBinPath [ pkgs.pkg-config pkgs.xdg-utils ]}:$PATH"
          export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" linuxDesktopDeps}"
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath ([ pkgs.sqlite ] ++ linuxDesktopDeps)}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          # sqlcipher_flutter_libs precisa achar o OpenSSL estático no configure
          # do CMake; sem isso, `flutter build linux` fora do devShell (ex: via
          # `nix run .#bestfin`) falha com "Could NOT find OpenSSL".
          export OPENSSL_ROOT_DIR="${opensslJoined}"
          exec ${pkgs.flutter}/bin/flutter "$@"
        '';

        # Recompila o bundle sempre que o código-fonte (lib/, pubspec.*, linux/)
        # tiver arquivos mais novos que o binário já buildado. Evita reusar um
        # bundle obsoleto (ex: builds antigos que ainda tinham o bug do
        # MissingPlatformDirectoryException) e evita rebuild a cada `nix run`
        # quando nada mudou.
        ensureFreshBundleScript = ''
          BUNDLE="build/linux/x64/release/bundle/bestfin"
          NEEDS_BUILD=1
          if [ -x "$BUNDLE" ]; then
            # linux/flutter/ephemeral/ é regenerado pelo próprio `flutter
            # build` a cada execução (ver linux/.gitignore) — se entrar no
            # find, o bundle nunca fica "fresco" e todo `nix run` recompila.
            STALE="$(find lib pubspec.yaml pubspec.lock linux -type f -newer "$BUNDLE" -not -path 'linux/flutter/ephemeral/*' 2>/dev/null | head -n1)"
            if [ -z "$STALE" ]; then
              NEEDS_BUILD=0
            fi
          fi
          if [ "$NEEDS_BUILD" = "1" ]; then
            echo "⚙️  Código-fonte mudou (ou bundle não existe), recompilando (flutter build linux --release)..." >&2
            ${flutterBuildEnv}/bin/flutter-build build linux --release
          fi
          BIN="$BUNDLE"
        '';
      in {
        packages.bestfin = bestfinPackage;
        packages.default = bestfinPackage;
        packages.debug-pub-cache = bestfinPubCacheDebug;
        packages.debug-pub-cache2 = bestfinPubCacheDebug2;

        packages.flutter-mcp-toolkit = flutterMcpToolkit;

        apps.flutter-mcp-toolkit-server = {
          type = "app";
          program = "${flutterMcpToolkit}/bin/flutter-mcp-toolkit-server";
        };

        apps.build-android = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "build-android" ''
            exec ${flutterBuildEnv}/bin/flutter-build build apk "$@"
          ''}/bin/build-android";
        };

        apps.build-linux = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "build-linux" ''
            exec ${flutterBuildEnv}/bin/flutter-build build linux "$@"
          ''}/bin/build-linux";
        };

        # BestFin CLI/TUI — mesmo binário da GUI, mas em modo CLI (sem janela)
        # Uso: nix run .#bestfin -- add "mercado 50"
        #      nix run .#bestfin -- tui
        #      nix run .#bestfin -- --help
        #      nix run .#tui  (atalho para bestfin tui)
        apps.bestfin = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "bestfin-app" ''
            set -euo pipefail
            ${ensureFreshBundleScript}
            # path_provider_linux chama `xdg-user-dir` para resolver o
            # diretório de documentos. Sem isso no PATH, lança
            # MissingPlatformDirectoryException (app_database.dart:640). O
            # helper app_paths.dart tem fallback para ~/Documents, mas é
            # melhor deixar o XDG resolver quando possível.
            export PATH="${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}:$PATH"
            export XDG_DOCUMENTS_DIR="''${XDG_DOCUMENTS_DIR:-$HOME/Documents}"
            mkdir -p "$XDG_DOCUMENTS_DIR"
            # No compositor cosmic-comp (COSMIC desktop), o embedder GTK/Flutter
            # do Linux estoura "Protocol error 2 (invalid_size) on wl_surface"
            # ao criar a superfície nativa Wayland e a janela nunca aparece,
            # sem nenhum erro do lado do Dart. cosmic-session já exporta
            # GDK_BACKEND=wayland,x11 por padrão — GDK tenta "wayland"
            # primeiro, e como o handshake inicial não falha (só o commit do
            # wl_surface, depois), nunca cai para o fallback x11 da lista.
            # Por isso é atribuição direta, não "''${GDK_BACKEND:-x11}".
            export GDK_BACKEND=x11
            exec "$BIN" "$@"
          ''}/bin/bestfin-app";
        };

        apps.tui = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "bestfin-tui" ''
            set -euo pipefail
            ${ensureFreshBundleScript}
            export PATH="${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}:$PATH"
            export XDG_DOCUMENTS_DIR="''${XDG_DOCUMENTS_DIR:-$HOME/Documents}"
            mkdir -p "$XDG_DOCUMENTS_DIR"
            # COSMIC (cosmic-session) já exporta GDK_BACKEND=wayland,x11 por
            # padrão — GDK tenta "wayland" primeiro, e como o handshake
            # inicial não falha (só o commit do wl_surface, depois), nunca
            # cai para o fallback x11 da lista. Por isso aqui é atribuição
            # direta, não "''${GDK_BACKEND:-x11}".
            export GDK_BACKEND=x11
            exec "$BIN" tui "$@"
          ''}/bin/bestfin-tui";
        };

        apps.llm-server = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "llm-server" ''
            MODEL_DIR="/home/lluz/Documents/llm"
            MODEL_PATH="$MODEL_DIR/MiniCPM-V-4_6-Q4_K_M.gguf"
            MODEL_URL="https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/MiniCPM-V-4_6-Q4_K_M.gguf"

            mkdir -p "$MODEL_DIR"

            if [ ! -f "$MODEL_PATH" ] || [ $(stat -c%s "$MODEL_PATH" 2>/dev/null || echo 0) -lt 500000000 ]; then
              echo "🤖 Modelo nao encontrado ou incompleto. Iniciando download do MiniCPM-V 4.6 (Q4_K_M) do Hugging Face..."
              ${pkgs.curl}/bin/curl -L -C - -o "$MODEL_PATH" "$MODEL_URL"
            fi

            echo "🚀 Iniciando Llama-Server na porta 8087 com o modelo: $MODEL_PATH"
            exec ${llama-cpp-vulkan}/bin/llama-server \
              -m "$MODEL_PATH" \
              --port 8087 \
              -c 4096
          ''}/bin/llm-server";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            flutter
            jdk17
            androidSdk
            flutterMcpToolkit
            sqlite
            # Linux desktop deps
            cmake
            ninja
            clang
            pkg-config
            gtk3
            pcre2
            libepoxy
            libsecret
            libsysprof-capture
            # Diálogos de arquivo do file_picker no Linux (abrir/salvar)
            zenity
            llama-cpp-vulkan
            # Rust (required by rust_lib_ndk Flutter plugin)
            cargo
            rustc
            # Scripting
            (python3.withPackages (ps: with ps; [
              pdfplumber
              pandas
              pydantic
            ]))
            # SOPS / Secrets Management
            sops
            age
            ssh-to-age
          ];

          env = {
            ANDROID_HOME = "${androidSdk}/share/android-sdk";
            ANDROID_SDK_ROOT = "${androidSdk}/share/android-sdk";
            JAVA_HOME = "${pkgs.jdk17}";
          };

          shellHook = ''
            export GRADLE_USER_HOME="$HOME/.gradle"
            export PATH="$HOME/.pub-cache/bin:$PATH"
            export LD_LIBRARY_PATH="${pkgs.sqlite.out}/lib:$LD_LIBRARY_PATH"
            export OPENSSL_ROOT_DIR="${opensslJoined}"
            export LLAMA_LIBRARY_PATH="${llama-cpp-vulkan}/lib/libllama.so"
            export LLAMA_SERVER_BIN="${llama-cpp-vulkan}/bin/llama-server"
            export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_SDK_ROOT/build-tools/35.0.0/aapt2"

            # path_provider_linux exige XDG_DOCUMENTS_DIR para
            # getApplicationDocumentsDirectory(); sem ele, abre o SQLite com
            # MissingPlatformDirectoryException (app_database.dart:640).
            # Definimos um fallback em $HOME/Documents caso o usuário esteja
            # num ambiente sem XDG (ex: headless, container).
            export XDG_DOCUMENTS_DIR="''${XDG_DOCUMENTS_DIR:-$HOME/Documents}"
            mkdir -p "$XDG_DOCUMENTS_DIR"

            # No compositor cosmic-comp (COSMIC desktop), o embedder GTK/Flutter
            # do Linux estoura "Protocol error 2 (invalid_size) on wl_surface"
            # ao criar a superfície nativa Wayland — a janela nunca aparece e
            # não há nenhum erro do lado do Dart (a conexão Wayland só morre
            # em silêncio). Forçar GDK a usar Xwayland contorna o bug.
            # COSMIC (cosmic-session) já exporta GDK_BACKEND=wayland,x11 por
            # padrão — GDK tenta "wayland" primeiro, e como o handshake
            # inicial não falha (só o commit do wl_surface, depois), nunca
            # cai para o fallback x11 da lista. Por isso aqui é atribuição
            # direta, não "''${GDK_BACKEND:-x11}".
            export GDK_BACKEND=x11

            # --- SOPS / Secrets configuration ---
            export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
            if [ -f secrets.enc.yaml ] || [ -f android/bestfin-release.enc.jks ]; then
              if [ -f "$SOPS_AGE_KEY_FILE" ] || [ -f "$HOME/.ssh/id_ed25519" ]; then
                echo "🔑 [SOPS] Descriptografando segredos do projeto..." >&2
                if [ ! -f "$SOPS_AGE_KEY_FILE" ] && [ -f "$HOME/.ssh/id_ed25519" ]; then
                  if command -v ssh-to-age >/dev/null 2>&1; then
                    export SOPS_AGE_KEY=$(ssh-to-age -private-key -i "$HOME/.ssh/id_ed25519" 2>/dev/null)
                  fi
                fi
                
                # 1. Descriptografa secrets.enc.yaml (gera .env e android/key.properties)
                if [ -f secrets.enc.yaml ] && command -v sops >/dev/null 2>&1; then
                  sops -d --output-type json secrets.enc.yaml 2>/dev/null | python3 -c '
import sys, json, os
try:
    data = json.load(sys.stdin)
    
    # Gerar .env
    with open(".env", "w") as f:
        for k in ["BESTFIN_DEV_NOSTR_PUBKEY", "BESTFIN_DEV_NOSTR_PRIVKEY"]:
            if k in data:
                f.write(f"{k}={data[k]}\n")
                
    # Gerar android/key.properties
    if os.path.exists("android"):
        with open("android/key.properties", "w") as f:
            f.write("storePassword={}\n".format(data.get("ANDROID_STORE_PASSWORD", "")))
            f.write("keyPassword={}\n".format(data.get("ANDROID_KEY_PASSWORD", "")))
            f.write("keyAlias={}\n".format(data.get("ANDROID_KEY_ALIAS", "")))
            f.write("storeFile={}\n".format(data.get("ANDROID_STORE_FILE", "")))
    print("✅ .env e android/key.properties gerados/atualizados via SOPS.")
except Exception as e:
    print("⚠️  Erro ao processar secrets.enc.yaml: {}".format(e))
' >&2
                fi

                # 2. Descriptografa a Keystore binaria (android/bestfin-release.enc.jks)
                # --input-type/--output-type binary são obrigatórios aqui: a extensão
                # .enc.jks não é um formato que o SOPS reconhece automaticamente, e sem
                # essas flags `sops -d` "funciona" (exit 0) mas escreve um arquivo vazio.
                if [ -f android/bestfin-release.enc.jks ] && command -v sops >/dev/null 2>&1; then
                  if sops -d --input-type binary --output-type binary android/bestfin-release.enc.jks \
                      > android/bestfin-release.tmp.jks 2>/dev/null \
                      && [ -s android/bestfin-release.tmp.jks ]; then
                    mv android/bestfin-release.tmp.jks android/bestfin-release.jks
                    echo "✅ Keystore android/bestfin-release.jks atualizada via SOPS." >&2
                  else
                    rm -f android/bestfin-release.tmp.jks
                    echo "⚠️  Falha ao descriptografar keystore binaria." >&2
                  fi
                fi
              else
                echo "ℹ️  Nenhuma chave privada (age ou SSH) encontrada para descriptografar segredos do SOPS." >&2
              fi
            fi

            echo "🏦 BestFin dev environment ready" >&2
          '';
        };

        # Shell enxuto usado só pelo CI (.github/workflows/release.yml) para
        # `flutter build apk|linux --release` e `dart run scripts/publish_update.dart`.
        # Sem emulator/zenity/llama-cpp/python/flutterMcpToolkit -- nada disso
        # é necessário para compilar um release, e cada um infla bastante o
        # fechamento cacheado em actions/cache. devShells.default (dev local)
        # continua com tudo.
        devShells.ci = pkgs.mkShell {
          buildInputs = with pkgs; [
            flutter
            jdk17
            androidSdkCi
            sqlite
            # Linux desktop deps
            cmake
            ninja
            clang
            pkg-config
            gtk3
            pcre2
            libepoxy
            libsecret
            libsysprof-capture
            # Rust (required by rust_lib_ndk Flutter plugin)
            cargo
            rustc
          ];

          env = {
            ANDROID_HOME = "${androidSdkCi}/share/android-sdk";
            ANDROID_SDK_ROOT = "${androidSdkCi}/share/android-sdk";
            JAVA_HOME = "${pkgs.jdk17}";
          };

          shellHook = ''
            export GRADLE_USER_HOME="$HOME/.gradle"
            export LD_LIBRARY_PATH="${pkgs.sqlite.out}/lib:$LD_LIBRARY_PATH"
            export OPENSSL_ROOT_DIR="${opensslJoined}"
            export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_SDK_ROOT/build-tools/35.0.0/aapt2"
          '';
        };
      });
}

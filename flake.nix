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
          platforms-android-34
          emulator
        ]);

        backend = pkgs.buildGoModule {
          pname = "bestfin-backend";
          version = "0.1.0";
          src = ./backend;
          vendorHash = null; # vendor/ directory is included in src
          postInstall = "mv $out/bin/server $out/bin/bestfin-backend";
        };
      in {
        packages.backend = backend;

        apps.backend = {
          type = "app";
          program = "${backend}/bin/bestfin-backend";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            flutter
            jdk17
            androidSdk
            sqlite
            # Linux desktop deps
            pkg-config
            gtk3
            pcre2
            libepoxy
            libsecret
            # Backend development
            go
            # Scripting
            (python3.withPackages (ps: with ps; [
              pdfplumber
              pandas
              pydantic
            ]))
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
            echo "🏦 BestFin dev environment ready"
          '';
        };
      }) // {
        nixosModules.backend = import ./backend/nix/module.nix;
      };
}

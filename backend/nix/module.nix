{ config, lib, pkgs, ... }:
let
  cfg = config.services.bestfin-backend;
in {
  options.services.bestfin-backend = {
    enable = lib.mkEnableOption "BestFin sync backend";

    package = lib.mkOption {
      type = lib.types.package;
      description = ''
        The bestfin-backend package to use.
        Typically: self.packages.''${pkgs.system}.backend
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "HTTP port to listen on.";
    };

    listenAddr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to bind the HTTP server to. Defaults to localhost-only for Cloudflare Tunnel use.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/bestfin-backend";
      description = "Directory where the SQLite database is stored.";
    };

    jwtSecretFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing environment variables, including JWT_SECRET.
        Example file contents: JWT_SECRET=your-secret-here-min-32-chars
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.bestfin-backend = {
      description = "BestFin Sync Backend";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      environment = {
        LISTEN_ADDR = "${cfg.listenAddr}:${toString cfg.port}";
        DATA_DIR = cfg.dataDir;
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/bestfin-backend";
        EnvironmentFile = cfg.jwtSecretFile;
        DynamicUser = true;
        StateDirectory = "bestfin-backend";
        Restart = "on-failure";
        RestartSec = "5s";
        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };
    };
  };
}

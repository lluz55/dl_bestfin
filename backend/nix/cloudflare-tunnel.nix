{ config, lib, pkgs, ... }:
let
  cfg = config.services.bestfin-cloudflare-tunnel;
  validateTunnelConfig = pkgs.writeShellScript "bestfin-cloudflare-tunnel-validate" ''
    set -eu

    token_file="$1"
    public_url_file="$2"

    if [ ! -s "$token_file" ]; then
      echo "Cloudflare Tunnel token file is empty or missing: $token_file" >&2
      exit 1
    fi

    if [ ! -s "$public_url_file" ]; then
      echo "Cloudflare Tunnel public URL file is empty or missing: $public_url_file" >&2
      exit 1
    fi

    public_url="$(tr -d '\r\n' < "$public_url_file")"
    case "$public_url" in
      https://*) ;;
      *)
        echo "Cloudflare Tunnel public URL must start with https://: $public_url" >&2
        exit 1
        ;;
    esac
  '';
in {
  options.services.bestfin-cloudflare-tunnel = {
    enable = lib.mkEnableOption "Cloudflare Tunnel for BestFin backend";

    tunnelTokenFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the Cloudflare Tunnel token.
        Obtain via: cloudflared tunnel create bestfin
        File contents: just the token string, no variable name.
        Example: /run/secrets/cloudflare-tunnel-token
      '';
    };

    publicUrlFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the public HTTPS URL exposed by Cloudflare Tunnel.
        This is intentionally read from a secret file so deployments can source both
        the tunnel token and the client-facing sync URL from sops-nix.
        File contents: just the URL, no variable name.
        Example: /run/secrets/bestfin-sync-url
      '';
    };

    localPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Local port where the BestFin backend listens.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.bestfin-cloudflared = {
      description = "Cloudflare Tunnel for BestFin";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "bestfin-backend.service" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        ExecStartPre = lib.escapeShellArgs [
          validateTunnelConfig
          cfg.tunnelTokenFile
          cfg.publicUrlFile
        ];
        ExecStart = lib.escapeShellArgs [
          "${pkgs.cloudflared}/bin/cloudflared"
          "tunnel"
          "--no-autoupdate"
          "run"
          "--token-file"
          cfg.tunnelTokenFile
          "--url"
          "http://127.0.0.1:${toString cfg.localPort}"
        ];
        Restart = "on-failure";
        RestartSec = "10s";
        DynamicUser = true;
        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        # Allow reading the sops-managed token and public URL files.
        ReadOnlyPaths = [ cfg.tunnelTokenFile cfg.publicUrlFile ];
      };
    };
  };
}

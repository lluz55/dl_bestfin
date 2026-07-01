# BestFin Sync Backend

Backend HTTP leve para sincronização E2E do BestFin. O servidor autentica usuários, guarda refresh tokens e persiste registros de sincronização como blobs opacos. Dados financeiros devem chegar cifrados pelo app; o backend não descriptografa payloads.

## Executar Localmente

Na raiz do projeto:

```bash
JWT_SECRET=dev-secret-32-chars-minimum-value nix run .#backend
```

Por padrão o servidor escuta em `127.0.0.1:8080` e grava o SQLite em `./data/bestfin.sqlite`.

Variáveis:

```bash
LISTEN_ADDR=127.0.0.1:8080
DATA_DIR=./data
JWT_SECRET=troque-por-um-segredo-com-32-chars-ou-mais
```

`JWT_SECRET` é obrigatório e deve ter pelo menos 32 caracteres.

## API

Auth:

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/recover`
- `PUT /auth/master-key` com `Authorization: Bearer <token>`

Sync:

- `GET /sync/pull?since=<unix_timestamp>` com `Authorization: Bearer <token>`
- `POST /sync/push` com `Authorization: Bearer <token>`

`/sync/push` recebe:

```json
{
  "records": [
    {
      "entity_type": "transaction",
      "entity_id": "uuid-local",
      "payload": "base64url-nonce-ciphertext-mac",
      "updated_at": 1760000000,
      "is_deleted": false
    }
  ]
}
```

Tipos aceitos hoje: `account`, `transaction`, `category`, `goal`.

## Build

```bash
nix build .#backend
```

O binário produzido é `result/bin/bestfin-backend`.

## Usar o NixOS Module em Outro Flake

Adicione este projeto como input do seu flake de infraestrutura:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bestfin.url = "github:SEU_USUARIO/SEU_REPO_BESTFIN";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, bestfin, sops-nix, ... }: {
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        sops-nix.nixosModules.sops
        bestfin.nixosModules.backend
        bestfin.nixosModules.cloudflareTunnel
        ./configuration.nix
        ({ config, ... }: {
          sops.defaultSopsFile = ./secrets.yaml;
          sops.secrets."bestfin/backend-env" = {};
          sops.secrets."bestfin/cloudflare-tunnel-token" = {};
          sops.secrets."bestfin/cloudflare-public-url" = {};

          services.bestfin-backend = {
            enable = true;
            package = bestfin.packages.x86_64-linux.backend;
            listenAddr = "127.0.0.1";
            port = 8080;
            dataDir = "/var/lib/bestfin-backend";
            jwtSecretFile = config.sops.secrets."bestfin/backend-env".path;
          };

          services.bestfin-cloudflare-tunnel = {
            enable = true;
            localPort = 8080;
            tunnelTokenFile = config.sops.secrets."bestfin/cloudflare-tunnel-token".path;
            publicUrlFile = config.sops.secrets."bestfin/cloudflare-public-url".path;
          };
        })
      ];
    };
  };
}
```

No `secrets.yaml` do `sops-nix`, mantenha os três valores fora do store Nix:

```yaml
bestfin:
  backend-env: |
    JWT_SECRET=troque-por-um-segredo-com-32-chars-ou-mais
  cloudflare-tunnel-token: eyJhIjoi...
  cloudflare-public-url: https://bestfin.example.com
```

Para criar os caminhos corretos em um repositório que já usa `sops-nix`, use `sops set`. O valor passado ao comando deve ser JSON válido, por isso strings precisam das aspas duplas internas:

```bash
sops set secrets.yaml '["bestfin"]["cloudflare-tunnel-token"]' '"TOKEN_DO_TUNNEL_CLOUDFLARE"'
sops set secrets.yaml '["bestfin"]["cloudflare-public-url"]' '"https://bestfin.example.com"'
sops set secrets.yaml '["bestfin"]["backend-env"]' '"JWT_SECRET=troque-por-um-segredo-com-32-chars-ou-mais"'
```

Também é possível criar o bloco `bestfin` inteiro de uma vez:

```bash
sops set secrets.yaml '["bestfin"]' '{"backend-env":"JWT_SECRET=troque-por-um-segredo-com-32-chars-ou-mais","cloudflare-tunnel-token":"TOKEN_DO_TUNNEL_CLOUDFLARE","cloudflare-public-url":"https://bestfin.example.com"}'
```

Para inserir valores vindos do ambiente:

```bash
sops set secrets.yaml '["bestfin"]["cloudflare-tunnel-token"]' "\"$CLOUDFLARE_TUNNEL_TOKEN\""
sops set secrets.yaml '["bestfin"]["cloudflare-public-url"]' "\"$BESTFIN_PUBLIC_URL\""
```

Ou via stdin:

```bash
printf '"https://bestfin.example.com"' |
  sops set --value-stdin secrets.yaml '["bestfin"]["cloudflare-public-url"]'
```

Se preferir editar manualmente, abra:

```bash
sops secrets.yaml
```

E adicione exatamente estas chaves:

```yaml
bestfin:
  backend-env: |
    JWT_SECRET=troque-por-um-segredo-com-32-chars-ou-mais
  cloudflare-tunnel-token: TOKEN_DO_TUNNEL_CLOUDFLARE
  cloudflare-public-url: https://bestfin.example.com
```

Se o arquivo ainda não existir, crie-o a partir de um template e depois criptografe com a sua regra `.sops.yaml`:

```bash
cat > secrets.yaml <<'EOF'
bestfin:
  backend-env: |
    JWT_SECRET=troque-por-um-segredo-com-32-chars-ou-mais
  cloudflare-tunnel-token: TOKEN_DO_TUNNEL_CLOUDFLARE
  cloudflare-public-url: https://bestfin.example.com
EOF

sops --encrypt --in-place secrets.yaml
```

Os nomes importam: `sops.secrets."bestfin/cloudflare-tunnel-token"` lê a chave YAML `bestfin.cloudflare-tunnel-token`, e `sops.secrets."bestfin/cloudflare-public-url"` lê `bestfin.cloudflare-public-url`.

O arquivo descriptografado referenciado em `jwtSecretFile` deve conter:

```bash
JWT_SECRET=troque-por-um-segredo-com-32-chars-ou-mais
```

O arquivo descriptografado referenciado em `tunnelTokenFile` deve conter somente o token do Cloudflare Tunnel, sem nome de variável:

```bash
eyJhIjoi...
```

O arquivo descriptografado referenciado em `publicUrlFile` deve conter somente a URL pública HTTPS usada pelos clientes:

```text
https://bestfin.example.com
```

Para teste local a partir de um checkout, também é possível usar:

```nix
bestfin.url = "path:/home/usuario/dev/dl_bestfin";
```

## Exposição Externa

O módulo escuta em `127.0.0.1` por padrão. Para acesso remoto, prefira publicar via reverse proxy com TLS ou túnel, mantendo o serviço local:

- Caddy/nginx com HTTPS.
- Cloudflare Tunnel apontando para `http://127.0.0.1:8080`.

Com o módulo `bestfin.nixosModules.cloudflareTunnel`, o serviço systemd `bestfin-cloudflared` executa:

```bash
cloudflared tunnel --no-autoupdate run --token-file <tunnelTokenFile> --url http://127.0.0.1:8080
```

No painel da Cloudflare, configure o Public Hostname do túnel para encaminhar para:

```text
http://127.0.0.1:8080
```

Mantenha o mesmo hostname público no segredo `bestfin/cloudflare-public-url`. O módulo valida esse arquivo no `ExecStartPre` para evitar deploy sem a URL que o app deve usar.

Após aplicar a configuração no servidor:

```bash
sudo nixos-rebuild switch --flake .#server
systemctl status bestfin-backend
systemctl status bestfin-cloudflared
```

Se for expor diretamente na rede local, configure:

```nix
services.bestfin-backend.listenAddr = "0.0.0.0";
networking.firewall.allowedTCPPorts = [ 8080 ];
```

## Persistência

O backend usa SQLite em `${DATA_DIR}/bestfin.sqlite`. No módulo NixOS, `StateDirectory = "bestfin-backend"` e `ReadWritePaths` é limitado ao `dataDir` configurado.

Faça backup periódico do diretório de dados. O banco contém credenciais de auth, refresh tokens e payloads cifrados de sincronização.

---
type: Guide
title: "Gerenciamento de Segredos com SOPS"
description: "Guia de configuração e uso do SOPS integrado ao Nix devShell no projeto BestFin."
tags: [sops, secrets, nix, security]
timestamp: 2026-07-12T11:35:00Z
---

# Gerenciamento de Segredos com SOPS

## O Que É / What It Is
Este projeto utiliza o **SOPS (Secrets Operations)** para criptografar segredos locais de desenvolvimento e build (como credenciais do arquivo `.env` e chaves do Android) de forma que possam ser armazenados no Git com total segurança. A descriptografia ocorre em memória ou disco local de forma transparente ao iniciar o ambiente de desenvolvimento (`nix develop`).

## Como Funciona a Criptografia
Utilizamos a criptografia com chaves do **`age`**. A chave pública autorizada está configurada no arquivo [.sops.yaml](file:///home/lluz/dev/dl_bestfin/.sops.yaml) na raiz do projeto.
Durante a inicialização do Nix devShell, o `shellHook` em [flake.nix](file:///home/lluz/dev/dl_bestfin/flake.nix) descriptografa:
1.  O arquivo [secrets.enc.yaml](file:///home/lluz/dev/dl_bestfin/secrets.enc.yaml) para gerar o local `.env` e o arquivo [android/key.properties](file:///home/lluz/dev/dl_bestfin/android/key.properties) (via script embutido em Python).
2.  O arquivo binário `android/bestfin-release.enc.jks` para gerar a keystore do Android [android/bestfin-release.jks](file:///home/lluz/dev/dl_bestfin/android/bestfin-release.jks).

## Configuração do Desenvolvedor

### 1. Pré-requisitos (Chaves)
O script de descriptografia automática no `shellHook` procura por chaves em dois locais padrão:
*   Um arquivo de chave `age` local: `~/.config/sops/age/keys.txt`
*   Uma chave SSH padrão: `~/.ssh/id_ed25519` (o script utiliza o `ssh-to-age` para converter a chave SSH em uma identidade compatível com o SOPS).

Se a sua chave pública correspondente não estiver no arquivo [.sops.yaml](file:///home/lluz/dev/dl_bestfin/.sops.yaml), você não conseguirá descriptografar os segredos. Fale com o administrador do repositório para adicionar sua chave pública.

### 2. Criptografando o `.env` ou propriedades do Android
O arquivo [secrets.enc.yaml](file:///home/lluz/dev/dl_bestfin/secrets.enc.yaml) contém tanto chaves do `.env` quanto propriedades do Android. 

Para editar ou adicionar novos valores, a forma mais recomendada é abrir o editor padrão e salvar:
```bash
nix develop -c sops secrets.enc.yaml
```

### 3. Criptografando arquivos binários (Keystore Android)
Para criptografar/atualizar o arquivo binário `android/bestfin-release.jks` para `android/bestfin-release.enc.jks`, utilize a flag `--output` do SOPS para evitar truncamentos de shell:
```bash
nix develop -c sops -e --filename-override android/bestfin-release.enc.jks --input-type binary --output android/bestfin-release.enc.jks android/bestfin-release.jks
```

## Benefícios e Integração
*   **Novos Desenvolvedores:** Não há necessidade de solicitar ou criar manualmente as chaves Nostr ou a keystore do Android ao clonar o projeto. Basta executar `nix develop` para gerar o `.env`, `key.properties` e `bestfin-release.jks` automaticamente.
*   **Separação Segura no CI/CD:** O CI do GitHub Actions continuará utilizando secrets do GitHub e injetando as variáveis de ambiente sem precisar descriptografar arquivos do SOPS (já que o CI já possui as variáveis declaradas nos segredos do repositório).

## Evitando Problemas Comuns (Common Pitfalls)
*   **Falha de Criação por Regra de Nome:** Nunca execute `sops -e .env` diretamente, pois o SOPS tentará ler regras para o arquivo `.env` e falhará devido ao regex restrito de arquivo do [.sops.yaml](file:///home/lluz/dev/dl_bestfin/.sops.yaml). Use sempre a flag `--filename-override`.
*   **Truncamento por Redirecionamento de Shell:** Ao usar redirecionamento simples (`> arquivo.enc.yaml`), o shell do host pode truncar o arquivo de destino para 0 bytes antes de o Nix inicializar e ler o arquivo no `shellHook` (causando falha de leitura e corrupção). Prefira usar o parâmetro `--output <arquivo>` do SOPS para salvar os resultados com segurança.
*   **Poluição da Saída do Shell Hook:** Todas as mensagens impressas (com `echo`) no `shellHook` do [flake.nix](file:///home/lluz/dev/dl_bestfin/flake.nix) devem ser direcionadas para o canal de erro padrão (`>&2`) para que não poluam ou corrompam a saída padrão (`stdout`) de pipelines de desenvolvimento.

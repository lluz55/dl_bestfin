---
type: Guide
title: "Gerenciamento de Segredos com SOPS"
description: "Guia de configuração e uso do SOPS integrado ao Nix devShell no projeto BestFin."
tags: [sops, secrets, nix, security]
timestamp: 2026-07-12T10:17:00Z
---

# Gerenciamento de Segredos com SOPS

## O Que É / What It Is
Este projeto utiliza o **SOPS (Secrets Operations)** para criptografar segredos locais de desenvolvimento (como credenciais do arquivo `.env`) de forma que possam ser armazenados no Git com total segurança. A descriptografia ocorre em memória de forma transparente ao iniciar o ambiente de desenvolvimento (`nix develop`).

## Como Funciona a Criptografia
Utilizamos a criptografia com chaves do **`age`**. A chave pública autorizada está configurada no arquivo [.sops.yaml](file:///home/lluz/dev/dl_bestfin/.sops.yaml) na raiz do projeto.
Durante a inicialização do Nix devShell, o `shellHook` em [flake.nix](file:///home/lluz/dev/dl_bestfin/flake.nix) tenta encontrar sua chave privada local e, se encontrada, descriptografa o arquivo [secrets.enc.yaml](file:///home/lluz/dev/dl_bestfin/secrets.enc.yaml) para o arquivo local `.env` (que é ignorado pelo Git).

## Configuração do Desenvolvedor

### 1. Pré-requisitos (Chaves)
O script de descriptografia automática no `shellHook` procura por chaves em dois locais padrão:
*   Um arquivo de chave `age` local: `~/.config/sops/age/keys.txt`
*   Uma chave SSH padrão: `~/.ssh/id_ed25519` (o script utiliza o `ssh-to-age` para converter a chave SSH em uma identidade compatível com o SOPS).

Se a sua chave pública correspondente não estiver no arquivo [.sops.yaml](file:///home/lluz/dev/dl_bestfin/.sops.yaml), você não conseguirá descriptografar os segredos. Fale com o administrador do repositório para adicionar seu public key.

### 2. Criptografando o `.env` Local
Para atualizar ou salvar novos segredos locais em seu `.env` para o repositório, rode o seguinte comando:
```bash
nix develop -c sops -e --filename-override secrets.enc.yaml --input-type dotenv --output-type yaml .env > secrets.tmp.yaml && mv secrets.tmp.yaml secrets.enc.yaml
```
Este comando gerará ou atualizará o arquivo `secrets.enc.yaml` criptografado de forma segura e sem conflito de leitura e gravação no mesmo arquivo.

### 3. Editando o arquivo criptografado diretamente
Se quiser abrir o editor padrão e alterar as chaves criptografadas diretamente em formato YAML:
```bash
nix develop -c sops secrets.enc.yaml
```

## Benefícios e Integração
*   **Integração Automatizada:** Não há necessidade de solicitar ou criar manualmente as chaves de desenvolvimento Nostr ao clonar o projeto. Basta executar `nix develop` para gerar o `.env` local.
*   **Separação Segura no CI/CD:** O CI do GitHub Actions continuará utilizando secrets do GitHub e injetando as variáveis de ambiente sem precisar descriptografar arquivos do SOPS (já que o CI já possui as variáveis declaradas nos segredos do repositório).

## Evitando Problemas Comuns (Common Pitfalls)
*   **Falha de Criação por Regra de Nome:** Nunca execute `sops -e .env > secrets.enc.yaml` diretamente, pois o SOPS tentará ler regras para o arquivo `.env` e falhará devido ao regex restrito de arquivo do [.sops.yaml](file:///home/lluz/dev/dl_bestfin/.sops.yaml). Use sempre o parâmetro `--filename-override secrets.enc.yaml`.
*   **Conflito de Truncamento:** Ao usar redirecionamento simples `> secrets.enc.yaml`, o shell do host pode truncar o arquivo para 0 bytes antes de o Nix inicializar e ler o arquivo no `shellHook`. Use sempre um arquivo temporário intermédio (`secrets.tmp.yaml`) ao criptografar segredos.
*   **Poluição da Saída do Shell Hook:** Todas as mensagens impressas (com `echo`) no `shellHook` do [flake.nix](file:///home/lluz/dev/dl_bestfin/flake.nix) devem ser direcionadas para o canal de erro padrão (`>&2`) para que não poluam ou corrompam a saída padrão (`stdout`) de pipelines de desenvolvimento.

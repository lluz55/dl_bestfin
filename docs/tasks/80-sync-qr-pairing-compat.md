---
type: Task
title: "Pareamento por QR entre Linux e Android (QR inválido no scanner)"
description: "O QR gerado no app Linux não era reconhecido pelo scanner Android; troca do payload do QR por um formato alfanumérico compacto, com fallback para o formato antigo e feedback de erro no scanner."
tags: [bug, sync, qr, pareamento, linux, android, nostr]
timestamp: 2026-08-29T00:00:00Z
status: completed
progress: 7/7
---

## Descrição

Ao gerar o QR de identidade no app **Linux** (`/sync/qr`) e escaneá-lo com o app
**Android** (`/sync/scan`), o pareamento falhava: ou nada acontecia, ou aparecia
"QR inválido ou frase incorreta".

### Diagnóstico

A criptografia estava correta — `masterKeyToMnemonic` / `mnemonicToMasterKey`
fazem round-trip perfeito (validado por teste). O problema estava na **camada do
QR**, com duas causas somadas:

1. **Payload denso demais para leitura de tela.** O QR carregava o mnemônico
   BIP39 em texto: 24 palavras minúsculas ≈ 160 caracteres. Letras minúsculas
   estão fora do alfabeto alfanumérico do QR, forçando o **modo byte** e uma
   matriz de ~versão 11 (61×61 módulos). Renderizada em `size: 240` com
   `padding: 16` (quiet zone menor que os 4 módulos exigidos) num monitor
   Linux com `devicePixelRatio: 1.0`, sobram ~3,7 px lógicos por módulo — abaixo
   do que a câmera do Android consegue decodificar de forma confiável a partir
   de uma tela (moiré, brilho, subpixel).
2. **Scanner silenciava a falha.** `_onDetect` fazia
   `if (words.length != 24) return;` — qualquer leitura parcial ou payload
   diferente era descartada **sem mensagem alguma**, o que para o usuário é
   indistinguível de "o app não reconhece o QR". Também não havia validação de
   checksum BIP39 antes de chamar `importIdentity`, e o scanner aceitava todos
   os formatos de código de barras.

### Solução

Novo payload de pareamento, restrito ao alfabeto alfanumérico do QR:

```
BESTFIN:1:<64 chars hex MAIÚSCULO da masterKey>     (74 chars → ~versão 5)
```

Isso habilita o **modo alfanumérico** do QR e reduz a matriz de ~61×61 para
~37×37 módulos, com módulos ~2,5× maiores na mesma área — margem folgada para
leitura de monitor. O mnemônico continua sendo a identidade: o scanner converte
o hex de volta para as 24 palavras e chama `importIdentity` como antes.

## Checklist

- [x] `E2ECryptoService.masterKeyToQrPayload(masterKey)` — codifica `BESTFIN:1:<hex>`, rejeitando masterKey que não tenha 32 bytes.
- [x] `E2ECryptoService.qrPayloadToMnemonic(raw)` — decodifica o payload novo **e** aceita o formato antigo (24 palavras), validando checksum BIP39; retorna `null` em vez de lançar.
- [x] `identity_qr_screen.dart` renderiza `_qrPayload` (não o mnemônico), com `size: 280`, quiet zone `padding: 24` e ECC `Q`.
- [x] `qr_scanner_screen.dart` usa `qrPayloadToMnemonic` e restringe o scanner a `BarcodeFormat.qrCode`.
- [x] Scanner mostra erro explícito quando um código é lido mas não é um pareamento BestFin (fim da falha silenciosa).
- [x] Botão "Copiar mnemônico" continua copiando **o mnemônico**, não o payload do QR.
- [x] Testes: `test/features/sync/qr_pairing_payload_test.dart` (round-trip, compatibilidade com QR antigo, tolerância a espaços/caixa, rejeição de lixo, masterKey inválida).

## Aceitação

- QR gerado no Linux é lido pelo Android à distância normal de uso (≈20–40 cm), com o app em release.
- QR gerado por versões anteriores do app (mnemônico em texto) continua funcionando no scanner novo — compatibilidade retroativa.
- Escanear um QR qualquer (Wi-Fi, URL, Pix) exibe mensagem clara em vez de não fazer nada.
- Após o scan bem-sucedido, o dispositivo deriva a mesma pubkey Nostr do dispositivo de origem e passa a ler/escrever os mesmos eventos kind:30078.

## Arquitetura

```
lib/features/sync/data/services/e2e_crypto_service.dart        # masterKeyToQrPayload / qrPayloadToMnemonic
lib/features/sync/presentation/screens/identity_qr_screen.dart # gera o QR (Linux e Android)
lib/features/sync/presentation/screens/qr_scanner_screen.dart  # lê o QR (Android)
test/features/sync/qr_pairing_payload_test.dart
```

## Armadilhas de agente

- **Nunca** colocar caractere minúsculo no payload do QR: derruba o modo
  alfanumérico e devolve a matriz densa que causou o bug.
- O prefixo `BESTFIN:1:` é versionado — mudar o formato exige bumpar para `2:` e
  manter o parser do `1:` (dispositivos antigos continuam gerando o formato anterior).
- O QR carrega a masterKey **em claro**: a tela mantém `SecureScreen.enable()` e o
  overlay "toque para revelar"; qualquer novo ponto que exponha o payload precisa
  do mesmo cuidado.
- `qrPayloadToMnemonic` retorna `null` para entrada inválida — não lança. Chamador
  precisa tratar o `null` explicitamente, senão a falha volta a ser silenciosa.
- `mobile_scanner` entrega vários barcodes por frame; iterar todos antes de
  declarar falha.

## Referências

- [[features/sync]]
- [[architecture/overview]]

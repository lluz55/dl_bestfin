import 'package:bestfin/features/sync/data/services/e2e_crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QR de pareamento', () {
    test('payload usa apenas o alfabeto alfanumérico do QR', () {
      final mk = E2ECryptoService.generateMasterKey();
      final payload = E2ECryptoService.masterKeyToQrPayload(mk);
      expect(payload, startsWith('BESTFIN:1:'));
      expect(payload.length, 74);
      expect(RegExp(r'^[0-9A-Z:]+$').hasMatch(payload), isTrue);
    });

    test('round-trip payload → mnemônico → masterKey', () {
      final mk = E2ECryptoService.generateMasterKey();
      final payload = E2ECryptoService.masterKeyToQrPayload(mk);
      final mnemonic = E2ECryptoService.qrPayloadToMnemonic(payload);
      expect(mnemonic, isNotNull);
      expect(mnemonic!.split(' ').length, 24);
      expect(E2ECryptoService.mnemonicToMasterKey(mnemonic), mk);
      expect(mnemonic, E2ECryptoService.masterKeyToMnemonic(mk));
    });

    test('aceita QR antigo com mnemônico de 24 palavras', () {
      final mk = E2ECryptoService.generateMasterKey();
      final mnemonic = E2ECryptoService.masterKeyToMnemonic(mk);
      expect(E2ECryptoService.qrPayloadToMnemonic(mnemonic), mnemonic);
      expect(
        E2ECryptoService.qrPayloadToMnemonic('  ${mnemonic.toUpperCase()}  '),
        mnemonic,
      );
    });

    test('tolera espaços e caixa no prefixo', () {
      final mk = E2ECryptoService.generateMasterKey();
      final payload = E2ECryptoService.masterKeyToQrPayload(mk);
      expect(
        E2ECryptoService.qrPayloadToMnemonic('  ${payload.toLowerCase()} '),
        E2ECryptoService.masterKeyToMnemonic(mk),
      );
    });

    test('rejeita conteúdo que não é pareamento BestFin', () {
      for (final bad in [
        '',
        'https://example.com',
        'BESTFIN:1:ZZZZ',
        'BESTFIN:1:${'ab' * 31}',
        'abandon abandon abandon',
        List.filled(24, 'abandon').join(' '), // checksum inválido
      ]) {
        expect(
          E2ECryptoService.qrPayloadToMnemonic(bad),
          isNull,
          reason: 'deveria rejeitar: $bad',
        );
      }
    });

    test('masterKey com tamanho inválido falha explicitamente', () {
      expect(
        () => E2ECryptoService.masterKeyToQrPayload(List.filled(16, 0)),
        throwsArgumentError,
      );
    });
  });
}

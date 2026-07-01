import 'package:bestfin/features/sync/data/services/e2e_crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deriveKEK is deterministic for same password and salt', () async {
    final first = await E2ECryptoService.deriveKEK(
      'correct horse battery staple',
      '00112233445566778899aabbccddeeff',
    );
    final second = await E2ECryptoService.deriveKEK(
      'correct horse battery staple',
      '00112233445566778899aabbccddeeff',
    );

    expect(await first.extractBytes(), await second.extractBytes());
  });

  test('encryptPayload and decryptPayload are inverses', () async {
    final masterKey = E2ECryptoService.generateMasterKey();
    const plainText = '{"id":"tx-1","amount":1234}';

    final encrypted = await E2ECryptoService.encryptPayload(
      masterKey,
      plainText,
    );
    final decrypted = await E2ECryptoService.decryptPayload(
      masterKey,
      encrypted,
    );

    expect(encrypted, isNot(plainText));
    expect(decrypted, plainText);
  });

  test('mnemonic round-trips master key', () {
    final masterKey = E2ECryptoService.generateMasterKey();

    final mnemonic = E2ECryptoService.masterKeyToMnemonic(masterKey);
    final recovered = E2ECryptoService.mnemonicToMasterKey(mnemonic);

    expect(recovered, masterKey);
  });
}

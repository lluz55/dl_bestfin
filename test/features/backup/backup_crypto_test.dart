import 'dart:convert';
import 'dart:typed_data';

import 'package:bestfin/features/backup/domain/backup_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupCrypto', () {
    final plaintext = Uint8List.fromList(
      utf8.encode('SQLite format 3\x00dados financeiros sensíveis'),
    );

    test('encrypt/decrypt são inversos com a senha correta', () async {
      final blob = await BackupCrypto.encrypt(plaintext, 'senha-forte-123');
      final restored = await BackupCrypto.decrypt(blob, 'senha-forte-123');
      expect(restored, equals(plaintext));
    });

    test('o blob cifrado não contém o texto claro', () async {
      final blob = await BackupCrypto.encrypt(plaintext, 'senha-forte-123');
      // O header mágico do SQLite não pode aparecer em claro no arquivo cifrado.
      final needle = utf8.encode('SQLite format 3');
      var found = false;
      for (var i = 0; i + needle.length <= blob.length; i++) {
        var match = true;
        for (var j = 0; j < needle.length; j++) {
          if (blob[i + j] != needle[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          found = true;
          break;
        }
      }
      expect(found, isFalse);
    });

    test('senha errada falha com FormatException', () async {
      final blob = await BackupCrypto.encrypt(plaintext, 'certa');
      expect(
        () => BackupCrypto.decrypt(blob, 'errada'),
        throwsA(isA<FormatException>()),
      );
    });

    test('arquivo sem o magic BFENCB1 é rejeitado', () async {
      final notABackup = Uint8List.fromList(
        List<int>.generate(128, (i) => i % 256),
      );
      expect(
        () => BackupCrypto.decrypt(notABackup, 'qualquer'),
        throwsA(isA<FormatException>()),
      );
    });

    test('nonces/salts diferentes a cada cifragem (não determinístico)', () async {
      final a = await BackupCrypto.encrypt(plaintext, 'senha');
      final b = await BackupCrypto.encrypt(plaintext, 'senha');
      expect(a, isNot(equals(b)));
    });
  });
}

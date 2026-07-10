import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Criptografia de backup baseada em senha do usuário: PBKDF2-SHA256 deriva uma
/// chave de 256 bits a partir da senha + salt aleatório, usada para cifrar os
/// bytes do backup com AES-256-GCM (autenticado). Diferente do backup `.sqlite`
/// puro, o arquivo resultante não expõe nenhum dado financeiro sem a senha.
///
/// Formato do arquivo (binário):
///   magic(7 = "BFENCB1") ‖ iterations(4, big-endian) ‖ salt(16) ‖
///   nonce(12) ‖ ciphertext(...) ‖ mac(16)
class BackupCrypto {
  // "BFENCB1" — BestFin ENCrypted Backup, formato v1.
  static const List<int> _magic = [0x42, 0x46, 0x45, 0x4E, 0x43, 0x42, 0x31];
  static const int _iterations = 210000;
  static const int _saltLen = 16;
  static const int _nonceLen = 12;
  static const int _macLen = 16;
  static const int _headerLen = 7 + 4 + _saltLen; // magic + iters + salt

  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// Cifra [plaintext] com a [password] e devolve o blob no formato acima.
  static Future<Uint8List> encrypt(
    List<int> plaintext,
    String password,
  ) async {
    final rng = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLen, (_) => rng.nextInt(256)),
    );
    final key = await _deriveKey(password, salt, _iterations);
    final box = await _aesGcm.encrypt(plaintext, secretKey: key);

    final builder = BytesBuilder(copy: false);
    builder.add(_magic);
    final iterBytes = ByteData(4)..setUint32(0, _iterations);
    builder.add(iterBytes.buffer.asUint8List());
    builder.add(salt);
    builder.add(box.nonce);
    builder.add(box.cipherText);
    builder.add(box.mac.bytes);
    return builder.toBytes();
  }

  /// Decifra um blob produzido por [encrypt]. Lança [FormatException] se o
  /// arquivo não for um backup criptografado válido ou a senha estiver errada.
  static Future<Uint8List> decrypt(List<int> blob, String password) async {
    final data = Uint8List.fromList(blob);
    if (data.length < _headerLen + _nonceLen + _macLen) {
      throw const FormatException('Arquivo de backup criptografado inválido.');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (data[i] != _magic[i]) {
        throw const FormatException(
          'Este arquivo não é um backup criptografado do BestFin.',
        );
      }
    }
    final iterations = ByteData.sublistView(data, 7, 11).getUint32(0);
    final salt = data.sublist(11, _headerLen);
    final nonce = data.sublist(_headerLen, _headerLen + _nonceLen);
    final mac = data.sublist(data.length - _macLen);
    final cipherText = data.sublist(_headerLen + _nonceLen, data.length - _macLen);

    final key = await _deriveKey(password, salt, iterations);
    try {
      final plain = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Senha incorreta ou arquivo de backup corrompido.',
      );
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }
}

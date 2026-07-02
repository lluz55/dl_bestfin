import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bip340/bip340.dart' as bip340;
import 'package:cryptography/cryptography.dart';

// Encrypted blob format: base64url(nonce_12 ‖ ciphertext ‖ mac_16)
class E2ECryptoService {
  static final _aesGcm = AesGcm.with256bits();

  // PBKDF2-SHA256, 600 000 iterations → 32-byte key-encryption-key
  static Future<SecretKey> deriveKEK(String password, String kdfSalt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 600000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode(kdfSalt),
    );
  }

  // Generate a cryptographically secure random 32-byte master key
  static Uint8List generateMasterKey() {
    final rng = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  // HMAC-SHA256(masterKey, "bestfin-recovery-v1") → hex string stored on server
  // Allows the server to verify a recovery attempt without knowing the master key.
  static Future<String> computeRecoveryVerifier(List<int> masterKey) async {
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      utf8.encode('bestfin-recovery-v1'),
      secretKey: SecretKey(masterKey),
    );
    return base64Url.encode(mac.bytes);
  }

  // Wrap masterKey with KEK using AES-256-GCM → base64url blob
  static Future<String> encryptMasterKey(
    SecretKey kek,
    List<int> masterKey,
  ) async {
    final box = await _aesGcm.encrypt(masterKey, secretKey: kek);
    return _encodeBox(box);
  }

  // Unwrap masterKey using KEK
  static Future<Uint8List> decryptMasterKey(
    SecretKey kek,
    String encryptedBlob,
  ) async {
    final box = _decodeBox(encryptedBlob);
    final plaintext = await _aesGcm.decrypt(box, secretKey: kek);
    return Uint8List.fromList(plaintext);
  }

  // Encrypt a sync payload string with the master key → base64url blob
  static Future<String> encryptPayload(
    List<int> masterKey,
    String plaintext,
  ) async {
    final key = SecretKey(masterKey);
    final box = await _aesGcm.encrypt(utf8.encode(plaintext), secretKey: key);
    return _encodeBox(box);
  }

  // Decrypt a sync payload blob with the master key → plaintext string
  static Future<String> decryptPayload(
    List<int> masterKey,
    String encryptedBlob,
  ) async {
    final key = SecretKey(masterKey);
    final box = _decodeBox(encryptedBlob);
    final plaintext = await _aesGcm.decrypt(box, secretKey: key);
    return utf8.decode(plaintext);
  }

  // Encode 32-byte master key as a BIP39 24-word mnemonic
  static String masterKeyToMnemonic(List<int> masterKey) {
    assert(masterKey.length == 32, 'masterKey must be 32 bytes');
    final entropyHex = masterKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return bip39.entropyToMnemonic(entropyHex);
  }

  // Decode a BIP39 24-word mnemonic back to the 32-byte master key
  static Uint8List mnemonicToMasterKey(String mnemonic) {
    final entropyHex = bip39.mnemonicToEntropy(mnemonic.trim().toLowerCase());
    final bytes = Uint8List(entropyHex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(entropyHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  // HKDF-SHA256(masterKey, salt="bestfin-nostr-v1") → 32-byte secp256k1 scalar
  // Returns the Nostr private key as a 64-char hex string.
  static Future<String> deriveNostrPrivkey(List<int> masterKey) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(masterKey),
      nonce: utf8.encode('bestfin-nostr-v1'),
      info: utf8.encode('nostr'),
    );
    final bytes = await derived.extractBytes();
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // Given a Nostr private key hex, return the corresponding public key hex.
  static String nostrPubkeyFromPrivkey(String privkeyHex) {
    return bip340.getPublicKey(privkeyHex);
  }

  // Generate a new masterKey and return both the mnemonic and masterKey bytes.
  static ({String mnemonic, Uint8List masterKey}) generateIdentity() {
    final masterKey = generateMasterKey();
    final mnemonic = masterKeyToMnemonic(masterKey);
    return (mnemonic: mnemonic, masterKey: masterKey);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static String _encodeBox(SecretBox box) {
    final nonce = Uint8List.fromList(box.nonce);
    final ciphertext = Uint8List.fromList(box.cipherText);
    final mac = Uint8List.fromList(box.mac.bytes);
    final combined = Uint8List(nonce.length + ciphertext.length + mac.length);
    combined.setRange(0, nonce.length, nonce);
    combined.setRange(
      nonce.length,
      nonce.length + ciphertext.length,
      ciphertext,
    );
    combined.setRange(nonce.length + ciphertext.length, combined.length, mac);
    return base64Url.encode(combined);
  }

  static SecretBox _decodeBox(String encoded) {
    final combined = base64Url.decode(encoded);
    const nonceLen = 12;
    const macLen = 16;
    final nonce = combined.sublist(0, nonceLen);
    final mac = combined.sublist(combined.length - macLen);
    final ciphertext = combined.sublist(nonceLen, combined.length - macLen);
    return SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));
  }
}

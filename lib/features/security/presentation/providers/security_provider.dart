import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const kPinKey = 'security_pin';
const _pinVersion = 'pin_v2';
const _pinIterations = 120000;

bool initialIsLocked = false;

class IsLockedNotifier extends Notifier<bool> {
  @override
  bool build() => initialIsLocked;

  void lock() => state = true;
  void unlock() => state = false;
}

final isLockedProvider = NotifierProvider<IsLockedNotifier, bool>(
  IsLockedNotifier.new,
);

class SecurityActions {
  static const _storage = FlutterSecureStorage();
  static final Random _secureRandom = Random.secure();

  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: kPinKey);
    return pin != null && pin.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    final salt = _randomBytes(16);
    final hash = _pbkdf2(pin, salt, _pinIterations, 32);
    final encoded =
        '$_pinVersion:$_pinIterations:${base64Encode(salt)}:${base64Encode(hash)}';
    await _storage.write(key: kPinKey, value: encoded);
  }

  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: kPinKey);
    if (stored == null || stored.isEmpty) return false;

    final parts = stored.split(':');
    if (parts.length == 4 && parts[0] == _pinVersion) {
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 100000) return false;
      final salt = base64Decode(parts[2]);
      final expected = base64Decode(parts[3]);
      final actual = _pbkdf2(pin, salt, iterations, expected.length);
      return _constantTimeEquals(actual, expected);
    }

    // One-time migration path for devices that already stored a plain PIN.
    if (stored == pin) {
      await setPin(pin);
      return true;
    }
    return false;
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: kPinKey);
  }

  static Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _secureRandom.nextInt(256)),
    );
  }

  static Uint8List _pbkdf2(
    String pin,
    List<int> salt,
    int iterations,
    int length,
  ) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    final blocks = <int>[];
    var blockIndex = 1;
    while (blocks.length < length) {
      final blockSalt = Uint8List(salt.length + 4)..setAll(0, salt);
      blockSalt.buffer.asByteData().setUint32(salt.length, blockIndex);
      var u = hmac.convert(blockSalt).bytes;
      final output = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < output.length; j++) {
          output[j] ^= u[j];
        }
      }
      blocks.addAll(output);
      blockIndex++;
    }
    return Uint8List.fromList(blocks.take(length).toList());
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

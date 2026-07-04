import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const kPinKey = 'security_pin';
const _pinVersion = 'pin_v2';
const _pinIterations = 120000;

const _failedAttemptsKey = 'security_pin_failed_attempts';
const _lockedUntilKey = 'security_pin_locked_until';
// First 3 attempts are free; each failure after that doubles the lockout,
// capped at 30 minutes, to make PIN brute-forcing impractical.
const _freeAttempts = 3;
const _maxLockoutSeconds = 30 * 60;

enum PinVerifyStatus { success, invalidPin, lockedOut }

class PinVerifyResult {
  const PinVerifyResult(this.status, [this.lockedUntil]);

  final PinVerifyStatus status;
  final DateTime? lockedUntil;
}

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
    await _resetFailedAttempts();
  }

  /// Returns the lockout expiry if a PIN lockout is currently active, or
  /// null if attempts are allowed. Clears an expired lockout as a side effect.
  static Future<DateTime?> pinLockedUntil() async {
    final stored = await _storage.read(key: _lockedUntilKey);
    if (stored == null) return null;
    final ms = int.tryParse(stored);
    if (ms == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    if (until.isAfter(DateTime.now())) return until;
    await _resetFailedAttempts();
    return null;
  }

  /// Verifies a PIN with brute-force throttling: after [_freeAttempts]
  /// failures, the account is locked out for an exponentially increasing
  /// duration (capped at [_maxLockoutSeconds]).
  static Future<PinVerifyResult> verifyPinAttempt(String pin) async {
    final lockedUntil = await pinLockedUntil();
    if (lockedUntil != null) {
      return PinVerifyResult(PinVerifyStatus.lockedOut, lockedUntil);
    }

    final ok = await verifyPin(pin);
    if (ok) {
      await _resetFailedAttempts();
      return const PinVerifyResult(PinVerifyStatus.success);
    }

    final attempts = await _incrementFailedAttempts();
    if (attempts >= _freeAttempts) {
      final lockSeconds = min(
        30 * pow(2, attempts - _freeAttempts).toInt(),
        _maxLockoutSeconds,
      );
      final until = DateTime.now().add(Duration(seconds: lockSeconds));
      await _storage.write(
        key: _lockedUntilKey,
        value: until.millisecondsSinceEpoch.toString(),
      );
      return PinVerifyResult(PinVerifyStatus.lockedOut, until);
    }
    return const PinVerifyResult(PinVerifyStatus.invalidPin);
  }

  static Future<int> _incrementFailedAttempts() async {
    final stored = await _storage.read(key: _failedAttemptsKey);
    final attempts = (int.tryParse(stored ?? '') ?? 0) + 1;
    await _storage.write(key: _failedAttemptsKey, value: attempts.toString());
    return attempts;
  }

  static Future<void> _resetFailedAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockedUntilKey);
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

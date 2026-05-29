import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const kPinKey = 'security_pin';

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

  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: kPinKey);
    return pin != null && pin.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    await _storage.write(key: kPinKey, value: pin);
  }

  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: kPinKey);
    return stored == pin;
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: kPinKey);
  }
}

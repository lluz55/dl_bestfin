import 'dart:io';

import 'package:flutter/services.dart';

/// Toggles Android's FLAG_SECURE on the app window, blocking screenshots,
/// screen recording, and the recents-list thumbnail. Use around screens
/// that display secrets (recovery phrases, keys, QR codes with key material).
class SecureScreen {
  static const _channel = MethodChannel('com.bestfin.bestfin/secure_screen');

  static Future<void> enable() => _set(true);

  static Future<void> disable() => _set(false);

  static Future<void> _set(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setSecureScreen', {'enabled': enabled});
    } on PlatformException {
      // Best-effort protection; ignore if the platform call fails.
    } on MissingPluginException {
      // Ignore on platforms/builds without the native handler.
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls Android's WindowManager.LayoutParams.FLAG_SECURE and
/// setRecentsScreenshotEnabled (Android 13+), blocking screenshots,
/// screen recording, and hiding/masking the recents-list preview thumbnail.
class SecureScreen {
  static const _channel = MethodChannel('com.bestfin.bestfin/secure_screen');
  static bool _globalEnabled = false;
  static int _temporaryScreenCount = 0;

  @visibleForTesting
  static bool get isGloballyEnabled => _globalEnabled;

  @visibleForTesting
  static int get temporaryScreenCount => _temporaryScreenCount;

  /// Enables or disables secure screen protection globally (e.g. from user settings).
  static Future<void> setGlobalEnabled(bool enabled) async {
    _globalEnabled = enabled;
    await _updateNative();
  }

  /// Temporarily enables secure screen protection (e.g. while displaying a sensitive screen).
  static Future<void> enable() async {
    _temporaryScreenCount++;
    await _updateNative();
  }

  /// Decrements temporary screen protection counter.
  static Future<void> disable() async {
    if (_temporaryScreenCount > 0) {
      _temporaryScreenCount--;
    }
    await _updateNative();
  }

  /// Resets state for testing purposes.
  @visibleForTesting
  static void resetForTesting() {
    _globalEnabled = false;
    _temporaryScreenCount = 0;
  }

  static Future<void> _updateNative() async {
    final shouldBeSecure = _globalEnabled || _temporaryScreenCount > 0;
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setSecureScreen', {'enabled': shouldBeSecure});
    } on PlatformException {
      // Best-effort protection; ignore if the platform call fails.
    } on MissingPluginException {
      // Ignore on platforms/builds without the native handler.
    }
  }
}


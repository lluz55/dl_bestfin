import 'package:flutter/services.dart';

/// Copies sensitive text (recovery phrases, keys) to the clipboard and
/// automatically clears it after a delay, so it doesn't linger in the
/// system clipboard (and any clipboard-sync/history feature) indefinitely.
class SecureClipboard {
  static Future<void> copyTemporarily(
    String text, {
    Duration clearAfter = const Duration(seconds: 30),
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    Future.delayed(clearAfter, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }
}

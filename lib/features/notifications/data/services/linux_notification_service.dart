import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bestfin/core/utils/notification_parser.dart';
import 'package:bestfin/features/notifications/domain/models/transaction_suggestion.dart';

/// Captures notifications on Linux via gdbus monitoring org.freedesktop.Notifications.
class LinuxNotificationService {
  Process? _process;
  StreamController<TransactionSuggestion>? _controller;
  StreamSubscription? _subscription;

  static final _bankKeywords = RegExp(
    r'nubank|banco inter|ita[uú]|bradesco|banco do brasil|c6 bank|picpay',
    caseSensitive: false,
  );

  Stream<TransactionSuggestion> get suggestionStream {
    _controller ??= StreamController<TransactionSuggestion>.broadcast();
    return _controller!.stream;
  }

  Future<bool> isSupported() async {
    try {
      final result = await Process.run('which', ['gdbus']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> startListening() async {
    _controller ??= StreamController<TransactionSuggestion>.broadcast();
    try {
      _process = await Process.start('gdbus', [
        'monitor',
        '--session',
        '--dest',
        'org.freedesktop.Notifications',
        '--object-path',
        '/org/freedesktop/Notifications',
      ]);

      _subscription = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_processLine, onError: (_) {});
    } catch (_) {
      // gdbus not available — silently skip
    }
  }

  void _processLine(String line) {
    if (!_bankKeywords.hasMatch(line)) return;
    final parsed = NotificationParser.parse('linux', '', line);
    if (!parsed.isValid) return;

    _controller?.add(
      TransactionSuggestion(
        packageName: 'linux',
        rawTitle: '',
        rawContent: line,
        amountInCents: parsed.amountInCents!,
        merchant: parsed.merchant,
        capturedAt: DateTime.now(),
      ),
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _process?.kill();
    _process = null;
  }

  void dispose() {
    stopListening();
    _controller?.close();
    _controller = null;
  }
}

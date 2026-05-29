import 'dart:async';
import 'dart:io';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:bestfin/core/utils/notification_parser.dart';
import 'package:bestfin/features/notifications/domain/models/transaction_suggestion.dart';

class AndroidNotificationService {
  StreamController<TransactionSuggestion>? _controller;
  StreamSubscription? _subscription;

  Stream<TransactionSuggestion> get suggestionStream {
    _controller ??= StreamController<TransactionSuggestion>.broadcast();
    return _controller!.stream;
  }

  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await NotificationListenerService.requestPermission();
    } catch (_) {}
  }

  Future<void> startListening(List<String> watchedPackages) async {
    if (!Platform.isAndroid) return;
    _controller ??= StreamController<TransactionSuggestion>.broadcast();

    try {
      _subscription = NotificationListenerService.notificationsStream.listen((
        event,
      ) {
        final packageName = event.packageName ?? '';
        if (watchedPackages.isNotEmpty &&
            !watchedPackages.any((p) => packageName.startsWith(p))) {
          return;
        }

        final title = event.title ?? '';
        final content = event.content ?? '';
        final parsed = NotificationParser.parse(packageName, title, content);
        if (!parsed.isValid) return;

        _controller?.add(
          TransactionSuggestion(
            packageName: packageName,
            rawTitle: title,
            rawContent: content,
            amountInCents: parsed.amountInCents!,
            merchant: parsed.merchant,
            capturedAt: DateTime.now(),
          ),
        );
      }, onError: (_) {});
    } catch (_) {}
  }

  void dispose() {
    _subscription?.cancel();
    _controller?.close();
    _controller = null;
  }
}

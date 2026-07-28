import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/utils/secure_screen.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final methodCalls = <MethodCall>[];

  setUp(() {
    methodCalls.clear();
    SecureScreen.resetForTesting();
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.bestfin.bestfin/secure_screen'),
          (call) async {
            methodCalls.add(call);
            return null;
          },
        );
  });


  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.bestfin.bestfin/secure_screen'),
          null,
        );
  });

  test('SecureScreen tracks global enabled state correctly', () async {
    expect(SecureScreen.isGloballyEnabled, isFalse);

    await SecureScreen.setGlobalEnabled(true);
    expect(SecureScreen.isGloballyEnabled, isTrue);

    await SecureScreen.setGlobalEnabled(false);
    expect(SecureScreen.isGloballyEnabled, isFalse);
  });

  test('SecureScreen tracks temporary screen reference count', () async {
    expect(SecureScreen.temporaryScreenCount, 0);

    await SecureScreen.enable();
    expect(SecureScreen.temporaryScreenCount, 1);

    await SecureScreen.enable();
    expect(SecureScreen.temporaryScreenCount, 2);

    await SecureScreen.disable();
    expect(SecureScreen.temporaryScreenCount, 1);

    await SecureScreen.disable();
    expect(SecureScreen.temporaryScreenCount, 0);

    // Further calls to disable do not drop below zero
    await SecureScreen.disable();
    expect(SecureScreen.temporaryScreenCount, 0);
  });

  test('hideRecentsPreviewProvider updates global SecureScreen state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(hideRecentsPreviewProvider), isTrue);

    await container.read(hideRecentsPreviewProvider.notifier).set(false);
    expect(container.read(hideRecentsPreviewProvider), isFalse);
    expect(SecureScreen.isGloballyEnabled, isFalse);

    await container.read(hideRecentsPreviewProvider.notifier).set(true);
    expect(container.read(hideRecentsPreviewProvider), isTrue);
    expect(SecureScreen.isGloballyEnabled, isTrue);
  });

}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:bestfin/features/security/presentation/providers/security_provider.dart';
import 'package:bestfin/features/security/presentation/screens/app_lock_screen.dart';
import 'package:bestfin/features/security/presentation/widgets/lock_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // AppLockScreen consulta o lockout do PIN via flutter_secure_storage no
    // initState; sem o mock o canal lança MissingPluginException não tratada.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  testWidgets(
    'bloquear mantém o Navigator montado e preserva a pilha de rotas',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navKey,
            builder: (context, child) =>
                LockOverlay(child: child ?? const SizedBox()),
            home: const Scaffold(body: Text('home')),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.text('home')),
      );
      container.read(biometricsEnabledProvider.notifier).set(true);

      // Empurra uma rota e bloqueia no mesmo frame — a implementação antiga
      // (AnimatedSwitcher trocando a subárvore inteira) descartava o
      // Navigator aqui, disparando o assert `!_debugLocked` no dispose
      // quando havia navegação em andamento.
      unawaited(
        navKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('detalhe')),
          ),
        ),
      );
      container.read(isLockedProvider.notifier).lock();
      await tester.pump();
      // Fade do AnimatedSwitcher + _authenticate adiado do AppLockScreen.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AppLockScreen), findsOneWidget);
      expect(
        navKey.currentState,
        isNotNull,
        reason: 'o Navigator deve continuar montado atrás do lock',
      );
      expect(find.text('detalhe', skipOffstage: false), findsOneWidget);

      container.read(isLockedProvider.notifier).unlock();
      await tester.pumpAndSettle();

      expect(find.byType(AppLockScreen), findsNothing);
      expect(
        find.text('detalhe'),
        findsOneWidget,
        reason: 'a pilha de rotas deve sobreviver ao ciclo lock/unlock',
      );
    },
  );

  testWidgets('conteúdo do app não recebe toques enquanto bloqueado', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) =>
              LockOverlay(child: child ?? const SizedBox()),
          home: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('acao'),
              ),
            ),
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.text('acao')),
    );
    container.read(biometricsEnabledProvider.notifier).set(true);
    container.read(isLockedProvider.notifier).lock();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(
      find.text('acao', skipOffstage: false),
      warnIfMissed: false,
    );
    expect(taps, 0);
  });
}

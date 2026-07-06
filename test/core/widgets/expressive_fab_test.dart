import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bestfin/core/theme/app_theme.dart';
import 'package:bestfin/core/widgets/expressive_fab.dart';

Widget _wrap(Widget fab) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(floatingActionButton: fab),
  );
}

void main() {
  group('ExpressiveFAB', () {
    testWidgets('.extended dispara onPressed no primeiro toque', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _wrap(
          ExpressiveFAB.extended(
            onPressed: () => pressed++,
            icon: Icons.add_rounded,
            label: 'Nova Conta',
          ),
        ),
      );
      // Aguarda a animação de entrada.
      await tester.pumpAndSettle();

      expect(find.text('Nova Conta'), findsOneWidget);
      await tester.tap(find.byType(ExpressiveFAB));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('modo confirm expande no primeiro toque e dispara no segundo', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _wrap(
          ExpressiveFAB(onPressed: () => pressed++, label: 'Nova transação'),
        ),
      );
      await tester.pumpAndSettle();

      // Colapsado: sem label visível.
      expect(find.text('Nova transação'), findsNothing);

      // 1º toque: expande sem disparar.
      await tester.tap(find.byType(ExpressiveFAB));
      await tester.pumpAndSettle();
      expect(pressed, 0);
      expect(find.text('Nova transação'), findsOneWidget);

      // 2º toque: dispara.
      await tester.tap(find.byType(ExpressiveFAB));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('long-press dispara imediatamente', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(_wrap(ExpressiveFAB(onPressed: () => pressed++)));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(ExpressiveFAB));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bestfin/core/theme/app_theme.dart';
import 'package:bestfin/core/theme/dimens.dart';
import 'package:bestfin/core/widgets/app_button.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('variante primary renderiza FilledButton', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Salvar', onPressed: () {})),
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('variante outlined renderiza OutlinedButton', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.outlined,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('variante text renderiza TextButton', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppButton(
            label: 'Voltar',
            variant: AppButtonVariant.text,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('variante destructive usa cor de erro do tema', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppButton(
            label: 'Excluir',
            variant: AppButtonVariant.destructive,
            onPressed: () {},
          ),
        ),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final context = tester.element(find.byType(FilledButton));
      final cs = Theme.of(context).colorScheme;
      expect(button.style?.backgroundColor?.resolve({}), cs.error);
    });

    testWidgets('loading mostra spinner e desabilita o botão', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AppButton(
            label: 'Salvar',
            loading: true,
            onPressed: () => tapped = true,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Salvar'), findsNothing);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('expanded ocupa toda a largura disponível', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            child: AppButton(label: 'Salvar', expanded: true, onPressed: () {}),
          ),
        ),
      );
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.width, 300);
      expect(size.height, AppDimens.buttonHeight);
    });

    testWidgets('size compact usa altura compacta', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppButton(
            label: 'Ok',
            size: AppButtonSize.compact,
            expanded: true,
            onPressed: () {},
          ),
        ),
      );
      // O box do botão inclui o padding invisível do alvo de toque (48);
      // a altura visual é a do Material interno.
      final size = tester.getSize(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        ),
      );
      expect(size.height, AppDimens.buttonHeightCompact);
    });

    testWidgets('icon renderiza o construtor .icon com Icon', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Adicionar', icon: Icons.add, onPressed: () {})),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('onPressed null desabilita o botão', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'Salvar', onPressed: null)),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });
}

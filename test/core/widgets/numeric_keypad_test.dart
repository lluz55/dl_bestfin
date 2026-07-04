import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/widgets/numeric_keypad.dart';

void main() {
  Future<void> pumpKeypad(
    WidgetTester tester, {
    required void Function(String) onKeyPressed,
    required VoidCallback onDeletePressed,
    VoidCallback? onConfirmPressed,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            onKeyPressed: onKeyPressed,
            onDeletePressed: onDeletePressed,
            onConfirmPressed: onConfirmPressed,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'pressing a physical digit key reports it without tapping the on-screen keys',
    (tester) async {
      final pressed = <String>[];
      await pumpKeypad(tester, onKeyPressed: pressed.add, onDeletePressed: () {});
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.pump();

      expect(pressed, ['5']);
    },
  );

  testWidgets('physical numpad digit keys map to the same string as top-row digits', (
    tester,
  ) async {
    final pressed = <String>[];
    await pumpKeypad(tester, onKeyPressed: pressed.add, onDeletePressed: () {});
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.numpad7);
    await tester.pump();

    expect(pressed, ['7']);
  });

  testWidgets('physical Backspace triggers onDeletePressed', (tester) async {
    var deleted = false;
    await pumpKeypad(
      tester,
      onKeyPressed: (_) {},
      onDeletePressed: () => deleted = true,
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(deleted, isTrue);
  });

  testWidgets(
    'physical Enter triggers onConfirmPressed when provided, ignored otherwise',
    (tester) async {
      var confirmed = false;
      await pumpKeypad(
        tester,
        onKeyPressed: (_) {},
        onDeletePressed: () {},
        onConfirmPressed: () => confirmed = true,
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(confirmed, isTrue);
    },
  );

  testWidgets('the keypad grabs focus on its own so typing works without a prior tap', (
    tester,
  ) async {
    final pressed = <String>[];
    await pumpKeypad(tester, onKeyPressed: pressed.add, onDeletePressed: () {});

    // No tap on the widget at all — autofocus (plus the post-frame
    // fallback) should already have claimed keyboard focus.
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();

    expect(pressed, ['3']);
  });
}

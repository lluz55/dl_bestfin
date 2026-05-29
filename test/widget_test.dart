import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';
import 'package:bestfin/main.dart';

void main() {
  testWidgets('App inicia sem erros', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BestFinApp()));
    expect(find.byType(MaterialApp), findsOneWidget);

    // Cancel pending auto-sync timers so the widget test can finish without leaks
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BestFinApp)),
    );
    container.read(syncServiceProvider).stopAutoSync();

    // Settle all remaining microtasks, routing transitions and schedules
    await tester.pumpAndSettle();
  });
}

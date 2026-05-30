import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/features/dashboard/domain/models/app_shortcut.dart';

final shortcutsProvider =
    AsyncNotifierProvider<ShortcutsNotifier, List<AppShortcut>>(
      ShortcutsNotifier.new,
    );

class ShortcutsNotifier extends AsyncNotifier<List<AppShortcut>> {
  static const _shortcutsKey = 'dashboard_shortcuts';

  // Default shortcuts if none are saved
  static const _defaultShortcuts = [
    AppShortcut.accounts,
    AppShortcut.categories,
    AppShortcut.creditCards,
    AppShortcut.recurring,
  ];

  @override
  Future<List<AppShortcut>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList(_shortcutsKey);

    if (savedIds == null || savedIds.isEmpty) {
      return _defaultShortcuts;
    }

    final shortcuts = savedIds
        .map((id) => AppShortcut.fromId(id))
        .whereType<AppShortcut>()
        .toList();

    return shortcuts.isEmpty ? _defaultShortcuts : shortcuts;
  }

  Future<void> saveShortcuts(List<AppShortcut> newShortcuts) async {
    // Limit to 4 shortcuts
    final limitedShortcuts = newShortcuts.take(4).toList();

    // Optimistic update
    state = AsyncData(limitedShortcuts);

    final prefs = await SharedPreferences.getInstance();
    final ids = limitedShortcuts.map((s) => s.id).toList();
    await prefs.setStringList(_shortcutsKey, ids);
  }
}

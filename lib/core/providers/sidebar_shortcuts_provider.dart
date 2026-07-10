import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/shell/nav_shortcut.dart';

/// Atalhos que o usuário fixou na barra lateral (abaixo das abas principais,
/// após um separador).
///
/// Persistidos na tabela `AppSettings` do Drift (chave/valor) — e não em
/// `SharedPreferences` — para que façam parte do backup/restauração de dados
/// (o export JSON inclui `app_settings`). Como o provider observa o
/// `databaseProvider`, ele é reconstruído automaticamente após uma restauração
/// ou limpeza (que invalidam o banco), refletindo o estado restaurado.
const kSidebarShortcutsKey = 'sidebar_shortcuts';

final sidebarShortcutsProvider =
    AsyncNotifierProvider<SidebarShortcutsNotifier, List<NavShortcut>>(
      SidebarShortcutsNotifier.new,
    );

class SidebarShortcutsNotifier extends AsyncNotifier<List<NavShortcut>> {
  @override
  Future<List<NavShortcut>> build() async {
    final db = ref.watch(databaseProvider);
    final row = await (db.select(
      db.appSettings,
    )..where((t) => t.key.equals(kSidebarShortcutsKey))).getSingleOrNull();

    final raw = row?.value ?? '';
    if (raw.isEmpty) return const [];

    return raw
        .split(',')
        .map(NavShortcut.fromId)
        .whereType<NavShortcut>()
        .toList();
  }

  Future<void> save(List<NavShortcut> shortcuts) async {
    // Preserva a ordem do catálogo para consistência visual.
    final ordered = NavShortcut.values.where(shortcuts.contains).toList();

    state = AsyncData(ordered);

    final db = ref.read(databaseProvider);
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(kSidebarShortcutsKey),
            value: Value(ordered.map((s) => s.id).join(',')),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> remove(NavShortcut shortcut) async {
    final current = state.value ?? const [];
    await save(current.where((s) => s != shortcut).toList());
  }
}

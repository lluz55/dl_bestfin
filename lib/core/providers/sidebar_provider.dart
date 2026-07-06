import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kSidebarCollapsedKey = 'sidebar_collapsed';

bool initialSidebarCollapsed = false;

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() {
    return initialSidebarCollapsed;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kSidebarCollapsedKey, state);
  }

  Future<void> setCollapsed(bool collapsed) async {
    state = collapsed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kSidebarCollapsedKey, collapsed);
  }
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
      SidebarCollapsedNotifier.new,
    );

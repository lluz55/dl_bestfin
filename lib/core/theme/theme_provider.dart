import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyThemeMode = 'theme_mode';
const _keyDynamicColor = 'dynamic_color';

class ThemeState {
  const ThemeState({
    this.mode = ThemeMode.system,
    this.useDynamicColor = false,
  });

  final ThemeMode mode;
  final bool useDynamicColor;

  ThemeState copyWith({ThemeMode? mode, bool? useDynamicColor}) {
    return ThemeState(
      mode: mode ?? this.mode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    _load();
    return const ThemeState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    final dynamic_ = prefs.getBool(_keyDynamicColor) ?? false;
    state = ThemeState(
      mode: ThemeMode.values[modeIndex],
      useDynamicColor: dynamic_,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<void> setDynamicColor(bool value) async {
    state = state.copyWith(useDynamicColor: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDynamicColor, value);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_presets.dart';

const _keyThemeMode = 'theme_mode';
const _keyDynamicColor = 'dynamic_color';
const _keyPreset = 'theme_preset';

class ThemeState {
  const ThemeState({
    this.mode = ThemeMode.system,
    this.useDynamicColor = false,
    this.preset = ThemePreset.indigo,
  });

  final ThemeMode mode;
  final bool useDynamicColor;
  final ThemePreset preset;

  ThemeState copyWith({
    ThemeMode? mode,
    bool? useDynamicColor,
    ThemePreset? preset,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      preset: preset ?? this.preset,
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
    final presetIndex = prefs.getInt(_keyPreset) ?? 0;
    state = ThemeState(
      mode: ThemeMode.values[modeIndex],
      useDynamicColor: dynamic_,
      preset: ThemePreset
          .values[presetIndex.clamp(0, ThemePreset.values.length - 1)],
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

  Future<void> setPreset(ThemePreset preset) async {
    state = state.copyWith(preset: preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPreset, preset.index);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);

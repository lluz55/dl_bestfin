import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyCustomSeed = 'custom_seed_color';
const _keyUseCustomSeed = 'use_custom_seed';

class CustomSeedState {
  const CustomSeedState({this.useCustomSeed = false, this.seedColor});

  final bool useCustomSeed;
  final Color? seedColor;

  CustomSeedState copyWith({
    bool? useCustomSeed,
    Color? seedColor,
    bool clearSeed = false,
  }) {
    return CustomSeedState(
      useCustomSeed: useCustomSeed ?? this.useCustomSeed,
      seedColor: clearSeed ? null : (seedColor ?? this.seedColor),
    );
  }
}

class CustomSeedNotifier extends Notifier<CustomSeedState> {
  @override
  CustomSeedState build() {
    _load();
    return const CustomSeedState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final useCustom = prefs.getBool(_keyUseCustomSeed) ?? false;
    final seedValue = prefs.getInt(_keyCustomSeed);
    final seed = seedValue != null ? Color(seedValue) : null;
    state = CustomSeedState(useCustomSeed: useCustom, seedColor: seed);
  }

  Future<void> setUseCustomSeed(bool value) async {
    state = state.copyWith(useCustomSeed: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseCustomSeed, value);
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color, useCustomSeed: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomSeed, color.value);
    await prefs.setBool(_keyUseCustomSeed, true);
  }

  ColorScheme generateLightScheme() {
    final seed = state.seedColor ?? const Color(0xFF3D5AFE);
    return ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
  }

  ColorScheme generateDarkScheme() {
    final seed = state.seedColor ?? const Color(0xFF3D5AFE);
    return ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
  }
}

final customSeedProvider =
    NotifierProvider<CustomSeedNotifier, CustomSeedState>(
      CustomSeedNotifier.new,
    );

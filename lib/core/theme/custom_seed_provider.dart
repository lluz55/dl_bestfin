import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyCustomSeed = 'custom_seed_color';

/// Seed padrão quando o usuário ainda não escolheu uma cor personalizada.
const kDefaultSeedColor = Color(0xFF3D5AFE);

class CustomSeedState {
  const CustomSeedState({this.seedColor});

  final Color? seedColor;

  /// Cor efetiva usada para gerar o esquema quando a cor dinâmica está off.
  Color get effectiveSeed => seedColor ?? kDefaultSeedColor;
}

class CustomSeedNotifier extends Notifier<CustomSeedState> {
  @override
  CustomSeedState build() {
    _load();
    return const CustomSeedState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final seedValue = prefs.getInt(_keyCustomSeed);
    final seed = seedValue != null ? Color(seedValue) : null;
    state = CustomSeedState(seedColor: seed);
  }

  Future<void> setSeedColor(Color color) async {
    state = CustomSeedState(seedColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomSeed, color.toARGB32());
  }

  ColorScheme generateLightScheme() {
    return ColorScheme.fromSeed(
      seedColor: state.effectiveSeed,
      brightness: Brightness.light,
    );
  }

  ColorScheme generateDarkScheme() {
    return ColorScheme.fromSeed(
      seedColor: state.effectiveSeed,
      brightness: Brightness.dark,
    );
  }
}

final customSeedProvider =
    NotifierProvider<CustomSeedNotifier, CustomSeedState>(
      CustomSeedNotifier.new,
    );

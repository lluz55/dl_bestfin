import 'package:flutter/material.dart';

enum ThemePreset {
  indigo(label: 'Índigo', seed: Color(0xFF3D5AFE)),
  esmeralda(label: 'Esmeralda', seed: Color(0xFF00897B)),
  oceano(label: 'Oceano', seed: Color(0xFF0277BD)),
  violeta(label: 'Violeta', seed: Color(0xFF7C4DFF)),
  rosa(label: 'Rosa', seed: Color(0xFFE91E63)),
  coral(label: 'Coral', seed: Color(0xFFE53935)),
  ambar(label: 'Âmbar', seed: Color(0xFFFFA000)),
  granito(label: 'Granito', seed: Color(0xFF546E7A)),
  laranja(label: 'Laranja', seed: Color(0xFFFF6D00)),
  menta(label: 'Menta', seed: Color(0xFF43A047)),
  lilas(label: 'Lilás', seed: Color(0xFF7B1FA2)),
  ciano(label: 'Ciano', seed: Color(0xFF0097A7)),
  marrom(label: 'Marrom', seed: Color(0xFF6D4C41)),
  limao(label: 'Limão', seed: Color(0xFF9E9D24));

  const ThemePreset({required this.label, required this.seed});

  final String label;
  final Color seed;

  ColorScheme light() =>
      ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

  ColorScheme dark() =>
      ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
}

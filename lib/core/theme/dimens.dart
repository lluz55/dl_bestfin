import 'package:flutter/material.dart';

/// Dimensões padronizadas de componentes interativos.
///
/// Fonte única para alturas de botões e alvos de toque — os raios de
/// borda continuam em [ExpressiveShapes] (`lib/core/theme/shapes.dart`).
abstract final class AppDimens {
  /// Altura padrão de botões de ação primária (forms, CTAs).
  static const double buttonHeight = 52;

  /// Altura compacta (dialogs, linhas densas, ações secundárias inline).
  static const double buttonHeightCompact = 44;

  /// Altura do FAB (deve casar com o ExpressiveFAB).
  static const double fabHeight = 56;

  /// Alvo de toque mínimo para IconButton.
  static const double minTapTarget = 44;

  /// Tamanho mínimo de botões padrão (Filled/Elevated/Outlined).
  static const Size buttonMinSize = Size(64, buttonHeight);

  /// Tamanho mínimo de botões compactos (TextButton, ações de dialog).
  static const Size buttonMinSizeCompact = Size(48, buttonHeightCompact);
}

import 'package:flutter/material.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/dimens.dart';

/// Variante semântica do [AppButton].
enum AppButtonVariant {
  /// Ação primária — FilledButton com cor primária do tema.
  primary,

  /// Ação secundária de destaque — FilledButton.tonal.
  tonal,

  /// Ação secundária — OutlinedButton.
  outlined,

  /// Ação leve (dialogs, links) — TextButton.
  text,

  /// Ação destrutiva confirmada — FilledButton com cor de erro.
  destructive,

  /// Ação destrutiva secundária — OutlinedButton com cor de erro.
  destructiveOutlined,
}

/// Tamanho do [AppButton].
enum AppButtonSize {
  /// Altura padrão de ação primária ([AppDimens.buttonHeight]).
  standard,

  /// Altura compacta para dialogs e linhas densas
  /// ([AppDimens.buttonHeightCompact]).
  compact,
}

/// Botão padronizado do app.
///
/// Delega para os botões Material ([FilledButton], [OutlinedButton],
/// [TextButton]) mantendo o [ThemeData] como fonte única de shape e altura —
/// este widget apenas adiciona semântica (variante, loading, largura total,
/// cor de domínio). Nunca sobrescreve o shape do tema.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.standard,
    this.expanded = false,
    this.loading = false,
    this.color,
  });

  /// Texto do botão.
  final String label;

  /// Callback de toque. `null` desabilita o botão.
  final VoidCallback? onPressed;

  /// Ícone opcional exibido antes do texto.
  final IconData? icon;

  /// Variante semântica (primária, destrutiva, etc.).
  final AppButtonVariant variant;

  /// Altura do botão.
  final AppButtonSize size;

  /// Se `true`, ocupa toda a largura disponível.
  final bool expanded;

  /// Se `true`, exibe um spinner no lugar do texto e desabilita o botão.
  final bool loading;

  /// Cor de domínio (ex: cor da meta, cor do tipo de transação).
  /// Substitui a cor de fundo nas variantes preenchidas ou a cor de
  /// destaque nas variantes outlined/text.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final style = _buildStyle(cs);
    final effectiveOnPressed = loading ? null : onPressed;
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _spinnerColor(cs),
            ),
          )
        : Text(label);
    final showIcon = icon != null && !loading;

    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.destructive:
        return showIcon
            ? FilledButton.icon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: Icon(icon),
                label: child,
              )
            : FilledButton(
                onPressed: effectiveOnPressed,
                style: style,
                child: child,
              );
      case AppButtonVariant.tonal:
        return showIcon
            ? FilledButton.tonalIcon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: Icon(icon),
                label: child,
              )
            : FilledButton.tonal(
                onPressed: effectiveOnPressed,
                style: style,
                child: child,
              );
      case AppButtonVariant.outlined:
      case AppButtonVariant.destructiveOutlined:
        return showIcon
            ? OutlinedButton.icon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: Icon(icon),
                label: child,
              )
            : OutlinedButton(
                onPressed: effectiveOnPressed,
                style: style,
                child: child,
              );
      case AppButtonVariant.text:
        return showIcon
            ? TextButton.icon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: Icon(icon),
                label: child,
              )
            : TextButton(
                onPressed: effectiveOnPressed,
                style: style,
                child: child,
              );
    }
  }

  /// Estilo por cima do tema: apenas tamanho e cores semânticas — nunca shape.
  ButtonStyle? _buildStyle(ColorScheme cs) {
    final height = size == AppButtonSize.compact
        ? AppDimens.buttonHeightCompact
        : AppDimens.buttonHeight;

    Size? minimumSize;
    if (expanded) {
      minimumSize = Size(double.infinity, height);
    } else if (size == AppButtonSize.compact) {
      minimumSize = AppDimens.buttonMinSizeCompact;
    }

    Color? background;
    Color? foreground;
    BorderSide? side;

    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.tonal:
        if (color != null) {
          background = color;
          foreground = _onColor(color!);
        }
      case AppButtonVariant.destructive:
        background = cs.error;
        foreground = cs.onError;
      case AppButtonVariant.destructiveOutlined:
        foreground = cs.error;
        side = BorderSide(color: cs.error.withValues(alpha: 0.5));
      case AppButtonVariant.outlined:
      case AppButtonVariant.text:
        if (color != null) {
          foreground = color;
        }
    }

    if (minimumSize == null &&
        background == null &&
        foreground == null &&
        side == null) {
      return null;
    }
    return ButtonStyle(
      minimumSize: minimumSize != null
          ? WidgetStatePropertyAll(minimumSize)
          : null,
      backgroundColor: background != null
          ? WidgetStatePropertyAll(background)
          : null,
      foregroundColor: foreground != null
          ? WidgetStatePropertyAll(foreground)
          : null,
      iconColor: foreground != null ? WidgetStatePropertyAll(foreground) : null,
      side: side != null ? WidgetStatePropertyAll(side) : null,
    );
  }

  Color _spinnerColor(ColorScheme cs) {
    switch (variant) {
      case AppButtonVariant.primary:
        return color != null ? _onColor(color!) : cs.onPrimary;
      case AppButtonVariant.tonal:
        return color != null ? _onColor(color!) : cs.onSecondaryContainer;
      case AppButtonVariant.destructive:
        return cs.onError;
      case AppButtonVariant.destructiveOutlined:
        return cs.error;
      case AppButtonVariant.outlined:
      case AppButtonVariant.text:
        return color ?? cs.primary;
    }
  }

  /// Cor de conteúdo legível sobre uma cor de domínio arbitrária.
  static Color _onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}

import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

/// AppBar unificado para todas as páginas do app.
/// Detecta o back button explicitamente para garantir padding e ícone consistentes.
class AppPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  /// Substitui a linha divisória padrão. Use para TabBar ou filtros customizados.
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 1.0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    // Detecta se um back button deve aparecer, para controle explícito do ícone e spacing
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final effectiveLeading = leading ??
        (automaticallyImplyLeading && canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
              )
            : null);
    final hasLeading = effectiveLeading != null;

    final effectiveBottom = bottom ??
        PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        );

    return AppBar(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: effectiveLeading,
      // 4px entre back button e título; 16px da borda quando não há leading
      titleSpacing: hasLeading ? 4 : 16,
      title: subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle!,
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
              ],
            )
          : Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      actions: actions,
      bottom: effectiveBottom,
    );
  }
}

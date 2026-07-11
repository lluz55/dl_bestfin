import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/page_info_modal.dart';

/// AppBar unificado para todas as páginas do app.
/// Detecta o back button explicitamente para garantir padding e ícone consistentes.
class AppPageAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppPageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.showVisibilityToggle = false,
    this.infoDescription,
    this.infoFeatures,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool showVisibilityToggle;

  /// Descrição exibida no modal de informações da página.
  /// Quando definida, um botão de informação é adicionado automaticamente ao header.
  final String? infoDescription;

  /// Lista opcional de funcionalidades destacadas no modal.
  final List<String>? infoFeatures;

  /// Substitui a linha divisória padrão. Use para TabBar ou filtros customizados.
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 1.0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    // Detecta se um back button deve aparecer, para controle explícito do ícone e spacing
    bool canPop = false;
    try {
      canPop = GoRouter.of(context).canPop();
    } catch (_) {}
    if (!canPop) {
      canPop = ModalRoute.of(context)?.canPop ?? false;
    }
    // Em tablets e desktop, a navegação é feita pelo sidebar — oculta a seta de voltar
    final isCompact = Breakpoints.isCompact(context);
    final effectiveLeading =
        leading ??
        (automaticallyImplyLeading && canPop && isCompact
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  try {
                    GoRouter.of(context).pop();
                  } catch (_) {
                    Navigator.maybePop(context);
                  }
                },
              )
            : null);
    final hasLeading = effectiveLeading != null;

    final effectiveBottom =
        bottom ??
        PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.6),
          ),
        );

    final hidden = ref.watch(valuesHiddenProvider);
    final List<Widget> effectiveActions = [
      if (infoDescription != null)
        PageInfoButton(
          title: title,
          description: infoDescription!,
          features: infoFeatures,
        ),
      ...?actions,
      if (showVisibilityToggle)
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              key: ValueKey(hidden),
              size: 20,
            ),
          ),
          tooltip: hidden ? 'Mostrar valores' : 'Ocultar valores',
          onPressed: () => ref.read(valuesHiddenProvider.notifier).toggle(),
        ),
    ];

    return AppBar(
      backgroundColor: cs.surface,
      surfaceTintColor: cs.primary,
      elevation: 0,
      scrolledUnderElevation: 1,
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
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            )
          : Text(
              title,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
      actions: effectiveActions,
      bottom: effectiveBottom,
    );
  }
}

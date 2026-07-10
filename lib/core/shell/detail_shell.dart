import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/shell/app_shell.dart';
import 'package:bestfin/core/shell/responsive_navigation.dart';
import 'package:bestfin/core/theme/breakpoints.dart';

/// Envolve as páginas de feature do hub "Mais" (Contas, Categorias, Orçamento,
/// etc.).
///
/// - **Mobile (compacto):** renderiza a página em tela cheia, com o próprio
///   `AppBar`/botão de voltar — comportamento inalterado.
/// - **Tablet/desktop:** mantém a barra lateral persistente e abre a página
///   apenas na área de conteúdo, ao lado da barra (respeitando o tamanho dela).
///
/// As abas da barra usam `context.go` para voltar ao shell principal; os
/// atalhos fixados também aparecem aqui, mantendo a navegação consistente.
class DetailShell extends StatelessWidget {
  const DetailShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isCompact(context)) return child;

    return ResponsiveNavigation(
      // Estas páginas pertencem ao hub "Mais"; destaca essa aba na barra.
      selectedIndex: 3,
      onDestinationSelected: (i) => context.go(AppShell.tabRoutes[i]),
      destinations: AppShell.destinations,
      body: child,
    );
  }
}

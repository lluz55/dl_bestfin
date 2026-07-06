import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:bestfin/features/security/presentation/providers/security_provider.dart';
import 'package:bestfin/features/security/presentation/screens/app_lock_screen.dart';

class LockOverlay extends ConsumerWidget {
  const LockOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = ref.watch(isLockedProvider);
    final biometricsEnabled = ref.watch(biometricsEnabledProvider);
    final showLock = isLocked && biometricsEnabled;

    // A subárvore do app (que contém todos os Navigators) precisa permanecer
    // montada durante o lock. Trocá-la pela tela de bloqueio descarta os
    // Navigators — se houver uma navegação em andamento no mesmo frame, o
    // dispose dispara o assert `!_debugLocked` — e perde todo o estado de
    // navegação ao desbloquear. A tela de bloqueio é opaca e cobre o
    // conteúdo por cima; foco, toques e semântica do app ficam bloqueados
    // enquanto o lock está ativo.
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: showLock,
          child: ExcludeSemantics(
            excluding: showLock,
            child: IgnorePointer(ignoring: showLock, child: child),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: showLock
              ? const AppLockScreen(key: ValueKey('lock'))
              : const SizedBox.shrink(key: ValueKey('unlocked')),
        ),
      ],
    );
  }
}

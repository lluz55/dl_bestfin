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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: (isLocked && biometricsEnabled)
          ? const AppLockScreen(key: ValueKey('lock'))
          : KeyedSubtree(key: const ValueKey('app'), child: child),
    );
  }
}

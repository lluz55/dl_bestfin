import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/create_account_step.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/notification_permission_step.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/security_step.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/select_categories_step.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/welcome_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  static const _totalPages = 5;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    await OnboardingActions.complete(ref);
    // Router guard will automatically navigate to /home
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PageDots(
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    activeColor: cs.primary,
                    inactiveColor: cs.surfaceContainerHighest,
                  ),
                  if (_currentPage > 0 && _currentPage < _totalPages - 1)
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Pular',
                        style: context.textTheme.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  WelcomeStep(onNext: _nextPage),
                  CreateAccountStep(onNext: _nextPage),
                  SelectCategoriesStep(onNext: _nextPage),
                  NotificationPermissionStep(onNext: _nextPage),
                  SecurityStep(onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.currentPage,
    required this.totalPages,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int currentPage;
  final int totalPages;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalPages, (i) {
        final isActive = i == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.only(right: 6),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:bestfin/features/onboarding/presentation/providers/tutorial_provider.dart';

class TutorialRunner extends ConsumerStatefulWidget {
  const TutorialRunner({
    super.key,
    required this.child,
    required this.fabKey,
    required this.maisTabKey,
    required this.customizeKey,
  });

  final Widget child;
  final GlobalKey fabKey;
  final GlobalKey maisTabKey;
  final GlobalKey customizeKey;

  @override
  ConsumerState<TutorialRunner> createState() => _TutorialRunnerState();
}

class _TutorialRunnerState extends ConsumerState<TutorialRunner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLaunch());
  }

  void _maybeLaunch() {
    if (!mounted) return;
    if (ref.read(tutorialSeenProvider)) return;
    _launch();
  }

  void _done() => TutorialActions.markSeen(ref);

  void _launch() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final targets = [
      _target(
        id: 'fab',
        key: widget.fabKey,
        shape: ShapeLightFocus.Circle,
        padding: 10,
        align: ContentAlign.top,
        title: 'Registre movimentações',
        body:
            'Toque aqui para adicionar gastos, receitas ou transferências em segundos.',
        cs: cs,
        tt: tt,
      ),
      _target(
        id: 'customize',
        key: widget.customizeKey,
        shape: ShapeLightFocus.RRect,
        padding: 6,
        align: ContentAlign.bottom,
        title: 'Personalize seu início',
        body:
            'Reorganize ou oculte os cards do dashboard para ver o que importa para você.',
        cs: cs,
        tt: tt,
      ),
      _target(
        id: 'mais_tab',
        key: widget.maisTabKey,
        shape: ShapeLightFocus.RRect,
        padding: 6,
        align: ContentAlign.top,
        title: 'Explore tudo',
        body: 'Orçamentos, metas, investimentos, IA e muito mais estão aqui.',
        cs: cs,
        tt: tt,
      ),
    ];

    final valid = targets
        .where((t) => t.keyTarget?.currentContext != null)
        .toList();

    if (valid.isEmpty) {
      _done();
      return;
    }

    TutorialCoachMark(
      targets: valid,
      colorShadow: Colors.black,
      opacityShadow: 0.72,
      textSkip: 'Pular',
      textStyleSkip: TextStyle(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      alignSkip: Alignment.topRight,
      paddingFocus: 8,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: const Duration(milliseconds: 250),
      pulseEnable: true,
      onFinish: _done,
      onSkip: () {
        _done();
        return true;
      },
    ).show(context: context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

TargetFocus _target({
  required String id,
  required GlobalKey key,
  required ShapeLightFocus shape,
  required double padding,
  required ContentAlign align,
  required String title,
  required String body,
  required ColorScheme cs,
  required TextTheme tt,
}) {
  return TargetFocus(
    identify: id,
    keyTarget: key,
    shape: shape,
    radius: 14,
    paddingFocus: padding,
    contents: [
      TargetContent(
        align: align,
        child: _TutorialCard(title: title, body: body, cs: cs, tt: tt),
      ),
    ],
  );
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    required this.title,
    required this.body,
    required this.cs,
    required this.tt,
  });

  final String title;
  final String body;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: tt.bodyMedium?.copyWith(
              color: cs.onPrimaryContainer.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

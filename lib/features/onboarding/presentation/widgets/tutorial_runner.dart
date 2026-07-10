import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:bestfin/features/onboarding/presentation/providers/tutorial_provider.dart';

class TutorialRunner extends ConsumerStatefulWidget {
  const TutorialRunner({
    super.key,
    required this.child,
    required this.fabKey,
    required this.transactionsTabKey,
    required this.reportsTabKey,
    required this.maisTabKey,
    required this.customizeKey,
    this.onCreateTransaction,
  });

  final Widget child;
  final GlobalKey fabKey;
  final GlobalKey transactionsTabKey;
  final GlobalKey reportsTabKey;
  final GlobalKey maisTabKey;
  final GlobalKey customizeKey;

  /// Abre o fluxo real de nova transação como demonstração prática do primeiro
  /// passo. Retorna quando o modal é fechado, para que o tutorial avance.
  final Future<void> Function()? onCreateTransaction;

  @override
  ConsumerState<TutorialRunner> createState() => _TutorialRunnerState();
}

/// Especificação de um passo antes de virar [TargetFocus] — permite filtrar os
/// alvos inválidos (sem contexto) e só então numerar os passos.
class _StepSpec {
  const _StepSpec({
    required this.id,
    required this.key,
    required this.shape,
    required this.padding,
    required this.align,
    required this.title,
    required this.body,
    this.isDemo = false,
  });

  final String id;
  final GlobalKey key;
  final ShapeLightFocus shape;
  final double padding;
  final ContentAlign align;
  final String title;
  final String body;
  final bool isDemo;
}

class _TutorialRunnerState extends ConsumerState<TutorialRunner> {
  bool _showing = false;
  TutorialCoachMark? _coach;

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

  void _done() {
    _showing = false;
    _coach = null;
    TutorialActions.markSeen(ref);
  }

  void _next() => _coach?.next();

  void _skip() => _coach?.skip();

  Future<void> _runDemo() async {
    if (widget.onCreateTransaction == null) {
      _next();
      return;
    }
    await widget.onCreateTransaction!.call();
    if (mounted) _next();
  }

  void _launch() {
    if (_showing) return;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final allSpecs = <_StepSpec>[
      _StepSpec(
        id: 'fab',
        key: widget.fabKey,
        shape: ShapeLightFocus.Circle,
        padding: 10,
        align: ContentAlign.top,
        title: 'Adicione uma transação',
        body:
            'Este é o botão principal. Por aqui você registra gastos, receitas e '
            'transferências. Que tal criar a sua primeira agora?',
        isDemo: true,
      ),
      _StepSpec(
        id: 'customize',
        key: widget.customizeKey,
        shape: ShapeLightFocus.RRect,
        padding: 6,
        align: ContentAlign.bottom,
        title: 'Personalize seu início',
        body:
            'Reorganize ou oculte os cards do dashboard para ver o que importa '
            'para você.',
      ),
      _StepSpec(
        id: 'transactions_tab',
        key: widget.transactionsTabKey,
        shape: ShapeLightFocus.RRect,
        padding: 6,
        align: ContentAlign.top,
        title: 'Suas transações',
        body:
            'Veja o histórico completo, filtre por período e edite qualquer '
            'lançamento.',
      ),
      _StepSpec(
        id: 'reports_tab',
        key: widget.reportsTabKey,
        shape: ShapeLightFocus.RRect,
        padding: 6,
        align: ContentAlign.top,
        title: 'Análises e relatórios',
        body:
            'Gráficos de categorias, fluxo de caixa, patrimônio e muito mais para '
            'entender suas finanças.',
      ),
      _StepSpec(
        id: 'mais_tab',
        key: widget.maisTabKey,
        shape: ShapeLightFocus.RRect,
        padding: 6,
        align: ContentAlign.top,
        title: 'Explore tudo',
        body:
            'Orçamentos, metas, investimentos, cartões e muito mais estão aqui.',
      ),
    ];

    final valid = allSpecs.where((s) => s.key.currentContext != null).toList();

    if (valid.isEmpty) {
      _done();
      return;
    }

    final targets = [
      for (int i = 0; i < valid.length; i++)
        _buildTarget(
          spec: valid[i],
          step: i + 1,
          total: valid.length,
          isLast: i == valid.length - 1,
          cs: cs,
          tt: tt,
        ),
    ];

    _showing = true;

    _coach = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.72,
      hideSkip: true,
      paddingFocus: 8,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: const Duration(milliseconds: 250),
      pulseEnable: true,
      onFinish: _done,
      onSkip: () {
        _done();
        return true;
      },
    )..show(context: context);
  }

  TargetFocus _buildTarget({
    required _StepSpec spec,
    required int step,
    required int total,
    required bool isLast,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return TargetFocus(
      identify: spec.id,
      keyTarget: spec.key,
      shape: spec.shape,
      radius: 14,
      paddingFocus: spec.padding,
      // Avanço só pelos botões do card — o usuário caminha passo a passo sem
      // encerrar o tutorial por engano.
      enableTargetTab: false,
      enableOverlayTab: false,
      contents: [
        TargetContent(
          align: spec.align,
          child: _TutorialCard(
            title: spec.title,
            body: spec.body,
            step: step,
            total: total,
            isLast: isLast,
            isDemo: spec.isDemo,
            onSkip: _skip,
            onNext: spec.isDemo ? _runDemo : _next,
            onSecondary: spec.isDemo ? _next : null,
            cs: cs,
            tt: tt,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reexibe o tutorial quando o usuário o redefine em Configurações (a flag
    // vai de true → false), mesmo com o dashboard já montado.
    ref.listen<bool>(tutorialSeenProvider, (prev, next) {
      if (prev == true && next == false && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _launch();
        });
      }
    });
    return widget.child;
  }
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    required this.title,
    required this.body,
    required this.step,
    required this.total,
    required this.isLast,
    required this.isDemo,
    required this.onSkip,
    required this.onNext,
    required this.cs,
    required this.tt,
    this.onSecondary,
  });

  final String title;
  final String body;
  final int step;
  final int total;
  final bool isLast;
  final bool isDemo;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final VoidCallback? onSecondary;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final nextLabel = isDemo
        ? 'Criar transação'
        : isLast
        ? 'Concluir'
        : 'Próximo';

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
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
            'Passo $step de $total',
            style: tt.labelSmall?.copyWith(
              color: cs.onPrimaryContainer.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Pular'),
              ),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (onSecondary != null)
                      TextButton(
                        onPressed: onSecondary,
                        style: TextButton.styleFrom(
                          foregroundColor: cs.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Depois'),
                      ),
                    FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        minimumSize: const Size(0, 40),
                      ),
                      child: Text(nextLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

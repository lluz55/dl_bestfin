import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_card_form_modal_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/widgets/credit_card_form_modal_overlay.dart';
import 'package:bestfin/features/credit_cards/presentation/widgets/credit_card_visual_widget.dart';
import 'package:bestfin/features/credit_cards/presentation/widgets/limit_bar_widget.dart';
import 'package:go_router/go_router.dart';

class CreditCardsListScreen extends ConsumerStatefulWidget {
  const CreditCardsListScreen({super.key});

  @override
  ConsumerState<CreditCardsListScreen> createState() =>
      _CreditCardsListScreenState();
}

class _CreditCardsListScreenState extends ConsumerState<CreditCardsListScreen> {
  // Carrossel horizontal de cartões: as páginas adjacentes "espiam" nas bordas
  // graças ao viewportFraction < 1.
  final _pageController = PageController(viewportFraction: 0.88);
  int _selectedIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    ref.watch(valuesHiddenProvider);
    final cardsAsync = ref.watch(creditCardsStreamProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: cs.surface,
          appBar: AppPageAppBar(
            title: 'Meus Cartões',
            showVisibilityToggle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Novo cartão',
                onPressed: () =>
                    ref.read(creditCardFormModalProvider.notifier).open(),
              ),
            ],
          ),
          body: cardsAsync.when(
            data: (cards) {
              if (cards.isEmpty) {
                return EmptyState(
                  title: 'Nenhum Cartão Cadastrado',
                  description:
                      'Cadastre seu primeiro cartão de crédito para gerenciar limites e acompanhar faturas inteligentes.',
                  icon: Icons.credit_card_rounded,
                  actionLabel: 'Cadastrar Cartão',
                  onAction: () =>
                      ref.read(creditCardFormModalProvider.notifier).open(),
                );
              }

              return _buildCarousel(cards, cs, tt);
            },
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (err, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar cartões',
                    style: tt.titleMedium?.copyWith(color: cs.error),
                  ),
                  const SizedBox(height: 8),
                  Text(err.toString(), style: tt.bodySmall),
                ],
              ),
            ),
          ),
        ),
        const CreditCardFormModalOverlay(),
      ],
    );
  }

  Widget _buildCarousel(
    List<CreditCardModel> cards,
    ColorScheme cs,
    TextTheme tt,
  ) {
    // Clampa o índice caso um cartão tenha sido removido enquanto era o
    // selecionado, evitando ler fora dos limites da lista.
    final selected = _selectedIndex.clamp(0, cards.length - 1);
    final selectedCard = cards[selected];

    return Column(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _selectedIndex = i),
            itemBuilder: (context, index) {
              final card = cards[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => context.push('/credit-cards/${card.id}'),
                  child: CreditCardVisualWidget(card: card),
                ),
              );
            },
          ),
        ),
        if (cards.length > 1) ...[
          const SizedBox(height: 20),
          _PageDots(count: cards.length, activeIndex: selected, cs: cs),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Container(
              key: ValueKey(selectedCard.id),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: LimitBarWidget(card: selectedCard),
            ).animate().fadeIn(duration: 250.ms),
          ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.activeIndex,
    required this.cs,
  });

  final int count;
  final int activeIndex;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/widgets/credit_card_visual_widget.dart';
import 'package:bestfin/features/credit_cards/presentation/widgets/limit_bar_widget.dart';
import 'package:go_router/go_router.dart';

class CreditCardsListScreen extends ConsumerWidget {
  const CreditCardsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    ref.watch(valuesHiddenProvider);
    final cardsAsync = ref.watch(creditCardsStreamProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(
        title: 'Meus Cartões',
        showVisibilityToggle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/credit-cards/new'),
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Novo Cartão'),
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
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
              onAction: () => context.push('/credit-cards/new'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final card = cards[index];

              return InkWell(
                    onTap: () => context.push('/credit-cards/${card.id}'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          CreditCardVisualWidget(card: card),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: LimitBarWidget(card: card),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  )
                  .animate(delay: Duration(milliseconds: index * 100))
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
            },
          );
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
    );
  }
}

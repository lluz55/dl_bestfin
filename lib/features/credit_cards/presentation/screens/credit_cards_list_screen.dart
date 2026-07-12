import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
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
  int _selectedIndex = 0;

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
            infoDescription: 'Cadastre e gerencie seus cartões de crédito. Acompanhe limite disponível, data de fechamento, vencimento e histórico de faturas.',
            infoFeatures: [
              'Limite total e disponível por cartão',
              'Fatura atual e próximas faturas',
              'Histórico completo de faturas',
              'Pagamento de faturas',
            ],
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

              return _buildList(cards, cs, tt);
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

  Widget _buildList(
    List<CreditCardModel> cards,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final isWide = Breakpoints.isWide(context);
    final selected = _selectedIndex.clamp(0, cards.length - 1);
    final selectedCard = cards[selected];

    if (isWide) {
      return _buildExpandedLayout(cards, selectedCard, cs, tt);
    }

    return _buildCompactLayout(cards, selectedCard, cs, tt);
  }

  Widget _buildCompactLayout(
    List<CreditCardModel> cards,
    CreditCardModel selectedCard,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Column(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 210,
          child: cards.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum cartão.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final isSelected = index == _selectedIndex.clamp(0, cards.length - 1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (isSelected) {
                            context.push('/credit-cards/${card.id}');
                          } else {
                            setState(() => _selectedIndex = index);
                          }
                        },
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isSelected ? 1.0 : 0.55,
                          child: CreditCardVisualWidget(card: card),
                        ),
                      ),
                    );
                  },
                ),
        ),
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

  Widget _buildExpandedLayout(
    List<CreditCardModel> cards,
    CreditCardModel selectedCard,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Cartões de Crédito',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final isSelected =
                        card.id == selectedCard.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CreditCardListTile(
                        card: card,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            final newIndex =
                                cards.indexWhere((c) => c.id == card.id);
                            if (newIndex >= 0) _selectedIndex = newIndex;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 0.5),
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
              child: _CreditCardDetailPanel(card: selectedCard, cs: cs, tt: tt),
            ).animate().fadeIn(duration: 250.ms),
          ),
        ),
      ],
    );
  }
}

class _CreditCardDetailPanel extends StatelessWidget {
  const _CreditCardDetailPanel({
    required this.card,
    required this.cs,
    required this.tt,
  });

  final CreditCardModel card;
  final ColorScheme cs;
  final TextTheme tt;

  Color get _baseColor {
    if (card.color != null && card.color!.isNotEmpty) {
      final hex = card.color!.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('ff$hex', radix: 16));
      }
    }
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final total = card.limitAmount / 100.0;
    final used = card.usedLimit / 100.0;
    final ratio = total > 0 ? (used / total) : 0.0;
    final barColor = ratio > 0.85 ? colors.expense : cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cartão de Crédito',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Limite',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  Icons.credit_card_rounded,
                  color: _baseColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  card.name,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Text(
              'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Utilizado vs Disponível',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '${(ratio * 100).toStringAsFixed(1)}%',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/credit-cards/${card.id}'),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Ver detalhes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/credit-cards/${card.id}/edit'),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CreditCardListTile extends StatelessWidget {
  const _CreditCardListTile({
    required this.card,
    required this.isSelected,
    required this.onTap,
  });

  final CreditCardModel card;
  final bool isSelected;
  final VoidCallback onTap;

  Color _baseColor(ColorScheme cs) {
    if (card.color != null && card.color!.isNotEmpty) {
      final hex = card.color!.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('ff$hex', radix: 16));
      }
    }
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final colors = context.customColors;
    final total = card.limitAmount / 100.0;
    final used = card.usedLimit / 100.0;

    return ListTile(
      selected: isSelected,
      selectedTileColor:
          cs.primaryContainer.withValues(alpha: 0.4),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _baseColor(cs).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.credit_card_rounded,
          color: _baseColor(cs).withValues(alpha: 0.7),
          size: 22,
        ),
      ),
      title: Text(
        card.name,
        style: tt.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Limite: R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          Text(
            'Utilizado: R\$ ${used.toStringAsFixed(2).replaceAll('.', ',')}',
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: used > total * 0.85
                  ? colors.expense
                  : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

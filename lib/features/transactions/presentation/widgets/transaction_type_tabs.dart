import 'package:flutter/material.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class TransactionTypeTabs extends StatelessWidget {
  final TransactionType selectedType;
  final ValueChanged<TransactionType> onTypeChanged;

  static const List<TransactionType> _tabOrder = [
    TransactionType.expense,
    TransactionType.income,
    TransactionType.transfer,
  ];

  const TransactionTypeTabs({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final motion = context.motion;
    final colors = context.customColors;

    return Container(
      height: 56,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tabWidth = constraints.maxWidth / 3;

          int selectedIndex = 0;
          Color selectedTabColor = colors.expense;
          Color onSelectedColor = Colors.white;

          if (selectedType == TransactionType.income) {
            selectedIndex = 1;
            selectedTabColor = colors.income;
          } else if (selectedType == TransactionType.transfer) {
            selectedIndex = 2;
            selectedTabColor = colors.transfer;
          }

          return Stack(
            children: [
              // Sliding active background indicator
              AnimatedPositioned(
                duration: motion.morphDuration,
                curve: motion.morphCurve,
                left: selectedIndex * tabWidth,
                width: tabWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedTabColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Row(
                children: [
                  for (int i = 0; i < _tabOrder.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final type = _tabOrder[i];
                          onTypeChanged(type);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            _tabOrder[i].label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selectedIndex == i
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: selectedIndex == i
                                  ? onSelectedColor
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

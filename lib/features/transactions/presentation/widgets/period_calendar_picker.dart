import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

class PeriodCalendarPicker extends ConsumerStatefulWidget {
  const PeriodCalendarPicker({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorScheme.surface,
      builder: (_) => const PeriodCalendarPicker(),
    );
  }

  @override
  ConsumerState<PeriodCalendarPicker> createState() =>
      _PeriodCalendarPickerState();
}

class _PeriodCalendarPickerState extends ConsumerState<PeriodCalendarPicker> {
  late DateTime _focusedMonth;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(transactionFiltersProvider);
    _tempStartDate = filters.startDate;
    _tempEndDate = filters.endDate;
    _focusedMonth = _tempStartDate ?? DateTime.now();
    // Normalizar _focusedMonth para primeiro dia do mês
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _onDaySelected(DateTime date) {
    setState(() {
      if (_tempStartDate == null ||
          (_tempStartDate != null && _tempEndDate != null)) {
        _tempStartDate = date;
        _tempEndDate = null;
      } else if (date.isBefore(_tempStartDate!)) {
        _tempStartDate = date;
        _tempEndDate = null;
      } else {
        _tempEndDate = date;
      }
    });
  }

  void _clear() {
    setState(() {
      _tempStartDate = null;
      _tempEndDate = null;
    });
  }

  void _apply() {
    ref.read(transactionFiltersProvider.notifier).update((state) {
      return state.copyWith(
        startDate: _tempStartDate,
        endDate: _tempEndDate,
        clearDate: _tempStartDate == null,
      );
    });
    Navigator.of(context).pop();
  }

  static const List<String> _weekdays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  static const List<String> _months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final txList = ref.watch(allTransactionsStreamProvider).value ?? [];

    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    // Calcular o offset: no Flutter, 7 = domingo, 1 = segunda, etc.
    final weekdayOffset = firstDay.weekday == 7 ? 0 : firstDay.weekday;

    // Calcular cor prevalecente por dia do mês
    final Map<int, Color> dayColors = {};
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final dayTxs = txList.where((tx) {
        return tx.date.year == date.year &&
            tx.date.month == date.month &&
            tx.date.day == date.day;
      }).toList();

      if (dayTxs.isNotEmpty) {
        int incomeSum = 0;
        int expenseSum = 0;
        int transferSum = 0;
        for (final tx in dayTxs) {
          if (tx.type == TransactionType.income) {
            incomeSum += tx.amount;
          } else if (tx.type == TransactionType.expense) {
            expenseSum += tx.amount;
          } else if (tx.type == TransactionType.transfer) {
            transferSum += tx.amount;
          }
        }

        if (incomeSum > 0 || expenseSum > 0 || transferSum > 0) {
          if (incomeSum >= expenseSum && incomeSum >= transferSum) {
            dayColors[day] = context.customColors.income;
          } else if (expenseSum >= incomeSum && expenseSum >= transferSum) {
            dayColors[day] = cs.error;
          } else {
            dayColors[day] = cs.primary;
          }
        }
      }
    }

    final totalGridItems = daysInMonth + weekdayOffset;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selecionar Período',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Month navigator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _prevMonth,
                ),
                Text(
                  '${_months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Weekday headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _weekdays.map((w) {
                return SizedBox(
                  width: 36,
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Days grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: totalGridItems,
              itemBuilder: (context, index) {
                if (index < weekdayOffset) {
                  return const SizedBox.shrink();
                }

                final day = index - weekdayOffset + 1;
                final date = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month,
                  day,
                );

                // Verificar estado de seleção
                final isStart =
                    _tempStartDate != null &&
                    DateUtils.isSameDay(_tempStartDate!, date);
                final isEnd =
                    _tempEndDate != null &&
                    DateUtils.isSameDay(_tempEndDate!, date);
                final isSelected = isStart || isEnd;

                final isInRange =
                    _tempStartDate != null &&
                    _tempEndDate != null &&
                    date.isAfter(_tempStartDate!) &&
                    date.isBefore(_tempEndDate!);

                final hasTransaction = dayColors.containsKey(day);
                final transColor = dayColors[day];

                return GestureDetector(
                  onTap: () => _onDaySelected(date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary
                          : (isInRange
                                ? cs.primaryContainer.withValues(alpha: 0.3)
                                : Colors.transparent),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? cs.onPrimary
                                : (isInRange
                                      ? cs.onPrimaryContainer
                                      : cs.onSurface),
                          ),
                        ),
                        if (hasTransaction && transColor != null)
                          Positioned(
                            bottom: 6,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected ? cs.onPrimary : transColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clear,
                    child: const Text('LIMPAR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(label: 'APLICAR', onPressed: _apply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

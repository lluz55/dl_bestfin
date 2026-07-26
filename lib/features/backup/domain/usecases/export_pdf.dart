import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final exportPdfUseCaseProvider = Provider<ExportPdfUseCase>((ref) {
  return ExportPdfUseCase(ref.watch(databaseProvider));
});

class ExportPdfUseCase {
  final AppDatabase _db;

  ExportPdfUseCase(this._db);

  Future<Uint8List> execute({DateTime? startDate, DateTime? endDate}) async {
    // 1. Fetch transactions with date filters
    final query = _db.select(_db.transactions);
    if (startDate != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
    ]);
    final txList = await query.get();

    // 2. Fetch categories and accounts
    final allCategories = await _db.select(_db.categories).get();
    final categoryMap = {for (var c in allCategories) c.id: c};

    final allEntries = await _db.select(_db.entries).get();
    final entriesByTx = <String, List<Entry>>{};
    for (final entry in allEntries) {
      entriesByTx.putIfAbsent(entry.transactionId, () => []).add(entry);
    }

    // 3. Compute Summary Calculations
    int totalIncomeCents = 0;
    int totalExpenseCents = 0;
    int expenseTxCount = 0;
    String? largestExpenseDesc;
    DateTime? largestExpenseDate;
    int largestExpenseCents = 0;

    final categorySpendingCents = <String, int>{};
    final monthlyIncomeCents = <DateTime, int>{};
    final monthlyExpenseCents = <DateTime, int>{};

    for (final tx in txList) {
      final txEntries = entriesByTx[tx.id] ?? [];
      final monthKey = DateTime(tx.date.year, tx.date.month);
      int amountCents = 0;

      if (tx.type == 'expense') {
        final creditEntry = txEntries.firstWhere(
          (e) => e.type == 'credit',
          orElse: () => txEntries.isNotEmpty
              ? txEntries.first
              : Entry(
                  id: '',
                  transactionId: '',
                  accountId: '',
                  amount: 0,
                  type: '',
                  createdAt: DateTime.now(),
                ),
        );
        amountCents = creditEntry.amount;
        totalExpenseCents += amountCents;
        expenseTxCount++;
        monthlyExpenseCents[monthKey] =
            (monthlyExpenseCents[monthKey] ?? 0) + amountCents;
        if (amountCents > largestExpenseCents) {
          largestExpenseCents = amountCents;
          largestExpenseDesc = tx.description;
          largestExpenseDate = tx.date;
        }

        // Group by category for chart
        final catId = tx.categoryId ?? 'sem_categoria';
        categorySpendingCents[catId] =
            (categorySpendingCents[catId] ?? 0) + amountCents;
      } else if (tx.type == 'income') {
        final debitEntry = txEntries.firstWhere(
          (e) => e.type == 'debit',
          orElse: () => txEntries.isNotEmpty
              ? txEntries.first
              : Entry(
                  id: '',
                  transactionId: '',
                  accountId: '',
                  amount: 0,
                  type: '',
                  createdAt: DateTime.now(),
                ),
        );
        amountCents = debitEntry.amount;
        totalIncomeCents += amountCents;
        monthlyIncomeCents[monthKey] =
            (monthlyIncomeCents[monthKey] ?? 0) + amountCents;
      } else if (tx.type == 'transfer') {
        final creditEntry = txEntries.firstWhere(
          (e) => e.type == 'credit',
          orElse: () => Entry(
            id: '',
            transactionId: '',
            accountId: '',
            amount: 0,
            type: '',
            createdAt: DateTime.now(),
          ),
        );
        amountCents = creditEntry.amount;
      }
    }

    final int netBalanceCents = totalIncomeCents - totalExpenseCents;

    // Sort category spending desc
    final sortedCategories = categorySpendingCents.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Months present in the period, ascending, for the monthly evolution table
    final monthKeys = <DateTime>{
      ...monthlyIncomeCents.keys,
      ...monthlyExpenseCents.keys,
    }.toList()..sort();

    // Insights computed from the data at export time
    final insights = txList.isEmpty
        ? <String>[]
        : _buildInsights(
            totalIncomeCents: totalIncomeCents,
            totalExpenseCents: totalExpenseCents,
            expenseTxCount: expenseTxCount,
            largestExpenseDesc: largestExpenseDesc,
            largestExpenseDate: largestExpenseDate,
            largestExpenseCents: largestExpenseCents,
            sortedCategories: sortedCategories,
            categoryMap: categoryMap,
            monthKeys: monthKeys,
            monthlyExpenseCents: monthlyExpenseCents,
            // txList vem ordenada desc: first = mais recente, last = mais antiga
            periodStart: startDate ?? txList.last.date,
            periodEnd: endDate ?? txList.first.date,
          );

    // 4. Generate PDF using pw.Document
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#1E3A8A'); // Dark Blue
    final incomeColor = PdfColor.fromHex('#16A34A'); // Green
    final expenseColor = PdfColor.fromHex('#DC2626'); // Red
    final greyColor = PdfColor.fromHex('#6B7280');
    final lightGreyColor = PdfColor.fromHex('#F3F4F6');

    final titleFont = pw.Font.helveticaBold();
    final bodyFont = pw.Font.helvetica();

    final df = DateFormat('dd/MM/yyyy');
    final periodStr = _formatPeriod(startDate, endDate, df);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Relatório Financeiro',
                      style: pw.TextStyle(
                        font: titleFont,
                        fontSize: 24,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      // Hífen em vez de travessão: Helvetica (WinAnsi) não
                      // renderiza U+2014 no package pdf.
                      'BestFin - Suas finanças de forma simples',
                      style: pw.TextStyle(
                        font: bodyFont,
                        fontSize: 10,
                        color: greyColor,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      periodStr,
                      style: pw.TextStyle(
                        font: titleFont,
                        fontSize: 10,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Gerado em: ${df.format(DateTime.now())}',
                      style: pw.TextStyle(
                        font: bodyFont,
                        fontSize: 8,
                        color: greyColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(color: primaryColor, thickness: 1.5, height: 20),

            // Summary Section
            pw.Text(
              'Resumo Geral',
              style: pw.TextStyle(
                font: titleFont,
                fontSize: 14,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _buildSummaryCard(
                  title: 'RECEITAS',
                  value: _formatCents(totalIncomeCents),
                  color: incomeColor,
                  titleFont: titleFont,
                  bodyFont: bodyFont,
                  lightGreyColor: lightGreyColor,
                ),
                pw.SizedBox(width: 12),
                _buildSummaryCard(
                  title: 'DESPESAS',
                  value: _formatCents(totalExpenseCents),
                  color: expenseColor,
                  titleFont: titleFont,
                  bodyFont: bodyFont,
                  lightGreyColor: lightGreyColor,
                ),
                pw.SizedBox(width: 12),
                _buildSummaryCard(
                  title: 'SALDO LÍQUIDO',
                  value: _formatCents(netBalanceCents),
                  color: netBalanceCents >= 0 ? incomeColor : expenseColor,
                  titleFont: titleFont,
                  bodyFont: bodyFont,
                  lightGreyColor: lightGreyColor,
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Insights Section (data-driven, computed at export time)
            if (insights.isNotEmpty) ...[
              pw.Text(
                'Insights do Período',
                style: pw.TextStyle(
                  font: titleFont,
                  fontSize: 14,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightGreyColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (final insight in insights)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 5,
                              height: 5,
                              margin: const pw.EdgeInsets.only(
                                top: 3,
                                right: 6,
                              ),
                              decoration: pw.BoxDecoration(
                                color: primaryColor,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                insight,
                                style: pw.TextStyle(
                                  font: bodyFont,
                                  fontSize: 9,
                                  color: PdfColor.fromHex('#374151'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Monthly Evolution Section (only when the period spans 2+ months)
            if (monthKeys.length > 1) ...[
              pw.Text(
                'Evolução Mensal',
                style: pw.TextStyle(
                  font: titleFont,
                  fontSize: 14,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              if (totalIncomeCents > 0 || totalExpenseCents > 0) ...[
                _buildMonthlyBarChart(
                  monthKeys: monthKeys,
                  monthlyIncomeCents: monthlyIncomeCents,
                  monthlyExpenseCents: monthlyExpenseCents,
                  incomeColor: incomeColor,
                  expenseColor: expenseColor,
                  greyColor: greyColor,
                  bodyFont: bodyFont,
                ),
                pw.SizedBox(height: 12),
              ],
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                    color: lightGreyColor,
                    width: 0.5,
                  ),
                  bottom: pw.BorderSide(color: primaryColor, width: 1.0),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(),
                  1: pw.FixedColumnWidth(90),
                  2: pw.FixedColumnWidth(90),
                  3: pw.FixedColumnWidth(90),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      _buildTableHeaderCell('Mês', titleFont),
                      _buildTableHeaderCell(
                        'Receitas',
                        titleFont,
                        alignEnd: true,
                      ),
                      _buildTableHeaderCell(
                        'Despesas',
                        titleFont,
                        alignEnd: true,
                      ),
                      _buildTableHeaderCell('Saldo', titleFont, alignEnd: true),
                    ],
                  ),
                  ...monthKeys.map((month) {
                    final incomeCents = monthlyIncomeCents[month] ?? 0;
                    final expenseCents = monthlyExpenseCents[month] ?? 0;
                    final balanceCents = incomeCents - expenseCents;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(_monthLabel(month), bodyFont),
                        _buildTableCell(
                          _formatCents(incomeCents),
                          bodyFont,
                          color: incomeColor,
                          alignEnd: true,
                        ),
                        _buildTableCell(
                          _formatCents(expenseCents),
                          bodyFont,
                          color: expenseColor,
                          alignEnd: true,
                        ),
                        _buildTableCell(
                          _formatCents(balanceCents),
                          titleFont,
                          color: balanceCents >= 0 ? incomeColor : expenseColor,
                          alignEnd: true,
                        ),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightGreyColor),
                    children: [
                      _buildTableCell('Média mensal', titleFont),
                      _buildTableCell(
                        _formatCents(totalIncomeCents ~/ monthKeys.length),
                        titleFont,
                        color: incomeColor,
                        alignEnd: true,
                      ),
                      _buildTableCell(
                        _formatCents(totalExpenseCents ~/ monthKeys.length),
                        titleFont,
                        color: expenseColor,
                        alignEnd: true,
                      ),
                      _buildTableCell(
                        _formatCents(netBalanceCents ~/ monthKeys.length),
                        titleFont,
                        color: netBalanceCents >= 0
                            ? incomeColor
                            : expenseColor,
                        alignEnd: true,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // Category Distribution Section (Custom horizontal charts)
            if (sortedCategories.isNotEmpty) ...[
              pw.Text(
                'Despesas por Categoria',
                style: pw.TextStyle(
                  font: titleFont,
                  fontSize: 14,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 10),
              if (totalExpenseCents > 0) ...[
                _buildCategoryPieChart(
                  sortedCategories: sortedCategories,
                  categoryMap: categoryMap,
                  totalExpenseCents: totalExpenseCents,
                  primaryColor: primaryColor,
                  greyColor: greyColor,
                  titleFont: titleFont,
                  bodyFont: bodyFont,
                ),
                pw.SizedBox(height: 12),
              ],
              pw.ListView.builder(
                itemCount: sortedCategories.length > 5
                    ? 5
                    : sortedCategories.length,
                itemBuilder: (pw.Context context, int index) {
                  final item = sortedCategories[index];
                  final cat = categoryMap[item.key];
                  final catName =
                      cat?.name ??
                      (item.key == 'sem_categoria'
                          ? 'Sem Categoria'
                          : item.key);
                  final valCents = item.value;
                  final percentage = totalExpenseCents > 0
                      ? (valCents / totalExpenseCents)
                      : 0.0;

                  // Parse color from category hex
                  final hexColor = cat?.color ?? '#9E9E9E';
                  final barColor = _parseColor(hexColor, primaryColor);

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              catName,
                              style: pw.TextStyle(
                                font: bodyFont,
                                fontSize: 10,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.Text(
                              '${_formatCents(valCents)} (${(percentage * 100).toStringAsFixed(1)}%)',
                              style: pw.TextStyle(
                                font: titleFont,
                                fontSize: 10,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Stack(
                          children: [
                            pw.Container(
                              height: 6,
                              width: double.infinity,
                              decoration: pw.BoxDecoration(
                                color: lightGreyColor,
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(3),
                                ),
                              ),
                            ),
                            pw.Container(
                              height: 6,
                              width: (percentage * 500).clamp(
                                0.0,
                                500.0,
                              ), // Multiplied by approximate scale width
                              decoration: pw.BoxDecoration(
                                color: barColor,
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                      ],
                    ),
                  );
                },
              ),
              pw.SizedBox(height: 24),
            ],

            // Transactions Table
            pw.Text(
              'Transações Recentes',
              style: pw.TextStyle(
                font: titleFont,
                fontSize: 14,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: lightGreyColor,
                  width: 0.5,
                ),
                bottom: pw.BorderSide(color: primaryColor, width: 1.0),
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(60), // Data
                1: pw.FlexColumnWidth(), // Descrição
                2: pw.FixedColumnWidth(80), // Tipo
                3: pw.FixedColumnWidth(100), // Categoria
                4: pw.FixedColumnWidth(80), // Valor
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    _buildTableHeaderCell('Data', titleFont),
                    _buildTableHeaderCell('Descrição', titleFont),
                    _buildTableHeaderCell('Tipo', titleFont),
                    _buildTableHeaderCell('Categoria', titleFont),
                    _buildTableHeaderCell('Valor', titleFont, alignEnd: true),
                  ],
                ),
                // Table Rows
                ...txList.take(30).map((tx) {
                  final txEntries = entriesByTx[tx.id] ?? [];
                  int amountCents = 0;

                  if (tx.type == 'expense') {
                    final creditEntry = txEntries.firstWhere(
                      (e) => e.type == 'credit',
                      orElse: () => txEntries.isNotEmpty
                          ? txEntries.first
                          : Entry(
                              id: '',
                              transactionId: '',
                              accountId: '',
                              amount: 0,
                              type: '',
                              createdAt: DateTime.now(),
                            ),
                    );
                    amountCents = creditEntry.amount;
                  } else if (tx.type == 'income') {
                    final debitEntry = txEntries.firstWhere(
                      (e) => e.type == 'debit',
                      orElse: () => txEntries.isNotEmpty
                          ? txEntries.first
                          : Entry(
                              id: '',
                              transactionId: '',
                              accountId: '',
                              amount: 0,
                              type: '',
                              createdAt: DateTime.now(),
                            ),
                    );
                    amountCents = debitEntry.amount;
                  } else if (tx.type == 'transfer') {
                    final creditEntry = txEntries.firstWhere(
                      (e) => e.type == 'credit',
                      orElse: () => Entry(
                        id: '',
                        transactionId: '',
                        accountId: '',
                        amount: 0,
                        type: '',
                        createdAt: DateTime.now(),
                      ),
                    );
                    amountCents = creditEntry.amount;
                  }

                  final cat = categoryMap[tx.categoryId];
                  final catName = cat?.name ?? 'Sem Categoria';
                  final displayValue = tx.type == 'expense'
                      ? -amountCents
                      : amountCents;

                  return pw.TableRow(
                    children: [
                      _buildTableCell(df.format(tx.date), bodyFont),
                      _buildTableCell(tx.description, bodyFont),
                      _buildTableCell(_translateType(tx.type), bodyFont),
                      _buildTableCell(catName, bodyFont),
                      _buildTableCell(
                        _formatCents(displayValue),
                        titleFont,
                        color: tx.type == 'expense'
                            ? expenseColor
                            : (tx.type == 'income'
                                  ? incomeColor
                                  : PdfColors.black),
                        alignEnd: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Gera frases de insight a partir dos agregados calculados no momento
  /// da exportação. Cada insight só entra quando há dados que o sustentem.
  List<String> _buildInsights({
    required int totalIncomeCents,
    required int totalExpenseCents,
    required int expenseTxCount,
    required String? largestExpenseDesc,
    required DateTime? largestExpenseDate,
    required int largestExpenseCents,
    required List<MapEntry<String, int>> sortedCategories,
    required Map<String, Category> categoryMap,
    required List<DateTime> monthKeys,
    required Map<DateTime, int> monthlyExpenseCents,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final insights = <String>[];

    // Taxa de poupança (ou estouro) sobre as receitas
    if (totalIncomeCents > 0) {
      final netCents = totalIncomeCents - totalExpenseCents;
      final rate = netCents / totalIncomeCents * 100;
      if (rate >= 0) {
        insights.add(
          'Você poupou ${rate.toStringAsFixed(1)}% das receitas no período '
          '(${_formatCents(netCents)}).',
        );
      } else {
        insights.add(
          'As despesas superaram as receitas em ${_formatCents(-netCents)} '
          '(${(-rate).toStringAsFixed(1)}% acima do que entrou).',
        );
      }
    }

    // Concentração na categoria de maior gasto
    if (sortedCategories.isNotEmpty && totalExpenseCents > 0) {
      final top = sortedCategories.first;
      final name =
          categoryMap[top.key]?.name ??
          (top.key == 'sem_categoria' ? 'Sem Categoria' : top.key);
      final pct = top.value / totalExpenseCents * 100;
      insights.add(
        '"$name" foi a categoria com maior gasto: ${_formatCents(top.value)} '
        '(${pct.toStringAsFixed(1)}% das despesas).',
      );
    }

    // Gasto médio diário no período
    if (totalExpenseCents > 0) {
      final days = periodEnd.difference(periodStart).inDays + 1;
      if (days > 0) {
        insights.add(
          'Gasto médio diário de ${_formatCents(totalExpenseCents ~/ days)} '
          'ao longo de $days ${days == 1 ? 'dia' : 'dias'}.',
        );
      }
    }

    // Maior despesa individual
    if (largestExpenseCents > 0 &&
        largestExpenseDesc != null &&
        largestExpenseDate != null) {
      final df = DateFormat('dd/MM/yyyy');
      insights.add(
        'Maior despesa individual: "$largestExpenseDesc" de '
        '${_formatCents(largestExpenseCents)} em '
        '${df.format(largestExpenseDate)}.',
      );
    }

    // Comparativos mensais (apenas quando o período cobre 2+ meses)
    if (monthKeys.length > 1 && totalExpenseCents > 0) {
      DateTime? peakMonth;
      int peakCents = 0;
      for (final month in monthKeys) {
        final value = monthlyExpenseCents[month] ?? 0;
        if (value > peakCents) {
          peakCents = value;
          peakMonth = month;
        }
      }
      final avgCents = totalExpenseCents ~/ monthKeys.length;
      if (peakMonth != null && avgCents > 0 && peakCents > avgCents) {
        final pctAbove = (peakCents - avgCents) / avgCents * 100;
        insights.add(
          '${_monthLabel(peakMonth)} concentrou o maior gasto '
          '(${_formatCents(peakCents)}), ${pctAbove.toStringAsFixed(0)}% '
          'acima da média mensal.',
        );
      }

      final lastMonth = monthKeys.last;
      final prevMonth = monthKeys[monthKeys.length - 2];
      final lastExp = monthlyExpenseCents[lastMonth] ?? 0;
      final prevExp = monthlyExpenseCents[prevMonth] ?? 0;
      if (prevExp > 0 && lastExp > 0) {
        final delta = (lastExp - prevExp) / prevExp * 100;
        if (delta.abs() >= 1) {
          insights.add(
            delta > 0
                ? 'As despesas de ${_monthLabel(lastMonth)} cresceram '
                      '${delta.toStringAsFixed(0)}% em relação a '
                      '${_monthLabel(prevMonth)}.'
                : 'As despesas de ${_monthLabel(lastMonth)} caíram '
                      '${(-delta).toStringAsFixed(0)}% em relação a '
                      '${_monthLabel(prevMonth)}.',
          );
        }
      }
    }

    // Volume de despesas e ticket médio
    if (expenseTxCount > 0) {
      insights.add(
        '$expenseTxCount ${expenseTxCount == 1 ? 'despesa registrada' : 'despesas registradas'}, '
        'com valor médio de ${_formatCents(totalExpenseCents ~/ expenseTxCount)}.',
      );
    }

    return insights;
  }

  /// Gráfico de barras receitas x despesas por mês (períodos de 2+ meses).
  pw.Widget _buildMonthlyBarChart({
    required List<DateTime> monthKeys,
    required Map<DateTime, int> monthlyIncomeCents,
    required Map<DateTime, int> monthlyExpenseCents,
    required PdfColor incomeColor,
    required PdfColor expenseColor,
    required PdfColor greyColor,
    required pw.Font bodyFont,
  }) {
    final incomeReais = [
      for (final m in monthKeys) (monthlyIncomeCents[m] ?? 0) / 100,
    ];
    final expenseReais = [
      for (final m in monthKeys) (monthlyExpenseCents[m] ?? 0) / 100,
    ];

    double maxVal = 0;
    for (final v in [...incomeReais, ...expenseReais]) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal <= 0) return pw.SizedBox();

    final step = _niceStep(maxVal / 4);
    final divisions = (maxVal / step).ceil();
    final yValues = [for (var i = 0; i <= divisions; i++) i * step];

    final labels = [for (final m in monthKeys) _shortMonthLabel(m)];
    final barWidth = (400 / monthKeys.length / 3).clamp(4.0, 14.0).toDouble();

    return pw.Column(
      children: [
        pw.SizedBox(
          height: 160,
          child: pw.Chart(
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis.fromStrings(
                labels,
                marginStart: 30,
                marginEnd: 30,
                ticks: true,
                textStyle: pw.TextStyle(font: bodyFont, fontSize: 7),
              ),
              yAxis: pw.FixedAxis(
                yValues,
                format: _compactReais,
                divisions: true,
                textStyle: pw.TextStyle(font: bodyFont, fontSize: 7),
              ),
            ),
            datasets: [
              pw.BarDataSet(
                color: incomeColor,
                width: barWidth,
                offset: -(barWidth / 2 + 1),
                borderColor: incomeColor,
                data: [
                  for (var i = 0; i < incomeReais.length; i++)
                    pw.PointChartValue(i.toDouble(), incomeReais[i]),
                ],
              ),
              pw.BarDataSet(
                color: expenseColor,
                width: barWidth,
                offset: barWidth / 2 + 1,
                borderColor: expenseColor,
                data: [
                  for (var i = 0; i < expenseReais.length; i++)
                    pw.PointChartValue(i.toDouble(), expenseReais[i]),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _buildLegendDot(incomeColor),
            pw.SizedBox(width: 4),
            pw.Text(
              'Receitas',
              style: pw.TextStyle(
                font: bodyFont,
                fontSize: 8,
                color: greyColor,
              ),
            ),
            pw.SizedBox(width: 16),
            _buildLegendDot(expenseColor),
            pw.SizedBox(width: 4),
            pw.Text(
              'Despesas',
              style: pw.TextStyle(
                font: bodyFont,
                fontSize: 8,
                color: greyColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Gráfico de pizza das despesas por categoria (top 5 + "Outros").
  pw.Widget _buildCategoryPieChart({
    required List<MapEntry<String, int>> sortedCategories,
    required Map<String, Category> categoryMap,
    required int totalExpenseCents,
    required PdfColor primaryColor,
    required PdfColor greyColor,
    required pw.Font titleFont,
    required pw.Font bodyFont,
  }) {
    const maxSlices = 5;
    final top = sortedCategories.take(maxSlices).toList();
    final othersCents = sortedCategories
        .skip(maxSlices)
        .fold<int>(0, (sum, e) => sum + e.value);

    final slices = <({String name, int cents, PdfColor color})>[];
    for (final entry in top) {
      final cat = categoryMap[entry.key];
      final name =
          cat?.name ??
          (entry.key == 'sem_categoria' ? 'Sem Categoria' : entry.key);
      slices.add((
        name: name,
        cents: entry.value,
        color: _parseColor(cat?.color ?? '#9E9E9E', primaryColor),
      ));
    }
    if (othersCents > 0) {
      slices.add((
        name: 'Outros',
        cents: othersCents,
        color: PdfColor.fromHex('#9CA3AF'),
      ));
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(
          width: 130,
          height: 130,
          child: pw.Chart(
            grid: pw.PieGrid(),
            datasets: [
              for (final slice in slices)
                pw.PieDataSet(
                  value: slice.cents / 100,
                  color: slice.color,
                  legendPosition: pw.PieLegendPosition.none,
                  borderColor: PdfColors.white,
                  borderWidth: 1,
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final slice in slices)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      _buildLegendDot(slice.color),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(
                          slice.name,
                          style: pw.TextStyle(font: bodyFont, fontSize: 9),
                        ),
                      ),
                      pw.Text(
                        '${(slice.cents / totalExpenseCents * 100).toStringAsFixed(1)}%  '
                        '${_formatCents(slice.cents)}',
                        style: pw.TextStyle(font: titleFont, fontSize: 9),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildLegendDot(PdfColor color) {
    return pw.Container(
      width: 8,
      height: 8,
      decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
    );
  }

  /// Passo "redondo" para o eixo Y do gráfico de barras.
  double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final normalized = raw / magnitude;
    if (normalized <= 1) return magnitude;
    if (normalized <= 2) return 2 * magnitude;
    if (normalized <= 2.5) return 2.5 * magnitude;
    if (normalized <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }

  String _compactReais(num value) {
    if (value >= 1000000) {
      final v = value / 1000000;
      return 'R\$${v.toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final v = value / 1000;
      return 'R\$${v.toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return 'R\$${value.toStringAsFixed(0)}';
  }

  static const _monthNamesShort = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  String _shortMonthLabel(DateTime month) =>
      '${_monthNamesShort[month.month - 1]}/${month.year % 100}';

  pw.Widget _buildSummaryCard({
    required String title,
    required String value,
    required PdfColor color,
    required pw.Font titleFont,
    required pw.Font bodyFont,
    required PdfColor lightGreyColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: lightGreyColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                font: bodyFont,
                fontSize: 8,
                color: PdfColor.fromHex('#4B5563'),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(font: titleFont, fontSize: 14, color: color),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTableHeaderCell(
    String text,
    pw.Font font, {
    bool alignEnd = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Align(
        alignment: alignEnd
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white),
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    PdfColor? color,
    bool alignEnd = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Align(
        alignment: alignEnd
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: 8,
            color: color ?? PdfColors.black,
          ),
        ),
      ),
    );
  }

  static const _monthNames = [
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

  String _monthLabel(DateTime month) =>
      '${_monthNames[month.month - 1]} ${month.year}';

  /// Exibe o nome do mês quando o período cobre exatamente um mês-calendário
  /// (relatório mensal); caso contrário, o intervalo de datas.
  String _formatPeriod(DateTime? start, DateTime? end, DateFormat df) {
    if (start == null || end == null) return 'Todo o período';
    final lastDayOfMonth = DateTime(start.year, start.month + 1, 0).day;
    final isFullMonth =
        start.day == 1 &&
        end.year == start.year &&
        end.month == start.month &&
        end.day == lastDayOfMonth;
    if (isFullMonth) return _monthLabel(start);
    return '${df.format(start)} até ${df.format(end)}';
  }

  String _formatCents(int cents) {
    final double value = cents / 100.0;
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return formatter.format(value);
  }

  String _translateType(String type) {
    switch (type) {
      case 'expense':
        return 'Despesa';
      case 'income':
        return 'Receita';
      case 'transfer':
        return 'Transf.';
      default:
        return type;
    }
  }

  PdfColor _parseColor(String hex, PdfColor fallback) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) {
        return PdfColor.fromHex('#$cleanHex');
      } else if (cleanHex.length == 8) {
        // ARGB to RGBA style
        final argb = cleanHex.substring(2) + cleanHex.substring(0, 2);
        return PdfColor.fromHex('#$argb');
      }
    } catch (_) {}
    return fallback;
  }
}

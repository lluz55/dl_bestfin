import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final exportPdfUseCaseProvider = Provider<ExportPdfUseCase>((ref) {
  return ExportPdfUseCase(ref.read(databaseProvider));
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

    final allAccounts = await _db.select(_db.accounts).get();
    final accountMap = {for (var a in allAccounts) a.id: a.name};

    final allEntries = await _db.select(_db.entries).get();
    final entriesByTx = <String, List<Entry>>{};
    for (final entry in allEntries) {
      entriesByTx.putIfAbsent(entry.transactionId, () => []).add(entry);
    }

    // 3. Compute Summary Calculations
    int totalIncomeCents = 0;
    int totalExpenseCents = 0;

    final categorySpendingCents = <String, int>{};

    for (final tx in txList) {
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
        totalExpenseCents += amountCents;

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
    final periodStr = startDate != null && endDate != null
        ? '${df.format(startDate)} até ${df.format(endDate)}'
        : 'Todo o período';

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
                      'BestFin — Suas finanças de forma simples',
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

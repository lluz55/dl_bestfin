import 'dart:io';

import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';
import 'package:bestfin/features/pdf_import/domain/usecases/import_pdf_usecase.dart';
import 'package:bestfin/features/transactions/domain/models/bulk_transaction_item.dart';

/// Importação de PDF: lê faturas e comprovantes suportados, deixa escolher
/// quais linhas importar e cria tudo num único lote.
class PdfImportScreen extends Screen {
  PdfImportScreen(super.ctx);

  @override
  String get title => 'Importar PDF';

  @override
  Future<void> run() async {
    Term.clear();
    Term.header(title);
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}Formatos suportados: Nubank (fatura e comprovante/Pix) '
      'e Banco do Brasil (comprovante).${Term.reset}',
    );
    Term.writeln();

    final path = Term.input('Caminho do PDF:', allowEmpty: false);
    if (path == null || path.trim().isEmpty) return;

    final resolved = _expandHome(path.trim());
    final file = File(resolved);
    if (!file.existsSync()) {
      Term.error('Arquivo não encontrado: $resolved');
      Term.pause();
      return;
    }

    Term.writeln();
    Term.writeln('  ${Term.gray}Lendo o PDF…${Term.reset}');

    List<PdfParsedTransaction> parsed;
    try {
      parsed = await ImportPdfUseCase().call(await file.readAsBytes());
    } on FormatException catch (e) {
      Term.error(e.message);
      Term.pause();
      return;
    } catch (e) {
      Term.error(
        'Não foi possível ler o PDF a partir do terminal: '
        '${Screen.describeError(e)}',
      );
      Term.pause();
      return;
    }

    if (parsed.isEmpty) {
      Term.alert(title, 'Nenhum lançamento encontrado no PDF.');
      return;
    }

    final picked = pickMulti<PdfParsedTransaction>(
      'Lançamentos encontrados (${parsed.length})',
      parsed,
      (t) =>
          '${Term.formatDate(t.date)}  ${Term.pad(t.description, 34)} '
          '${Term.padLeft(Term.formatMoney(t.amountCents), 15)} '
          '${Term.gray}${t.type == 'income' ? 'receita' : 'despesa'}${Term.reset}',
      initial: {for (var i = 0; i < parsed.length; i++) i},
    );
    if (picked == null || picked.isEmpty) return;

    final account = await pickAccount('Conta de destino');
    if (account == null) return;

    final (choseCategory, category) = await pickCategoryOptional(
      'Categoria (aplicada a todos)',
    );
    if (!choseCategory) return;

    Term.writeln();
    if (!Term.confirm(
      'Importar ${picked.length} lançamento(s) para ${account.name}?',
      defaultYes: true,
    )) {
      return;
    }

    await guard(() async {
      final items = picked
          .map(
            (i) => BulkTransactionItem(
              date: parsed[i].date,
              description: parsed[i].description,
              type: parsed[i].type,
              amount: parsed[i].amountCents,
              categoryId: category?.id,
              accountId: account.id,
            ),
          )
          .toList();
      await ctx.transactions.createTransactionsBulk(items);
    }, successMessage: '${picked.length} lançamento(s) importado(s).');
  }

  static String _expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final home = Platform.environment['HOME'];
    if (home == null) return path;
    return '$home${path.substring(1)}';
  }
}

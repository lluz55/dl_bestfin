import 'package:bestfin/features/ai_quick_transaction/domain/models/ai_transaction_draft.dart';

sealed class AiQuickTxState {
  const AiQuickTxState();
}

class AiQuickTxIdle extends AiQuickTxState {
  const AiQuickTxIdle();
}

class AiQuickTxParsing extends AiQuickTxState {
  const AiQuickTxParsing();
}

class AiQuickTxNeedsType extends AiQuickTxState {
  final AiTransactionDraft partial;
  const AiQuickTxNeedsType(this.partial);
}

class AiQuickTxPreview extends AiQuickTxState {
  final AiTransactionDraft draft;
  const AiQuickTxPreview(this.draft);
}

class AiQuickTxSaving extends AiQuickTxState {
  const AiQuickTxSaving();
}

class AiQuickTxDone extends AiQuickTxState {
  const AiQuickTxDone();
}

class AiQuickTxError extends AiQuickTxState {
  final String message;
  const AiQuickTxError(this.message);
}

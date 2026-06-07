import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/core/widgets/entity_autocomplete.dart'
    show allEntitiesProvider;
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart'
    show allFlatCategoriesProvider;
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

import 'package:bestfin/features/ai_quick_transaction/domain/models/ai_quick_tx_state.dart';
import 'package:bestfin/features/ai_quick_transaction/domain/models/ai_transaction_draft.dart';
import 'package:bestfin/features/ai_quick_transaction/domain/services/ai_quick_tx_prompt.dart';
import 'package:bestfin/features/ai_quick_transaction/presentation/providers/ai_quick_tx_context_provider.dart';

class AiQuickTxNotifier extends Notifier<AiQuickTxState> {
  @override
  AiQuickTxState build() => const AiQuickTxIdle();

  void reset() => state = const AiQuickTxIdle();

  Future<void> parse(String rawInput) async {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return;

    final llmState = ref.read(llmStateProvider);
    if (llmState.status != LlmStatus.ready) {
      state = AiQuickTxPreview(_heuristicFallback(trimmed));
      return;
    }

    state = const AiQuickTxParsing();

    try {
      final context = ref.read(aiQuickTxContextProvider);
      final prompt = AiQuickTxPrompt.build(trimmed, context, DateTime.now());
      final service = ref.read(llmServiceProvider);
      final raw = await service.generateOnce(prompt, maxTokens: 220);
      final draft = _parseResponse(raw, trimmed);

      if (draft.type == null) {
        state = AiQuickTxNeedsType(draft);
      } else {
        state = AiQuickTxPreview(draft);
      }
    } catch (e, st) {
      debugPrint('[AiQuickTx] Erro ao parsear: $e\n$st');
      state = AiQuickTxPreview(_heuristicFallback(trimmed));
    }
  }

  // ── Field setters ─────────────────────────────────────────────────────────

  void selectType(TransactionType type) {
    final s = state;
    if (s is AiQuickTxNeedsType) {
      state = AiQuickTxPreview(s.partial.copyWith(type: type));
    } else if (s is AiQuickTxPreview) {
      // Clear entity/toAccount if switching away from/to transfer
      final draft = s.draft;
      final wasTransfer = draft.type == TransactionType.transfer;
      final isTransfer = type == TransactionType.transfer;
      state = AiQuickTxPreview(
        draft.copyWith(
          type: type,
          entityName: isTransfer
              ? null
              : (wasTransfer ? null : draft.entityName),
          toAccountId: isTransfer ? draft.toAccountId : null,
          toAccountName: isTransfer ? draft.toAccountName : null,
        ),
      );
    }
  }

  void selectCategory(String id, String name) {
    final s = state;
    if (s is! AiQuickTxPreview) return;
    state = AiQuickTxPreview(
      s.draft.copyWith(categoryId: id, categoryName: name),
    );
  }

  void selectAccount(String id, String name) {
    final s = state;
    if (s is! AiQuickTxPreview) return;
    state = AiQuickTxPreview(
      s.draft.copyWith(accountId: id, accountName: name),
    );
  }

  void selectToAccount(String id, String name) {
    final s = state;
    if (s is! AiQuickTxPreview) return;
    state = AiQuickTxPreview(
      s.draft.copyWith(toAccountId: id, toAccountName: name),
    );
  }

  void selectEntity(String name) {
    final s = state;
    if (s is! AiQuickTxPreview) return;
    final trimmed = name.trim();
    state = AiQuickTxPreview(
      s.draft.copyWith(entityName: trimmed.isEmpty ? null : trimmed),
    );
  }

  void selectDate(DateTime date) {
    final s = state;
    if (s is! AiQuickTxPreview) return;
    state = AiQuickTxPreview(s.draft.copyWith(date: date));
  }

  void toggleRecurring() {
    final s = state;
    if (s is! AiQuickTxPreview) return;
    final draft = s.draft;
    final nowRecurring = !draft.isRecurring;
    state = AiQuickTxPreview(
      draft.copyWith(
        isRecurring: nowRecurring,
        recurringFrequency: nowRecurring
            ? (draft.recurringFrequency ?? RecurringFrequency.monthly)
            : null,
      ),
    );
  }

  void selectFrequency(RecurringFrequency frequency) {
    final s = state;
    if (s is! AiQuickTxPreview) return;
    state = AiQuickTxPreview(
      s.draft.copyWith(isRecurring: true, recurringFrequency: frequency),
    );
  }

  void updateDraft(AiTransactionDraft draft) => state = AiQuickTxPreview(draft);

  // ── Confirm ───────────────────────────────────────────────────────────────

  Future<void> confirm() async {
    final s = state;
    if (s is! AiQuickTxPreview) return;
    final draft = s.draft;
    if (!draft.isComplete || draft.type == null) return;

    state = const AiQuickTxSaving();

    try {
      // Resolve entity (lookup by name or create inline)
      String? entityId;
      if (draft.type != TransactionType.transfer && draft.entityName != null) {
        entityId = await _resolveOrCreateEntity(
          draft.entityName!,
          draft.type == TransactionType.income ? 'payer' : 'payee',
        );
      }

      final txId = await ref
          .read(createTransactionProvider)
          .call(
            date: draft.date,
            description: draft.description,
            type: draft.type!.name,
            amount: (draft.amount * 100).round(),
            categoryId: draft.categoryId,
            accountId: draft.accountId!,
            toAccountId: draft.type == TransactionType.transfer
                ? draft.toAccountId
                : null,
            entityId: entityId,
          );

      if (draft.isRecurring && draft.recurringFrequency != null) {
        await ref.read(createRecurringRuleProvider)(
          baseTransactionId: txId,
          frequency: draft.recurringFrequency!,
          interval: 1,
          startDate: draft.date,
          autoConfirm: false,
        );
      }

      state = const AiQuickTxDone();
    } catch (e, st) {
      debugPrint('[AiQuickTx] Erro ao salvar: $e\n$st');
      state = AiQuickTxError('Erro ao salvar transação: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Finds an existing entity by name (case-insensitive) or creates a new one.
  Future<String> _resolveOrCreateEntity(String name, String type) async {
    final entities = ref.read(allEntitiesProvider).value ?? [];
    final existing = entities
        .where((e) => e.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (existing != null) return existing.id;

    final newId = const Uuid().v4();
    final database = ref.read(databaseProvider);
    await database.entitiesDao.insertEntity(
      db.EntitiesCompanion.insert(
        id: newId,
        name: name,
        type: type,
        useCount: const drift.Value(0),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
    return newId;
  }

  AiTransactionDraft _parseResponse(String raw, String rawInput) {
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleaned);
      if (jsonMatch == null) return _heuristicFallback(rawInput);

      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

      final typeStr = (json['type'] as String? ?? 'unknown').toLowerCase();
      TransactionType? type;
      if (typeStr == 'income') type = TransactionType.income;
      if (typeStr == 'expense') type = TransactionType.expense;
      if (typeStr == 'transfer') type = TransactionType.transfer;

      // Date
      DateTime parsedDate = DateTime.now();
      final dateStr = json['date'] as String?;
      if (dateStr != null) {
        try {
          parsedDate = DateTime.parse(dateStr);
        } catch (_) {}
      }

      final categoryId = json['categoryId'] as String?;
      final accountId = json['accountId'] as String?;
      final toAccountId = json['toAccountId'] as String?;
      final isRecurring = json['isRecurring'] as bool? ?? false;
      final entityName = (json['entityName'] as String?)?.trim();

      final freqStr = json['recurringFrequency'] as String?;
      final frequency = freqStr != null ? _parseFrequency(freqStr) : null;

      final allCats = ref.read(allFlatCategoriesProvider);
      final rawSuggestions =
          (json['categorySuggestions'] as List<dynamic>? ?? [])
              .whereType<String>()
              .toList();
      final suggestions = rawSuggestions
          .map((id) {
            final cat = allCats.where((c) => c.id == id).firstOrNull;
            return cat != null ? (id: cat.id, name: cat.name) : null;
          })
          .nonNulls
          .toList();

      final categoryName = categoryId != null
          ? allCats.where((c) => c.id == categoryId).firstOrNull?.name
          : null;

      final allAccounts = ref.read(activeAccountsProvider);
      final resolvedAccountId = accountId ?? _defaultAccountId();
      final accountName = resolvedAccountId != null
          ? allAccounts
                .where((a) => a.id == resolvedAccountId)
                .firstOrNull
                ?.name
          : null;

      final toAccountName = toAccountId != null
          ? allAccounts.where((a) => a.id == toAccountId).firstOrNull?.name
          : null;

      return AiTransactionDraft(
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        description: (json['description'] as String?)?.trim().isNotEmpty == true
            ? json['description'] as String
            : rawInput,
        type: type,
        categoryId: categoryId,
        categoryName: categoryName,
        categorySuggestions: suggestions,
        accountId: resolvedAccountId,
        accountName: accountName,
        toAccountId: toAccountId,
        toAccountName: toAccountName,
        entityName: entityName?.isEmpty == true ? null : entityName,
        date: parsedDate,
        rawInput: rawInput,
        isRecurring: isRecurring,
        recurringFrequency: frequency,
      );
    } catch (e) {
      debugPrint('[AiQuickTx] JSON parse error: $e');
      return _heuristicFallback(rawInput);
    }
  }

  AiTransactionDraft _heuristicFallback(String rawInput) {
    final lower = rawInput.toLowerCase();
    final now = DateTime.now();

    final amountMatch = RegExp(r'(\d+(?:[.,]\d{1,2})?)').firstMatch(rawInput);
    final amount = amountMatch != null
        ? double.tryParse(amountMatch.group(1)!.replaceAll(',', '.')) ?? 0
        : 0.0;

    TransactionType? type;
    if (RegExp(
      r'\b(paguei|gastei|comprei|pagar|despesa|saiu)\b',
    ).hasMatch(lower)) {
      type = TransactionType.expense;
    } else if (RegExp(
      r'\b(recebi|salário|entrada|renda|ganho|receber)\b',
    ).hasMatch(lower)) {
      type = TransactionType.income;
    } else if (RegExp(
      r'\b(transferi|transferência|enviei)\b',
    ).hasMatch(lower)) {
      type = TransactionType.transfer;
    }

    // Date heuristic
    DateTime parsedDate = now;
    if (RegExp(r'\bontem\b').hasMatch(lower)) {
      parsedDate = now.subtract(const Duration(days: 1));
    } else if (RegExp(r'\bamanhã\b').hasMatch(lower)) {
      parsedDate = now.add(const Duration(days: 1));
    } else if (RegExp(r'\bsemana passada\b').hasMatch(lower)) {
      parsedDate = now.subtract(const Duration(days: 7));
    } else if (RegExp(r'\bmês passado\b').hasMatch(lower)) {
      final m = now.month == 1 ? 12 : now.month - 1;
      final y = now.month == 1 ? now.year - 1 : now.year;
      parsedDate = DateTime(y, m, now.day);
    } else {
      final dayMatch = RegExp(r'\bdia\s+(\d{1,2})\b').firstMatch(lower);
      if (dayMatch != null) {
        final day = int.tryParse(dayMatch.group(1)!);
        if (day != null && day >= 1 && day <= 31) {
          final candidate = DateTime(now.year, now.month, day);
          parsedDate = candidate.isAfter(now)
              ? DateTime(now.year, now.month == 1 ? 12 : now.month - 1, day)
              : candidate;
        }
      } else {
        const weekdays = {
          'segunda': DateTime.monday,
          'terça': DateTime.tuesday,
          'quarta': DateTime.wednesday,
          'quinta': DateTime.thursday,
          'sexta': DateTime.friday,
          'sábado': DateTime.saturday,
          'domingo': DateTime.sunday,
        };
        for (final entry in weekdays.entries) {
          if (lower.contains(entry.key)) {
            int diff = (now.weekday - entry.value) % 7;
            if (diff == 0) diff = 7;
            parsedDate = now.subtract(Duration(days: diff));
            break;
          }
        }
      }
    }

    // Recurrence heuristic
    bool isRecurring = false;
    RecurringFrequency? frequency;
    if (RegExp(r'\b(todo\s+dia|diário|diaria|diariamente)\b').hasMatch(lower)) {
      isRecurring = true;
      frequency = RecurringFrequency.daily;
    } else if (RegExp(
      r'\b(toda\s+semana|todo\s+semana|semanal|semanalmente)\b',
    ).hasMatch(lower)) {
      isRecurring = true;
      frequency = RecurringFrequency.weekly;
    } else if (RegExp(r'\b(quinzenal|quinzenalmente)\b').hasMatch(lower)) {
      isRecurring = true;
      frequency = RecurringFrequency.biweekly;
    } else if (RegExp(
      r'\b(todo\s+mês|toda\s+mês|mensal|mensalidade|assinatura|recorrente|fixo\s+mensal)\b',
    ).hasMatch(lower)) {
      isRecurring = true;
      frequency = RecurringFrequency.monthly;
    } else if (RegExp(r'\b(anual|todo\s+ano)\b').hasMatch(lower)) {
      isRecurring = true;
      frequency = RecurringFrequency.yearly;
    }

    final defaultId = _defaultAccountId();
    final allAccounts = ref.read(activeAccountsProvider);
    final defaultAccount = defaultId != null
        ? allAccounts.where((a) => a.id == defaultId).firstOrNull
        : allAccounts.firstOrNull;

    return AiTransactionDraft(
      amount: amount,
      description: rawInput,
      type: type,
      accountId: defaultAccount?.id,
      accountName: defaultAccount?.name,
      date: parsedDate,
      rawInput: rawInput,
      isRecurring: isRecurring,
      recurringFrequency: frequency,
    );
  }

  String? _defaultAccountId() =>
      ref.read(defaultAccountIdProvider) ??
      ref.read(activeAccountsProvider).firstOrNull?.id;

  RecurringFrequency? _parseFrequency(String raw) =>
      switch (raw.toLowerCase()) {
        'daily' => RecurringFrequency.daily,
        'weekly' => RecurringFrequency.weekly,
        'biweekly' => RecurringFrequency.biweekly,
        'monthly' => RecurringFrequency.monthly,
        'yearly' => RecurringFrequency.yearly,
        _ => null,
      };
}

final aiQuickTxProvider = NotifierProvider<AiQuickTxNotifier, AiQuickTxState>(
  AiQuickTxNotifier.new,
);

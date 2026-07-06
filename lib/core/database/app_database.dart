import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../constants/default_categories.dart';

// Tables
import 'tables/accounts.dart';
import 'tables/app_settings.dart';
import 'tables/attachments.dart';
import 'tables/categories.dart';
import 'tables/credit_cards.dart';
import 'tables/entities.dart';
import 'tables/entries.dart';
import 'tables/financing_installments.dart';
import 'tables/financings.dart';
import 'tables/goals.dart';
import 'tables/holidays.dart';
import 'tables/installment_plans.dart';
import 'tables/investments.dart';
import 'tables/invoices.dart';
import 'tables/notification_patterns.dart';
import 'tables/recurring_rules.dart';
import 'tables/scheduled_reminders.dart';
import 'tables/transactions.dart';
import 'tables/sync_queue.dart';
import 'tables/households.dart';
import 'tables/nostr_event_log.dart';
import 'tables/streaks.dart';
import 'tables/badges.dart';
import 'tables/category_parents.dart';
import 'tables/goal_categories.dart';
import 'tables/chat_messages.dart';
import 'tables/budgets.dart';
import 'tables/transaction_splits.dart';
import 'tables/reconciliation_checkpoints.dart';

// DAOs (To be added later)
import 'daos/accounts_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/credit_cards_dao.dart';
import 'daos/entities_dao.dart';
import 'daos/financings_dao.dart';
import 'daos/goals_dao.dart';
import 'daos/investments_dao.dart';
import 'daos/invoices_dao.dart';
import 'daos/notification_patterns_dao.dart';
import 'daos/recurring_rules_dao.dart';
import 'daos/scheduled_reminders_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/households_dao.dart';
import 'daos/nostr_event_log_dao.dart';
import 'daos/streaks_dao.dart';
import 'daos/badges_dao.dart';
import 'daos/budgets_dao.dart';
import 'daos/reconciliation_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    AppSettings,
    Attachments,
    Categories,
    CreditCards,
    Entities,
    Entries,
    FinancingInstallments,
    Financings,
    Goals,
    Holidays,
    InstallmentPlans,
    Investments,
    Invoices,
    NotificationPatterns,
    RecurringRules,
    ScheduledReminders,
    Transactions,
    SyncQueue,
    Households,
    HouseholdMembers,
    Streaks,
    Badges,
    CategoryParents,
    GoalCategories,
    ChatMessages,
    Budgets,
    TransactionSplits,
    ReconciliationCheckpoints,
    NostrEventLog,
  ],
  daos: [
    AccountsDao,
    CategoriesDao,
    CreditCardsDao,
    EntitiesDao,
    FinancingsDao,
    GoalsDao,
    InvestmentsDao,
    InvoicesDao,
    NotificationPatternsDao,
    RecurringRulesDao,
    ScheduledRemindersDao,
    TransactionsDao,
    SyncQueueDao,
    HouseholdsDao,
    StreaksDao,
    BadgesDao,
    BudgetsDao,
    ReconciliationDao,
    NostrEventLogDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 22;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Seed default categories
        await batch((batch) {
          batch.insertAll(
            categories,
            SeedDataConstants.defaultCategories.map((c) {
              return CategoriesCompanion.insert(
                id: c.id,
                name: c.name,
                icon: c.icon,
                color: c.color,
                type: c.type.name,
                isSystem: const Value(true),
                description: c.description != null
                    ? Value(c.description)
                    : const Value.absent(),
              );
            }).toList(),
          );
        });

        // Seed default category parent-child relationships
        await batch((batch) {
          batch.insertAll(
            categoryParents,
            SeedDataConstants.defaultCategoryRelationships
                .map(
                  (r) => CategoryParentsCompanion.insert(
                    parentCategoryId: r.$1,
                    childCategoryId: r.$2,
                  ),
                )
                .toList(),
          );
        });

        // Seed national holidays for the current year
        final currentYear = DateTime.now().year;
        await batch((batch) {
          batch.insertAll(
            holidays,
            SeedDataConstants.nationalHolidays.map((h) {
              final uuid = const Uuid().v4();
              return HolidaysCompanion.insert(
                id: uuid,
                name: h.name,
                date: DateTime(currentYear, h.month, h.day),
                isRecurring: const Value(true),
              );
            }).toList(),
          );
        });
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(recurringRules, recurringRules.status);
          await m.addColumn(recurringRules, recurringRules.autoConfirm);
        }
        if (from < 3) {
          await m.addColumn(transactions, transactions.installmentPlanId);
          await m.addColumn(transactions, transactions.installmentNumber);
        }
        if (from < 4) {
          await m.addColumn(goals, goals.status);
          await m.addColumn(goals, goals.description);
        }
        if (from < 5) {
          await m.addColumn(transactions, transactions.isConfirmed);
          await m.addColumn(transactions, transactions.source);
          await m.addColumn(
            notificationPatterns,
            notificationPatterns.bankName,
          );
          await m.addColumn(
            notificationPatterns,
            notificationPatterns.isEnabled,
          );
          // Seed default bank patterns
          await _seedDefaultNotificationPatterns();
        }
        if (from < 6) {
          await m.createTable(syncQueue);
          await m.createTable(households);
          await m.createTable(householdMembers);
        }
        if (from < 7) {
          await m.createTable(streaks);
          await m.createTable(badges);
        }
        if (from < 8) {
          await m.addColumn(goals, goals.type);
          await m.addColumn(transactions, transactions.goalId);
        }
        if (from < 9) {
          await m.addColumn(entities, entities.category);
        }
        if (from < 11) {
          await m.addColumn(transactions, transactions.recurringRuleId);
        }
        if (from < 12) {
          await m.addColumn(creditCards, creditCards.minPaymentPercent);
        }
        if (from < 10) {
          await m.createIndex(attachmentsTransactionIdx);
          await m.createIndex(categoriesParentIdx);
          await m.createIndex(creditCardsAccountIdx);
          await m.createIndex(entriesTransactionIdx);
          await m.createIndex(entriesAccountIdx);
          await m.createIndex(financingInstallmentsFinancingIdx);
          await m.createIndex(goalsAccountIdx);
          await m.createIndex(installmentPlansOriginTransactionIdx);
          await m.createIndex(invoicesCreditCardIdx);
          await m.createIndex(notificationPatternsCategoryIdx);
          await m.createIndex(notificationPatternsAccountIdx);
          await m.createIndex(recurringRulesBaseTransactionIdx);
          await m.createIndex(transactionsConfirmedDateIdx);
          await m.createIndex(transactionsCategoryIdx);
          await m.createIndex(transactionsEntityIdx);
          await m.createIndex(transactionsGoalIdx);
          await m.createIndex(householdMembersHouseholdIdx);
        }
        if (from < 14) {
          await m.addColumn(transactions, transactions.creditCardId);
          await m.addColumn(transactions, transactions.rawAmount);
          await m.addColumn(transactions, transactions.invoiceId);
        }
        if (from < 13) {
          await m.addColumn(categories, categories.description);
          // Update default descriptions for existing system categories
          final systemCategories = {
            'cat_opening_balance':
                'Saldo inicial inserido ao criar uma conta ou ajustar saldo manual.',
            'cat_salary':
                'Receitas provenientes de salário recorrente, remuneração fixa ou pagamentos trabalhistas.',
            'cat_freelance':
                'Rendas extras, serviços autônomos ou projetos esporádicos.',
            'cat_investments_yield':
                'Rendimentos de investimentos, dividendos, juros de poupança ou outras aplicações.',
            'cat_housing':
                'Despesas gerais relacionadas à moradia, condomínio, taxas, reformas ou utilidades.',
            'cat_rent':
                'Pagamento mensal de aluguel ou financiamento imobiliário residencial.',
            'cat_food':
                'Gastos com supermercado, restaurantes, feiras, delivery ou lanches rápidos.',
            'cat_transport':
                'Gastos com combustível, transporte público, carros por aplicativo, pedágio ou manutenção de veículos.',
            'cat_health':
                'Despesas com planos de saúde, farmácia, consultas médicas, dentistas ou exames.',
            'cat_education':
                'Gastos com mensalidades escolares, faculdade, cursos, livros ou materiais educativos.',
            'cat_leisure':
                'Despesas com cinema, viagens, shows, festas, hobbies ou entretenimento em geral.',
            'cat_clothing':
                'Gastos com roupas, sapatos, acessórios ou itens de vestuário.',
            'cat_transfer':
                'Movimentação de fundos entre contas próprias ou ajustes de transferência interna.',
          };
          for (final entry in systemCategories.entries) {
            await (update(categories)..where((t) => t.id.equals(entry.key)))
                .write(CategoriesCompanion(description: Value(entry.value)));
          }
        }
        if (from < 15) {
          await m.createTable(categoryParents);
          // Migrate existing parentId relationships to the junction table
          await customStatement(
            'INSERT OR IGNORE INTO category_parents (parent_category_id, child_category_id) '
            'SELECT parent_id, id FROM categories WHERE parent_id IS NOT NULL',
          );
        }
        if (from < 16) {
          await m.createTable(goalCategories);
          await m.addColumn(goals, goals.isRecurring);
          await m.addColumn(goals, goals.recurrenceFrequency);
          await m.addColumn(goals, goals.periodStartDate);
        }
        if (from < 17) {
          await m.createTable(chatMessages);
        }
        if (from < 18) {
          // Feature: Orçamento Envelope
          await m.createTable(budgets);
          // Feature: Reconciliação de Contas
          await m.addColumn(entries, entries.reconciledAt);
          await m.createTable(reconciliationCheckpoints);
          // Feature: Split de Transações
          await m.addColumn(transactions, transactions.isSplit);
          await m.createTable(transactionSplits);
        }
        if (from < 19) {
          await m.createTable(nostrEventLog);
        }
        if (from < 20) {
          await _seedNewDefaultCategories();
        }
        if (from < 21) {
          await m.createIndex(nostrEventLogPublishedIdx);
        }
        if (from < 22) {
          await m.createTable(scheduledReminders);
          await m.createIndex(scheduledRemindersTransactionIdx);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
        await customStatement('PRAGMA synchronous = NORMAL');
        // Without this, any write that races a pending watch-stream re-query
        // on the same connection (e.g. sync writing to sync_queue while
        // watchPendingCount() re-evaluates) fails immediately with
        // SQLITE_BUSY/SQLITE_BUSY_SNAPSHOT instead of waiting for the other
        // statement to finish.
        await customStatement('PRAGMA busy_timeout = 5000');

        // Ensure system opening balance category exists
        final openingBalanceExists = await (select(
          categories,
        )..where((t) => t.id.equals('cat_opening_balance'))).getSingleOrNull();

        if (openingBalanceExists == null) {
          await into(categories).insert(
            CategoriesCompanion.insert(
              id: 'cat_opening_balance',
              name: 'Saldo Inicial',
              icon: 'account_balance_wallet',
              color: '#9E9E9E',
              type: 'income',
              isSystem: const Value(true),
            ),
          );
        }

        // Seed default badges and streaks
        await _seedDefaultBadges();
        await _seedDefaultStreaks();
      },
    );
  }

  Future<void> _seedDefaultNotificationPatterns() async {
    const banks = [
      (
        'nubank',
        'Nubank',
        r'Compra aprovada de R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
      ),
      (
        'nubank_2',
        'Nubank',
        r'Débito de R\$\s*(?<amount>[\d.,]+)\s+-\s*(?<merchant>.+)',
      ),
      (
        'inter',
        'Inter',
        r'Débito R\$\s*(?<amount>[\d.,]+)\s*-\s*(?<merchant>.+)',
      ),
      (
        'inter_pix',
        'Inter',
        r'PIX enviado de R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
      ),
      (
        'itau',
        'Itaú',
        r'Compra no crédito de R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
      ),
      (
        'itau_pix',
        'Itaú',
        r'Pix enviado: R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
      ),
      (
        'bradesco',
        'Bradesco',
        r'Compra aprovada de R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
      ),
      (
        'bradesco_pix',
        'Bradesco',
        r'Pix no valor de R\$\s*(?<amount>[\d.,]+)\s+enviado para\s+(?<merchant>.+)',
      ),
      (
        'bb',
        'Banco do Brasil',
        r'Compra de R\$\s*(?<amount>[\d.,]+)\s+(?<merchant>.+)',
      ),
      (
        'bb_pix',
        'Banco do Brasil',
        r'Pix enviado: R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
      ),
      (
        'c6',
        'C6 Bank',
        r'Compra aprovada: R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
      ),
      (
        'picpay',
        'PicPay',
        r'Você pagou R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
      ),
    ];

    for (final (id, bankName, pattern) in banks) {
      final exists = await (select(
        notificationPatterns,
      )..where((t) => t.id.equals('default_$id'))).getSingleOrNull();
      if (exists == null) {
        await into(notificationPatterns).insert(
          NotificationPatternsCompanion.insert(
            id: 'default_$id',
            bankName: Value(bankName),
            regexPattern: pattern,
            isEnabled: const Value(true),
          ),
        );
      }
    }
  }

  Future<void> _seedNewDefaultCategories() async {
    for (final c in SeedDataConstants.defaultCategories) {
      final exists = await (select(
        categories,
      )..where((t) => t.id.equals(c.id))).getSingleOrNull();
      if (exists == null) {
        await into(categories).insert(
          CategoriesCompanion.insert(
            id: c.id,
            name: c.name,
            icon: c.icon,
            color: c.color,
            type: c.type.name,
            isSystem: const Value(true),
            description: c.description != null
                ? Value(c.description)
                : const Value.absent(),
          ),
        );
      }
    }

    for (final r in SeedDataConstants.defaultCategoryRelationships) {
      final exists =
          await (select(categoryParents)..where(
                (t) =>
                    t.parentCategoryId.equals(r.$1) &
                    t.childCategoryId.equals(r.$2),
              ))
              .getSingleOrNull();
      if (exists == null) {
        await into(categoryParents).insert(
          CategoryParentsCompanion.insert(
            parentCategoryId: r.$1,
            childCategoryId: r.$2,
          ),
        );
      }
    }
  }

  Future<void> _seedDefaultBadges() async {
    final badgesToSeed = [
      (
        'first_transaction',
        'Primeiro registro',
        'Registre sua primeira transação no aplicativo',
        'first_transaction',
      ),
      (
        'seven_days_streak',
        'Mão na massa',
        'Complete uma sequência de 7 dias registrando transações',
        'seven_days_streak',
      ),
      (
        'emergency_fund',
        'Fundo de emergência',
        'Crie um objetivo com o nome "Emergência"',
        'emergency_fund',
      ),
      (
        'debt_free',
        'Livre de dívidas',
        'Mantenha o sistema livre de qualquer financiamento ativo',
        'debt_free',
      ),
      (
        'goal_reached',
        'Meta atingida',
        'Conclua com sucesso seu primeiro objetivo financeiro',
        'goal_reached',
      ),
      (
        'finance_master',
        'Mestre das finanças',
        'Mantenha-se sob o orçamento diário por 30 dias consecutivos',
        'finance_master',
      ),
      (
        'investor',
        'Investidor',
        'Registre seu primeiro investimento no aplicativo',
        'investor',
      ),
      (
        'installment_completed',
        'Parcelamento quitado',
        'Pague todas as parcelas de um parcelamento ou financiamento',
        'installment_completed',
      ),
    ];

    for (final (key, title, description, icon) in badgesToSeed) {
      final exists = await (select(
        badges,
      )..where((t) => t.badgeKey.equals(key))).getSingleOrNull();
      if (exists == null) {
        await into(badges).insert(
          BadgesCompanion.insert(
            id: 'badge_$key',
            badgeKey: key,
            title: title,
            description: description,
            iconAsset: icon,
            unlockedAt: const Value.absent(),
          ),
        );
      }
    }
  }

  Future<void> _seedDefaultStreaks() async {
    final streaksToSeed = [
      ('recording_streak', 'recording'),
      ('budget_streak', 'budget'),
    ];

    for (final (id, type) in streaksToSeed) {
      final exists = await (select(
        streaks,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (exists == null) {
        await into(streaks).insert(
          StreaksCompanion.insert(
            id: id,
            type: type,
            currentCount: const Value(0),
            longestCount: const Value(0),
            lastDate: const Value.absent(),
            isActive: const Value(true),
          ),
        );
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'bestfin.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

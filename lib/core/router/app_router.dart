import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/shell/app_shell.dart';
import 'package:bestfin/core/shell/detail_shell.dart';
import 'package:bestfin/features/accounts/presentation/screens/account_form_screen.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/accounts/presentation/screens/accounts_list_screen.dart';
import 'package:bestfin/features/accounts/presentation/screens/account_detail_screen.dart';
import 'package:bestfin/features/accounts/presentation/screens/reconciliation_screen.dart';
import 'package:bestfin/features/dashboard/dashboard_screen.dart';
import 'package:bestfin/features/gamification/presentation/screens/gamification_hub_screen.dart';
import 'package:bestfin/features/more/presentation/screens/more_screen.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:bestfin/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:bestfin/features/installments/presentation/screens/installments_list_screen.dart';
import 'package:bestfin/features/settings/presentation/screens/settings_screen.dart';
import 'package:bestfin/features/transactions/presentation/screens/bulk_transaction_screen.dart';
import 'package:bestfin/features/transactions/presentation/screens/transaction_form_screen.dart';
import 'package:bestfin/features/transactions/presentation/screens/transaction_group_screen.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:bestfin/features/recurring/presentation/screens/recurring_list_screen.dart';
import 'package:bestfin/features/recurring/presentation/screens/subscriptions_hub_screen.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/goals/presentation/screens/goals_list_screen.dart';
import 'package:bestfin/features/goals/presentation/screens/goal_form_screen.dart';
import 'package:bestfin/features/goals/presentation/screens/goal_detail_screen.dart';
import 'package:bestfin/features/backup/presentation/screens/backup_screen.dart';
import 'package:bestfin/features/reports/presentation/screens/reports_hub_screen.dart';
import 'package:bestfin/features/investments/presentation/screens/portfolio_screen.dart';
import 'package:bestfin/features/investments/presentation/screens/investment_form_screen.dart';
import 'package:bestfin/features/investments/presentation/screens/investment_detail_screen.dart';
import 'package:bestfin/features/financing/presentation/screens/financing_list_screen.dart';
import 'package:bestfin/features/financing/presentation/screens/financing_form_screen.dart';
import 'package:bestfin/features/financing/presentation/screens/financing_detail_screen.dart';
import 'package:bestfin/features/notifications/presentation/screens/review_queue_screen.dart';
import 'package:bestfin/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/login_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/register_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/sync_settings_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/household_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/mnemonic_recovery_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/mnemonic_display_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/identity_qr_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/qr_scanner_screen.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/presentation/screens/categories_screen.dart';
import 'package:bestfin/features/categories/presentation/screens/category_form_screen.dart';
import 'package:bestfin/features/investments/domain/models/investment.dart';
import 'package:bestfin/features/credit_cards/presentation/screens/credit_cards_list_screen.dart';
import 'package:bestfin/features/credit_cards/presentation/screens/credit_card_form_screen.dart';
import 'package:bestfin/features/credit_cards/presentation/screens/credit_card_detail_screen.dart';
import 'package:bestfin/features/credit_cards/presentation/screens/invoice_detail_screen.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';
import 'package:bestfin/features/security/presentation/screens/pin_setup_screen.dart';
import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';
import 'package:bestfin/features/pdf_import/presentation/screens/pdf_import_screen.dart';
import 'package:bestfin/features/pdf_import/presentation/screens/pdf_review_screen.dart';
import 'package:bestfin/features/budgets/presentation/screens/budgets_list_screen.dart';
import 'package:bestfin/features/cashflow/presentation/screens/cashflow_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  bool _onboardingCompleted;

  _RouterNotifier(this._onboardingCompleted);

  void update(bool value) {
    _onboardingCompleted = value;
    notifyListeners();
  }

  bool get onboardingCompleted => _onboardingCompleted;
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  final isCompleted = ref.read(onboardingCompletedProvider);
  final notifier = _RouterNotifier(isCompleted);

  ref.listen<bool>(
    onboardingCompletedProvider,
    (_, next) => notifier.update(next),
  );
  ref.onDispose(notifier.dispose);

  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final isOnboarding = state.matchedLocation.startsWith('/onboarding');
      final isSyncAuth =
          state.matchedLocation.startsWith('/sync/login') ||
          state.matchedLocation.startsWith('/sync/scan') ||
          state.matchedLocation.startsWith('/sync/recover') ||
          state.matchedLocation.startsWith('/sync/register');
      // Rotas que os próprios steps do onboarding abrem por push — sem esta
      // exceção o guard as rebate para /onboarding e o usuário volta ao
      // início do wizard ao tentar configurar PIN ou criar categoria.
      final isOnboardingSubflow =
          state.matchedLocation.startsWith('/security/pin-setup') ||
          state.matchedLocation.startsWith('/categories/new');
      if (!notifier.onboardingCompleted) {
        return (isOnboarding || isSyncAuth || isOnboardingSubflow)
            ? null
            : '/onboarding';
      }
      return isOnboarding ? '/home' : null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/transaction/new',
        builder: (context, state) {
          final typeStr = state.uri.queryParameters['type'];
          final isCloning = state.uri.queryParameters['isCloning'] == 'true';
          final type = typeStr != null
              ? TransactionType.fromString(typeStr)
              : TransactionType.expense;
          final prefilled = state.extra as TransactionModel?;
          return TransactionFormScreen(
            initialType: type,
            transaction: prefilled,
            isCloning: isCloning,
          );
        },
      ),
      GoRoute(
        path: '/transaction/bulk-new',
        builder: (context, state) {
          final typeStr = state.uri.queryParameters['type'];
          return BulkTransactionScreen(
            initialType: typeStr != null
                ? TransactionType.fromString(typeStr)
                : TransactionType.expense,
          );
        },
      ),
      GoRoute(
        path: '/transaction/edit',
        builder: (context, state) {
          final tx = state.extra as TransactionModel;
          return TransactionFormScreen(transaction: tx);
        },
      ),
      GoRoute(
        path: '/transaction/group/:groupId',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return TransactionGroupScreen(groupId: groupId);
        },
      ),
      // ── Páginas de feature (hub "Mais") ──────────────────────────────────
      // Em telas largas renderizam ao lado da barra lateral persistente (só na
      // área de conteúdo); em mobile, tela cheia com botão de voltar. As rotas
      // e chamadas `push('/...')` existentes seguem inalteradas.
      ShellRoute(
        builder: (context, state, child) => DetailShell(child: child),
        routes: [
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsListScreen(),
          ),
          GoRoute(
            path: '/accounts/new',
            builder: (context, state) => const AccountFormScreen(),
          ),
          GoRoute(
            path: '/accounts/edit',
            builder: (context, state) {
              final account = state.extra as Account;
              return AccountFormScreen(accountToEdit: account);
            },
          ),
          GoRoute(
            path: '/accounts/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return AccountDetailScreen(accountId: id);
            },
          ),
          GoRoute(
            path: '/accounts/:id/reconcile',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ReconciliationScreen(accountId: id);
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/budgets',
            builder: (context, state) => const BudgetsListScreen(),
          ),
          GoRoute(
            path: '/cashflow',
            builder: (context, state) => const CashFlowScreen(),
          ),
          GoRoute(
            path: '/backup',
            builder: (context, state) => const BackupScreen(),
          ),
          GoRoute(
            path: '/installments',
            builder: (context, state) => const InstallmentsListScreen(),
          ),
          GoRoute(
            path: '/recurring',
            builder: (context, state) => const RecurringListScreen(),
          ),
          GoRoute(
            path: '/recurring/subscriptions',
            builder: (context, state) => const SubscriptionsHubScreen(),
          ),
          GoRoute(
            path: '/goals',
            builder: (context, state) => const GoalsListScreen(),
          ),
          GoRoute(
            path: '/goals/new',
            builder: (context, state) => const GoalFormScreen(),
          ),
          GoRoute(
            path: '/goals/edit',
            builder: (context, state) {
              final goal = state.extra as GoalModel;
              return GoalFormScreen(existingGoal: goal);
            },
          ),
          GoRoute(
            path: '/goals/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return GoalDetailScreen(goalId: id);
            },
          ),
          GoRoute(
            path: '/investments',
            builder: (context, state) => const PortfolioScreen(),
          ),
          GoRoute(
            path: '/investments/new',
            builder: (context, state) => const InvestmentFormScreen(),
          ),
          GoRoute(
            path: '/investments/edit',
            builder: (context, state) {
              final inv = state.extra as Investment;
              return InvestmentFormScreen(existingInvestment: inv);
            },
          ),
          GoRoute(
            path: '/investments/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return InvestmentDetailScreen(investmentId: id);
            },
          ),
          GoRoute(
            path: '/financing',
            builder: (context, state) => const FinancingListScreen(),
          ),
          GoRoute(
            path: '/financing/new',
            builder: (context, state) => const FinancingFormScreen(),
          ),
          GoRoute(
            path: '/financing/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return FinancingDetailScreen(financingId: id);
            },
          ),
          GoRoute(
            path: '/notifications/review',
            builder: (context, state) => const ReviewQueueScreen(),
          ),
          GoRoute(
            path: '/notifications/settings',
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: '/sync',
            builder: (context, state) => const SyncSettingsScreen(),
          ),
          GoRoute(
            path: '/sync/household',
            builder: (context, state) => const HouseholdScreen(),
          ),
          GoRoute(
            path: '/gamification',
            builder: (context, state) => const GamificationHubScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: '/categories/edit',
            builder: (context, state) {
              final cat = state.extra as CategoryModel;
              return CategoryFormScreen(categoryToEdit: cat);
            },
          ),
          GoRoute(
            path: '/credit-cards',
            builder: (context, state) => const CreditCardsListScreen(),
          ),
          GoRoute(
            path: '/credit-cards/new',
            builder: (context, state) => const CreditCardFormScreen(),
          ),
          GoRoute(
            path: '/credit-cards/edit',
            builder: (context, state) {
              final card = state.extra as CreditCardModel;
              return CreditCardFormScreen(card: card);
            },
          ),
          GoRoute(
            path: '/credit-cards/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CreditCardDetailScreen(cardId: id);
            },
          ),
          GoRoute(
            path: '/credit-cards/:cardId/invoices/:invoiceId',
            builder: (context, state) {
              final cardId = state.pathParameters['cardId']!;
              final invoiceId = state.pathParameters['invoiceId']!;
              return InvoiceDetailScreen(cardId: cardId, invoiceId: invoiceId);
            },
          ),
          GoRoute(
            path: '/pdf-import',
            builder: (context, state) => const PdfImportScreen(),
          ),
          GoRoute(
            path: '/pdf-import/review',
            builder: (context, state) {
              final transactions = state.extra as List<PdfParsedTransaction>;
              return PdfReviewScreen(transactions: transactions);
            },
          ),
        ],
      ),
      // ── Rotas de tela cheia (sem barra lateral) ──────────────────────────
      // Fluxos de autenticação do sync, configuração de PIN e criação de
      // categoria (subfluxo do onboarding) permanecem cobrindo a tela inteira.
      GoRoute(
        path: '/sync/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/sync/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/sync/recover',
        builder: (context, state) => const MnemonicRecoveryScreen(),
      ),
      GoRoute(
        path: '/sync/mnemonic-display',
        builder: (context, state) =>
            MnemonicDisplayScreen(mnemonic: state.extra as String),
      ),
      GoRoute(
        path: '/sync/qr',
        builder: (context, state) =>
            IdentityQrScreen(masterKey: state.extra as List<int>),
      ),
      GoRoute(
        path: '/sync/scan',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/categories/new',
        builder: (context, state) => const CategoryFormScreen(),
      ),
      GoRoute(
        path: '/security/pin-setup',
        builder: (context, state) => const PinSetupScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

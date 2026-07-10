import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/account_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/byte_formatter.dart';
import 'package:bestfin/features/backup/domain/usecases/backup_database.dart';
import 'package:bestfin/features/backup/domain/usecases/import_data.dart';
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/create_account_step.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/notification_permission_step.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/profile_step.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/security_step.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/select_categories_step.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/welcome_step.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart'
    show SyncPhaseKind;
import 'package:bestfin/features/sync/domain/models/sync_identity.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';
import 'package:bestfin/features/sync/presentation/widgets/relay_status_section.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _totalPages = 6;

  // Retoma do último step persistido — sem isso, se o SO matar o processo
  // no meio do setup, o wizard volta ao início e o usuário refaz tudo
  // (inclusive a conta do step 1, que já foi criada no banco).
  late final PageController _controller;
  late int _currentPage;
  bool _isSyncing = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _currentPage = initialOnboardingStep.clamp(0, _totalPages - 1);
    _controller = PageController(initialPage: _currentPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final identity = ref.read(currentIdentityProvider).value;
      if (identity != null) {
        setState(() {
          _isSyncing = true;
        });
        ref.read(syncStateProvider.notifier).syncNow();
      }
    });
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool _finishing = false;

  /// Cria a conta configurada no step 1 (a criação é adiada até aqui — se o
  /// usuário abandonar o onboarding, nada é gravado no banco) e então marca
  /// o onboarding como completo.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      final draft = ref.read(onboardingAccountDraftProvider);
      if (draft != null && draft.name.trim().isNotEmpty) {
        final type = AccountType.fromString(draft.type);
        try {
          await ref.read(createAccountProvider)(
            name: draft.name.trim(),
            type: type.name,
            icon: type.defaultIcon.codePoint.toString(),
            color: draft.colorHex.isNotEmpty
                ? draft.colorHex
                : type.defaultColorHex,
            initialBalance: draft.balanceCents,
          );
          ref.invalidate(accountsProvider);
        } on DuplicateAccountNameException {
          // Conta homônima já existe (ex.: restaurada via sync) — segue.
        }
      }
      await OnboardingActions.complete(ref);
      // Router guard will automatically navigate to /home
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao criar conta: $e')));
      }
    } finally {
      _finishing = false;
    }
  }

  /// Restaura um backup (.sqlite ou .json) exportado pelo BestFin e conclui
  /// o onboarding direto — os dados restaurados já contêm contas/categorias,
  /// então a conta do rascunho do step 2 NÃO é criada (por isso não usa
  /// `_finish()`).
  Future<void> _restoreFromBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sqlite', 'json'],
      );
      if (result == null || result.files.single.path == null) return;
      final path = result.files.single.path!;

      setState(() => _isRestoring = true);

      if (path.toLowerCase().endsWith('.json')) {
        final jsonString = await File(path).readAsString(encoding: utf8);
        final importUseCase = ref.read(importDataUseCaseProvider);
        await importUseCase.previewJson(jsonString); // valida o formato
        await importUseCase.restoreJson(jsonString);
        // Fecha a conexão antiga antes de invalidar — evita duas instâncias
        // do AppDatabase abertas ao mesmo tempo sobre o mesmo arquivo.
        await ref.read(databaseProvider).close();
        ref.invalidate(databaseProvider);
      } else {
        // restoreBackup valida o header SQLite e fecha o banco atual.
        await ref.read(backupDatabaseUseCaseProvider).restoreBackup(path);
        ref.invalidate(databaseProvider);
      }

      // Verificação pós-restore na instância nova do banco.
      final db = ref.read(databaseProvider);
      final restoredAccounts = await db.select(db.accounts).get();
      debugPrint(
        '[Restore] Backup restaurado: ${restoredAccounts.length} conta(s) '
        'no banco.',
      );

      await OnboardingActions.complete(ref);
      // Router guard will automatically navigate to /home
    } catch (e, st) {
      debugPrint('Erro ao restaurar backup: $e\n$st');
      if (mounted) {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao restaurar backup: '
              '${e is FormatException ? e.message : e}',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final syncState = ref.watch(syncStateProvider);

    ref.listen<AsyncValue<SyncIdentity?>>(currentIdentityProvider, (
      prev,
      next,
    ) {
      final identity = next.value;
      if (identity != null && !_isSyncing) {
        setState(() {
          _isSyncing = true;
        });
        ref.read(syncStateProvider.notifier).syncNow();
      }
    });

    ref.listen<SyncState>(syncStateProvider, (prev, next) {
      if (_isSyncing && next.status == SyncStatus.success) {
        _finish();
      }
    });

    if (_isRestoring) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restore_rounded,
                      size: 48,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Restaurando seu backup...',
                  textAlign: TextAlign.center,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                const AppLoadingIndicator(),
              ],
            ),
          ),
        ),
      );
    }

    if (_isSyncing) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.sync_rounded, size: 48, color: cs.primary)
                        .animate(onPlay: (controller) => controller.repeat())
                        .rotate(duration: const Duration(seconds: 2)),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Sincronizando seus dados...',
                  textAlign: TextAlign.center,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  syncState.currentPhase ?? 'Conectando aos relays...',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                // ── Live progress ────────────────────────────────────────
                // Push has a known total (queue length), pull doesn't (the
                // relays' page count isn't known ahead of time) — without
                // this, the screen shows the same static phase text for the
                // whole backfill push/pull and looks frozen.
                if (syncState.syncKind == SyncPhaseKind.push &&
                    syncState.syncTotal > 0) ...[
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: syncState.syncPercent,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${syncState.syncProgress} de ${syncState.syncTotal} itens '
                    '(${(syncState.syncPercent * 100).toStringAsFixed(0)}%) • '
                    '${ByteFormatter.format(syncState.syncBytes)}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ] else if (syncState.syncKind == SyncPhaseKind.pull) ...[
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${syncState.syncProgress} '
                    '${syncState.syncProgress == 1 ? 'item recebido' : 'itens recebidos'} '
                    '• ${ByteFormatter.format(syncState.syncBytes)}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const RelayStatusSection(maxListHeight: 110),
                const SizedBox(height: 20),
                if (syncState.status == SyncStatus.error) ...[
                  Text(
                    syncState.errorMessage ?? 'Ocorreu um erro desconhecido.',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: cs.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _isSyncing = false;
                            });
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            ref.read(syncStateProvider.notifier).syncNow();
                          },
                          child: const Text('Tentar Novamente'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Continuar sem sincronizar'),
                  ),
                ] else ...[
                  const AppLoadingIndicator(),
                  const SizedBox(height: 48),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Pular e sincronizar em segundo plano'),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: _prevPage,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: cs.onSurfaceVariant,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: _PageDots(
                      currentPage: _currentPage,
                      totalPages: _totalPages,
                      activeColor: cs.primary,
                      inactiveColor: cs.surfaceContainerHighest,
                    ),
                  ),
                  // "Pular" encerra o onboarding inteiro — não aparece no
                  // welcome, no perfil (que já é opcional e tem o próprio
                  // "Continuar") nem na criação de conta (obrigatória).
                  if (_currentPage > 2 && _currentPage < _totalPages - 1)
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Pular',
                        style: context.textTheme.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  unawaited(OnboardingActions.saveStep(i));
                },
                children: [
                  WelcomeStep(
                    onNext: _nextPage,
                    onRestoreBackup: _restoreFromBackup,
                  ),
                  ProfileStep(onNext: _nextPage),
                  CreateAccountStep(onNext: _nextPage),
                  SelectCategoriesStep(onNext: _nextPage),
                  NotificationPermissionStep(onNext: _nextPage),
                  SecurityStep(onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.currentPage,
    required this.totalPages,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int currentPage;
  final int totalPages;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalPages, (i) {
        final isActive = i == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.only(right: 6),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

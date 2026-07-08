import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';

const kOnboardingKey = 'onboarding_completed';
const kBiometricsKey = 'biometrics_enabled';
const kOnboardingStepKey = 'onboarding_step';
const kOnboardingAccountDraftKey = 'onboarding_account_draft';

// Set before runApp() via OnboardingActions.readCompleted()
bool initialOnboardingCompleted = false;
bool initialBiometricsEnabled = false;
// Último step do wizard alcançado — permite retomar de onde parou se o
// processo for morto pelo SO antes de completar o setup inicial.
int initialOnboardingStep = 0;
// Rascunho do step de conta, lido antes de runApp() para seed síncrono.
Map<String, dynamic>? initialOnboardingAccountDraft;

/// Dados coletados no step de conta do onboarding. A conta em si só é criada
/// quando o onboarding é finalizado (`OnboardingScreen._finish`).
class OnboardingAccountDraft {
  const OnboardingAccountDraft({
    required this.name,
    required this.type,
    required this.colorHex,
    required this.colorCustomized,
    required this.balanceCents,
  });

  final String name;
  final String type;
  final String colorHex;
  final bool colorCustomized;
  final int balanceCents;

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type,
    'color': colorHex,
    'colorCustomized': colorCustomized,
    'balance': balanceCents,
  };

  static OnboardingAccountDraft? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return OnboardingAccountDraft(
      name: (map['name'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'checking',
      colorHex: (map['color'] as String?) ?? '',
      colorCustomized: (map['colorCustomized'] as bool?) ?? false,
      balanceCents: (map['balance'] as int?) ?? 0,
    );
  }
}

/// Mantém o rascunho em memória (restauração instantânea ao navegar entre
/// steps) e espelha em SharedPreferences (sobrevive à morte do processo).
class OnboardingAccountDraftNotifier extends Notifier<OnboardingAccountDraft?> {
  @override
  OnboardingAccountDraft? build() =>
      OnboardingAccountDraft.fromMap(initialOnboardingAccountDraft);

  void set(OnboardingAccountDraft draft) {
    state = draft;
    unawaited(OnboardingActions.saveAccountDraft(draft.toMap()));
  }
}

final onboardingAccountDraftProvider =
    NotifierProvider<OnboardingAccountDraftNotifier, OnboardingAccountDraft?>(
      OnboardingAccountDraftNotifier.new,
    );

class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => initialOnboardingCompleted;

  void set(bool value) => state = value;
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
      OnboardingCompletedNotifier.new,
    );

class BiometricsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => initialBiometricsEnabled;

  void set(bool value) => state = value;
}

final biometricsEnabledProvider =
    NotifierProvider<BiometricsEnabledNotifier, bool>(
      BiometricsEnabledNotifier.new,
    );

class OnboardingActions {
  static Future<void> complete(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingKey, true);
    await prefs.remove(kOnboardingStepKey);
    await prefs.remove(kOnboardingAccountDraftKey);

    final database = ref.read(databaseProvider);
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          const AppSettingsCompanion(
            key: Value(kOnboardingKey),
            value: Value('true'),
          ),
        );

    ref.read(onboardingCompletedProvider.notifier).set(true);
  }

  static Future<void> setBiometrics(WidgetRef ref, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kBiometricsKey, enabled);

    final database = ref.read(databaseProvider);
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(kBiometricsKey),
            value: Value(enabled.toString()),
          ),
        );

    ref.read(biometricsEnabledProvider.notifier).set(enabled);
  }

  static Future<bool> readCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kOnboardingKey) ?? false;
  }

  static Future<bool> readBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kBiometricsKey) ?? false;
  }

  static Future<void> saveStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kOnboardingStepKey, step);
  }

  static Future<int> readStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(kOnboardingStepKey) ?? 0;
  }

  static Future<void> saveAccountDraft(Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kOnboardingAccountDraftKey, jsonEncode(draft));
  }

  static Future<Map<String, dynamic>?> readAccountDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kOnboardingAccountDraftKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

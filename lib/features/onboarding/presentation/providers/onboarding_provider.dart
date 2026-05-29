import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';

const kOnboardingKey = 'onboarding_completed';
const kBiometricsKey = 'biometrics_enabled';

// Set before runApp() via OnboardingActions.readCompleted()
bool initialOnboardingCompleted = false;
bool initialBiometricsEnabled = false;

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

    final database = ref.read(databaseProvider);
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(kOnboardingKey),
            value: const Value('true'),
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
}

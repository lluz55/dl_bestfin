import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

const kValuesHiddenKey = 'values_hidden';
const kAlwaysHideValuesKey = 'always_hide_values';

bool initialValuesHidden = false;
bool initialAlwaysHideValues = false;

class ValuesHiddenNotifier extends Notifier<bool> {
  @override
  bool build() {
    final val = initialValuesHidden;
    CurrencyFormatter.valuesHidden = val;
    return val;
  }

  Future<void> toggle() async {
    state = !state;
    CurrencyFormatter.valuesHidden = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kValuesHiddenKey, state);
  }

  Future<void> setHidden(bool hidden) async {
    state = hidden;
    CurrencyFormatter.valuesHidden = hidden;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kValuesHiddenKey, hidden);
  }
}

final valuesHiddenProvider = NotifierProvider<ValuesHiddenNotifier, bool>(
  ValuesHiddenNotifier.new,
);

class AlwaysHideValuesNotifier extends Notifier<bool> {
  @override
  bool build() => initialAlwaysHideValues;

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAlwaysHideValuesKey, value);

    if (value) {
      await ref.read(valuesHiddenProvider.notifier).setHidden(true);
    }
  }
}

final alwaysHideValuesProvider =
    NotifierProvider<AlwaysHideValuesNotifier, bool>(
      AlwaysHideValuesNotifier.new,
    );

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kValuesHiddenKey = 'values_hidden';

bool initialValuesHidden = false;

class ValuesHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => initialValuesHidden;

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kValuesHiddenKey, state);
  }
}

final valuesHiddenProvider = NotifierProvider<ValuesHiddenNotifier, bool>(
  ValuesHiddenNotifier.new,
);

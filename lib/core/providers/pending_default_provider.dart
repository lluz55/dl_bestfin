import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kDefaultPendingForPastKey = 'default_pending_for_past';

/// Se novas transações com data passada ou de hoje devem nascer marcadas
/// como "Pendente" por padrão. Transações futuras não usam esta preferência
/// — nascem sempre não concluídas (agendadas) e só viram "Pendente" quando a
/// data chegar.
bool initialDefaultPendingForPast = true;

class DefaultPendingForPastNotifier extends Notifier<bool> {
  @override
  bool build() => initialDefaultPendingForPast;

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDefaultPendingForPastKey, value);
  }
}

final defaultPendingForPastProvider =
    NotifierProvider<DefaultPendingForPastNotifier, bool>(
      DefaultPendingForPastNotifier.new,
    );

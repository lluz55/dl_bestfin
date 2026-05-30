import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kDefaultAccountIdKey = 'default_account_id';

String? initialDefaultAccountId;

class DefaultAccountNotifier extends Notifier<String?> {
  @override
  String? build() => initialDefaultAccountId;

  Future<void> set(String? id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(kDefaultAccountIdKey);
    } else {
      await prefs.setString(kDefaultAccountIdKey, id);
    }
  }
}

final defaultAccountIdProvider =
    NotifierProvider<DefaultAccountNotifier, String?>(
      DefaultAccountNotifier.new,
    );

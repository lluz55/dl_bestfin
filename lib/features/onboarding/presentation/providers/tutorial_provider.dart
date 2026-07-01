import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kTutorialSeenKey = 'tutorial_seen';

bool initialTutorialSeen = false;

class TutorialKeys {
  final fabKey = GlobalKey(debugLabel: 'tutorial_fab');
  final maisTabKey = GlobalKey(debugLabel: 'tutorial_mais_tab');
}

final tutorialKeysProvider = Provider<TutorialKeys>((_) => TutorialKeys());

class TutorialSeenNotifier extends Notifier<bool> {
  @override
  bool build() => initialTutorialSeen;

  void set(bool value) => state = value;
}

final tutorialSeenProvider = NotifierProvider<TutorialSeenNotifier, bool>(
  TutorialSeenNotifier.new,
);

class TutorialActions {
  static Future<void> markSeen(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kTutorialSeenKey, true);
    ref.read(tutorialSeenProvider.notifier).set(true);
  }

  static Future<bool> readSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kTutorialSeenKey) ?? false;
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class FinancialSkill {
  const FinancialSkill();

  String get id;
  String get displayName;
  IconData get icon;

  /// Tool names this skill is allowed to invoke.
  List<String> get toolNames;

  /// Whether this skill returns a static response (no LLM call needed).
  bool get isStaticResponse => false;
  String? get staticResponse => null;

  /// Maximum characters for the dynamic context injected into the system prompt.
  /// Prevents context overflow on Android models with small context windows (2048 tokens).
  /// Subclasses may override for skills with richer or simpler contexts.
  int get maxContextChars => 2000;

  /// Builds the dynamic financial context snippet for this skill.
  Future<String> buildContext(Ref ref);

  /// Returns the full system prompt using [contextData] from [buildContext].
  /// Static instructions come first (KV cache hit), dynamic data at the bottom.
  String systemPrompt(String contextData);
}

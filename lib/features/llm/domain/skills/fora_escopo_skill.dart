import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/llm/domain/models/financial_skill.dart';

class ForaEscopoSkill extends FinancialSkill {
  const ForaEscopoSkill();

  @override
  String get id => 'fora_escopo';

  @override
  String get displayName => 'Fora do Escopo';

  @override
  IconData get icon => Icons.info_outline_rounded;

  @override
  List<String> get toolNames => [];

  @override
  bool get isStaticResponse => true;

  @override
  String get staticResponse => '''Sou um assistente financeiro focado nos seus dados do BestFin.

Posso te ajudar com:
• Análise de gastos — "quanto gastei em supermercado esse mês?"
• Metas e poupança — "como está minha meta de viagem?"
• Fluxo de caixa — "terei saldo positivo no fim do mês?"
• Busca de transações — "onde usei o cartão no último sábado?"

Perguntas fora desses temas estão além do meu escopo. Tente me perguntar algo sobre suas finanças!''';

  @override
  Future<String> buildContext(Ref ref) async => '';

  @override
  String systemPrompt(String contextData) => '';
}

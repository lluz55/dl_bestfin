import 'package:bestfin/features/llm/domain/models/financial_skill.dart';
import 'package:bestfin/features/llm/domain/skills/gastos_skill.dart';
import 'package:bestfin/features/llm/domain/skills/metas_skill.dart';
import 'package:bestfin/features/llm/domain/skills/fluxo_skill.dart';
import 'package:bestfin/features/llm/domain/skills/busca_skill.dart';
import 'package:bestfin/features/llm/domain/skills/fora_escopo_skill.dart';

class SkillRegistry {
  static final SkillRegistry instance = SkillRegistry._();
  SkillRegistry._();

  final Map<String, FinancialSkill> _skills = const {
    'gastos': GastosSkill(),
    'metas': MetasSkill(),
    'fluxo': FluxoSkill(),
    'busca': BuscaSkill(),
    'fora_escopo': ForaEscopoSkill(),
  };

  FinancialSkill get(String id) => _skills[id] ?? const GastosSkill();

  List<FinancialSkill> get all => _skills.values.toList();
}

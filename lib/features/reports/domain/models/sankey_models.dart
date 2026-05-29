import 'package:flutter/material.dart';

class SankeyNode {
  final String id;
  final String label;
  final int value;
  final Color color;
  final int column;

  const SankeyNode({
    required this.id,
    required this.label,
    required this.value,
    required this.color,
    required this.column,
  });
}

class SankeyLink {
  final String sourceId;
  final String targetId;
  final int value;

  const SankeyLink({
    required this.sourceId,
    required this.targetId,
    required this.value,
  });
}

class SankeyData {
  final List<SankeyNode> nodes;
  final List<SankeyLink> links;
  final List<String> columnLabels;

  const SankeyData({
    required this.nodes,
    required this.links,
    this.columnLabels = const ['Receitas', 'Categorias', 'Estabelecimentos'],
  });

  bool get isEmpty => nodes.isEmpty || links.isEmpty;
}

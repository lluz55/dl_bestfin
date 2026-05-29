import 'package:flutter/material.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/core/utils/icon_mapper.dart';

class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String type; // 'income', 'expense', 'transfer'
  final bool isSystem;
  final String? parentId;
  final bool isArchived;
  final List<CategoryModel> children;
  final DateTime createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.isSystem,
    this.parentId,
    required this.isArchived,
    this.children = const [],
    required this.createdAt,
  });

  factory CategoryModel.fromDb(
    db.Category entity, {
    List<CategoryModel> children = const [],
  }) {
    return CategoryModel(
      id: entity.id,
      name: entity.name,
      icon: entity.icon,
      color: entity.color,
      type: entity.type,
      isSystem: entity.isSystem,
      parentId: entity.parentId,
      isArchived: entity.isArchived,
      children: children,
      createdAt: entity.createdAt,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    String? type,
    bool? isSystem,
    Object? parentId = _sentinel,
    bool? isArchived,
    List<CategoryModel>? children,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      isSystem: isSystem ?? this.isSystem,
      parentId: parentId == _sentinel ? this.parentId : parentId as String?,
      isArchived: isArchived ?? this.isArchived,
      children: children ?? this.children,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isRoot => parentId == null;
  bool get hasChildren => children.isNotEmpty;

  Color get parsedColor {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  IconData get iconData => IconMapper.fromString(icon);

  String get typeLabel {
    switch (type) {
      case 'income':
        return 'Receita';
      case 'expense':
        return 'Despesa';
      case 'transfer':
        return 'Transferência';
      default:
        return type;
    }
  }
}

const _sentinel = Object();

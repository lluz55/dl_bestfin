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
  final String? description;
  final List<CategoryModel> children;
  final DateTime createdAt;
  final String? parentName;
  final String? parentIcon;
  final String? parentColor;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.isSystem,
    this.parentId,
    required this.isArchived,
    this.description,
    this.children = const [],
    required this.createdAt,
    this.parentName,
    this.parentIcon,
    this.parentColor,
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
      description: entity.description,
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
    Object? description = _sentinel,
    List<CategoryModel>? children,
    DateTime? createdAt,
    String? parentName,
    String? parentIcon,
    String? parentColor,
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
      description: description == _sentinel
          ? this.description
          : description as String?,
      children: children ?? this.children,
      createdAt: createdAt ?? this.createdAt,
      parentName: parentName ?? this.parentName,
      parentIcon: parentIcon ?? this.parentIcon,
      parentColor: parentColor ?? this.parentColor,
    );
  }

  bool get isRoot => parentId == null;
  bool get hasChildren => children.isNotEmpty;

  String get displayName => parentName != null ? '$parentName › $name' : name;

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

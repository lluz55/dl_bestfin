import 'package:flutter/material.dart';

enum CategoryType { income, expense, transfer }

class DefaultCategory {
  final String id;
  final String name;
  final String icon;
  final String color;
  final CategoryType type;
  final String? parentId;

  const DefaultCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.parentId,
  });
}

class DefaultHoliday {
  final int month;
  final int day;
  final String name;

  const DefaultHoliday({
    required this.month,
    required this.day,
    required this.name,
  });
}

class SeedDataConstants {
  static const List<DefaultCategory> defaultCategories = [
    // Incomes
    DefaultCategory(
      id: 'cat_opening_balance',
      name: 'Saldo Inicial',
      icon: 'account_balance_wallet',
      color: '#9E9E9E',
      type: CategoryType.income,
    ),
    DefaultCategory(
      id: 'cat_salary',
      name: 'Salário',
      icon: 'money',
      color: '#4CAF50',
      type: CategoryType.income,
    ),
    DefaultCategory(
      id: 'cat_freelance',
      name: 'Freelance',
      icon: 'work',
      color: '#8BC34A',
      type: CategoryType.income,
    ),
    DefaultCategory(
      id: 'cat_investments_yield',
      name: 'Rendimentos',
      icon: 'trending_up',
      color: '#009688',
      type: CategoryType.income,
    ),
    // Expenses
    DefaultCategory(
      id: 'cat_housing',
      name: 'Moradia',
      icon: 'home',
      color: '#F44336',
      type: CategoryType.expense,
    ),
    DefaultCategory(
      id: 'cat_rent',
      name: 'Aluguel',
      icon: 'house',
      color: '#E53935',
      type: CategoryType.expense,
      parentId: 'cat_housing',
    ),
    DefaultCategory(
      id: 'cat_food',
      name: 'Alimentação',
      icon: 'restaurant',
      color: '#FF9800',
      type: CategoryType.expense,
    ),
    DefaultCategory(
      id: 'cat_transport',
      name: 'Transporte',
      icon: 'directions_car',
      color: '#2196F3',
      type: CategoryType.expense,
    ),
    DefaultCategory(
      id: 'cat_health',
      name: 'Saúde',
      icon: 'favorite',
      color: '#E91E63',
      type: CategoryType.expense,
    ),
    DefaultCategory(
      id: 'cat_education',
      name: 'Educação',
      icon: 'school',
      color: '#9C27B0',
      type: CategoryType.expense,
    ),
    DefaultCategory(
      id: 'cat_leisure',
      name: 'Lazer',
      icon: 'movie',
      color: '#FFC107',
      type: CategoryType.expense,
    ),
    DefaultCategory(
      id: 'cat_clothing',
      name: 'Vestuário',
      icon: 'checkroom',
      color: '#795548',
      type: CategoryType.expense,
    ),
    // Transfers
    DefaultCategory(
      id: 'cat_transfer',
      name: 'Transferência',
      icon: 'swap_horiz',
      color: '#9E9E9E',
      type: CategoryType.transfer,
    ),
  ];

  static const List<DefaultHoliday> nationalHolidays = [
    DefaultHoliday(month: 1, day: 1, name: 'Confraternização Universal'),
    DefaultHoliday(month: 4, day: 21, name: 'Tiradentes'),
    DefaultHoliday(month: 5, day: 1, name: 'Dia do Trabalhador'),
    DefaultHoliday(month: 9, day: 7, name: 'Independência do Brasil'),
    DefaultHoliday(month: 10, day: 12, name: 'Nossa Senhora Aparecida'),
    DefaultHoliday(month: 11, day: 2, name: 'Finados'),
    DefaultHoliday(month: 11, day: 15, name: 'Proclamação da República'),
    DefaultHoliday(month: 12, day: 25, name: 'Natal'),
  ];
}

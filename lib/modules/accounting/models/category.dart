import 'package:flutter/material.dart';
import 'transaction.dart';

/// 分类模型
class Category {
  final String id;
  final String name;
  final TransactionType type;
  final IconData icon;
  final bool isCustom;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.isCustom = false,
    required this.sortOrder,
  });

  Category copyWith({
    String? id,
    String? name,
    TransactionType? type,
    IconData? icon,
    bool? isCustom,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      isCustom: isCustom ?? this.isCustom,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// 从数据库 Map 创建
  factory Category.fromMap(Map<String, dynamic> map) {
    // 从 codePoint 和 fontFamily 恢复 IconData
    final codePoint = map['icon_code_point'] as int;
    final fontFamily = map['icon_font_family'] as String? ?? 'MaterialIcons';

    // ignore: non_const_argument_for_const_parameter
    final iconData = IconData(codePoint, fontFamily: fontFamily);

    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      icon: iconData,
      isCustom: (map['is_custom'] as int) == 1,
      sortOrder: map['sort_order'] as int,
    );
  }

  /// 转为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.value,
      'icon_code_point': icon.codePoint,
      'icon_font_family': icon.fontFamily ?? 'MaterialIcons',
      'is_custom': isCustom ? 1 : 0,
      'sort_order': sortOrder,
    };
  }
}

/// 预设支出分类
final List<Category> defaultExpenseCategories = [
  Category(id: 'exp_food', name: '餐饮', type: TransactionType.expense, icon: const IconData(0xe56c, fontFamily: 'MaterialIcons'), sortOrder: 0),
  Category(id: 'exp_transport', name: '交通', type: TransactionType.expense, icon: const IconData(0xe531, fontFamily: 'MaterialIcons'), sortOrder: 1),
  Category(id: 'exp_shopping', name: '购物', type: TransactionType.expense, icon: const IconData(0xf318, fontFamily: 'MaterialIcons'), sortOrder: 2),
  Category(id: 'exp_housing', name: '住房', type: TransactionType.expense, icon: const IconData(0xe318, fontFamily: 'MaterialIcons'), sortOrder: 3),
  Category(id: 'exp_entertainment', name: '娱乐', type: TransactionType.expense, icon: const IconData(0xe311, fontFamily: 'MaterialIcons'), sortOrder: 4),
  Category(id: 'exp_medical', name: '医疗', type: TransactionType.expense, icon: const IconData(0xf49a, fontFamily: 'MaterialIcons'), sortOrder: 5),
  Category(id: 'exp_education', name: '教育', type: TransactionType.expense, icon: const IconData(0xe8ef, fontFamily: 'MaterialIcons'), sortOrder: 6),
  Category(id: 'exp_communication', name: '通讯', type: TransactionType.expense, icon: const IconData(0xe6cd, fontFamily: 'MaterialIcons'), sortOrder: 7),
  Category(id: 'exp_clothing', name: '服饰', type: TransactionType.expense, icon: const IconData(0xf4c3, fontFamily: 'MaterialIcons'), sortOrder: 8),
  Category(id: 'exp_other', name: '其他', type: TransactionType.expense, icon: const IconData(0xe8d6, fontFamily: 'MaterialIcons'), sortOrder: 9),
];

/// 预设收入分类
final List<Category> defaultIncomeCategories = [
  Category(id: 'inc_salary', name: '工资', type: TransactionType.income, icon: const IconData(0xf06b, fontFamily: 'MaterialIcons'), sortOrder: 0),
  Category(id: 'inc_bonus', name: '奖金', type: TransactionType.income, icon: const IconData(0xf4a1, fontFamily: 'MaterialIcons'), sortOrder: 1),
  Category(id: 'inc_investment', name: '投资', type: TransactionType.income, icon: const IconData(0xe5c5, fontFamily: 'MaterialIcons'), sortOrder: 2),
  Category(id: 'inc_sidejob', name: '副业', type: TransactionType.income, icon: const IconData(0xe31b, fontFamily: 'MaterialIcons'), sortOrder: 3),
  Category(id: 'inc_other', name: '其他', type: TransactionType.income, icon: const IconData(0xe8d6, fontFamily: 'MaterialIcons'), sortOrder: 4),
];
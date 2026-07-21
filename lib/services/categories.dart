import 'package:flutter/material.dart';

/// 分类定义
class CategoryDef {
  final String name;
  final IconData icon;
  final Color color;
  const CategoryDef(this.name, this.icon, this.color);
}

/// 全局分类注册表 —— 唯一数据源
/// 记账页、分类管理、分类预算、首页统计等所有页面的分类图标/颜色都从这里取，
/// 保证新增、删除、自定义分类时各处自动同步。
class Categories {
  /// 自定义分类的默认图标/颜色（与记账页保持一致）
  static const IconData customIcon = Icons.label;
  static const Color customColor = Color(0xFF95A5A6);

  static const List<CategoryDef> builtinExpense = [
    CategoryDef('餐饮', Icons.restaurant, Color(0xFFFF6B6B)),
    CategoryDef('交通', Icons.directions_bus, Color(0xFF4ECDC4)),
    CategoryDef('购物', Icons.shopping_bag, Color(0xFFFFE66D)),
    CategoryDef('娱乐', Icons.sports_esports, Color(0xFFFF9F43)),
    CategoryDef('居家', Icons.home, Color(0xFF6C5CE7)),
    CategoryDef('医疗', Icons.local_hospital, Color(0xFFFDA7DF)),
    CategoryDef('教育', Icons.school, Color(0xFF00D2D3)),
    CategoryDef('通讯', Icons.phone_android, Color(0xFF74B9FF)),
    CategoryDef('服饰', Icons.checkroom, Color(0xFFA29BFE)),
    CategoryDef('美容', Icons.face_retouching_natural, Color(0xFFFD79A8)),
    CategoryDef('社交', Icons.people, Color(0xFF55EFC4)),
    CategoryDef('旅行', Icons.flight, Color(0xFF81ECEC)),
    CategoryDef('宠物', Icons.pets, Color(0xFFFAB1A0)),
    CategoryDef('运动', Icons.fitness_center, Color(0xFF00B894)),
    CategoryDef('数码', Icons.devices, Color(0xFF636E72)),
    CategoryDef('礼物', Icons.card_giftcard, Color(0xFFE17055)),
    CategoryDef('其他', Icons.more_horiz, Color(0xFFB2BEC3)),
  ];

  static const List<CategoryDef> builtinIncome = [
    CategoryDef('工资', Icons.work, Color(0xFF10B981)),
    CategoryDef('兼职', Icons.laptop, Color(0xFF4ECDC4)),
    CategoryDef('理财', Icons.trending_up, Color(0xFFFF9F43)),
    CategoryDef('礼金', Icons.card_giftcard, Color(0xFFFF6B6B)),
    CategoryDef('报销', Icons.receipt_long, Color(0xFF6C5CE7)),
    CategoryDef('红包', Icons.monetization_on, Color(0xFFE17055)),
    CategoryDef('其他', Icons.more_horiz, Color(0xFFB2BEC3)),
  ];

  /// 按名称查图标（找不到视为自定义分类）
  static IconData iconOf(String name) {
    for (final c in builtinExpense) {
      if (c.name == name) return c.icon;
    }
    for (final c in builtinIncome) {
      if (c.name == name) return c.icon;
    }
    return customIcon;
  }

  /// 按名称查颜色（找不到视为自定义分类）
  static Color colorOf(String name) {
    for (final c in builtinExpense) {
      if (c.name == name) return c.color;
    }
    for (final c in builtinIncome) {
      if (c.name == name) return c.color;
    }
    return customColor;
  }

  /// 记账页同款的支出分类列表：内置（排除已删除）+ 自定义（排除已删除），顺序一致
  static List<CategoryDef> activeExpense(List<String> deleted, List<String> custom) {
    final list = builtinExpense.where((c) => !deleted.contains(c.name)).toList();
    for (final name in custom) {
      if (!deleted.contains(name)) {
        list.add(CategoryDef(name, customIcon, customColor));
      }
    }
    return list;
  }

  /// 记账页同款的收入分类列表：内置（排除已删除）
  static List<CategoryDef> activeIncome(List<String> deleted) =>
      builtinIncome.where((c) => !deleted.contains(c.name)).toList();
}

import 'package:flutter/material.dart';

/// 分类定义
class CategoryDef {
  final String name;
  final Color color;
  const CategoryDef(this.name, this.color);
}

/// 全局分类注册表 —— 唯一数据源
/// 记账页、分类管理、分类预算、首页统计等所有页面的分类颜色都从这里取，
/// 保证新增、删除、自定义分类时各处自动同步。
///
/// 图标不在这里：统一由 CategoryGlyph 按分类名绘制
/// （见 widgets/category_glyph.dart），新增分类只需登记名字与颜色。
class Categories {
  /// 自定义分类的默认颜色（与记账页保持一致）
  static const Color customColor = Color(0xFF95A5A6);

  static const List<CategoryDef> builtinExpense = [
    CategoryDef('餐饮', Color(0xFFFF6B6B)),
    CategoryDef('交通', Color(0xFF4ECDC4)),
    CategoryDef('购物', Color(0xFFFFE66D)),
    CategoryDef('娱乐', Color(0xFFFF9F43)),
    CategoryDef('居家', Color(0xFF6C5CE7)),
    CategoryDef('医疗', Color(0xFFFDA7DF)),
    CategoryDef('教育', Color(0xFF00D2D3)),
    CategoryDef('通讯', Color(0xFF74B9FF)),
    CategoryDef('服饰', Color(0xFFA29BFE)),
    CategoryDef('美容', Color(0xFFFD79A8)),
    CategoryDef('社交', Color(0xFF55EFC4)),
    CategoryDef('旅行', Color(0xFF81ECEC)),
    CategoryDef('宠物', Color(0xFFFAB1A0)),
    CategoryDef('运动', Color(0xFF00B894)),
    CategoryDef('数码', Color(0xFF636E72)),
    CategoryDef('礼物', Color(0xFFE17055)),
    CategoryDef('其他', Color(0xFFB2BEC3)),
  ];

  static const List<CategoryDef> builtinIncome = [
    CategoryDef('工资', Color(0xFF10B981)),
    CategoryDef('兼职', Color(0xFF4ECDC4)),
    CategoryDef('理财', Color(0xFFFF9F43)),
    CategoryDef('礼金', Color(0xFFFF6B6B)),
    CategoryDef('报销', Color(0xFF6C5CE7)),
    CategoryDef('红包', Color(0xFFE17055)),
    CategoryDef('其他', Color(0xFFB2BEC3)),
  ];

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
        list.add(CategoryDef(name, customColor));
      }
    }
    return list;
  }

  /// 记账页同款的收入分类列表：内置（排除已删除）
  static List<CategoryDef> activeIncome(List<String> deleted) =>
      builtinIncome.where((c) => !deleted.contains(c.name)).toList();
}

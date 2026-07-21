import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF3B82F6);       // 蓝
  static const Color primaryDark = Color(0xFF2563EB);   // 深蓝
  static const Color accent = Color(0xFF60A5FA);        // 浅蓝
  static const Color success = Color(0xFF10B981);       // 绿
  static const Color warning = Color(0xFFF59E0B);       // 黄
  static const Color danger = Color(0xFFEF4444);        // 红

  static const Color bgPage = Color(0xFFF9FAFB);        // 页面背景
  static const Color bgCard = Colors.white;             // 卡片背景
  static const Color bgInput = Color(0xFFF3F4F6);       // 输入框

  static const Color textPrimary = Color(0xFF111827);   // 主文字
  static const Color textSecondary = Color(0xFF6B7280); // 次文字
  static const Color textHint = Color(0xFF9CA3AF);      // 占位
  static const Color divider = Color(0xFFE5E7EB);       // 分割线
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.bgPage,
      ),
      scaffoldBackgroundColor: AppColors.bgPage,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgPage,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

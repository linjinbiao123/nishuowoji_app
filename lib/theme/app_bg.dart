import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 全局背景主题（深色底 + 环境光晕）
class AppBgTheme {
  final String name;
  final List<Color> base; // 底层渐变（左上 → 右下）
  final List<Color> glows; // 两个环境光晕颜色
  final Color accent; // 强调色（FAB/按钮等品牌元素跟随主题）
  const AppBgTheme({required this.name, required this.base, required this.glows, required this.accent});

  static const List<AppBgTheme> all = [
    AppBgTheme(
      name: '深空蓝',
      base: [Color(0xFF0B1220), Color(0xFF152036)],
      glows: [Color(0xFF38BDF8), Color(0xFF6366F1)],
      accent: Color(0xFF38BDF8),
    ),
    AppBgTheme(
      name: '极光紫',
      base: [Color(0xFF170E29), Color(0xFF251641)],
      glows: [Color(0xFFA78BFA), Color(0xFFF472B6)],
      accent: Color(0xFFA78BFA),
    ),
    AppBgTheme(
      name: '翡翠绿',
      base: [Color(0xFF081811), Color(0xFF0F2B1E)],
      glows: [Color(0xFF34D399), Color(0xFF2DD4BF)],
      accent: Color(0xFF10B981),
    ),
    AppBgTheme(
      name: '樱花粉',
      base: [Color(0xFF1A0B12), Color(0xFF2B1220)],
      glows: [Color(0xFFF472B6), Color(0xFFFB7185)],
      accent: Color(0xFFEC4899),
    ),
  ];
}

/// 深色界面统一文字/分割线颜色
class AppDark {
  static const Color title = Colors.white; // 标题
  static const Color body = Color(0xD9FFFFFF); // 主要文字 0.85
  static const Color sub = Color(0x99FFFFFF); // 次要文字 0.6
  static const Color hint = Color(0x66FFFFFF); // 占位/弱化 0.4
  static const Color divider = Color(0x1AFFFFFF); // 分割线 0.10
  static const Color track = Color(0x14FFFFFF); // 进度条底 0.08
  static const Color surface = Color(0xFF18212F); // 不透明深色面板（需遮挡底层时用）
}

/// 全局深色背景：渐变底 + 环境光晕，[child] 叠在其上。
class AppBackground extends StatelessWidget {
  final AppBgTheme theme;
  final Widget child;
  const AppBackground({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.base,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(top: -130, right: -90, child: _Glow(color: theme.glows[0], size: 320)),
        Positioned(bottom: 40, left: -120, child: _Glow(color: theme.glows[1], size: 360)),
        Positioned(top: 260, right: -60, child: _Glow(color: theme.glows[1], size: 200, opacity: 0.14)),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Glow({required this.color, required this.size, this.opacity = 0.26});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ),
      ),
    );
  }
}

/// 毛玻璃卡片（半透明白 + 背景模糊 + 细白边）
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const GlassCard({super.key, required this.child, this.padding, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

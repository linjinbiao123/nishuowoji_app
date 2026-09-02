import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'bg_painters.dart';

/// 全局背景主题
class AppBgTheme {
  final String name;
  final List<Color> base; // 底层渐变（左上 → 右下）
  final List<Color> glows; // 两个环境光晕颜色
  final Color accent; // 强调色（FAB/按钮等品牌元素跟随主题）
  final bool isLight; // 是否为浅色（亮色）主题

  /// 背景渲染风格。glow 为原有的渐变光晕，其余为新增的绘制方案。
  final BgStyle style;

  /// 动效周期。数值越大越沉稳；新增主题刻意放在 20 秒以上，
  /// 观感是材质在缓慢流动，而不是界面在播放动画。
  final Duration motion;

  const AppBgTheme({
    required this.name,
    required this.base,
    required this.glows,
    required this.accent,
    this.isLight = false,
    this.style = BgStyle.glow,
    this.motion = const Duration(seconds: 18),
  });

  /// 直接贴在背景上的主文字颜色（浅色主题用深字，深色主题用白字）
  Color get onBg => isLight ? const Color(0xFF1F2329) : Colors.white;

  static const List<AppBgTheme> all = [
    // 第 0 位：默认主题。纯白底 + 黑/灰字，真·微信风格。
    AppBgTheme(
      name: '简约白',
      base: [Colors.white, Colors.white],
      glows: [Color(0xFFB9C4DA), Color(0xFFB7E0CF)],
      accent: Color(0xFF07C160), // 微信绿
      isLight: true,
    ),
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

    // ── 以下为「中式账簿」系列 ──
    // 不再使用渐变光晕，改由各自的绘制器渲染：
    // 宣纸取账本的纸与朱印，水墨取墨滴化开，算盘取算珠浮动。

    AppBgTheme(
      name: '宣纸',
      base: [Color(0xFFF6F2E9), Color(0xFFE9E2D3)],
      glows: [Color(0xFFB03A2E), Color(0xFF8C7A5B)],
      accent: Color(0xFFB03A2E), // 朱砂
      isLight: true,
      style: BgStyle.paper,
      motion: const Duration(seconds: 34),
    ),
    AppBgTheme(
      name: '水墨',
      base: [Color(0xFF0B0A09), Color(0xFF15120F)],
      glows: [Color(0xFF2B2723), Color(0xFF1C2530)],
      accent: Color(0xFFC9A227), // 泥金
      style: BgStyle.ink,
      motion: const Duration(seconds: 26),
    ),
    AppBgTheme(
      name: '算盘',
      base: [Color(0xFF17110C), Color(0xFF201810)],
      glows: [Color(0xFF8A5A2B), Color(0xFFA63A2E)],
      accent: Color(0xFFC87F3A), // 木色
      style: BgStyle.abacus,
      motion: const Duration(seconds: 22),
    ),
  ];
}

/// 界面统一文字/分割线颜色（随明暗主题自动切换）
class AppDark {
  static bool get _light => AppThemeMode.isLight;
  static Color get title => _light ? const Color(0xFF1A1A1A) : Colors.white;
  static Color get body => _light ? const Color(0xFF333333) : const Color(0xD9FFFFFF);
  static Color get sub => _light ? const Color(0xFF666666) : const Color(0x99FFFFFF);
  static Color get hint => _light ? const Color(0xFF999999) : const Color(0x66FFFFFF);
  static Color get divider => _light ? const Color(0xFFE5E7EB) : const Color(0x1AFFFFFF);
  static Color get track => _light ? const Color(0xFFE5E7EB) : const Color(0x14FFFFFF);
  // 弹窗/对话框背景保持深色（不随主题变浅），其内部白字天然可见，避免逐弹窗改色
  static Color get surface => const Color(0xFF18212F);
  // 卡片背景/边框：浅色主题用白底浅灰边，深色主题用半透明白
  static Color get cardBg => _light ? Colors.white : Colors.white.withValues(alpha: 0.07);
  static Color get cardBorder => _light ? const Color(0xFFE5E7EB) : Colors.white.withValues(alpha: 0.10);
}

/// 全局背景：[child] 叠在其上。
///
/// glow 风格走原有的渐变光晕；其余风格交由对应的绘制器渲染，
/// 每种风格有独立的材质与动效。
class AppBackground extends StatelessWidget {
  final AppBgTheme theme;
  final Widget child;
  const AppBackground({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    if (theme.style != BgStyle.glow) {
      return Stack(
        children: [
          Positioned.fill(child: _PaintedBg(theme: theme)),
          child,
        ],
      );
    }
    if (theme.isLight) {
      // 浅色主题：纯白背景，不叠加彩色光晕（真·白底黑字）
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
          child,
        ],
      );
    }
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

/// 驱动绘制类背景的动画容器。
///
/// 以 [AppBgTheme.motion] 为周期反复播放，绘制器据此得到 0~1 的进度。
/// 背景自带 RepaintBoundary 语义，重绘不会波及上层内容。
class _PaintedBg extends StatefulWidget {
  final AppBgTheme theme;
  const _PaintedBg({required this.theme});

  @override
  State<_PaintedBg> createState() => _PaintedBgState();
}

class _PaintedBgState extends State<_PaintedBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.theme.motion)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant _PaintedBg old) {
    super.didUpdateWidget(old);
    // 切换主题时按新主题的节奏重新计时
    if (old.theme.motion != widget.theme.motion ||
        old.theme.style != widget.theme.style) {
      _ctrl.duration = widget.theme.motion;
      _ctrl
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => RepaintBoundary(
        child: CustomPaint(
          painter: _painterFor(widget.theme, _ctrl.value),
          size: Size.infinite,
        ),
      ),
    );
  }

  CustomPainter _painterFor(AppBgTheme t, double v) {
    switch (t.style) {
      case BgStyle.paper:
        return PaperBgPainter(t: v, lineColor: t.glows[0], fiberColor: t.glows[1]);
      case BgStyle.ink:
        return InkBgPainter(t: v, goldColor: t.accent);
      case BgStyle.abacus:
        return AbacusBgPainter(t: v, beadColor: t.glows[0], accentBead: t.glows[1]);
      case BgStyle.glow:
        // 不会走到：glow 风格由 AppBackground 直接渲染
        return PaperBgPainter(t: v);
    }
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
          colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// 卡片（浅色主题=白底浅灰边+阴影；深色主题=半透明白毛玻璃）
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const GlassCard({super.key, required this.child, this.padding, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeMode.isLight;
    if (isLight) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 全局明暗主题状态。
/// 由 main() 在启动时初始化，并在设置页切换主题时同步更新。
/// AppDark、GlassCard 等据此返回对应明暗的配色。
class AppThemeMode {
  static bool isLight = true;
}

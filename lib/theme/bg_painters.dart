import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 背景渲染风格。
///
/// glow 是原有的「渐变 + 圆形光晕」，ink 为水墨绘制，
/// 两种风格有独立的绘制逻辑与动效语言。
enum BgStyle {
  glow,
  ink,
}

/// 一团墨。用 0~1 相对坐标定位，半径随动画缓慢胀缩。
class InkBlob {
  final double x, y, radius, phase, speed;
  final Color color;
  const InkBlob({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.speed,
    required this.color,
  });

  /// 默认排布：四团墨散布在画面四角附近，
  /// 相位与速度互不相同，避免同步胀缩显得机械。
  static const List<InkBlob> preset = [
    InkBlob(x: 0.20, y: 0.16, radius: 150, phase: 0.0, speed: 1.00, color: Color(0xFF2B2723)),
    InkBlob(x: 0.86, y: 0.30, radius: 190, phase: 1.9, speed: 0.70, color: Color(0xFF1C2530)),
    InkBlob(x: 0.14, y: 0.70, radius: 210, phase: 3.4, speed: 0.55, color: Color(0xFF232B26)),
    InkBlob(x: 0.70, y: 0.90, radius: 170, phase: 5.1, speed: 0.85, color: Color(0xFF2A2420)),
  ];
}

/// 水墨。
///
/// 不用圆形光晕那种规整的径向渐变，改为几团边界不规则的墨，
/// 缓慢胀缩，像墨滴落在水里化开又收拢的过程。
/// 再点几粒金箔，打破纯黑的沉闷。
class InkBgPainter extends CustomPainter {
  final double t;
  final List<InkBlob> blobs;
  final Color goldColor;

  InkBgPainter({
    required this.t,
    List<InkBlob>? blobs,
    this.goldColor = const Color(0xFFC9A227),
  }) : blobs = blobs ?? InkBlob.preset;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w * 0.3, h),
          const [Color(0xFF0B0A09), Color(0xFF15120F)],
        ),
    );

    final wave = t * math.pi * 2;

    // 墨团：边缘用三层透明度递减的圆叠加，形成自然的晕开边界
    for (final b in blobs) {
      final pulse = 0.5 + 0.5 * math.sin(wave * b.speed + b.phase);
      final cx = b.x * w + math.sin(wave * 0.25 + b.phase) * 12;
      final cy = b.y * h + math.cos(wave * 0.21 + b.phase) * 14;
      final r = b.radius * (0.86 + pulse * 0.28);

      for (var layer = 0; layer < 3; layer++) {
        final lr = r * (1 + layer * 0.85);
        final la = (0.16 - layer * 0.05) * (0.6 + pulse * 0.4);
        if (la <= 0) continue;
        canvas.drawCircle(
          Offset(cx, cy),
          lr,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(cx, cy),
              lr,
              [b.color.withValues(alpha: la), b.color.withValues(alpha: 0)],
            ),
        );
      }
    }

    // 金箔：少量细点，随时间明灭，避免画面死板
    final rnd = math.Random(77);
    for (var i = 0; i < 26; i++) {
      final gx = rnd.nextDouble() * w;
      final gy = rnd.nextDouble() * h;
      final tw = math.sin(wave * (0.3 + rnd.nextDouble() * 0.5) + i);
      final a = (0.05 + tw * 0.09).clamp(0.0, 0.20);
      canvas.drawCircle(
        Offset(gx, gy),
        0.7 + rnd.nextDouble() * 1.3,
        Paint()..color = goldColor.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(covariant InkBgPainter old) => old.t != t;
}

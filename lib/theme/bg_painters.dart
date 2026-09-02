import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 背景渲染风格。
///
/// glow 是原有的「渐变 + 圆形光晕」，其余为本套新设计，
/// 每种风格有独立的绘制逻辑与动效语言。
enum BgStyle {
  glow,
  paper,
  ink,
  abacus,
}

/// 一根纸纤维。位置用 0~1 的相对坐标，绘制时再乘以画布尺寸，
/// 这样同一份数据能适配任意屏幕大小。
class _Fiber {
  final double x, y, angle, length, width, alpha, phase, speed;
  const _Fiber({
    required this.x,
    required this.y,
    required this.angle,
    required this.length,
    required this.width,
    required this.alpha,
    required this.phase,
    required this.speed,
  });
}

/// 宣纸。
///
/// 不做对角渐变和圆形光晕，改为：
///  - 垂直向的极淡明暗（模拟纸张受光）
///  - 上百根随机纸纤维，随时间做极小幅漂移，像纸在光下的呼吸
///  - 规整的水平行线，取朱砂的极淡痕迹，呼应账本的格线
///  - 右下角一枚做旧的朱红印
///
/// 动效刻意放到 30 秒量级，观感是「材质在缓慢流动」而非「界面在动」。
class PaperBgPainter extends CustomPainter {
  final double t; // 0~1 循环进度
  final Color lineColor;
  final Color fiberColor;

  PaperBgPainter({
    required this.t,
    this.lineColor = const Color(0xFFB03A2E),
    this.fiberColor = const Color(0xFF8C7A5B),
  });

  // 静态缓存：painter 每帧都会重建，纤维只在首次使用时生成一次，
  // 否则每帧重新随机会导致纹理闪烁。
  static final List<_Fiber> _fibers = _genFibers();

  static List<_Fiber> _genFibers() {
    final rnd = math.Random(20260902); // 固定种子，保证纹理稳定
    return List.generate(160, (i) {
      return _Fiber(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        angle: rnd.nextDouble() * math.pi,
        length: 4 + rnd.nextDouble() * 14,
        width: 0.5 + rnd.nextDouble() * 0.9,
        alpha: 0.03 + rnd.nextDouble() * 0.07,
        phase: rnd.nextDouble() * math.pi * 2,
        speed: 0.4 + rnd.nextDouble() * 0.8,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 纸张基底：垂直向的极淡渐变，比斜向渐变更像自然受光
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          const [Color(0xFFF6F2E9), Color(0xFFE9E2D3)],
        ),
    );

    final wave = t * math.pi * 2;

    // 纸纤维：各自以不同相位和速度做微幅漂移
    for (final f in _fibers) {
      final drift = math.sin(wave * f.speed + f.phase);
      final dx = f.x * w + drift * 3.2;
      final dy = f.y * h + math.cos(wave * f.speed * 0.7 + f.phase) * 2.6;
      final a = (f.alpha + drift * 0.012).clamp(0.008, 0.12);
      final p = Paint()
        ..color = fiberColor.withValues(alpha: a)
        ..strokeWidth = f.width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(dx, dy),
        Offset(dx + math.cos(f.angle) * f.length,
            dy + math.sin(f.angle) * f.length),
        p,
      );
    }

    // 账本行线：等距横线，朱砂极淡，随呼吸轻微明灭
    final lineGap = 34.0;
    final linePaint = Paint()..strokeWidth = 0.6;
    for (var y = 88.0; y < h; y += lineGap) {
      final breathe = 0.5 + 0.5 * math.sin(wave * 0.5 + y * 0.01);
      linePaint.color = lineColor.withValues(alpha: 0.022 + breathe * 0.020);
      canvas.drawLine(Offset(20, y), Offset(w - 20, y), linePaint);
    }

    // 朱印：右下角一枚做旧方印
    _drawSeal(canvas, w, h, wave);
  }

  void _drawSeal(Canvas canvas, double w, double h, double wave) {
    final size0 = 62.0;
    final left = w - size0 - 26;
    final top = h - size0 - 120;
    final breathe = 0.5 + 0.5 * math.sin(wave * 0.35);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, size0, size0),
      const Radius.circular(6),
    );

    // 印泥不是均匀实色：先铺一层，再挖几道细缝模拟盖印的斑驳
    canvas.drawRRect(
      rrect,
      Paint()..color = lineColor.withValues(alpha: 0.10 + breathe * 0.035),
    );
    final gap = Paint()
      ..color = const Color(0xFFEFE9DC).withValues(alpha: 0.55)
      ..strokeWidth = 1.6;
    canvas.drawLine(
      Offset(left + 10, top + 20),
      Offset(left + size0 - 12, top + 22),
      gap,
    );
    canvas.drawLine(
      Offset(left + 14, top + 42),
      Offset(left + size0 - 9, top + 39),
      gap,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = lineColor.withValues(alpha: 0.28 + breathe * 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant PaperBgPainter old) => old.t != t;
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

/// 算盘。
///
/// 深色木底之上，是规则排布的算珠矩阵。
/// 每一列有独立相位，整片珠子在极慢地上下浮动，
/// 像刚被拨过、余势未停。
class AbacusBgPainter extends CustomPainter {
  final double t;
  final Color beadColor;
  final Color accentBead;

  AbacusBgPainter({
    required this.t,
    this.beadColor = const Color(0xFF8A5A2B),
    this.accentBead = const Color(0xFFA63A2E),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          const [Color(0xFF17110C), Color(0xFF201810)],
        ),
    );

    final wave = t * math.pi * 2;
    final colGap = 46.0;
    final rowGap = 58.0;

    for (var col = 0; col * colGap < w + colGap; col++) {
      // 每列独立相位：形成错落的波动，而非整齐划一的运动
      final phase = col * 0.55;
      final cx = col * colGap + colGap * 0.5;

      // 横梁（算盘的档）
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, h),
        Paint()
          ..strokeWidth = 1.0
          ..color = const Color(0xFF3D2B1F).withValues(alpha: 0.5),
      );

      for (var row = 0; row * rowGap < h + rowGap; row++) {
        final isAccent = (row + col) % 7 == 0;
        final sway = math.sin(wave * 0.6 + phase + row * 0.32);
        final cy = row * rowGap + rowGap * 0.5 + sway * 5.5;
        final alpha = (0.10 + sway * 0.05).clamp(0.03, 0.20);
        final color = isAccent ? accentBead : beadColor;

        // 算珠：横向的扁圆角矩形，贴合真实算珠的轮廓
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, cy), width: 26, height: 12),
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: alpha));
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = color.withValues(alpha: (alpha * 1.5).clamp(0.0, 0.34)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AbacusBgPainter old) => old.t != t;
}

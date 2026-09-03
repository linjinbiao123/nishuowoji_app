import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 分类图形标识。
///
/// 每个分类一个手绘感的几何图形，统一在 24×24 的虚拟坐标系里绘制，
/// 再按显示尺寸等比缩放，因此任意大小下风格都一致。
enum GlyphId {
  // 支出
  food,
  transit,
  shopping,
  fun,
  home,
  medical,
  edu,
  phone,
  clothes,
  beauty,
  social,
  travel,
  pet,
  sport,
  digital,
  gift,
  dots,

  // 收入
  salary,
  parttime,
  invest,
  cashGift,
  reimburse,
  redpacket,

  // 自定义/兜底
  label,
}

/// 分类图标。
///
/// 不用 Material Icons，改由 [_GlyphPainter] 逐笔绘制：
/// 统一的圆头描边、统一的转角，整套图标因此有同一支笔画出来的感觉，
/// 而不是从图标库里各挑一个拼起来。
class CategoryGlyph extends StatelessWidget {
  final String name;
  final double size;
  final Color color;

  const CategoryGlyph({
    super.key,
    required this.name,
    required this.size,
    required this.color,
  });

  /// 分类名 → 图形。未登记的名称（含用户自建分类）落到标签图形。
  static GlyphId idOf(String name) {
    switch (name) {
      case '餐饮':
        return GlyphId.food;
      case '交通':
        return GlyphId.transit;
      case '购物':
        return GlyphId.shopping;
      case '娱乐':
        return GlyphId.fun;
      case '居家':
        return GlyphId.home;
      case '医疗':
        return GlyphId.medical;
      case '教育':
        return GlyphId.edu;
      case '通讯':
        return GlyphId.phone;
      case '服饰':
        return GlyphId.clothes;
      case '美容':
        return GlyphId.beauty;
      case '社交':
        return GlyphId.social;
      case '旅行':
        return GlyphId.travel;
      case '宠物':
        return GlyphId.pet;
      case '运动':
        return GlyphId.sport;
      case '数码':
        return GlyphId.digital;
      case '礼物':
        return GlyphId.gift;
      case '其他':
        return GlyphId.dots;

      case '工资':
        return GlyphId.salary;
      case '兼职':
        return GlyphId.parttime;
      case '理财':
        return GlyphId.invest;
      case '礼金':
        return GlyphId.cashGift;
      case '报销':
        return GlyphId.reimburse;
      case '红包':
        return GlyphId.redpacket;

      default:
        return GlyphId.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(id: idOf(name), color: color),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final GlyphId id;
  final Color color;

  _GlyphPainter({required this.id, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 统一坐标系：所有图形按 24×24 设计，这里缩放适配实际尺寸
    final s = size.width / 24;
    canvas.scale(s);

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (id) {
      case GlyphId.food:
        // 碗身 + 碗口，右上角斜插一双筷子
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 8),
          0,
          math.pi,
          false,
          p,
        );
        canvas.drawLine(const Offset(4, 12), const Offset(20, 12), p);
        canvas.drawLine(const Offset(13, 3), const Offset(16, 10), p);
        canvas.drawLine(const Offset(15.5, 3), const Offset(18.5, 10), p);
        break;

      case GlyphId.transit:
        // 车厢 + 车窗线 + 两个轮子
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(4, 4, 20, 16),
            Radius.circular(2),
          ),
          p,
        );
        canvas.drawLine(const Offset(7, 9.5), const Offset(17, 9.5), p);
        canvas.drawCircle(const Offset(8, 18), 1.6, p);
        canvas.drawCircle(const Offset(16, 18), 1.6, p);
        break;

      case GlyphId.shopping:
        // 袋身 + 半圆提手
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(5, 8, 19, 20),
            Radius.circular(2),
          ),
          p,
        );
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 8), radius: 3),
          math.pi,
          math.pi,
          false,
          p,
        );
        break;

      case GlyphId.fun:
        // 手柄：圆润机身 + 十字方向键 + 一颗按键
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(3, 8, 21, 17),
            Radius.circular(4),
          ),
          p,
        );
        canvas.drawLine(const Offset(7, 11), const Offset(7, 14), p);
        canvas.drawLine(const Offset(5.5, 12.5), const Offset(8.5, 12.5), p);
        canvas.drawCircle(const Offset(16, 12.5), 1, p);
        break;

      case GlyphId.home:
        // 屋顶折线 + 墙体
        canvas.drawPath(
          Path()
            ..moveTo(3, 11)
            ..lineTo(12, 4)
            ..lineTo(21, 11),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(6, 11, 18, 20),
            Radius.circular(1.5),
          ),
          p,
        );
        break;

      case GlyphId.medical:
        // 十字
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), p);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), p);
        break;

      case GlyphId.edu:
        // 摊开的书 + 中缝
        canvas.drawPath(
          Path()
            ..moveTo(3, 7)
            ..lineTo(12, 5)
            ..lineTo(21, 7)
            ..lineTo(21, 18)
            ..lineTo(12, 16)
            ..lineTo(3, 18)
            ..close(),
          p,
        );
        canvas.drawLine(const Offset(12, 5), const Offset(12, 16), p);
        break;

      case GlyphId.phone:
        // 手机 + 底部按键
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(7, 3, 17, 21),
            Radius.circular(2.5),
          ),
          p,
        );
        canvas.drawLine(const Offset(10.5, 18.5), const Offset(13.5, 18.5), p);
        break;

      case GlyphId.clothes:
        // T 恤：领口、两袖、衣身一笔连成
        canvas.drawPath(
          Path()
            ..moveTo(9, 4)
            ..lineTo(12, 7)
            ..lineTo(15, 4)
            ..lineTo(20, 6.5)
            ..lineTo(18, 11)
            ..lineTo(16, 10)
            ..lineTo(16, 20)
            ..lineTo(8, 20)
            ..lineTo(8, 10)
            ..lineTo(6, 11)
            ..lineTo(4, 6.5)
            ..close(),
          p,
        );
        break;

      case GlyphId.beauty:
        // 口红：斜切膏体 + 管身
        canvas.drawPath(
          Path()
            ..moveTo(10, 12)
            ..lineTo(10, 7)
            ..lineTo(14, 5)
            ..lineTo(14, 12),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(10, 12, 14, 20),
            Radius.circular(1),
          ),
          p,
        );
        break;

      case GlyphId.social:
        // 两个人：头 + 肩线
        canvas.drawCircle(const Offset(8, 8), 2.5, p);
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(8, 17), radius: 4),
          math.pi,
          math.pi,
          false,
          p,
        );
        canvas.drawCircle(const Offset(16.5, 8), 2.5, p);
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(16.5, 17), radius: 4),
          math.pi,
          math.pi,
          false,
          p,
        );
        break;

      case GlyphId.travel:
        // 纸飞机：外轮廓 + 一道折痕
        canvas.drawPath(
          Path()
            ..moveTo(2, 12)
            ..lineTo(22, 4)
            ..lineTo(13, 21)
            ..lineTo(10.5, 13)
            ..close(),
          p,
        );
        canvas.drawLine(const Offset(10.5, 13), const Offset(22, 4), p);
        break;

      case GlyphId.pet:
        // 猫：圆脸 + 两只耳朵
        canvas.drawCircle(const Offset(12, 14), 5.5, p);
        canvas.drawPath(
          Path()
            ..moveTo(8, 10.5)
            ..lineTo(7, 4.5)
            ..lineTo(11.5, 7.5)
            ..close(),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 10.5)
            ..lineTo(17, 4.5)
            ..lineTo(12.5, 7.5)
            ..close(),
          p,
        );
        break;

      case GlyphId.sport:
        // 哑铃：横杆 + 两端配重
        canvas.drawLine(const Offset(8, 12), const Offset(16, 12), p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(4, 8.5, 7.5, 15.5),
            Radius.circular(1.5),
          ),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(16.5, 8.5, 20, 15.5),
            Radius.circular(1.5),
          ),
          p,
        );
        break;

      case GlyphId.digital:
        // 显示器 + 底座
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(3, 4, 21, 15),
            Radius.circular(1.5),
          ),
          p,
        );
        canvas.drawLine(const Offset(12, 15), const Offset(12, 18), p);
        canvas.drawLine(const Offset(8.5, 19), const Offset(15.5, 19), p);
        break;

      case GlyphId.gift:
        // 礼盒 + 竖丝带 + 蝴蝶结
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(4, 9, 20, 20),
            Radius.circular(1.5),
          ),
          p,
        );
        canvas.drawLine(const Offset(12, 9), const Offset(12, 20), p);
        canvas.drawCircle(const Offset(10, 7), 2, p);
        canvas.drawCircle(const Offset(14, 7), 2, p);
        break;

      case GlyphId.dots:
        // 省略号
        canvas.drawCircle(const Offset(6, 12), 1.6, p);
        canvas.drawCircle(const Offset(12, 12), 1.6, p);
        canvas.drawCircle(const Offset(18, 12), 1.6, p);
        break;

      case GlyphId.salary:
        // 公文包：包身 + 提手
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(3, 8, 21, 20),
            Radius.circular(1.5),
          ),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(9, 8)
            ..lineTo(9, 5.5)
            ..lineTo(15, 5.5)
            ..lineTo(15, 8),
          p,
        );
        break;

      case GlyphId.parttime:
        // 笔记本：屏幕 + 键盘板
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(5, 4, 19, 15),
            Radius.circular(1.5),
          ),
          p,
        );
        canvas.drawLine(const Offset(3, 17), const Offset(21, 17), p);
        break;

      case GlyphId.invest:
        // 上扬折线 + 箭头
        canvas.drawPath(
          Path()
            ..moveTo(3, 17)
            ..lineTo(9, 11)
            ..lineTo(13, 14)
            ..lineTo(21, 6),
          p,
        );
        canvas.drawLine(const Offset(21, 6), const Offset(15.5, 6), p);
        canvas.drawLine(const Offset(21, 6), const Offset(21, 11.5), p);
        break;

      case GlyphId.cashGift:
        // 红包：封套 + 翻盖线 + 封印
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(5, 7, 19, 20),
            Radius.circular(1.5),
          ),
          p,
        );
        canvas.drawLine(const Offset(5, 11), const Offset(19, 11), p);
        canvas.drawCircle(const Offset(12, 15.5), 2, p);
        break;

      case GlyphId.reimburse:
        // 票据：票身 + 三行内容
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(5, 3, 19, 21),
            Radius.circular(1.5),
          ),
          p,
        );
        canvas.drawLine(const Offset(8, 8), const Offset(16, 8), p);
        canvas.drawLine(const Offset(8, 12), const Offset(16, 12), p);
        canvas.drawLine(const Offset(8, 16), const Offset(13, 16), p);
        break;

      case GlyphId.redpacket:
        // 钱币：外圆 + 抽象的 ¥ 笔画
        canvas.drawCircle(const Offset(12, 12), 8, p);
        canvas.drawLine(const Offset(12, 7.5), const Offset(12, 16.5), p);
        canvas.drawLine(const Offset(9, 10.5), const Offset(15, 10.5), p);
        canvas.drawLine(const Offset(9, 13.5), const Offset(15, 13.5), p);
        break;

      case GlyphId.label:
        // 标签：带尖角的外形 + 挂孔
        canvas.drawPath(
          Path()
            ..moveTo(4, 7)
            ..lineTo(17, 7)
            ..lineTo(21, 12)
            ..lineTo(17, 17)
            ..lineTo(4, 17)
            ..close(),
          p,
        );
        canvas.drawCircle(const Offset(8, 12), 1.3, p);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.id != id || old.color != color;
}

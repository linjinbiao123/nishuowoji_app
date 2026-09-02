import 'package:flutter/material.dart';

/// 逐位滚动的数字。
///
/// 数值变化时，每一位像里程表一样纵向滚到新数字，
/// 而不是整串数字瞬间跳变。用于金额、结余这类核心数字，
/// 让「钱在变」这件事被看见。
///
/// 只在数值真正变化时播放动画；首次显示直接落位，不做入场滚动。
class RollingNumber extends StatefulWidget {
  final double value;
  final int decimals;
  final TextStyle style;
  final Duration duration;
  final Curve curve;

  /// 每位数字的滚动方向：true 为数值增大时向上滚
  final bool upOnIncrease;

  const RollingNumber({
    super.key,
    required this.value,
    this.decimals = 2,
    required this.style,
    this.duration = const Duration(milliseconds: 620),
    this.curve = Curves.easeOutCubic,
    this.upOnIncrease = true,
  });

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber>
    with TickerProviderStateMixin {
  /// 每一位对应一个控制器，值为该位当前的滚动进度
  final List<AnimationController> _ctrls = [];
  final List<Animation<double>> _anims = [];

  /// 上一次渲染用的字符序列
  List<String> _chars = [];
  bool _inited = false;

  @override
  void didUpdateWidget(covariant RollingNumber old) {
    super.didUpdateWidget(old);
    if (widget.decimals != old.decimals) {
      _inited = false; // 小数位变化需要重建
    }
    _sync(animate: true);
  }

  @override
  void initState() {
    super.initState();
    _sync(animate: false);
    _inited = true;
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync({required bool animate}) {
    final next = _formatChars(widget.value, widget.decimals);

    // 位数变了（例如 9.9 → 10.0），直接重建，避免错位
    if (next.length != _chars.length) {
      for (final c in _ctrls) {
        c.dispose();
      }
      _ctrls.clear();
      _anims.clear();
      for (var i = 0; i < next.length; i++) {
        final c = AnimationController(vsync: this, duration: widget.duration);
        _ctrls.add(c);
        _anims.add(CurvedAnimation(parent: c, curve: widget.curve));
      }
      _chars = next;
      if (animate && _inited) {
        // 新出现的位从下往上滑入，带一点错位感
        for (var i = 0; i < _ctrls.length; i++) {
          Future.delayed(Duration(milliseconds: 18 * i), () {
            if (mounted) _ctrls[i].forward(from: 0);
          });
        }
      } else {
        for (final c in _ctrls) {
          c.value = 1;
        }
      }
      return;
    }

    // 位数不变：只让变化的那几位滚动
    for (var i = 0; i < next.length; i++) {
      if (!_inited) {
        _chars = next;
        for (final c in _ctrls) {
          c.value = 1;
        }
        continue;
      }
      if (next[i] != _chars[i]) {
        final from = int.tryParse(_chars[i]);
        final to = int.tryParse(next[i]);
        // 分隔符（如小数点、千分位）没有数值，整段位移即可
        if (from == null || to == null) {
          _ctrls[i].forward(from: 0);
        } else {
          final rising = widget.upOnIncrease ? to > from : to < from;
          _ctrls[i].value = rising ? 0 : 1;
          _ctrls[i].forward(from: rising ? 0 : 1);
        }
      }
    }
    _chars = next;
  }

  /// 把数值拆成字符序列，含千分位与小数点
  static List<String> _formatChars(double v, int decimals) {
    final fixed = v.abs().toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = parts[0];
    // 千分位
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    final s = decimals > 0 ? '$buf.${parts[1]}' : buf.toString();
    return s.split('');
  }

  @override
  Widget build(BuildContext context) {
    // 量出单数字宽度，让 Stack 在 Row 里也有明确约束，避免无界布局崩溃
    final digitW = TextPainter(
      text: TextSpan(text: '0', style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    final digitWidth = digitW.width;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(_chars.length, (i) {
        final ch = _chars[i];
        final digit = int.tryParse(ch);
        // 非数字（小数点、逗号）直接静态呈现
        if (digit == null) {
          return Text(ch, style: widget.style);
        }
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => _DigitRoll(
            digit: digit,
            progress: _anims[i].value,
            style: widget.style,
            increasing: true,
            width: digitWidth,
          ),
        );
      }),
    );
  }
}

/// 单个数位的滚动。
///
/// 用一个纵向的 [0..9] 数字条，通过偏移让它停在目标数字上。
/// 进度从 0 到 1 时，视觉上是数字向上翻滚并定格。
class _DigitRoll extends StatelessWidget {
  final int digit;
  final double progress;
  final TextStyle style;
  final bool increasing;
  final double width;

  const _DigitRoll({
    required this.digit,
    required this.progress,
    required this.style,
    required this.increasing,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    // 行高取字号的 1.25 倍，保证滚动时数字不会互相挤压
    final lineHeight = (style.fontSize ?? 16) * 1.25;
    final digits = 10;

    // 起点：从前一个数字（下方一位）滚到目标数字
    final start = (digit + (increasing ? 1 : digits - 1)) % digits;
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));

    // 在 0~9 的循环带上插值，取最短路径，避免绕一大圈
    var delta = digit - start;
    if (delta > digits / 2) delta -= digits;
    if (delta < -digits / 2) delta += digits;
    final pos = start + delta * eased;

    return SizedBox(
      width: width,
      height: lineHeight,
      child: ClipRect(
        child: SizedBox(
          height: lineHeight,
          child: Stack(
            children: [
              for (var n = 0; n < digits; n++)
                Positioned(
                  // 把目标数字放在可视区中心，其余按循环位置排布
                  top: _offsetFor(n, pos) * lineHeight,
                  left: 0,
                  width: width,
                  child: SizedBox(
                    height: lineHeight,
                    child: Center(
                      child: Text('$n', style: style),
                    ),
                  ),
                ),
          ],
        ),
      ),
      ),
    );
  }

  /// 计算数字 n 应当出现的纵向偏移（单位：行高）。
  /// pos 是当前滚动位置（可为小数、可超出 0~9）。
  double _offsetFor(int n, double pos) {
    final digits = 10;
    var d = n - pos;
    // 归约到 [-5, 5)，使数字条在循环带上始终紧邻可视区
    d = d - (d / digits).round() * digits;
    return d;
  }
}

/// 数字「飘动」：数值变化时，整体做一次轻微上浮并淡入。
///
/// 与 [RollingNumber] 的区别是它不逐位滚动，
/// 而是整串数字轻轻抬起一下，适合次要数字或频繁变动的场景。
class DriftNumber extends StatefulWidget {
  final double value;
  final int decimals;
  final TextStyle style;
  final String? prefix;

  const DriftNumber({
    super.key,
    required this.value,
    required this.style,
    this.decimals = 2,
    this.prefix,
  });

  @override
  State<DriftNumber> createState() => _DriftNumberState();
}

class _DriftNumberState extends State<DriftNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _shown = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _anim = CuratedDrift(parent: _ctrl);
    _shown = widget.value;
  }

  @override
  void didUpdateWidget(covariant DriftNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      // 先把显示值换成新值再播放，避免出现旧数字在飘
      setState(() => _shown = widget.value);
      _ctrl.forward(from: 0);
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
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        return Transform.translate(
          offset: Offset(0, 6 * (1 - v)),
          child: Opacity(
            opacity: 0.35 + 0.65 * v,
            child: Text(
              '${widget.prefix ?? ''}${_shown.toStringAsFixed(widget.decimals)}',
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

/// 轻微过冲的缓动：数字飘起时带一丝弹性，落位更自然。
class CuratedDrift extends CurvedAnimation {
  CuratedDrift({required super.parent})
      : super(curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
}

/// 供外部复用：把数值格式化成带千分位的字符串
String formatAmount(double v, {int decimals = 2}) {
  final fixed = v.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  final sign = v < 0 ? '-' : '';
  return decimals > 0 ? '$sign$buf.${parts[1]}' : '$sign$buf';
}

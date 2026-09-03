import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/export_helper.dart';
import '../services/bill_export_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/vip_service.dart';
import '../widgets/vip_widgets.dart';
import '../widgets/category_glyph.dart';

class _Bar {
  final String label;
  final double value;
  final int key;
  _Bar({required this.label, required this.value, required this.key});
}

class DataStatsPage extends StatefulWidget {
  const DataStatsPage({super.key});

  @override
  State<DataStatsPage> createState() => _DataStatsPageState();
}

class _DataStatsPageState extends State<DataStatsPage> {
  int _dim = 1; // 0=日 1=月 2=年
  late DateTime _anchor;
  List<Record> _records = [];
  String? _selectedCategory;
  int? _selectedBar;
  int _bgIndex = 0; // 全局深色背景主题索引

  static const _categoryColors = <String, Color>{
    '餐饮': Color(0xFFFF6B6B),
    '交通': Color(0xFF4ECDC4),
    '购物': Color(0xFFFFE66D),
    '娱乐': Color(0xFFFF9F43),
    '居家': Color(0xFF6C5CE7),
    '医疗': Color(0xFFFDA7DF),
    '教育': Color(0xFF00D2D3),
    '通讯': Color(0xFF74B9FF),
    '服饰': Color(0xFFA29BFE),
    '美容': Color(0xFFFD79A8),
    '社交': Color(0xFF55EFC4),
    '旅行': Color(0xFF81ECEC),
    '宠物': Color(0xFFFAB1A0),
    '运动': Color(0xFF00B894),
    '数码': Color(0xFF636E72),
    '礼物': Color(0xFFE17055),
    '其他': Color(0xFFB2BEC3),
    '工资': Color(0xFF10B981),
    '兼职': Color(0xFF4ECDC4),
    '理财': Color(0xFFFF9F43),
    '礼金': Color(0xFFFF6B6B),
    '报销': Color(0xFF6C5CE7),
    '红包': Color(0xFFE17055),
  };
  static const _fallbackPalette = [
    Color(0xFF5C7AFA), Color(0xFFB388EB), Color(0xFFFF8A65), Color(0xFF4DB6AC),
    Color(0xFFF06292), Color(0xFFAED581), Color(0xFFFFD54F), Color(0xFF4FC3F7),
    Color(0xFF90A4AE), Color(0xFFFFAB91), Color(0xFF80CBC4), Color(0xFFCE93D8),
  ];


  Color _colorOf(String category, int index) {
    return _categoryColors[category] ?? _fallbackPalette[index % _fallbackPalette.length];
  }

  @override
  void initState() {
    super.initState();
    _anchor = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    final records = await Storage.getAll();
    final bg = await Storage.getBgIndex();
    setState(() {
      _records = records;
      _bgIndex = bg;
    });
  }

  // ---- 周期边界 ----
  DateTime get _periodStart {
    if (_dim == 0) return DateTime(_anchor.year, _anchor.month, _anchor.day);
    if (_dim == 1) return DateTime(_anchor.year, _anchor.month, 1);
    return DateTime(_anchor.year, 1, 1);
  }

  DateTime get _periodEnd {
    if (_dim == 0) return DateTime(_anchor.year, _anchor.month, _anchor.day + 1);
    if (_dim == 1) return DateTime(_anchor.year, _anchor.month + 1, 1);
    return DateTime(_anchor.year + 1, 1, 1);
  }

  List<Record> get _periodRecords {
    final s = _periodStart;
    final e = _periodEnd;
    return _records.where((r) => !r.time.isBefore(s) && r.time.isBefore(e)).toList();
  }

  double get _income =>
      _periodRecords.where((r) => !r.isExpense).fold(0, (a, r) => a + r.amount);
  double get _expense =>
      _periodRecords.where((r) => r.isExpense).fold(0, (a, r) => a + r.amount);

  List<MapEntry<String, double>> get _categoryExpenses {
    final map = <String, double>{};
    for (final r in _periodRecords) {
      if (r.isExpense) map[r.category] = (map[r.category] ?? 0) + r.amount;
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<_Bar> get _barSeries {
    if (_dim == 0) {
      final slots = List<double>.generate(8, (_) => 0);
      for (final r in _periodRecords) {
        if (r.isExpense) slots[(r.time.hour ~/ 3).clamp(0, 7)] += r.amount;
      }
      return List.generate(8, (i) => _Bar(label: '${i * 3}', value: slots[i], key: i));
    } else if (_dim == 1) {
      final days = DateTime(_anchor.year, _anchor.month + 1, 0).day;
      final arr = List<double>.generate(days, (_) => 0);
      for (final r in _periodRecords) {
        if (r.isExpense) arr[r.time.day - 1] += r.amount;
      }
      return List.generate(days, (i) => _Bar(label: '${i + 1}', value: arr[i], key: i + 1));
    } else {
      final arr = List<double>.generate(12, (_) => 0);
      for (final r in _periodRecords) {
        if (r.isExpense) arr[r.time.month - 1] += r.amount;
      }
      return List.generate(12, (i) => _Bar(label: '${i + 1}', value: arr[i], key: i + 1));
    }
  }

  int _barKeyOf(Record r) {
    if (_dim == 0) return (r.time.hour ~/ 3).clamp(0, 7);
    if (_dim == 1) return r.time.day;
    return r.time.month;
  }

  List<Record> get _detailRecords {
    var list = _periodRecords;
    if (_selectedCategory != null) {
      list = list.where((r) => r.isExpense && r.category == _selectedCategory).toList();
    } else if (_selectedBar != null) {
      list = list.where((r) => _barKeyOf(r) == _selectedBar).toList();
    }
    list = List<Record>.from(list)..sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  bool get _atCurrent {
    final now = DateTime.now();
    if (_dim == 0) {
      return _anchor.year == now.year && _anchor.month == now.month && _anchor.day == now.day;
    }
    if (_dim == 1) return _anchor.year == now.year && _anchor.month == now.month;
    return _anchor.year == now.year;
  }

  String get _periodLabel {
    const week = ['日', '一', '二', '三', '四', '五', '六'];
    if (_dim == 0) {
      return '${_anchor.year}年${_anchor.month}月${_anchor.day}日 周${week[_anchor.weekday % 7]}';
    }
    if (_dim == 1) return '${_anchor.year}年${_anchor.month}月';
    return '${_anchor.year}年';
  }

  String get _barFilterLabel {
    if (_selectedBar == null) return '';
    if (_dim == 0) return '${_selectedBar! * 3}:00-${_selectedBar! * 3 + 3}:00';
    if (_dim == 1) return '${_selectedBar!}日';
    return '${_selectedBar!}月';
  }

  void _switchDim(int i) {
    if (_dim == i) return;
    setState(() {
      _dim = i;
      _selectedCategory = null;
      _selectedBar = null;
    });
  }

  void _nav(int delta) {
    setState(() {
      if (_dim == 0) {
        _anchor = _anchor.add(Duration(days: delta));
      } else if (_dim == 1) {
        _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
      } else {
        _anchor = DateTime(_anchor.year + delta, 1, 1);
      }
      _selectedCategory = null;
      _selectedBar = null;
    });
  }

  /// 点击日期标签 → 按当前维度打开对应的选择器
  void _pickPeriod() {
    if (_dim == 0) {
      _pickDay();
    } else if (_dim == 1) {
      _pickMonth();
    } else {
      _pickYear();
    }
  }

  void _jumpTo(DateTime d) {
    setState(() {
      _anchor = d;
      _selectedCategory = null;
      _selectedBar = null;
    });
  }

  /// 按日：系统日历面板（中文）
  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor.isAfter(now) ? now : _anchor,
      firstDate: DateTime(2000, 1, 1),
      lastDate: now,
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.success,
            onPrimary: Colors.white,
            surface: Color(0xFF1E293B),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) _jumpTo(picked);
  }

  /// 按月：年份切换 + 12 宫格月份选择
  Future<void> _pickMonth() async {
    final now = DateTime.now();
    var year = _anchor.year;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return Dialog(
            backgroundColor: AppDark.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _pickerNavBtn(Icons.chevron_left, year > 2000 ? () => setSt(() => year--) : null),
                      Text('$year年', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      _pickerNavBtn(Icons.chevron_right, year < now.year ? () => setSt(() => year++) : null),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: List.generate(12, (i) {
                      final m = i + 1;
                      final isFuture = year > now.year || (year == now.year && m > now.month);
                      final isSel = year == _anchor.year && m == _anchor.month;
                      final isNow = year == now.year && m == now.month;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: isFuture
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _jumpTo(DateTime(year, m, 1));
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.success : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel
                                  ? AppColors.success
                                  : (isNow ? AppColors.success.withValues(alpha: 0.5) : AppDark.divider),
                            ),
                          ),
                          child: Center(
                            child: Text('$m月', style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : (isFuture ? AppDark.hint : Colors.white),
                            )),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 按年：12 年一页的宫格选择
  Future<void> _pickYear() async {
    final now = DateTime.now();
    var pageStart = (_anchor.year ~/ 12) * 12;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final years = List.generate(12, (i) => pageStart + i);
          return Dialog(
            backgroundColor: AppDark.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _pickerNavBtn(Icons.chevron_left, pageStart > 2000 ? () => setSt(() => pageStart -= 12) : null),
                      Text('${years.first}-${years.last}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      _pickerNavBtn(Icons.chevron_right, years.last < now.year ? () => setSt(() => pageStart += 12) : null),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: years.map((y) {
                      final isFuture = y > now.year;
                      final isSel = y == _anchor.year;
                      final isNow = y == now.year;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: isFuture
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _jumpTo(DateTime(y, 1, 1));
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.success : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel
                                  ? AppColors.success
                                  : (isNow ? AppColors.success.withValues(alpha: 0.5) : AppDark.divider),
                            ),
                          ),
                          child: Center(
                            child: Text('$y', style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : (isFuture ? AppDark.hint : Colors.white),
                            )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pickerNavBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          shape: BoxShape.circle,
          border: Border.all(color: AppDark.divider),
        ),
        child: Icon(icon, size: 18,
          color: onTap != null ? Colors.white : AppDark.hint.withValues(alpha: 0.6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppThemeMode.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: AppBackground(
        theme: theme,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                    child: Column(
                      children: [
                        _buildDimSwitch(),
                        const SizedBox(height: 14),
                        _buildPeriodNav(),
                        const SizedBox(height: 14),
                        _buildSummaryCard(),
                        const SizedBox(height: 14),
                        _buildPieCard(),
                        const SizedBox(height: 14),
                        _buildBarCard(),
                        const SizedBox(height: 14),
                        _buildDetailCard(),
                        const SizedBox(height: 22),
                        _buildExportSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppDark.title),
            onPressed: () => Navigator.pop(context),
          ),
          Text('数据统计', style: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w800,
            color: AppDark.title,
          )),
        ],
      ),
    );
  }

  Widget _buildDimSwitch() {
    const labels = ['按日', '按月', '按年'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppDark.cardBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppDark.divider),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final selected = _dim == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchDim(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Text(labels[i], style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : AppDark.sub,
                  )),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPeriodNav() {
    return Row(
      children: [
        _navButton(Icons.chevron_left, true),
        Expanded(
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _pickPeriod,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
                              child: child,
                            )),
                        child: Text(_periodLabel, key: ValueKey(_periodLabel), style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppDark.title,
                        )),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_calendar_outlined, size: 16, color: AppColors.success),
                  ],
                ),
              ),
            ),
          ),
        ),
        _navButton(Icons.chevron_right, !_atCurrent),
      ],
    );
  }

  Widget _navButton(IconData icon, bool enabled) {
    return GestureDetector(
      onTap: enabled ? () => _nav(icon == Icons.chevron_left ? -1 : 1) : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppDark.cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: AppDark.divider),
        ),
        child: Icon(icon, size: 20,
          color: enabled ? AppDark.title : AppDark.hint.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final balance = _income - _expense;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          _summaryItem('总收入', _income, false),
          Container(width: 1, height: 40, color: Colors.white24),
          _summaryItem('总支出', _expense, true),
          Container(width: 1, height: 40, color: Colors.white24),
          _summaryItem('结余', balance, false),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, bool isExpense) {
    final prefix = isExpense ? '-' : (amount >= 0 ? '+' : '-');
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text('$prefix¥${amount.abs().toStringAsFixed(2)}', style: const TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800,
          )),
        ],
      ),
    );
  }

  Widget _cardShell({required String title, required IconData icon, required Color accent, required Widget child, Widget? trailing}) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(
                color: accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppDark.title)),
              const SizedBox(width: 6),
              Icon(icon, size: 15, color: AppDark.hint),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPieCard() {
    final data = _categoryExpenses;
    final total = _expense;
    return _cardShell(
      title: '支出构成',
      icon: Icons.pie_chart_outline,
      accent: const Color(0xFF6C5CE7),
      trailing: _selectedCategory != null
          ? GestureDetector(
              onTap: () => setState(() => _selectedCategory = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_selectedCategory!, style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6C5CE7))),
                  const SizedBox(width: 3),
                  const Icon(Icons.close, size: 12, color: Color(0xFF6C5CE7)),
                ]),
              ),
            )
          : null,
      child: data.isEmpty
          ? _empty('本周期暂无支出数据')
          : Row(
              children: [
                SizedBox(
                  width: 140, height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 42,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              if (event is FlTapUpEvent) {
                                final idx = response?.touchedSection?.touchedSectionIndex;
                                if (idx != null && idx >= 0 && idx < data.length) {
                                  setState(() {
                                    final name = data[idx].key;
                                    _selectedCategory = _selectedCategory == name ? null : name;
                                    _selectedBar = null;
                                  });
                                }
                              }
                            },
                          ),
                          sections: data.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final e = entry.value;
                            final selected = _selectedCategory == e.key;
                            final dimmed = _selectedCategory != null && !selected;
                            return PieChartSectionData(
                              value: e.value,
                              color: _colorOf(e.key, idx).withValues(alpha: dimmed ? 0.25 : 1),
                              radius: selected ? 27 : 21,
                              showTitle: false,
                            );
                          }).toList(),
                        ),
                        swapAnimationDuration: const Duration(milliseconds: 350),
                        swapAnimationCurve: Curves.easeOut,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('总支出', style: TextStyle(color: AppDark.sub, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text('¥${total.toStringAsFixed(0)}', style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: AppDark.title)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: data.take(5).toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final e = entry.value;
                      final color = _colorOf(e.key, idx);
                      final percent = total > 0 ? e.value / total * 100 : 0.0;
                      final selected = _selectedCategory == e.key;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategory = selected ? null : e.key;
                          _selectedBar = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(width: 9, height: 9, decoration: BoxDecoration(
                                color: color, borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 7),
                              Expanded(child: Text(e.key, style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w500, color: AppDark.body))),
                              Text('¥${e.value.toStringAsFixed(0)}', style: TextStyle(
                                fontSize: 11.5, color: AppDark.sub)),
                              const SizedBox(width: 6),
                              Text('${percent.toStringAsFixed(0)}%', style: TextStyle(
                                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBarCard() {
    final series = _barSeries;
    final hasData = series.any((b) => b.value > 0);
    final unit = _dim == 0 ? '时段' : (_dim == 1 ? '日' : '月');
    return _cardShell(
      title: '支出趋势',
      icon: Icons.bar_chart,
      accent: const Color(0xFF0984E3),
      trailing: _selectedBar != null
          ? GestureDetector(
              onTap: () => setState(() => _selectedBar = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0984E3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_barFilterLabel, style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0984E3))),
                  const SizedBox(width: 3),
                  const Icon(Icons.close, size: 12, color: Color(0xFF0984E3)),
                ]),
              ),
            )
          : null,
      child: !hasData
          ? _empty('本周期暂无支出数据')
          : SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (series.map((b) => b.value).reduce((a, b) => a > b ? a : b)) * 1.25,
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent) {
                        final gi = response?.spot?.touchedBarGroupIndex;
                        if (gi != null && gi >= 0 && gi < series.length) {
                          setState(() {
                            final key = series[gi].key;
                            _selectedBar = _selectedBar == key ? null : key;
                            _selectedCategory = null;
                          });
                        }
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: const Color(0xFF1E293B).withValues(alpha: 0.95),
                      getTooltipItem: (group, gi, rod, ri) {
                        if (rod.toY == 0) return null;
                        return BarTooltipItem(
                          '$unit ${series[gi].label}\n',
                          const TextStyle(color: Colors.white70, fontSize: 11),
                          children: [TextSpan(
                            text: '¥${rod.toY.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          )],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _dim == 1 ? 5 : 1,
                        reservedSize: 20,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= series.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(series[i].label, style: TextStyle(
                              color: AppDark.hint, fontSize: 9.5)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  barGroups: series.asMap().entries.map((entry) {
                    final i = entry.key;
                    final b = entry.value;
                    final selected = _selectedBar == b.key;
                    final dimmed = _selectedBar != null && !selected;
                    return BarChartGroupData(
                      x: i,
                      barRods: [BarChartRodData(
                        toY: b.value,
                        color: b.value == 0
                            ? const Color(0xFF0984E3).withValues(alpha: 0.12)
                            : const Color(0xFF0984E3).withValues(alpha: dimmed ? 0.3 : (selected ? 1 : 0.85)),
                        width: _dim == 1 ? 6 : 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      )],
                    );
                  }).toList(),
                ),
                swapAnimationDuration: const Duration(milliseconds: 350),
                swapAnimationCurve: Curves.easeOut,
              ),
            ),
    );
  }

  Widget _buildDetailCard() {
    final list = _detailRecords;
    String title = '账单明细';
    if (_selectedCategory != null) {
      title = '$_selectedCategory · 明细';
    } else if (_selectedBar != null) {
      title = '${_barFilterLabel} · 明细';
    }
    return _cardShell(
      title: title,
      icon: Icons.receipt_long,
      accent: const Color(0xFF10B981),
      trailing: Text('${list.length} 笔', style: TextStyle(
        fontSize: 12, color: AppDark.sub)),
      child: list.isEmpty
          ? _empty('没有符合条件的记录')
          : Column(
              children: list.map((r) => _detailRow(r)).toList(),
            ),
    );
  }

  Widget _detailRow(Record r) {
    final color = _categoryColors[r.category] ?? const Color(0xFF95A5A6);
    final timeStr = '${r.time.month}/${r.time.day} ${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
            child: CategoryGlyph(name: r.category, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.category, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppDark.title)),
                if (r.note.isNotEmpty)
                  Text(r.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                    fontSize: 11.5, color: AppDark.hint)),
              ],
            ),
          ),
          Text(timeStr, style: TextStyle(fontSize: 11, color: AppDark.hint)),
          const SizedBox(width: 10),
          Text('${r.isExpense ? '-' : '+'}¥${r.amount.toStringAsFixed(2)}', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: r.isExpense ? AppColors.danger : const Color(0xFF10B981))),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 34),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 38, color: AppDark.hint.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(fontSize: 12.5, color: AppDark.hint)),
          ],
        ),
      ),
    );
  }

  // ---- 数据导出 ----
  Widget _buildExportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.file_download_outlined, size: 17, color: Color(0xFF0984E3)),
            const SizedBox(width: 6),
            Text('数据导出', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppDark.title)),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _onExportTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppDark.cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF0984E3).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: const Color(0xFF0984E3).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.file_download_outlined, size: 20, color: Color(0xFF0984E3)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('导出数据', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppDark.title)),
                      const SizedBox(height: 2),
                      Text('Excel 账单含附件图片，可选择单个账本或全部', style: TextStyle(fontSize: 11.5, color: AppDark.sub)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 19, color: AppDark.hint),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 导出入口：数据导出为 VIP 功能，非 VIP 先引导激活
  Future<void> _onExportTap() async {
    if (!await VipService.isVip()) {
      if (!mounted) return;
      await showVipActivateSheet(context, feature: '数据导出');
      return;
    }
    _showExportPicker();
  }

  /// 选择要导出的账本（单个或全部）
  Future<void> _showExportPicker() async {
    final ledgers = await Storage.getLedgers();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppDark.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择导出范围', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('可导出单个账本，或一次性导出全部账本', style: TextStyle(
                fontSize: 12, color: AppDark.sub)),
              const SizedBox(height: 16),
              // 全部账本
              _exportOption(
                ctx,
                icon: Icons.all_inclusive,
                color: const Color(0xFF0984E3),
                title: '全部账本',
                onTap: () async {
                  Navigator.pop(ctx);
                  final all = await Storage.getAllRaw();
                  _doExport(all, '全部账本');
                },
              ),
              const SizedBox(height: 8),
              Divider(color: AppDark.divider, height: 1),
              const SizedBox(height: 8),
              ...ledgers.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _exportOption(
                  ctx,
                  icon: Icons.menu_book,
                  color: Color(l.color),
                  title: l.name,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final recs = await Storage.getForLedger(l.id);
                    _doExport(recs, l.name);
                  },
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportOption(BuildContext ctx, {required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
            Icon(Icons.file_download_outlined, size: 17, color: AppDark.hint),
          ],
        ),
      ),
    );
  }

  /// 选完账本后让用户选择导出格式
  Future<void> _doExport(List<Record> records, String label) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$label」暂无数据可导出')),
      );
      return;
    }
    final hasImages = records.any((r) => r.images.isNotEmpty);
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppDark.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择导出格式',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                hasImages
                    ? '「$label」共 ${records.length} 条记录，含附件图片'
                    : '「$label」共 ${records.length} 条记录',
                style: TextStyle(fontSize: 12, color: AppDark.sub),
              ),
              const SizedBox(height: 16),
              _formatOption(
                ctx,
                icon: Icons.table_chart_outlined,
                color: const Color(0xFF0984E3),
                title: 'Excel 账单 + 图片',
                subtitle: '压缩包，含 xlsx 表格与全部附件图片',
                onTap: () => Navigator.pop(ctx, 'zip'),
              ),
              const SizedBox(height: 10),
              _formatOption(
                ctx,
                icon: Icons.description_outlined,
                color: const Color(0xFF636E72),
                title: 'CSV 账单',
                subtitle: '仅文字数据，体积小，不含图片',
                onTap: () => Navigator.pop(ctx, 'csv'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'zip') {
      await _exportZip(records, label);
    } else {
      _exportCsv(records, label);
    }
  }

  Widget _formatOption(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: AppDark.sub)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 导出为「Excel + 图片」压缩包
  Future<void> _exportZip(List<Record> records, String label) async {
    // 打包可能耗时（图片按原始大小读取），先给出进度提示
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppDark.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('正在打包附件…',
                    style: TextStyle(fontSize: 14, color: AppDark.title)),
              ],
            ),
          ),
        ),
      ),
    );

    BillExportResult result;
    try {
      result = await BillExportService.build(records: records);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    final now = DateTime.now();
    final stamp = '${now.year}${_p2(now.month)}${_p2(now.day)}';
    final filename = 'nishuowoji_${label}_$stamp.zip';
    downloadBytes(result.bytes, filename);

    if (!mounted) return;
    final sizeMb = result.bytes.length / 1024 / 1024;
    final sizeText = sizeMb >= 1
        ? '${sizeMb.toStringAsFixed(1)}MB'
        : '${(result.bytes.length / 1024).toStringAsFixed(0)}KB';
    var msg = '已导出 ${result.recordCount} 条记录、${result.imageCount} 张图片（$sizeText）';
    if (result.hasMissingImages) {
      msg += '，${result.missingImages.length} 张图片已丢失';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  /// 导出为纯 CSV（原有行为）
  void _exportCsv(List<Record> records, String label) {
    final buffer = StringBuffer();
    buffer.writeln('时间,类型,分类,金额,备注');
    final sorted = List<Record>.from(records)..sort((a, b) => b.time.compareTo(a.time));
    for (final r in sorted) {
      final type = r.isExpense ? '支出' : '收入';
      final note = r.note.replaceAll(',', '，').replaceAll('\n', ' ');
      final cat = r.category.replaceAll(',', '，');
      final t = r.time;
      final ts = '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      buffer.writeln('$ts,$type,$cat,${r.amount.toStringAsFixed(2)},$note');
    }
    final now = DateTime.now();
    final filename = 'nishuowoji_${label}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    downloadCsv(buffer.toString(), filename);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导出「$label」共 ${records.length} 条记录')),
    );
  }

  static String _p2(int v) => v.toString().padLeft(2, '0');
}

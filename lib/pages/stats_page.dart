import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage.dart';
import '../theme/app_bg.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => StatsPageState();
}

class StatsPageState extends State<StatsPage> {
  bool _isMonthly = true; // 月度/年度切换
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _trendType = 0; // 0=支出, 1=收入

  List<Record> _records = [];
  double _totalExpense = 0;
  double _totalIncome = 0;
  double _balance = 0;
  Map<String, double> _categoryExpenses = {};
  Map<int, double> _dailyExpenses = {};
  Map<int, double> _dailyIncome = {};
  Map<int, double> _dailyBalance = {};
  Map<int, double> _monthlyExpenses = {};
  Map<int, double> _monthlyIncome = {};

  // 深色主题配色
  static const Color _incomeColor = Color(0xFF34D399);
  static const Color _expenseColor = Color(0xFFFB7185);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次页面可见时刷新数据
    _loadData();
  }

  void refresh() {
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await Storage.getAll();
    _calculateStats(records);
    setState(() {
      _records = records;
    });
  }

  void _calculateStats(List<Record> records) {
    double expense = 0;
    double income = 0;
    _categoryExpenses = {};
    _dailyExpenses = {};
    _dailyIncome = {};
    _dailyBalance = {};
    _monthlyExpenses = {};
    _monthlyIncome = {};

    for (final r in records) {
      final isTargetMonth = _isMonthly
          ? (r.time.year == _selectedYear && r.time.month == _selectedMonth)
          : (r.time.year == _selectedYear);

      if (isTargetMonth) {
        if (r.isExpense) {
          expense += r.amount;
          _categoryExpenses[r.category] = (_categoryExpenses[r.category] ?? 0) + r.amount;
          if (_isMonthly) {
            _dailyExpenses[r.time.day] = (_dailyExpenses[r.time.day] ?? 0) + r.amount;
          } else {
            _monthlyExpenses[r.time.month] = (_monthlyExpenses[r.time.month] ?? 0) + r.amount;
          }
        } else {
          income += r.amount;
          if (_isMonthly) {
            _dailyIncome[r.time.day] = (_dailyIncome[r.time.day] ?? 0) + r.amount;
          } else {
            _monthlyIncome[r.time.month] = (_monthlyIncome[r.time.month] ?? 0) + r.amount;
          }
        }
      }
    }

    // 计算累计结余（逐日叠加）
    final daysInMonth = _isMonthly
        ? DateTime(_selectedYear, _selectedMonth + 1, 0).day
        : 365;
    double runningBalance = 0;
    for (int day = 1; day <= daysInMonth; day++) {
      runningBalance += (_dailyIncome[day] ?? 0) - (_dailyExpenses[day] ?? 0);
      _dailyBalance[day] = runningBalance;
    }

    setState(() {
      _totalExpense = expense;
      _totalIncome = income;
      _balance = income - expense;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      if (_isMonthly) {
        _selectedMonth += delta;
        if (_selectedMonth > 12) {
          _selectedMonth = 1;
          _selectedYear++;
        } else if (_selectedMonth < 1) {
          _selectedMonth = 12;
          _selectedYear--;
        }
      } else {
        _selectedYear += delta;
      }
    });
    _calculateStats(_records);
  }

  String _getMonthYearText() {
    if (_isMonthly) {
      return '$_selectedYear 年 $_selectedMonth 月';
    }
    return '$_selectedYear 年';
  }

  List<MapEntry<String, double>> _getSortedCategories() {
    final list = _categoryExpenses.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  final _categoryColors = {
    '餐饮': const Color(0xFFFF6B6B),
    '交通': const Color(0xFF4ECDC4),
    '购物': const Color(0xFFFFE66D),
    '娱乐': const Color(0xFFFF9F43),
    '居家': const Color(0xFF6C5CE7),
    '医疗': const Color(0xFFFDA7DF),
    '教育': const Color(0xFF00D2D3),
    '通讯': const Color(0xFF74B9FF),
    '服饰': const Color(0xFFA29BFE),
    '美容': const Color(0xFFFD79A8),
    '社交': const Color(0xFF55EFC4),
    '旅行': const Color(0xFF81ECEC),
    '宠物': const Color(0xFFFAB1A0),
    '运动': const Color(0xFF00B894),
    '数码': const Color(0xFF636E72),
    '礼物': const Color(0xFFE17055),
    '其他': const Color(0xFFB2BEC3),
  };

  // 自定义分类的备选颜色
  static const _fallbackPalette = [
    Color(0xFFE84393), Color(0xFF0984E3), Color(0xFF00CEC9),
    Color(0xFFD63031), Color(0xFF6C5CE7), Color(0xFFFDAA5E),
    Color(0xFF2ED573), Color(0xFFFFA502), Color(0xFF3742FA),
    Color(0xFF8854D0), Color(0xFF20BF6B), Color(0xFFEB3B5A),
  ];

  Color _getColor(String category, int index) {
    return _categoryColors[category] ?? _fallbackPalette[index % _fallbackPalette.length];
  }

  // ---------------- 构建 ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            _buildPeriodNav(),
            const SizedBox(height: 18),
            _buildSummary(),
            const SizedBox(height: 20),
            _buildDailyTrend(),
            const SizedBox(height: 20),
            _buildCategoryRanking(),
          ],
        ),
      ),
    );
  }

  /// 毛玻璃卡片
  Widget _glass({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDark.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppDark.cardBorder),
        ),
          child: child,
        ),
      ),
    );
  }

  // ---------------- 头部：标题 + 月度/年度 ----------------

  Widget _buildHeader() {
    return Row(
      children: [
        Text('统计', style: TextStyle(
          color: AppDark.title, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1,
        )),
        const Spacer(),
        // 月度/年度切换（毛玻璃分段）
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppDark.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppDark.cardBorder),
          ),
          child: Row(
            children: [
              _buildToggleBtn('月度', _isMonthly, () => setState(() {
                _isMonthly = true;
                _selectedYear = DateTime.now().year;
                _selectedMonth = DateTime.now().month;
                _calculateStats(_records);
              })),
              _buildToggleBtn('年度', !_isMonthly, () => setState(() {
                _isMonthly = false;
                _selectedYear = DateTime.now().year;
                _calculateStats(_records);
              })),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleBtn(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppBgTheme.all[0].accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: selected ? Border.all(color: AppBgTheme.all[0].accent) : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? AppBgTheme.all[0].accent : AppDark.sub,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ---------------- 时间选择 ----------------

  Widget _buildPeriodNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _navArrow(Icons.chevron_left, () => _changeMonth(-1)),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: _showDatePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppDark.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDark.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month, color: AppDark.sub, size: 15),
                const SizedBox(width: 6),
                Text(
                  _getMonthYearText(),
                  style: TextStyle(
                    color: AppDark.title, fontWeight: FontWeight.w700, fontSize: 13.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, color: AppDark.sub, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        _navArrow(Icons.chevron_right, () => _changeMonth(1)),
      ],
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppDark.cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: AppDark.cardBorder),
        ),
        child: Icon(icon, size: 19, color: AppDark.sub),
      ),
    );
  }

  // ---------------- 日期选择器（日历 / 年份） ----------------

  void _showDatePicker() {
    if (_isMonthly) {
      _showCalendarPicker();
    } else {
      _showYearPicker();
    }
  }

  /// 紧凑金额文本（用于日历小格子）：满万显示 w、满千显示 k、其余保留一位小数（整数不带小数）
  String _compactAmount(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}w';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.roundToDouble()) return '${v.toInt()}';
    return v.toStringAsFixed(1);
  }

  /// 月度模式：弹出日历，点选任意日期即跳转到该月统计
  void _showCalendarPicker() async {
    int pickerYear = _selectedYear;
    int pickerMonth = _selectedMonth;
    final now = DateTime.now();
    final accent = AppBgTheme.all[(await Storage.getBgIndex()) % AppBgTheme.all.length].accent;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: AppDark.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final firstDay = DateTime(pickerYear, pickerMonth, 1);
              final daysInMonth = DateTime(pickerYear, pickerMonth + 1, 0).day;
              final startWeekday = firstDay.weekday % 7; // 0=周日
              // 当月每日支出合计（日 -> 金额），用于日历直接展示每天花了多少
              final dailyExpense = <int, double>{};
              for (final r in _records) {
                if (r.time.year == pickerYear && r.time.month == pickerMonth && r.isExpense) {
                  dailyExpense[r.time.day] = (dailyExpense[r.time.day] ?? 0) + r.amount;
                }
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 拖拽把手
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 年月导航
                    Row(
                      children: [
                        _pickerNavArrow(Icons.chevron_left, () {
                          setSheetState(() {
                            pickerMonth--;
                            if (pickerMonth < 1) { pickerMonth = 12; pickerYear--; }
                          });
                        }),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$pickerYear 年 $pickerMonth 月',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setSheetState(() {
                            pickerYear = now.year;
                            pickerMonth = now.month;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accent.withOpacity(0.4)),
                            ),
                            child: Text('今天', style: TextStyle(
                              color: accent, fontSize: 12, fontWeight: FontWeight.w700,
                            )),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _pickerNavArrow(Icons.chevron_right, () {
                          setSheetState(() {
                            pickerMonth++;
                            if (pickerMonth > 12) { pickerMonth = 1; pickerYear++; }
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 星期头
                    Row(
                      children: ['日', '一', '二', '三', '四', '五', '六'].map((d) =>
                        Expanded(child: Center(
                          child: Text(d, style: TextStyle(
                            fontSize: 12, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w600,
                          )),
                        ))
                      ).toList(),
                    ),
                    const SizedBox(height: 6),
                    // 日期网格
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: startWeekday + daysInMonth,
                      itemBuilder: (gctx, index) {
                        if (index < startWeekday) return const SizedBox();
                        final day = index - startWeekday + 1;
                        final isToday = pickerYear == now.year && pickerMonth == now.month && day == now.day;
                        final dayExpense = dailyExpense[day] ?? 0;
                        return GestureDetector(
                          onTap: () {
                            // 直接查看当天记录：先关日历，再加一帧弹出当日记录列表
                            Navigator.pop(sheetCtx);
                            Future.delayed(Duration.zero, () {
                              _showDayRecords(day, year: pickerYear, month: pickerMonth);
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isToday ? accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                    color: isToday ? Colors.white : Colors.white.withOpacity(0.85),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  dayExpense > 0 ? '-${_compactAmount(dayExpense)}' : '',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                    color: isToday
                                        ? Colors.white
                                        : (dayExpense > 0 ? _expenseColor : Colors.transparent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('点击任意日期查看当天记录', style: TextStyle(
                      fontSize: 11.5, color: Colors.white.withOpacity(0.4),
                    )),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 年度模式：弹出年份选择器（12 年/页），点选即跳转该年统计
  void _showYearPicker() async {
    int pageStart = (_selectedYear ~/ 12) * 12;
    final currentYear = DateTime.now().year;
    final accent = AppBgTheme.all[(await Storage.getBgIndex()) % AppBgTheme.all.length].accent;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: AppDark.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final years = List.generate(12, (i) => pageStart + i);
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _pickerNavArrow(Icons.chevron_left, () {
                          setSheetState(() => pageStart -= 12);
                        }),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$pageStart - ${pageStart + 11}',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        _pickerNavArrow(Icons.chevron_right, () {
                          setSheetState(() => pageStart += 12);
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: years.map((y) {
                        final isSelected = y == _selectedYear;
                        final isCurrent = y == currentYear;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedYear = y);
                            _calculateStats(_records);
                            Navigator.pop(sheetCtx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? accent
                                    : (isCurrent
                                        ? accent.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.10)),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$y',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected || isCurrent ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isCurrent ? accent : Colors.white.withOpacity(0.8)),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _pickerNavArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Icon(icon, size: 18, color: Colors.white.withOpacity(0.75)),
      ),
    );
  }

  // ---------------- 汇总数字（裸排在底色上） ----------------

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          _summaryNum('总收入', _totalIncome, _incomeColor),
          _summaryDivider(),
          _summaryNum('总支出', _totalExpense, _expenseColor),
          _summaryDivider(),
          _summaryNum('结余', _balance, AppDark.title),
        ],
      ),
    );
  }

  Widget _summaryNum(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(
            color: AppDark.sub, fontSize: 12,
          )),
          const SizedBox(height: 6),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color, fontSize: 18.5, fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(width: 1, height: 34, color: AppDark.divider);
  }

  // ---------------- 每日趋势 ----------------

  Widget _buildDailyTrend() {
    final data = _isMonthly
        ? (_trendType == 0 ? _dailyExpenses : _dailyIncome)
        : (_trendType == 0 ? _monthlyExpenses : _monthlyIncome);
    final trendColor = _trendType == 0 ? _expenseColor : _incomeColor;
    final trendLabel = _trendType == 0 ? '支出' : '收入';

    double summaryValue = _trendType == 0 ? _totalExpense : _totalIncome;
    final hasData = data.isNotEmpty;

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(
                  color: trendColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text('每日趋势', style: TextStyle(
                color: AppDark.title, fontSize: 16, fontWeight: FontWeight.w700,
              )),
              const Spacer(),
              Text(
                '$trendLabel合计',
                style: TextStyle(color: AppDark.sub, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                '¥${summaryValue.toStringAsFixed(2)}',
                style: TextStyle(
                  color: trendColor, fontSize: 14, fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 支出/收入切换 + 图表类型
          Row(
            children: [
              _buildTrendTypeBtn('支出', 0, _expenseColor),
              const SizedBox(width: 8),
              _buildTrendTypeBtn('收入', 1, _incomeColor),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: !hasData
                ? Center(child: Text('暂无数据',
                    style: TextStyle(color: AppDark.hint)))
                : _buildBarChart(data, trendColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendTypeBtn(String text, int type, Color color) {
    final selected = _trendType == type;
    return GestureDetector(
      onTap: () => setState(() => _trendType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : AppDark.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppDark.cardBorder,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : AppDark.sub,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<int, double> data, Color color) {
    // 月度: 最近7天; 年度: 12个月
    final int startDay;
    final int endDay;
    if (_isMonthly) {
      final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      final today = DateTime.now().day;
      endDay = (_selectedMonth == DateTime.now().month) ? today : daysInMonth;
      startDay = (endDay - 6).clamp(1, daysInMonth);
    } else {
      startDay = 1;
      endDay = 12;
    }
    final range = endDay - startDay + 1;

    final visibleValues = <double>[];
    for (int i = startDay; i <= endDay; i++) {
      visibleValues.add(data[i] ?? 0);
    }
    final maxVal = visibleValues.isEmpty ? 100.0 : visibleValues.reduce((a, b) => a > b ? a : b);
    final minVal = visibleValues.isEmpty ? 0.0 : visibleValues.reduce((a, b) => a < b ? a : b);
    final maxY = maxVal > 0 ? maxVal * 1.2 : 100.0;
    final minY = minVal < 0 ? minVal * 1.2 : 0.0;
    final yInterval = (maxY - minY) > 0 ? (maxY - minY) / 3 : 100.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: minY,
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent || event is FlTapDownEvent) {
              final day = response?.spot?.touchedBarGroup.x;
              if (day != null) _showDayRecords(day);
            }
          },
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: const Color(0xFF1E293B).withOpacity(0.95),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (rod.toY == 0) return null;
              final unit = _isMonthly ? '日' : '月';
              return BarTooltipItem(
                '${group.x}$unit\n',
                TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                children: [
                  TextSpan(
                    text: '¥${rod.toY.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: range <= 7 ? 1 : (range <= 15 ? 2 : 5),
              getTitlesWidget: (value, meta) {
                final d = value.toInt();
                if (d < startDay || d > endDay) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('$d', style: TextStyle(
                    color: AppDark.hint, fontSize: 10,
                  )),
                );
              },
              reservedSize: 22,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                if (value.abs() >= 1000) {
                  return Text('${(value / 1000).toStringAsFixed(1)}k', style: TextStyle(
                    color: AppDark.hint, fontSize: 10,
                  ));
                }
                return Text('${value.toInt()}', style: TextStyle(
                  color: AppDark.hint, fontSize: 10,
                ));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppDark.divider,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        barGroups: List.generate(range, (i) {
          final day = startDay + i;
          final amount = data[day] ?? 0;
          return BarChartGroupData(
            x: day,
            barRods: [
              BarChartRodData(
                toY: amount,
                color: amount != 0 ? color : color.withOpacity(0.12),
                width: range > 14 ? 6 : (range > 7 ? 10 : 16),
                borderRadius: amount >= 0
                    ? const BorderRadius.vertical(top: Radius.circular(4))
                    : const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// 展示某一天的全部记录（year/month 不传则取当前选中月）
  void _showDayRecords(int day, {int? year, int? month}) {
    final y = year ?? _selectedYear;
    final m = month ?? _selectedMonth;
    final dayRecords = _records.where((r) =>
        r.time.year == y && r.time.month == m && r.time.day == day
    ).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppDark.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Column(
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('$y年$m月$day日',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text('共${dayRecords.length}笔',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            if (dayRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
                child: Text('当天无记录', style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 14,
                )),
              )
            else
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: dayRecords.length,
                  itemBuilder: (ctx, idx) {
                    final r = dayRecords[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                r.category.isNotEmpty ? r.category.substring(0, 1) : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.category, style: const TextStyle(
                                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600,
                                )),
                                if (r.note != r.category)
                                  Text(r.note, style: TextStyle(
                                    color: Colors.white.withOpacity(0.5), fontSize: 12,
                                  )),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                r.isExpense ? '-¥${r.amount.toStringAsFixed(2)}' : '+¥${r.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: r.isExpense ? _expenseColor : _incomeColor,
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- 分类排行 ----------------

  Widget _buildCategoryRanking() {
    final sortedCategories = _getSortedCategories();
    final total = _totalExpense;

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFF472B6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text('分类排行', style: TextStyle(
                color: AppDark.title, fontSize: 16, fontWeight: FontWeight.w700,
              )),
              const Spacer(),
              Text(
                '共${sortedCategories.length}类',
                style: TextStyle(color: AppDark.sub, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (sortedCategories.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(30),
              child: Text('暂无数据', style: TextStyle(color: AppDark.hint)),
            ))
          else ...[
            // 环形图 + Top4 图例
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 40,
                          sections: sortedCategories.toList().asMap().entries.map((entry) {
                            final idx = entry.key;
                            final e = entry.value;
                            final color = _getColor(e.key, idx);
                            return PieChartSectionData(
                              value: e.value,
                              color: color,
                              radius: 22,
                              showTitle: false,
                            );
                          }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('总支出', style: TextStyle(
                            color: AppDark.sub, fontSize: 10,
                          )),
                          const SizedBox(height: 2),
                          Text('¥${total.toStringAsFixed(0)}', style: TextStyle(
                            color: AppDark.title, fontSize: 16, fontWeight: FontWeight.w800,
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: sortedCategories.take(4).toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final e = entry.value;
                      final color = _getColor(e.key, index);
                      final percent = total > 0 ? (e.value / total * 100) : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(e.key, style: TextStyle(
                                color: AppDark.body,
                                fontSize: 13, fontWeight: FontWeight.w500,
                              )),
                            ),
                            Text(
                              '${percent.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: color, fontSize: 12, fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: AppDark.divider),
            const SizedBox(height: 14),
            Text('消费明细排行', style: TextStyle(
              color: AppDark.body, fontSize: 14, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 14),
            // 详细排行
            ...sortedCategories.asMap().entries.map((entry) {
              final index = entry.key;
              final e = entry.value;
              final color = _getColor(e.key, index);
              final percent = total > 0 ? (e.value / total * 100) : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    // 排名
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                      color: index < 3 ? color.withOpacity(0.22) : AppDark.cardBg,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text('${index + 1}', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: index < 3 ? color : AppDark.hint,
                      )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 分类名
                    SizedBox(
                      width: 44,
                      child: Text(e.key, style: TextStyle(
                        color: AppDark.body,
                        fontSize: 13, fontWeight: FontWeight.w500,
                      )),
                    ),
                    const SizedBox(width: 8),
                    // 进度条
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 8,
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            backgroundColor: AppDark.track,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 金额
                    SizedBox(
                      width: 60,
                      child: Text(
                        '¥${e.value.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppDark.title, fontSize: 12, fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

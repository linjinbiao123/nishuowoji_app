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
  int _chartType = 1; // 0=柱状图, 1=折线图
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
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
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
        const Text('统计', style: TextStyle(
          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1,
        )),
        const Spacer(),
        // 月度/年度切换（毛玻璃分段）
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
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
          color: selected ? Colors.white.withOpacity(0.20) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withOpacity(0.55),
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
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month, color: Colors.white.withOpacity(0.6), size: 15),
                const SizedBox(width: 6),
                Text(
                  _getMonthYearText(),
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, color: Colors.white.withOpacity(0.5), size: 16),
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
          color: Colors.white.withOpacity(0.07),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Icon(icon, size: 19, color: Colors.white.withOpacity(0.75)),
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

  /// 月度模式：弹出日历，点选任意日期即跳转到该月统计
  void _showCalendarPicker() {
    int pickerYear = _selectedYear;
    int pickerMonth = _selectedMonth;
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: AppDark.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final firstDay = DateTime(pickerYear, pickerMonth, 1);
              final daysInMonth = DateTime(pickerYear, pickerMonth + 1, 0).day;
              final startWeekday = firstDay.weekday % 7; // 0=周日
              // 当月有记录的日子
              final daysWithRecords = <int>{};
              for (final r in _records) {
                if (r.time.year == pickerYear && r.time.month == pickerMonth) {
                  daysWithRecords.add(r.time.day);
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
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                            ),
                            child: const Text('今天', style: TextStyle(
                              color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.w700,
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
                        final hasRecord = daysWithRecords.contains(day);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedYear = pickerYear;
                              _selectedMonth = pickerMonth;
                            });
                            _calculateStats(_records);
                            Navigator.pop(sheetCtx);
                          },
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isToday ? const Color(0xFF10B981) : Colors.transparent,
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
                                const SizedBox(height: 2),
                                Container(
                                  width: 4, height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasRecord
                                        ? (isToday ? Colors.white : const Color(0xFF34D399))
                                        : Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('点击任意日期查看该月统计', style: TextStyle(
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
  void _showYearPicker() {
    int pageStart = (_selectedYear ~/ 12) * 12;
    final currentYear = DateTime.now().year;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
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
                                  ? const Color(0xFF10B981)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF10B981)
                                    : (isCurrent
                                        ? const Color(0xFF34D399).withOpacity(0.5)
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
                                      : (isCurrent ? const Color(0xFF34D399) : Colors.white.withOpacity(0.8)),
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
          _summaryNum('结余', _balance, Colors.white),
        ],
      ),
    );
  }

  Widget _summaryNum(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(
            color: Colors.white.withOpacity(0.55), fontSize: 12,
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
    return Container(width: 1, height: 34, color: Colors.white.withOpacity(0.12));
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
              const Text('每日趋势', style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
              )),
              const Spacer(),
              Text(
                '$trendLabel合计',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
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
              const Spacer(),
              _buildChartTypeBtn('柱状', 0),
              const SizedBox(width: 6),
              _buildChartTypeBtn('折线', 1),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: !hasData
                ? Center(child: Text('暂无数据',
                    style: TextStyle(color: Colors.white.withOpacity(0.35))))
                : _chartType == 0
                    ? _buildBarChart(data, trendColor)
                    : _buildLineChart(data, trendColor),
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
          color: selected ? color : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.10),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildChartTypeBtn(String text, int type) {
    final selected = _chartType == type;
    return GestureDetector(
      onTap: () => setState(() => _chartType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withOpacity(0.5),
            fontSize: 11,
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
                    color: Colors.white.withOpacity(0.38), fontSize: 10,
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
                    color: Colors.white.withOpacity(0.38), fontSize: 10,
                  ));
                }
                return Text('${value.toInt()}', style: TextStyle(
                  color: Colors.white.withOpacity(0.38), fontSize: 10,
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
            color: Colors.white.withOpacity(0.07),
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

  Widget _buildLineChart(Map<int, double> data, Color color) {
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

    final spots = <FlSpot>[];
    for (int i = startDay; i <= endDay; i++) {
      spots.add(FlSpot(i.toDouble(), data[i] ?? 0));
    }

    final visibleValues = <double>[];
    for (int i = startDay; i <= endDay; i++) {
      visibleValues.add(data[i] ?? 0);
    }
    final maxValue = visibleValues.isEmpty ? 100.0 : visibleValues.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
    final minValue = visibleValues.isEmpty ? 0.0 : visibleValues.reduce((a, b) => a < b ? a : b);
    final maxY = maxValue > 0 ? maxValue * 1.2 : 100.0;
    final minY = minValue > 0 ? minValue * 0.8 : 0.0;
    final yInterval = (maxY - minY) > 0 ? (maxY - minY) / 3 : 100.0;
    final range = endDay - startDay;

    return LineChart(
      LineChartData(
        minX: startDay.toDouble(),
        maxX: endDay.toDouble(),
        maxY: maxY,
        minY: minY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: const Color(0xFF1E293B).withOpacity(0.95),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final unit = _isMonthly ? '日' : '月';
                return LineTooltipItem(
                  '${spot.x.toInt()}$unit\n',
                  TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                  children: [
                    TextSpan(
                      text: '¥${spot.y.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              }).toList();
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
                    color: Colors.white.withOpacity(0.38), fontSize: 10,
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
                if (value >= 1000) {
                  return Text('${(value / 1000).toStringAsFixed(1)}k', style: TextStyle(
                    color: Colors.white.withOpacity(0.38), fontSize: 10,
                  ));
                }
                return Text('${value.toInt()}', style: TextStyle(
                  color: Colors.white.withOpacity(0.38), fontSize: 10,
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
            color: Colors.white.withOpacity(0.07),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                return (data[spot.x.toInt()] ?? 0) != 0;
              },
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: color,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.25), color.withOpacity(0.02)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
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
              const Text('分类排行', style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
              )),
              const Spacer(),
              Text(
                '共${sortedCategories.length}类',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (sortedCategories.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(30),
              child: Text('暂无数据', style: TextStyle(color: Colors.white.withOpacity(0.35))),
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
                            color: Colors.white.withOpacity(0.55), fontSize: 10,
                          )),
                          const SizedBox(height: 2),
                          Text('¥${total.toStringAsFixed(0)}', style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
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
                                color: Colors.white.withOpacity(0.85),
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
            Divider(color: Colors.white.withOpacity(0.10)),
            const SizedBox(height: 14),
            Text('消费明细排行', style: TextStyle(
              color: Colors.white.withOpacity(0.85), fontSize: 14, fontWeight: FontWeight.w600,
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
                        color: index < 3 ? color.withOpacity(0.22) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text('${index + 1}', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: index < 3 ? color : Colors.white.withOpacity(0.4),
                        )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 分类名
                    SizedBox(
                      width: 44,
                      child: Text(e.key, style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
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
                            backgroundColor: Colors.white.withOpacity(0.08),
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
                        style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
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

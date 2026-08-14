import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../widgets/attachment_image.dart';
import '../widgets/image_viewer.dart';
import '../services/attachment_service.dart';
import 'receipt_gallery_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  List<Record> _allRecords = [];
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDay;
  bool _showCalendar = false;
  bool _isYearly = false;
  String _attachDir = '';
  List<Account> _accounts = [];

  final _categoryIcons = <String, IconData>{
    '餐饮': Icons.restaurant,
    '交通': Icons.directions_bus,
    '购物': Icons.shopping_bag,
    '娱乐': Icons.sports_esports,
    '居家': Icons.home,
    '医疗': Icons.local_hospital,
    '教育': Icons.school,
    '通讯': Icons.phone_android,
    '服饰': Icons.checkroom,
    '美容': Icons.face_retouching_natural,
    '社交': Icons.people,
    '旅行': Icons.flight,
    '宠物': Icons.pets,
    '运动': Icons.fitness_center,
    '数码': Icons.devices,
    '礼物': Icons.card_giftcard,
    '其他': Icons.more_horiz,
  };

  final _categoryColors = <String, Color>{
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCustomCategories();
    AttachmentService.dirPath().then((d) {
      if (mounted) setState(() => _attachDir = d);
    });
  }

  void refresh() => _loadData();

  Future<void> _loadData() async {
    final records = await Storage.getAll();
    final accounts = await Storage.getAccounts();
    setState(() {
      _allRecords = records;
      _accounts = accounts;
    });
  }

  String? _accountNameFor(String? accountId) {
    if (accountId == null || accountId.isEmpty) return null;
    try {
      return _accounts.firstWhere((a) => a.id == accountId).name;
    } catch (_) {
      return null;
    }
  }

  Color _accountTagColor(String name) {
    if (name == '微信') return const Color(0xFF07C160);
    if (name == '支付宝') return AppColors.primary;
    return AppColors.primary;
  }

  Future<void> _loadCustomCategories() async {
    final custom = await Storage.getCustomCategories();
    setState(() {
      for (final name in custom) {
        _categoryIcons[name] = Icons.label;
        _categoryColors[name] = const Color(0xFF95A5A6);
      }
    });
  }

  /// 当前账本下的附件图片总张数（用于「票据」入口角标）
  int get _photoCount =>
      _allRecords.fold<int>(0, (sum, r) => sum + r.images.length);

  Widget _buildToggleBtn(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppBgTheme.all[0].accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: AppBgTheme.all[0].accent) : null,
        ),
        child: Text(text, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? AppBgTheme.all[0].accent : AppDark.sub,
        )),
      ),
    );
  }

  /// 打开票据相册：按年月分组集中翻阅所有带图片的记录
  void _openReceiptGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptGalleryPage()),
    ).then((_) => _loadData());
  }

  void _changeMonth(int delta) {
    setState(() {
      if (_isYearly) {
        _currentMonth = DateTime(_currentMonth.year + delta, _currentMonth.month);
      } else {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
      }
      _selectedDay = null;
    });
  }

  List<Record> get _monthRecords {
    return _allRecords.where((r) =>
      r.time.year == _currentMonth.year && r.time.month == _currentMonth.month
    ).toList();
  }

  List<Record> get _yearRecords {
    return _allRecords.where((r) =>
      r.time.year == _currentMonth.year
    ).toList();
  }

  List<Record> get _displayRecords {
    if (_isYearly) return _yearRecords;
    if (_selectedDay != null) {
      return _allRecords.where((r) =>
        r.time.year == _selectedDay!.year &&
        r.time.month == _selectedDay!.month &&
        r.time.day == _selectedDay!.day
      ).toList();
    }
    return _monthRecords;
  }

  Map<String, List<Record>> get _groupedByDate {
    final map = <String, List<Record>>{};
    if (_isYearly) {
      // 年度按月分组
      for (final r in _displayRecords) {
        final key = '${r.time.year}-${r.time.month.toString().padLeft(2, '0')}';
        map.putIfAbsent(key, () => []).add(r);
      }
      final sorted = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
      return Map.fromEntries(sorted);
    }
    for (final r in _displayRecords) {
      final key = '${r.time.year}-${r.time.month.toString().padLeft(2, '0')}-${r.time.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(r);
    }
    final sorted = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sorted);
  }

  Set<int> get _daysWithRecords {
    final days = <int>{};
    for (final r in _monthRecords) {
      days.add(r.time.day);
    }
    return days;
  }

  double get _displayExpense {
    return _displayRecords.where((r) => r.isExpense).fold(0, (sum, r) => sum + r.amount);
  }

  double get _displayIncome {
    return _displayRecords.where((r) => !r.isExpense).fold(0, (sum, r) => sum + r.amount);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedByDate;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题 + 月份切换
              Row(
                children: [
                  Text('历史账单', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: AppDark.title,
                  )),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _changeMonth(-1),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppDark.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppDark.cardBorder),
                      ),
                      child: Icon(Icons.chevron_left, size: 20, color: AppDark.sub),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isYearly ? '${_currentMonth.year}年' : '${_currentMonth.year}年${_currentMonth.month}月',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppDark.title),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _changeMonth(1),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppDark.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppDark.cardBorder),
                      ),
                      child: Icon(Icons.chevron_right, size: 20, color: AppDark.sub),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 月度/年度切换 + 日历按钮
              Row(
                children: [
                  // 月度/年度 toggle
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppDark.cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppDark.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggleBtn('月度', !_isYearly, () => setState(() { _isYearly = false; _selectedDay = null; })),
                        _buildToggleBtn('年度', _isYearly, () => setState(() { _isYearly = true; _selectedDay = null; _showCalendar = false; })),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 票据相册入口（集中查看所有带图片的记录）
                  GestureDetector(
                    onTap: _openReceiptGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppDark.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppDark.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 14, color: AppDark.sub),
                          const SizedBox(width: 4),
                          Text(
                            _photoCount > 0 ? '票据 $_photoCount' : '票据',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: AppDark.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_isYearly) const SizedBox(width: 8),
                  // 日历切换按钮（仅月度显示）
                  if (!_isYearly)
                    GestureDetector(
                      onTap: () => setState(() {
                        _showCalendar = !_showCalendar;
                        if (!_showCalendar) _selectedDay = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppDark.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppDark.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month, size: 14,
                              color: _showCalendar ? AppDark.title : AppDark.sub),
                            const SizedBox(width: 4),
                            Text(
                              _showCalendar ? '收起' : '日历',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: _showCalendar ? AppDark.title : AppDark.sub,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              _showCalendar ? Icons.expand_less : Icons.expand_more,
                              size: 14,
                              color: _showCalendar ? AppDark.title : AppDark.sub,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              // 日历
              if (_showCalendar) ...[
                const SizedBox(height: 12),
                _buildCalendar(),
              ],
              const SizedBox(height: 12),
              // 汇总
              GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('收入', style: TextStyle(color: AppDark.sub, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('+¥${_displayIncome.toStringAsFixed(2)}', style: TextStyle(
                            color: Color(0xFF34D399), fontSize: 15, fontWeight: FontWeight.w700,
                          )),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: AppDark.divider),
                    Expanded(
                      child: Column(
                        children: [
                          Text('支出', style: TextStyle(color: AppDark.sub, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('-¥${_displayExpense.toStringAsFixed(2)}', style: TextStyle(
                            color: Color(0xFFFB7185), fontSize: 15, fontWeight: FontWeight.w700,
                          )),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: AppDark.divider),
                    Expanded(
                      child: Column(
                        children: [
                          Text('笔数', style: TextStyle(color: AppDark.sub, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('${_displayRecords.length}', style: TextStyle(
                            color: AppDark.title, fontSize: 15, fontWeight: FontWeight.w700,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 选中日期提示
              if (_selectedDay != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedDay!.month}月${_selectedDay!.day}日 的记录',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppDark.title),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _selectedDay = null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppDark.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppDark.cardBorder),
                          ),
                          child: Text('查看全月', style: TextStyle(
                            fontSize: 12, color: AppColors.accent,
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
              // 按日期分组
              if (grouped.isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('暂无记录', style: TextStyle(color: AppDark.hint, fontSize: 14)),
                ))
              else
                ...grouped.entries.map((entry) => _buildDateGroup(entry.key, entry.value)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=周日
    final today = DateTime.now();
    final daysWithRecords = _daysWithRecords;

    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 星期头
          Row(
            children: ['日', '一', '二', '三', '四', '五', '六'].map((d) =>
              Expanded(child: Center(
                child: Text(d, style: TextStyle(
                  fontSize: 12, color: AppDark.hint, fontWeight: FontWeight.w500,
                )),
              ))
            ).toList(),
          ),
          const SizedBox(height: 8),
          // 日期网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (ctx, index) {
              if (index < startWeekday) return const SizedBox();
              final day = index - startWeekday + 1;
              final date = DateTime(year, month, day);
              final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
              final isSelected = _selectedDay != null &&
                _selectedDay!.year == year && _selectedDay!.month == month && _selectedDay!.day == day;
              final hasRecord = daysWithRecords.contains(day);

              return GestureDetector(
                onTap: () => setState(() {
                  _selectedDay = isSelected ? null : date;
                }),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : (isToday ? AppColors.primary.withOpacity(0.15) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? Colors.white : (isToday ? AppColors.accent : AppDark.title),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasRecord
                            ? (isSelected ? Colors.white : AppColors.accent)
                            : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(String dateKey, List<Record> records) {
    final parts = dateKey.split('-');
    final month = int.parse(parts[1]);
    final day = parts.length > 2 ? int.parse(parts[2]) : null;
    final expense = records.where((r) => r.isExpense).fold(0.0, (s, r) => s + r.amount);
    final income = records.where((r) => !r.isExpense).fold(0.0, (s, r) => s + r.amount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  day != null ? '${month}月${day}日' : '${month}月',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppDark.title),
                ),
                const Spacer(),
                if (expense > 0)
                  Text('支出 ¥${expense.toStringAsFixed(0)}', style: TextStyle(
                    color: AppDark.hint, fontSize: 11,
                  )),
                if (expense > 0 && income > 0)
                  Text(' / ', style: TextStyle(color: AppDark.hint, fontSize: 11)),
                if (income > 0)
                  Text('收入 ¥${income.toStringAsFixed(0)}', style: TextStyle(
                    color: AppDark.hint, fontSize: 11,
                  )),
              ],
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: AppDark.divider),
            ...records.map((r) => _buildRecordItem(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordItem(Record r) {
    final icon = _categoryIcons[r.category] ?? Icons.receipt;
    final color = _categoryColors[r.category] ?? AppColors.primary;

    return _SwipeableRecord(
      onDelete: () => _showDeleteDialog(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r.category, style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, color: AppDark.title,
                      )),
                      if (r.isInvoice) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB020).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('发票', style: TextStyle(
                            color: Color(0xFFFFB020), fontSize: 10, fontWeight: FontWeight.w600,
                          )),
                        ),
                      ],
                      if (_accountNameFor(r.accountId) case final name?) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accountTagColor(name).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(name, style: TextStyle(
                          color: _accountTagColor(name), fontSize: 10, fontWeight: FontWeight.w600,
                        )),
                      ),
                      ],
                    ],
                  ),
                  if (r.note != r.category)
                    Text(r.note, style: TextStyle(
                      color: AppDark.sub, fontSize: 12,
                    )),
                ],
              ),
            ),
            if (r.images.isNotEmpty) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showImageViewer(r.images),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...r.images.take(3).map((img) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AttachmentImage(
                          path: _attachDir.isNotEmpty ? '$_attachDir/$img' : img,
                          width: 38, height: 38,
                        ),
                      ),
                    )).toList(),
                    if (r.images.length > 3)
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+${r.images.length - 3}',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  r.isExpense ? '-¥${r.amount.toStringAsFixed(2)}' : '+¥${r.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: r.isExpense ? AppColors.danger : AppColors.success,
                    fontWeight: FontWeight.w700, fontSize: 15,
                  ),
                ),
                Text(
                  '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: AppDark.hint, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 全屏查看附件，支持手势滑动与按钮切换
  void _showImageViewer(List<String> names, {int initialIndex = 0}) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => ImageViewerDialog(
        names: names,
        attachDir: _attachDir,
        initialIndex: initialIndex,
      ),
    );
  }

  void _showDeleteDialog(Record r) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppDark.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 26),
              ),
              const SizedBox(height: 14),
              Text('删除记录', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
              const SizedBox(height: 8),
              Text(
                '确定删除「${r.category}」¥${r.amount.toStringAsFixed(2)} 吗？\n删除后无法恢复',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppDark.sub, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppDark.cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('取消', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: Colors.white,
                          )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        final all = await Storage.getAll();
                        final idx = all.indexWhere((e) =>
                          e.time.toIso8601String() == r.time.toIso8601String() &&
                          e.category == r.category &&
                          e.amount == r.amount
                        );
                        if (idx >= 0) {
                          await Storage.remove(idx);
                          _loadData();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('删除', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: Colors.white,
                          )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS风格左滑显示删除按钮
class _SwipeableRecord extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeableRecord({required this.child, required this.onDelete});

  @override
  State<_SwipeableRecord> createState() => _SwipeableRecordState();
}

class _SwipeableRecordState extends State<_SwipeableRecord> {
  double _offset = 0;
  static const double _buttonWidth = 72;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        setState(() {
          _offset = (_offset + d.delta.dx).clamp(-_buttonWidth, 0.0);
        });
      },
      onHorizontalDragEnd: (d) {
        setState(() {
          _offset = _offset < -_buttonWidth / 2 ? -_buttonWidth : 0;
        });
      },
      child: Stack(
        children: [
          // 删除按钮只在滑动时渲染，避免静止时从半透明层透出红色
          if (_offset < 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: _buttonWidth,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        color: AppColors.danger,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.white, size: 20),
                            SizedBox(height: 2),
                            Text('删除', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_offset != 0) setState(() => _offset = 0);
              },
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

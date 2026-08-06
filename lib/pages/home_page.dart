import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/categories.dart';
import '../services/attachment_service.dart';
import '../services/vip_service.dart';
import '../services/asr_service.dart';
import '../services/voice_parser.dart';
import '../widgets/vip_widgets.dart';
import '../widgets/image_viewer.dart';
import '../widgets/attachment_image.dart';
import 'add_record_page.dart';
import 'voice_record_dialog.dart';
import 'stats_page.dart';
import 'budget_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _tab = 0;
  List<Record> _records = [];
  double _monthIncome = 0;
  double _monthExpense = 0;
  double _monthBalance = 0;
  int _todayCount = 0;
  double _monthlyBudget = 0;
  Map<String, double> _categoryBudgets = {};
  Map<String, double> _catExpenses = {};
  Ledger? _currentLedger;
  int _bgIndex = 0; // 全局背景主题索引
  int _budgetStartDay = 1;
  bool _isVip = false; // 是否为有效 VIP（控制预算/多账本等功能）

  // 长按麦克风直接录音
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecordingVoice = false;
  final ImagePicker _picker = ImagePicker();
  String _attachDir = ''; // 附件目录，用于首页图片预览

  // 账本可选颜色
  static const _ledgerPalette = [
    0xFF10B981, 0xFF3B82F6, 0xFF8B5CF6, 0xFFEC4899, 0xFFFF9F43,
    0xFFEF4444, 0xFF06B6D4, 0xFF84CC16, 0xFFF59E0B, 0xFF636E72,
  ];

  final GlobalKey<StatsPageState> _statsKey = GlobalKey();
  final GlobalKey<BudgetPageState> _budgetKey = GlobalKey();
  final GlobalKey<SettingsPageState> _settingsKey = GlobalKey();
  late final AnimationController _fabAnimCtrl;
  late final Animation<Offset> _fabSlide;

  @override
  void initState() {
    super.initState();
    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fabSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fabAnimCtrl, curve: Curves.easeOutCubic));
    _fabAnimCtrl.forward();
    _loadData();
    _loadCustomCategories();
    // 预取附件目录，首页图片预览用
    AttachmentService.dirPath().then((d) {
      if (mounted) setState(() => _attachDir = d);
    });
  }

  @override
  void dispose() {
    _fabAnimCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCategories() async {
    final custom = await Storage.getCustomCategories();
    setState(() {
      for (final name in custom) {
        _categoryIcons[name] = Categories.customIcon;
        _categoryColors[name] = Categories.customColor;
      }
    });
  }

  Future<void> _loadData() async {
    final records = await Storage.getAll();
    final budget = await Storage.getMonthlyBudget();
    final catBudgets = await Storage.getCategoryBudgets();
    final ledger = await Storage.getCurrentLedger();
    final bg = await Storage.getBgIndex();
    final vip = await VipService.isVip();
    final budgetStartDay = await Storage.getBudgetStartDay();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    double monthInc = 0;
    double monthExp = 0;
    int todayCnt = 0;
    final catExp = <String, double>{};

    for (final r in records) {
      final recordDate = DateTime(r.time.year, r.time.month, r.time.day);
      if (recordDate.year == now.year && recordDate.month == now.month) {
        if (r.isExpense) {
          monthExp += r.amount;
          catExp[r.category] = (catExp[r.category] ?? 0) + r.amount;
        } else {
          monthInc += r.amount;
        }
      }
      if (recordDate == today) {
        todayCnt++;
      }
    }

    setState(() {
      _records = records;
      _monthIncome = monthInc;
      _monthExpense = monthExp;
      _monthBalance = monthInc - monthExp;
      _todayCount = todayCnt;
      _monthlyBudget = budget;
      _categoryBudgets = catBudgets;
      _catExpenses = catExp;
      _currentLedger = ledger;
      _bgIndex = bg;
      _isVip = vip;
      _budgetStartDay = budgetStartDay;
    });
  }

  // ---------------- 长按麦克风直接录音 ----------------

  Future<void> _startVoice() async {
    if (kIsWeb) return;
    final ready = await AsrService.isReady;
    if (!ready) {
      // 模型未下载，打开弹窗让用户下载
      _openVoiceSheet();
      return;
    }
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) return;
    setState(() => _isRecordingVoice = true);
    final path = AsrService.tempRecordPath();
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
        path: path,
      );
    } catch (_) {
      if (mounted) setState(() => _isRecordingVoice = false);
    }
  }

  Future<void> _stopVoice() async {
    if (!_isRecordingVoice) return;
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _isRecordingVoice = false);
    if (path == null) return;

    try {
      final text = await AsrService.recognizeFile(path);
      if (!mounted) return;
      if (text.trim().isEmpty) {
        _showSnack('没听清，请再说一次');
        return;
      }
      final result = VoiceParser.parse(text);
      // 金额+分类都有 → 直接保存
      if (result.amount != null && result.amount! > 0 && result.hasCategory) {
        await Storage.add(Record(
          amount: result.amount!,
          category: result.category,
          note: text,
          time: DateTime.now(),
          isExpense: result.isExpense,
        ));
        if (!mounted) return;
        _showSnack('已记录：${result.category} ¥${result.amount!.toStringAsFixed(0)}');
        _loadData();
        _statsKey.currentState?.refresh();
        _budgetKey.currentState?.refresh();
      } else {
        // 识别不全，打开弹窗手动编辑
        _openVoiceSheet();
      }
    } catch (_) {
      if (mounted) _showSnack('识别失败，请重试');
    }
  }

  Future<void> _cancelVoice() async {
    if (!_isRecordingVoice) return;
    await _recorder.cancel().catchError((_) => null);
    if (mounted) setState(() => _isRecordingVoice = false);
  }

  void _openVoiceSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceRecordSheet(),
    );
    if (result == true) {
      _loadData();
      _statsKey.currentState?.refresh();
      _budgetKey.currentState?.refresh();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Center(child: Text(msg, style: TextStyle(color: Colors.white, fontSize: 13))),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF10B981).withOpacity(0.95),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  String _formatDate(DateTime date) {
    final months = ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'];
    return '${date.year}年${months[date.month - 1]}${date.day}日';
  }

  final _categoryIcons = {
    for (final c in Categories.builtinExpense) c.name: c.icon,
  };

  final _categoryColors = {
    for (final c in Categories.builtinExpense) c.name: c.color,
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayRecords = _records.where((r) {
      final recordDate = DateTime(r.time.year, r.time.month, r.time.day);
      final today = DateTime(now.year, now.month, now.day);
      return recordDate == today;
    }).toList();

    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppThemeMode.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.base[0],
        body: AppBackground(
          theme: theme,
          child: SafeArea(
            child: IndexedStack(
              index: _tab,
              children: [
                _buildAccountPage(todayRecords),
                StatsPage(key: _statsKey),
                BudgetPage(key: _budgetKey),
                SettingsPage(
                  key: _settingsKey,
                  onBgChanged: (i) => setState(() => _bgIndex = i),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppDark.cardBg,
            border: Border(top: BorderSide(color: AppDark.cardBorder)),
          ),
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) {
              setState(() => _tab = i);
              // 切换标签时刷新数据，保证设置页改动（自定义分类、预算等）同步到各页
              _loadData();
              _loadCustomCategories();
              _statsKey.currentState?.refresh();
              _budgetKey.currentState?.refresh();
              _settingsKey.currentState?.refresh();
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: theme.accent,
            unselectedItemColor: AppDark.sub,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.book_outlined),
                activeIcon: Icon(Icons.book),
                label: '记账',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: '统计',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet),
                label: '预算',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        ),
      floatingActionButton: _tab == 0
          ? SlideTransition(
              position: _fabSlide,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'manual',
                    onPressed: () async {
                      final result = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AddRecordSheet(),
                      );
                      if (result == true) {
                        _loadData();
                        _statsKey.currentState?.refresh();
                        _budgetKey.currentState?.refresh();
                      }
                    },
                    backgroundColor: theme.accent,
                    child: Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onLongPressStart: (_) => _startVoice(),
                    onLongPressEnd: (_) => _stopVoice(),
                    onLongPressCancel: () => _cancelVoice(),
                    onTap: () => _openVoiceSheet(),
                    child: FloatingActionButton(
                      heroTag: 'voice',
                      onPressed: null,
                      backgroundColor: _isRecordingVoice ? Colors.red : theme.accent,
                      child: Icon(
                        _isRecordingVoice ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    heroTag: 'camera',
                    onPressed: () => _takePhoto(),
                    backgroundColor: theme.accent,
                    child: Icon(Icons.camera_alt, color: Colors.white, size: 24),
                  ),
                ],
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildAccountPage(List<Record> todayRecords) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ).createShader(bounds),
                child: Icon(Icons.book, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 8),
              Text('记账', style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: AppDark.title,
              )),
              const Spacer(),
              _buildLedgerChip(),
              IconButton(
                icon: Icon(Icons.notifications_none, color: AppDark.title),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(),
          if (_monthlyBudget > 0) ...[
            const SizedBox(height: 12),
            _buildBudgetProgress(),
          ],
          if (_isVip && _categoryBudgets.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCategoryBudgetProgress(),
          ],
          const SizedBox(height: 16),
          _buildTodayRecordsCard(todayRecords),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryItem('总收入', _monthIncome, const Color(0xFF34D399), false),
          _buildDivider(),
          _buildSummaryItem('总支出', _monthExpense, const Color(0xFFFB7185), true),
          _buildDivider(),
          _buildSummaryItem('结余', _monthBalance, AppDark.title, false),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color amountColor, bool isExpense) {
    final prefix = isExpense ? '-' : (amount >= 0 ? '+' : '-');
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: AppDark.sub, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            '$prefix¥${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: amountColor, fontSize: 18, fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: AppDark.divider);
  }

  Widget _buildLedgerChip() {
    final ledger = _currentLedger;
    final color = Color(ledger?.color ?? 0xFF10B981);
    return GestureDetector(
      onTap: () => _showLedgerManager(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                ledger?.name ?? '日常账本',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _showLedgerManager() async {
    final ledgers = await Storage.getLedgers();
    var currentId = await Storage.getCurrentLedgerId();
    // 每个账本的记录数
    final counts = <String, int>{};
    for (final l in ledgers) {
      counts[l.id] = (await Storage.getForLedger(l.id)).length;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppDark.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('账本管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(Icons.close, color: AppDark.sub, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '可创建多个账本，工作生活分开记',
                    style: TextStyle(fontSize: 12, color: AppDark.hint),
                  ),
                  const SizedBox(height: 16),
                  ...ledgers.map((l) {
                    final color = Color(l.color);
                    final isCurrent = l.id == currentId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isCurrent ? color.withOpacity(0.08) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isCurrent ? color.withOpacity(0.5) : AppDark.divider),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          if (!isCurrent) {
                            await Storage.setCurrentLedgerId(l.id);
                            await _refreshAll();
                          }
                          if (mounted) Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.menu_book, size: 19, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                    const SizedBox(height: 2),
                                    Text('${counts[l.id] ?? 0} 笔记录', style: TextStyle(fontSize: 11.5, color: AppDark.hint)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showLedgerEditDialog(
                                  ledger: l,
                                  onSaved: () async {
                                    final newList = await Storage.getLedgers();
                                    final newCounts = <String, int>{};
                                    for (final x in newList) {
                                      newCounts[x.id] = (await Storage.getForLedger(x.id)).length;
                                    }
                                    setSheetState(() {
                                      ledgers
                                        ..clear()
                                        ..addAll(newList);
                                      counts
                                        ..clear()
                                        ..addAll(newCounts);
                                    });
                                    await _refreshAll();
                                  },
                                  onDelete: ledgers.length > 1
                                      ? () => _confirmDeleteLedger(l, () async {
                                            await Storage.deleteLedger(l.id);
                                            final newList = await Storage.getLedgers();
                                            currentId = await Storage.getCurrentLedgerId();
                                            setSheetState(() {
                                              ledgers
                                                ..clear()
                                                ..addAll(newList);
                                              counts.remove(l.id);
                                            });
                                            await _refreshAll();
                                          })
                                      : null,
                                ),
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(9), border: Border.all(color: AppDark.divider)),
                                  child: Icon(Icons.edit_outlined, size: 15, color: AppDark.sub),
                                ),
                              ),
                              const SizedBox(width: 8),
                              isCurrent
                                  ? Icon(Icons.check_circle, size: 22, color: color)
                                  : Icon(Icons.radio_button_unchecked, size: 22, color: AppDark.hint),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      if (!await VipService.isVip()) {
                        await showVipActivateSheet(context, feature: '多账本');
                        return;
                      }
                      _showLedgerEditDialog(
                        ledger: null,
                        onSaved: () async {
                          final newList = await Storage.getLedgers();
                          setSheetState(() {
                            ledgers
                              ..clear()
                              ..addAll(newList);
                          });
                          await _refreshAll();
                        },
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4), style: BorderStyle.solid),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 18, color: Color(0xFF10B981)),
                          SizedBox(width: 6),
                          Text(
                            '新建账本',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 刷新首页 + 统计 + 预算 + 设置（切换账本后调用）
  Future<void> _refreshAll() async {
    await _loadData();
    _statsKey.currentState?.refresh();
    _budgetKey.currentState?.refresh();
    _settingsKey.currentState?.refresh();
  }

  void _confirmDeleteLedger(Ledger l, VoidCallback onConfirm) {
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
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.delete_outline, color: AppColors.danger, size: 26),
              ),
              const SizedBox(height: 14),
              Text('删除「${l.name}」', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),
              Text('该账本下的所有记录将一并删除，\n删除后无法恢复！',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppDark.sub, fontSize: 13, height: 1.5)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('取消', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onConfirm();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('删除', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))),
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

  /// 创建（ledger=null）或编辑账本
  void _showLedgerEditDialog({Ledger? ledger, required VoidCallback onSaved, VoidCallback? onDelete}) {
    final isEdit = ledger != null;
    final nameCtrl = TextEditingController(text: isEdit ? ledger.name : '');
    int selectedColor = isEdit ? ledger.color : _ledgerPalette[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppDark.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Color(selectedColor).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.menu_book, size: 19, color: Color(selectedColor)),
                    ),
                    const SizedBox(width: 10),
                    Text(isEdit ? '编辑账本' : '新建账本', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 18),
                Text('账本名称', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppDark.sub)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  autofocus: !isEdit,
                  maxLength: 10,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '如：旅行基金、宝宝账本',
                    hintStyle: TextStyle(color: AppDark.hint, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text('账本颜色', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppDark.sub)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _ledgerPalette.map((c) {
                    final selected = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: selected ? 2.5 : 0),
                          boxShadow: [
                            BoxShadow(color: Color(c).withOpacity(selected ? 0.5 : 0.2), blurRadius: selected ? 8 : 3),
                          ],
                        ),
                        child: selected ? Icon(Icons.check, size: 17, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (isEdit && onDelete != null) ...[
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text('取消', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          if (isEdit) {
                            await Storage.updateLedger(ledger.copyWith(name: name, color: selectedColor));
                          } else {
                            await Storage.addLedger(Ledger(
                              id: 'ledger_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              color: selectedColor,
                            ));
                          }
                          if (mounted) Navigator.pop(ctx);
                          onSaved();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Text('保存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetProgress() {
    final now = DateTime.now();
    // 用预算周期计算支出（可能与自然月不同）
    final startDay = _budgetStartDay;
    DateTime periodStart;
    if (now.day >= startDay) {
      periodStart = DateTime(now.year, now.month, startDay);
    } else {
      periodStart = DateTime(now.year, now.month - 1, startDay);
    }
    final periodEnd = DateTime(periodStart.year, periodStart.month + 1, startDay - 1);
    double budgetExp = 0;
    for (final r in _records) {
      if (r.isExpense && !r.time.isBefore(periodStart) && !r.time.isAfter(periodEnd)) {
        budgetExp += r.amount;
      }
    }
    final percent = _monthlyBudget > 0 ? budgetExp / _monthlyBudget : 0.0;
    final isOver = percent >= 1.0;
    final isWarning = percent >= 0.8;
    final barColor = isOver ? AppColors.danger : (isWarning ? const Color(0xFFFF9F43) : const Color(0xFF10B981));
    final remaining = _monthlyBudget - budgetExp;
    final daysLeft = periodEnd.difference(now).inDays + 1;
    final rawAllowance = (remaining > 0 && daysLeft > 0) ? remaining / daysLeft : 0.0;
    // 扣掉今天已花的
    double todayExp = 0;
    for (final r in _records) {
      if (r.isExpense && r.time.year == now.year && r.time.month == now.month && r.time.day == now.day) {
        todayExp += r.amount;
      }
    }
    final dailyAllowance = (rawAllowance - todayExp).clamp(0.0, double.infinity);

    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('本月预算', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
              )),
              const Spacer(),
              Text(
                '¥${budgetExp.toStringAsFixed(0)} / ¥${_monthlyBudget.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isOver ? AppColors.danger : AppDark.sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: percent > 1 ? 1.0 : percent,
                backgroundColor: AppDark.track,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          if (isOver) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber, size: 14, color: AppColors.danger),
                const SizedBox(width: 4),
                Text(
                  '已超支 ¥${(budgetExp - _monthlyBudget).toStringAsFixed(0)}，请注意控制消费',
                  style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.today, size: 14,
                    color: isWarning ? const Color(0xFFFF9F43) : const Color(0xFF34D399)),
                const SizedBox(width: 4),
                Text(
                  '今日可花 ¥${dailyAllowance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isWarning ? const Color(0xFFFF9F43) : const Color(0xFF34D399),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.calendar_view_week, size: 14, color: AppDark.sub),
                const SizedBox(width: 4),
                Text(
                  '平均每日 ¥${rawAllowance.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppDark.sub),
                ),
              ],
            ),
            if (isWarning) ...[
              const SizedBox(height: 4),
              Text(
                '已使用 ${(percent * 100).toStringAsFixed(0)}%，接近预算上限',
                style: TextStyle(fontSize: 12, color: Color(0xFFFF9F43), fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetProgress() {
    // 只显示有预算的分类
    final entries = _categoryBudgets.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('分类预算', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
          )),
          const SizedBox(height: 12),
          ...entries.map((e) {
            final name = e.key;
            final budget = e.value;
            final spent = _catExpenses[name] ?? 0;
            final percent = budget > 0 ? spent / budget : 0.0;
            final isOver = percent >= 1.0;
            final isWarning = percent >= 0.8;
            final barColor = isOver
                ? AppColors.danger
                : (isWarning ? const Color(0xFFFF9F43) : (_categoryColors[name] ?? const Color(0xFF10B981)));

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_categoryIcons[name] ?? Icons.label, size: 14,
                        color: _categoryColors[name] ?? AppColors.textHint),
                      const SizedBox(width: 5),
                      Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                      const Spacer(),
                      Text(
                        '¥${spent.toStringAsFixed(0)} / ¥${budget.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: isOver ? AppColors.danger : AppDark.sub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: percent > 1 ? 1.0 : percent,
                        backgroundColor: AppDark.track,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  if (isOver) ...[
                    const SizedBox(height: 4),
                    Text(
                      '已超支 ¥${(spent - budget).toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTodayRecordsCard(List<Record> todayRecords) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(_formatDate(DateTime.now()), style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppDark.title,
              )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppDark.divider,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$_todayCount笔', style: TextStyle(
                  color: AppDark.title, fontSize: 12, fontWeight: FontWeight.w600,
                )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (todayRecords.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: AppDark.hint),
                    const SizedBox(height: 12),
                    Text('今天还没有记录', style: TextStyle(
                      color: AppDark.title, fontSize: 14, fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(height: 4),
                    Text('点击右下角麦克风按钮语音记账', style: TextStyle(
                      color: AppDark.hint, fontSize: 12,
                    )),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayRecords.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppDark.divider),
              itemBuilder: (context, index) {
                final r = todayRecords[index];
                final icon = _categoryIcons[r.category] ?? Icons.receipt;
                final color = _categoryColors[r.category] ?? AppColors.primary;
                return InkWell(
                  onTap: () => _editRecord(r),
                  child: _buildRecordItem(r, icon, color),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(Record r, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.category, style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15, color: AppDark.title,
                )),
                Text(r.note, style: TextStyle(
                  color: AppDark.sub, fontSize: 12,
                )),
                if (r.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                              path: _attachDir.isNotEmpty
                                  ? '$_attachDir/$img'
                                  : img,
                              width: 40, height: 40,
                            ),
                          ),
                        )).toList(),
                        if (r.images.length > 3)
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+${r.images.length - 3}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                r.isExpense ? '-¥${r.amount.toStringAsFixed(2)}' : '+¥${r.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: r.isExpense ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.w700, fontSize: 16,
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
    );
  }

  /// 首页记录卡片点击图片放大预览；支持多张左右滑动。
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

  /// 底部拍照按钮：拍照后把图片带入手动记账弹窗。
  Future<void> _takePhoto() async {
    try {
      final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (xfile == null) return;
      final name = await AttachmentService.saveImage(xfile.path);
      if (!mounted) return;
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddRecordSheet(initialImages: [name]),
      );
      if (result == true) {
        _loadData();
        _statsKey.currentState?.refresh();
        _budgetKey.currentState?.refresh();
      } else {
        // 用户未保存，清理刚才拍的临时附件
        await AttachmentService.deleteImages([name]);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败：$e')),
      );
    }
  }

  void _deleteRecord(Record r) async {
    final records = await Storage.getAll();
    final index = records.indexWhere((e) => e.time.millisecondsSinceEpoch == r.time.millisecondsSinceEpoch);
    if (index != -1) {
      await Storage.remove(index);
      _loadData();
      _statsKey.currentState?.refresh();
      _budgetKey.currentState?.refresh();
    }
  }

  void _editRecord(Record r) async {
    final amountController = TextEditingController(text: r.amount.toStringAsFixed(2));
    final noteController = TextEditingController(text: r.note);
    String selectedCategory = r.category;
    bool isExpense = r.isExpense;
    bool _showAllCategories = false;
    final attachDir = await AttachmentService.dirPath();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppDark.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('编辑记录', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
                const SizedBox(height: 20),
                // 金额
                Text('金额', style: TextStyle(color: AppDark.sub, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700,
                    color: isExpense ? AppColors.danger : AppColors.success,
                  ),
                  decoration: InputDecoration(
                    prefixText: '¥ ',
                    prefixStyle: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700,
                      color: isExpense ? AppColors.danger : AppColors.success,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
                // 收支类型
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() {
                          isExpense = true;
                          selectedCategory = Categories.builtinExpense.first.name;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isExpense ? AppColors.danger.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isExpense ? AppColors.danger : AppDark.divider),
                          ),
                          child: Text('支出', textAlign: TextAlign.center, style: TextStyle(
                            color: isExpense ? AppColors.danger : AppDark.sub,
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() {
                          isExpense = false;
                          selectedCategory = Categories.builtinIncome.first.name;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isExpense ? AppColors.success.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !isExpense ? AppColors.success : AppDark.divider),
                          ),
                          child: Text('收入', textAlign: TextAlign.center, style: TextStyle(
                            color: !isExpense ? AppColors.success : AppDark.sub,
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 分类
                Row(
                  children: [
                    Text('分类', style: TextStyle(color: AppDark.sub, fontSize: 12)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setDialogState(() => _showAllCategories = !_showAllCategories),
                      child: Row(
                        children: [
                          Text(_showAllCategories ? '收起' : '更多', style: TextStyle(
                            color: AppColors.primary, fontSize: 12,
                          )),
                          Icon(_showAllCategories ? Icons.expand_less : Icons.expand_more,
                            color: AppColors.primary, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    ...(isExpense
                        ? (_showAllCategories ? Categories.builtinExpense : Categories.builtinExpense.take(5))
                        : (_showAllCategories ? Categories.builtinIncome : Categories.builtinIncome.take(5))
                    ).map((c) {
                      final selected = c.name == selectedCategory;
                      final color = c.color;
                      final icon = c.icon;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedCategory = c.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected ? color : AppDark.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 14, color: selected ? color : AppDark.sub),
                              const SizedBox(width: 4),
                              Text(c.name, style: TextStyle(
                                color: selected ? color : AppDark.sub,
                                fontSize: 12, fontWeight: FontWeight.w500,
                              )),
                            ],
                          ),
                        ),
                      );
                    }),
                    // 自定义分类
                    GestureDetector(
                      onTap: () => _showCustomCategoryDialog(
                        setDialogState,
                        (name) => selectedCategory = name,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppDark.divider, style: BorderStyle.solid),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: AppDark.sub),
                            SizedBox(width: 4),
                            Text('自定义', style: TextStyle(
                              color: AppDark.sub, fontSize: 12,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 备注
                Text('备注', style: TextStyle(color: AppDark.sub, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: noteController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '输入备注',
                    hintStyle: TextStyle(color: AppDark.hint),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 20),
                // 附件（只读预览）
                if (r.images.isNotEmpty) ...[
                  Text('附件', style: TextStyle(color: AppDark.sub, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: r.images.map((img) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AttachmentImage(
                        path: attachDir.isNotEmpty ? '$attachDir/$img' : img,
                        width: 52, height: 52,
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                // 按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteRecord(r);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('删除'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final newAmount = double.tryParse(amountController.text);
                          if (newAmount != null && newAmount > 0) {
                            _updateRecord(r, newAmount, selectedCategory, noteController.text, isExpense);
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('保存', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  void _updateRecord(Record oldRecord, double newAmount, String newCategory, String newNote, bool newIsExpense) async {
    final records = await Storage.getAll();
    final index = records.indexWhere((e) => e.time.millisecondsSinceEpoch == oldRecord.time.millisecondsSinceEpoch);
    if (index != -1) {
      await Storage.remove(index);
      final newRecord = Record(
        amount: newAmount,
        category: newCategory,
        note: newNote.isEmpty ? newCategory : newNote,
        time: oldRecord.time,
        isExpense: newIsExpense,
        images: oldRecord.images,
        isInvoice: oldRecord.isInvoice,
      );
      await Storage.add(newRecord);
      _loadData();
      _statsKey.currentState?.refresh();
      _budgetKey.currentState?.refresh();
    }
  }

  void _showCustomCategoryDialog(void Function(void Function()) setDialogState, void Function(String) onSelect) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDark.surface,
        title: Text('自定义分类', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '输入分类名称',
            hintStyle: TextStyle(color: AppDark.hint),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppDark.sub)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _categoryIcons[name] = Categories.customIcon;
                _categoryColors[name] = Categories.customColor;
                await Storage.addCustomCategory(name);
                onSelect(name);
                setDialogState(() {});
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('添加', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

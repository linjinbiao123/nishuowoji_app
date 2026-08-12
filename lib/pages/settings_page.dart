import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/categories.dart';
import '../services/notification_service.dart';
import '../services/vip_service.dart';
import '../widgets/vip_widgets.dart';
import '../services/update_service.dart';
import 'package:file_picker/file_picker.dart';
import 'agreement_page.dart';
import 'data_stats_page.dart';
import 'import_preview_page.dart';

class SettingsPage extends StatefulWidget {
  /// 切换背景主题时回调父级（HomePage），让全局背景实时刷新
  final ValueChanged<int>? onBgChanged;
  const SettingsPage({super.key, this.onBgChanged});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  int _recordCount = 0;
  int _totalCatCount = 0;
  String _ledgerName = '日常账本';
  int _bgIndex = 0;
  bool _reminderEnabled = false;
  int _reminderMinutes = 20 * 60;
  bool _isVip = false;
  String _vipExpiry = '';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final records = await Storage.getAll();
    final cats = await Storage.getCustomCategories();
    final deleted = await Storage.getDeletedCategories();
    final ledger = await Storage.getCurrentLedger();
    final bgIndex = await Storage.getBgIndex();
    final reminderEnabled = await Storage.getReminderEnabled();
    final reminderMinutes = await Storage.getReminderMinutes();
    final isVip = await VipService.isVip();
    final vipExpiry = await VipService.vipExpiryText();
    final pkgInfo = await PackageInfo.fromPlatform();

    // 有效分类总数 = 内置支出 + 内置收入 + 自定义，排除已删除（与记账页完全一致）
    int total = 0;
    for (final c in Categories.builtinExpense) {
      if (!deleted.contains(c.name)) total++;
    }
    for (final c in Categories.builtinIncome) {
      if (!deleted.contains(c.name)) total++;
    }
    for (final n in cats) {
      if (!deleted.contains(n)) total++;
    }

    setState(() {
      _recordCount = records.length;
      _totalCatCount = total;
      _ledgerName = ledger?.name ?? '日常账本';
      _bgIndex = bgIndex;
      _reminderEnabled = reminderEnabled;
      _reminderMinutes = reminderMinutes;
      _isVip = isVip;
      _vipExpiry = vipExpiry ?? '';
      _version = pkgInfo.version;
    });
  }

  /// 供父页面通过 GlobalKey 调用（切换账本/数据变更后刷新）
  void refresh() => _loadInfo();

  // ---------------- 检查更新 ----------------

  Future<void> _checkUpdate() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在检查更新…'), duration: Duration(seconds: 1)),
    );
    final info = await UpdateService.check();
    if (!mounted) return;

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查失败，请确认网络连接')),
      );
      return;
    }
    if (!info.hasUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已是最新版本')),
      );
      return;
    }
    // 有新版本 → 弹窗提示
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDark.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('发现新版本 v${info.version}',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.note.isNotEmpty)
              Text(info.note,
                  style: TextStyle(color: AppDark.sub, fontSize: 14, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('稍后再说', style: TextStyle(color: AppDark.sub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              UpdateService.openDownload(info.url);
            },
            child: Text('去下载', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------------- 每日记账提醒 ----------------

  String _formatReminderTime() {
    final h = _reminderMinutes ~/ 60;
    final m = _reminderMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleReminder(bool on) async {
    if (on) {
      // Android 13+ 必须运行时授予通知权限，否则提醒会被系统完全屏蔽
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        _showPermissionDeniedTip();
        return;
      }
    }
    setState(() => _reminderEnabled = on);
    await Storage.setReminderEnabled(on);
    if (on) {
      await NotificationService.scheduleDailyReminder(
        _reminderMinutes ~/ 60,
        _reminderMinutes % 60,
      );
    } else {
      await NotificationService.cancelDailyReminder();
    }
  }

  /// 用户拒绝通知权限时的提示（风格与首页 SnackBar 统一）
  void _showPermissionDeniedTip() {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_off, color: theme.accent, size: 18),
              const SizedBox(width: 8),
              Text('未获得通知权限，请前往系统设置开启后重试',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppThemeMode.isLight
            ? const Color(0xFF323232)
            : theme.base[1].withOpacity(0.96),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.accent.withOpacity(0.35)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _reminderMinutes ~/ 60,
        minute: _reminderMinutes % 60,
      ),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() => _reminderMinutes = minutes);
    await Storage.setReminderMinutes(minutes);
    // 已开启提醒则按新时间重新安排
    if (_reminderEnabled) {
      await NotificationService.scheduleDailyReminder(
        picked.hour,
        picked.minute,
      );
    }
  }

  Widget _buildReminderToggle() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _toggleReminder(!_reminderEnabled),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.notifications_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('每日记账提醒', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: AppDark.title,
                  )),
                ],
              ),
            ),
            Switch(
              value: _reminderEnabled,
              onChanged: _toggleReminder,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 统计页背景选择 ----------------

  void _showBgPicker() {
    int current = _bgIndex;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppDark.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: AppDark.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(Icons.palette_outlined,
                            color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Text('背景主题', style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: Colors.white,
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (var i = 0; i < AppBgTheme.all.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _bgSwatch(AppBgTheme.all[i], current == i, () async {
                            await Storage.setBgIndex(i);
                            AppThemeMode.isLight = AppBgTheme.all[i].isLight;
                            setSheetState(() => current = i);
                            setState(() => _bgIndex = i);
                            widget.onBgChanged?.call(i);
                          }),
                        ),
                      ],
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

  Widget _bgSwatch(AppBgTheme t, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? const Color(0xFF10B981) : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Container(
                height: 92,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: t.base,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // 迷你光晕预览
              Positioned(
                top: -18, right: -12,
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      t.glows[0].withOpacity(0.5), t.glows[0].withOpacity(0),
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: -16, left: -10,
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      t.glows[1].withOpacity(0.4), t.glows[1].withOpacity(0),
                    ]),
                  ),
                ),
              ),
              // 迷你毛玻璃卡片预览
              Positioned(
                left: 12, right: 12, top: 24,
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                ),
              ),
              // 名称
              Positioned(
                left: 0, right: 0, bottom: 8,
                child: Text(
                  t.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // 选中对勾
              if (selected)
                Positioned(
                  top: 7, right: 7,
                  child: Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 13, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设置', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: AppDark.title,
              )),
              const SizedBox(height: 20),
              // 权限
              _buildVipSection(),
              const SizedBox(height: 20),
              // 外观
              _buildSectionTitle('外观'),
              const SizedBox(height: 10),
              _buildCard([
                _buildSettingItem(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  title: '背景主题',
                  subtitle: '当前：${AppBgTheme.all[_bgIndex].name}',
                  onTap: _showBgPicker,
                ),
              ]),
              const SizedBox(height: 20),
              // 提醒
              _buildSectionTitle('提醒'),
              const SizedBox(height: 10),
              _buildCard([
                _buildReminderToggle(),
                Divider(height: 1, indent: 52, color: AppDark.divider),
                _buildSettingItem(
                  icon: Icons.access_time,
                  iconColor: AppColors.primary,
                  title: '提醒时间',
                  subtitle: '每天 ${_formatReminderTime()} 提醒',
                  onTap: _pickReminderTime,
                ),
              ]),
              const SizedBox(height: 20),
              // 分类管理
              _buildSectionTitle('分类管理'),
              const SizedBox(height: 10),
              _buildCard([
                _buildSettingItem(
                  icon: Icons.category,
                  iconColor: const Color(0xFF6C5CE7),
                  title: '分类管理',
                  subtitle: '共 $_totalCatCount 个分类 · 长按可删除',
                  onTap: () => _showCustomCategoryManager(),
                ),
              ]),
              const SizedBox(height: 20),
              // 数据管理
              _buildSectionTitle('数据管理'),
              const SizedBox(height: 10),
              _buildCard([
                _buildSettingItem(
                  icon: Icons.file_download,
                  iconColor: const Color(0xFF10B981),
                  title: '导入账本',
                  subtitle: '从其它记账 App 的 CSV/Excel 导入',
                  onTap: () => _importLedger(),
                ),
                Divider(height: 1, indent: 52, color: AppDark.divider),
                _buildSettingItem(
                  icon: Icons.insights,
                  iconColor: const Color(0xFF0984E3),
                  title: '数据统计导出',
                  subtitle: '共 $_recordCount 条记录 · 图表分析',
                  onTap: () => _openDataStats(),
                ),
                Divider(height: 1, indent: 52, color: AppDark.divider),
                _buildSettingItem(
                  icon: Icons.delete_forever,
                  iconColor: AppColors.danger,
                  title: '清空当前账本',
                  subtitle: '删除「$_ledgerName」的全部记录',
                  onTap: () => _showClearDataDialog(),
                  danger: true,
                ),
              ]),
              const SizedBox(height: 20),
              // 关于
              _buildSectionTitle('关于'),
              const SizedBox(height: 10),
              _buildCard([
                _buildSettingItem(
                  icon: Icons.info_outline,
                  iconColor: AppColors.textSecondary,
                  title: '说记',
                  subtitle: '版本 ${_version.isEmpty ? "..." : _version}',
                  onTap: null,
                ),
                Divider(height: 1, color: AppDark.divider),
                _buildSettingItem(
                  icon: Icons.system_update_alt,
                  iconColor: const Color(0xFF10B981),
                  title: '检查更新',
                  subtitle: '检查是否有新版本',
                  onTap: _checkUpdate,
                ),
              ]),
              const SizedBox(height: 24),
              // 底部小字：隐私政策 / 用户服务协议
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AgreementPage(isPrivacy: true))),
                    child: Text('隐私政策', style: TextStyle(fontSize: 12, color: AppDark.hint)),
                  ),
                  const SizedBox(width: 6),
                  Text('·', style: TextStyle(fontSize: 12, color: AppDark.hint)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AgreementPage(isPrivacy: false))),
                    child: Text('用户服务协议', style: TextStyle(fontSize: 12, color: AppDark.hint)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVipSection() {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    final vipSubtitle = _isVip
        ? (_vipExpiry == '永久有效' ? '永久有效' : '有效期至 $_vipExpiry')
        : '解锁多账本、数据导出、分类预算';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('权限'),
        const SizedBox(height: 10),
        _buildCard([
          _buildSettingItem(
            icon: Icons.workspace_premium,
            iconColor: _isVip ? const Color(0xFFFFD700) : theme.accent,
            title: _isVip ? '已开通权限' : '开通权限',
            subtitle: vipSubtitle,
            onTap: () async {
              if (_isVip) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Center(child: Text(
                    _vipExpiry == '永久有效' ? '已是永久权限，无需重复激活' : '权限有效期至 $_vipExpiry',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  )),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF10B981).withOpacity(0.95),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ));
                return;
              }
              final ok = await showVipActivateSheet(context);
              if (ok) _loadInfo();
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600,
      color: AppDark.hint,
    ));
  }

  Widget _buildCard(List<Widget> children) {
    return GlassCard(
      radius: 14,
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: danger ? AppColors.danger : AppDark.title,
                  )),
                  Text(subtitle, style: TextStyle(
                    fontSize: 12, color: AppDark.hint,
                  )),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: AppDark.hint, size: 20),
          ],
        ),
      ),
    );
  }

  void _openDataStats() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DataStatsPage()),
    );
    _loadInfo();
  }

  void _importLedger() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('读取文件失败')));
      }
      return;
    }
    if (!mounted) return;
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportPreviewPage(fileName: file.name, bytes: bytes),
      ),
    );
    if (count != null && mounted) {
      _loadInfo();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 $count 条记录')),
      );
    }
  }

  void _showCustomCategoryManager() async {
    final deleted = await Storage.getDeletedCategories();
    final customCats = await Storage.getCustomCategories();
    if (!mounted) return;

    // 统一注册表，和记账页/分类预算完全一致
    final expenseCats = Categories.builtinExpense;
    final incomeCats = Categories.builtinIncome;

    String? deletingCat;
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('分类管理', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(Icons.close, color: AppDark.sub, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('长按分类可删除 · 底部可添加自定义分类', style: TextStyle(
                    fontSize: 12, color: AppDark.hint,
                  )),
                  const SizedBox(height: 16),
                  // 支出分类
                  Text('支出分类', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppDark.hint,
                  )),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: expenseCats.map((c) {
                      final name = c.name;
                      final isDeleted = deleted.contains(name);
                      if (isDeleted) return const SizedBox.shrink();
                      return GestureDetector(
                        onLongPress: () => setSheetState(() => deletingCat = deletingCat == name ? null : name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: deletingCat == name ? AppColors.danger : AppDark.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c.icon, size: 16, color: c.color),
                              const SizedBox(width: 5),
                              Text(name, style: TextStyle(fontSize: 13, color: Colors.white)),
                              if (deletingCat == name) ...[
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () async {
                                    await Storage.addDeletedCategory(name);
                                    // 同步清掉该分类的预算，避免记账页进度条残留
                                    final budgets = await Storage.getCategoryBudgets();
                                    if (budgets.remove(name) != null) {
                                      await Storage.setCategoryBudgets(budgets);
                                    }
                                    setSheetState(() {
                                      deleted.add(name);
                                      deletingCat = null;
                                    });
                                    _loadInfo();
                                  },
                                  child: Container(
                                    width: 16, height: 16,
                                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                    child: Icon(Icons.close, color: Colors.white, size: 10),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // 收入分类
                  Text('收入分类', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppDark.hint,
                  )),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: incomeCats.map((c) {
                      final name = c.name;
                      final isDeleted = deleted.contains(name);
                      if (isDeleted) return const SizedBox.shrink();
                      return GestureDetector(
                        onLongPress: () => setSheetState(() => deletingCat = deletingCat == name ? null : name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: deletingCat == name ? AppColors.danger : AppDark.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c.icon, size: 16, color: c.color),
                              const SizedBox(width: 5),
                              Text(name, style: TextStyle(fontSize: 13, color: Colors.white)),
                              if (deletingCat == name) ...[
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () async {
                                    await Storage.addDeletedCategory(name);
                                    // 同步清掉该分类的预算，避免记账页进度条残留
                                    final budgets = await Storage.getCategoryBudgets();
                                    if (budgets.remove(name) != null) {
                                      await Storage.setCategoryBudgets(budgets);
                                    }
                                    setSheetState(() {
                                      deleted.add(name);
                                      deletingCat = null;
                                    });
                                    _loadInfo();
                                  },
                                  child: Container(
                                    width: 16, height: 16,
                                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                    child: Icon(Icons.close, color: Colors.white, size: 10),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // 自定义分类（支持在此新建）
                  Text('自定义分类', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppDark.hint,
                  )),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...customCats.map((name) {
                        return GestureDetector(
                          onLongPress: () => setSheetState(() => deletingCat = deletingCat == name ? null : name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: deletingCat == name ? AppColors.danger : AppDark.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Categories.customIcon, size: 16, color: Categories.customColor),
                                const SizedBox(width: 5),
                                Text(name, style: TextStyle(fontSize: 13, color: Colors.white)),
                                if (deletingCat == name) ...[
                                  const SizedBox(width: 5),
                                  GestureDetector(
                                    onTap: () async {
                                      await Storage.removeCustomCategory(name);
                                      // 同步清掉该自定义分类的预算
                                      final budgets = await Storage.getCategoryBudgets();
                                      if (budgets.remove(name) != null) {
                                        await Storage.setCategoryBudgets(budgets);
                                      }
                                      setSheetState(() {
                                        customCats.remove(name);
                                        deletingCat = null;
                                      });
                                      _loadInfo();
                                    },
                                    child: Container(
                                      width: 16, height: 16,
                                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                      child: Icon(Icons.close, color: Colors.white, size: 10),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      // 新建自定义分类
                      _addCategoryChip(customCats, setSheetState),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 分类管理 · 自定义分类末尾的「添加」按钮
  Widget _addCategoryChip(List<String> customCats, StateSetter setSheetState) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showAddCustomCategoryDialog(customCats, setSheetState),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.45)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
            SizedBox(width: 5),
            Text('添加', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF10B981),
            )),
          ],
        ),
      ),
    );
  }

  /// 新建自定义分类弹窗（重名校验，保存后分类管理/记账页/分类预算同步生效）
  void _showAddCustomCategoryDialog(List<String> customCats, StateSetter setSheetState) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDark.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('新建自定义分类', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
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
              if (name.isEmpty) return;
              final exists = Categories.builtinExpense.any((c) => c.name == name) ||
                  Categories.builtinIncome.any((c) => c.name == name) ||
                  customCats.contains(name);
              if (exists) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('该分类已存在')),
                );
                return;
              }
              await Storage.addCustomCategory(name);
              setSheetState(() => customCats.add(name));
              _loadInfo();
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('添加', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
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
                child: Icon(Icons.warning_amber, color: AppColors.danger, size: 26),
              ),
              const SizedBox(height: 14),
              Text('清空账本数据', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
              const SizedBox(height: 8),
              Text(
                '此操作将删除「$_ledgerName」的全部 $_recordCount 条记录，\n其他账本不受影响，删除后无法恢复！',
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
                          color: Colors.white.withOpacity(0.08),
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
                        // 清空当前账本的全部记录
                        await Storage.clearCurrentLedger();
                        setState(() => _recordCount = 0);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('「$_ledgerName」数据已清空')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('确认清空', style: TextStyle(
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

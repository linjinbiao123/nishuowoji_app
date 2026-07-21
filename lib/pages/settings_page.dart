import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/categories.dart';
import 'data_stats_page.dart';

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
    });
  }

  /// 供父页面通过 GlobalKey 调用（切换账本/数据变更后刷新）
  void refresh() => _loadInfo();

  // ---------------- 统计页背景选择 ----------------

  void _showBgPicker() {
    int current = _bgIndex;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          decoration: const BoxDecoration(
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
                        child: const Icon(Icons.palette_outlined,
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
                  style: const TextStyle(
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
                    child: const Icon(Icons.check, size: 13, color: Colors.white),
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
              const Text('设置', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
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
                  icon: Icons.insights,
                  iconColor: const Color(0xFF0984E3),
                  title: '数据统计',
                  subtitle: '共 $_recordCount 条记录 · 图表分析',
                  onTap: () => _openDataStats(),
                ),
                const Divider(height: 1, indent: 52, color: AppDark.divider),
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
                  title: '你说我记',
                  subtitle: '版本 1.0.0',
                  onTap: null,
                ),
              ]),
            ],
          ),
        ),
      ),
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
                    color: danger ? AppColors.danger : Colors.white,
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
                      const Text('分类管理', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: AppDark.sub, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('长按分类可删除 · 底部可添加自定义分类', style: TextStyle(
                    fontSize: 12, color: AppDark.hint,
                  )),
                  const SizedBox(height: 16),
                  // 支出分类
                  const Text('支出分类', style: TextStyle(
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
                              Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
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
                                    child: const Icon(Icons.close, color: Colors.white, size: 10),
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
                  const Text('收入分类', style: TextStyle(
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
                              Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
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
                                    child: const Icon(Icons.close, color: Colors.white, size: 10),
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
                  const Text('自定义分类', style: TextStyle(
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
                                Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
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
                                      child: const Icon(Icons.close, color: Colors.white, size: 10),
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
        title: const Text('新建自定义分类', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '输入分类名称',
            hintStyle: const TextStyle(color: AppDark.hint),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppDark.sub)),
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
            child: const Text('添加', style: TextStyle(color: Colors.white)),
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
                child: const Icon(Icons.warning_amber, color: AppColors.danger, size: 26),
              ),
              const SizedBox(height: 14),
              const Text('清空账本数据', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
              const SizedBox(height: 8),
              Text(
                '此操作将删除「$_ledgerName」的全部 $_recordCount 条记录，\n其他账本不受影响，删除后无法恢复！',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppDark.sub, fontSize: 13, height: 1.5),
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

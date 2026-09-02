import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/categories.dart';
import '../services/vip_service.dart';
import '../widgets/vip_widgets.dart';
import '../widgets/rolling_number.dart';

/// 预算管理页（取代原「历史账单」tab）
/// 月预算：进度圆环 + 已花/剩余，点击编辑（所有用户可用）
/// 分类预算：全部支出分类平铺展示（权限功能，未开通显示锁定入口）
class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => BudgetPageState();
}

class BudgetPageState extends State<BudgetPage> {
  double _monthlyBudget = 0;
  double _monthExpense = 0;
  double _todayExpense = 0;
  Map<String, double> _categoryBudgets = {};
  Map<String, double> _catExpenses = {};
  List<CategoryDef> _cats = [];
  bool _isVip = false;
  int _budgetStartDay = 1;
  List<Account> _accounts = [];
  int _bgIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void refresh() => _loadData();

  /// 根据起始日计算当前预算周期的起止日期
  (DateTime, DateTime) _budgetPeriod() {
    final now = DateTime.now();
    DateTime start;
    if (now.day >= _budgetStartDay) {
      start = DateTime(now.year, now.month, _budgetStartDay);
    } else {
      start = DateTime(now.year, now.month - 1, _budgetStartDay);
    }
    final end = DateTime(start.year, start.month + 1, _budgetStartDay - 1);
    return (start, end);
  }

  Future<void> _loadData() async {
    final records = await Storage.getAll();
    final budget = await Storage.getMonthlyBudget();
    final catBudgets = await Storage.getCategoryBudgets();
    final deleted = await Storage.getDeletedCategories();
    final custom = await Storage.getCustomCategories();
    final isVip = await VipService.isVip();
    final startDay = await Storage.getBudgetStartDay();
    final accounts = await Storage.getAccounts();
    final bgIndex = await Storage.getBgIndex();

    final (periodStart, periodEnd) = _budgetPeriodWith(startDay);

    double monthExp = 0;
    double todayExp = 0;
    final catExp = <String, double>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final r in records) {
      if (r.isExpense && !r.time.isBefore(periodStart) && !r.time.isAfter(periodEnd)) {
        monthExp += r.amount;
        catExp[r.category] = (catExp[r.category] ?? 0) + r.amount;
      }
      if (r.isExpense && r.time.year == today.year && r.time.month == today.month && r.time.day == today.day) {
        todayExp += r.amount;
      }
    }

    if (!mounted) return;
    setState(() {
      _monthlyBudget = budget;
      _monthExpense = monthExp;
      _todayExpense = todayExp;
      _categoryBudgets = catBudgets;
      _catExpenses = catExp;
      _cats = Categories.activeExpense(deleted, custom);
      _isVip = isVip;
      _budgetStartDay = startDay;
      _accounts = accounts;
      _bgIndex = bgIndex;
    });
  }

  /// 静态版本：用给定的 startDay 计算周期（供 _loadData 在 setState 前使用）
  (DateTime, DateTime) _budgetPeriodWith(int startDay) {
    final now = DateTime.now();
    DateTime start;
    if (now.day >= startDay) {
      start = DateTime(now.year, now.month, startDay);
    } else {
      start = DateTime(now.year, now.month - 1, startDay);
    }
    final end = DateTime(start.year, start.month + 1, startDay - 1);
    return (start, end);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ).createShader(bounds),
                  child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 8),
                Text('预算', style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: AppDark.title,
                )),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDark.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDark.cardBorder),
                  ),
                  child: Text('${now.year}年${now.month}月', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppDark.sub,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMonthlyCard(),
            const SizedBox(height: 22),
            _buildAccountSection(),
            const SizedBox(height: 22),
            if (_isVip) ...[
              _buildCategoryHeader(),
              const SizedBox(height: 10),
              _buildCategoryList(),
            ] else
              _buildCategoryLocked(),
          ],
        ),
      ),
    );
  }

  // ---------------- 分类预算锁定（未开通权限） ----------------

  Widget _buildCategoryLocked() {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, size: 30, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 16),
          Text('分类预算', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppDark.title)),
          const SizedBox(height: 6),
          Text('按分类精细控制预算，开通权限即可使用',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppDark.sub)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final ok = await showVipActivateSheet(context, feature: '分类预算');
              if (ok) _loadData();
            },
            icon: Icon(Icons.workspace_premium, size: 18, color: Colors.white),
            label: Text('开通权限', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 月预算 ----------------

  Widget _buildMonthlyCard() {
    final now = DateTime.now();
    final hasBudget = _monthlyBudget > 0;
    final percent = hasBudget ? _monthExpense / _monthlyBudget : 0.0;
    final isOver = percent >= 1.0;
    final isWarning = percent >= 0.8 && !isOver;
    final ringColor = isOver
        ? AppColors.danger
        : (isWarning ? const Color(0xFFFF9F43) : const Color(0xFF10B981));
    final remaining = _monthlyBudget - _monthExpense;
    final (_, periodEnd) = _budgetPeriod();
    final daysLeft = periodEnd.difference(now).inDays + 1;
    final rawAllowance = (remaining > 0 && daysLeft > 0) ? remaining / daysLeft : 0.0;
    final dailyAllowance = (rawAllowance - _todayExpense).clamp(0.0, double.infinity);

    return GestureDetector(
      onTap: _showMonthlyBudgetDialog,
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // 进度圆环
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 9,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppDark.track),
                  ),
                  if (hasBudget)
                    CircularProgressIndicator(
                      value: percent > 1 ? 1.0 : percent,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                  Center(
                    child: Text(
                      hasBudget ? '${(percent * 100).toInt()}%' : '--',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: hasBudget ? ringColor : AppDark.hint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本月预算', style: TextStyle(fontSize: 13, color: AppDark.sub)),
                  const SizedBox(height: 6),
                  Text(
                    '¥${_monthlyBudget.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, color: AppDark.title,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasBudget) ...[
                    Row(
                      children: [
                        Icon(
                          isOver ? Icons.trending_down : Icons.trending_up,
                          size: 14,
                          color: isOver ? AppColors.danger : const Color(0xFF34D399),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isOver
                                ? '已超支 ¥${(-remaining).toStringAsFixed(0)}'
                                : '本月剩余 ¥${remaining.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isOver) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.today, size: 14, color: AppDark.sub),
                          const SizedBox(width: 4),
                          Text(
                            '今日可花 ¥${dailyAllowance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppDark.sub,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_view_week, size: 14, color: AppDark.hint),
                          const SizedBox(width: 4),
                          Text(
                            '平均每日 ¥${rawAllowance.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppDark.hint),
                          ),
                        ],
                      ),
                    ],
                  ] else
                    Text('未设置 · 点击设置月预算', style: TextStyle(fontSize: 12, color: AppDark.hint)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppDark.hint, size: 22),
          ],
        ),
      ),
    );
  }

  // ---------------- 多账户余额 ----------------

  Icon _accountIcon(int code, Color color, double size) =>
      Icon(IconData(code, fontFamily: 'MaterialIcons'), color: color, size: size);

  Widget _buildAccountSection() {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    final total = _accounts.fold<double>(0, (s, a) => s + a.balance);
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: theme.accent, size: 20),
              const SizedBox(width: 8),
              Text('账户余额', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppDark.title,
              )),
              const Spacer(),
              GestureDetector(
                onTap: _showAccountManageDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 14, color: theme.accent),
                      const SizedBox(width: 4),
                      Text('管理', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.accent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._accounts.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: _accountIcon(a.icon, theme.accent, 18),
                ),
                const SizedBox(width: 10),
                Text(a.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppDark.title)),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(a.balance < 0 ? '-¥' : '¥', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: a.balance < 0 ? AppColors.danger : AppDark.title,
                    )),
                    RollingNumber(
                      value: a.balance.abs(),
                      decimals: 2,
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: a.balance < 0 ? AppColors.danger : AppDark.title,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )),
          Divider(height: 16, color: AppDark.divider),
          Row(
            children: [
              Text('总资产', style: TextStyle(fontSize: 13, color: AppDark.sub)),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('¥', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: theme.accent,
                  )),
                  RollingNumber(
                    value: total,
                    decimals: 2,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: theme.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAccountManageDialog() async {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    final work = List<Account>.from(_accounts);
    final nameCtrls = work.map((a) => TextEditingController(text: a.name)).toList();
    final balCtrls = work.map((a) => TextEditingController(text: a.balance.toStringAsFixed(2))).toList();

    final result = await showDialog<List<Account>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void addAccount() {
            work.add(Account(
              id: 'acc_${DateTime.now().microsecondsSinceEpoch}',
              name: '新账户',
              balance: 0,
              icon: 0xE850,
            ));
            nameCtrls.add(TextEditingController(text: '新账户'));
            balCtrls.add(TextEditingController(text: '0.00'));
            setDialogState(() {});
          }

          void removeAccount(int idx) {
            work.removeAt(idx);
            nameCtrls[idx].dispose();
            balCtrls[idx].dispose();
            nameCtrls.removeAt(idx);
            balCtrls.removeAt(idx);
            setDialogState(() {});
          }

          List<Account> collect() {
            final list = <Account>[];
            for (var i = 0; i < work.length; i++) {
              list.add(work[i].copyWith(
                name: nameCtrls[i].text.trim(),
                balance: double.tryParse(balCtrls[i].text) ?? work[i].balance,
              ));
            }
            return list;
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('管理账户', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                    child: SingleChildScrollView(
                      child: Column(
                        children: work.asMap().entries.map((e) {
                          final a = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                _accountIcon(a.icon, theme.accent, 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: nameCtrls[e.key],
                                    style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      hintText: '账户名',
                                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: balCtrls[e.key],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      hintText: '余额',
                                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      prefixText: '¥ ',
                                      prefixStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => removeAccount(e.key),
                                  child: Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: addAccount,
                          icon: Icon(Icons.add, size: 16, color: theme.accent),
                          label: Text('新增账户', style: TextStyle(color: theme.accent, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: theme.accent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, collect()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('保存', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    for (final c in nameCtrls) c.dispose();
    for (final c in balCtrls) c.dispose();

    if (result != null) {
      // 找出被删除的账户，清理其历史记录引用
      final removed = _accounts.where((a) => !result.any((r) => r.id == a.id)).toList();
      for (final a in removed) {
        await Storage.deleteAccount(a.id);
      }
      await Storage.saveAccounts(result);
      setState(() => _accounts = result);
    }
  }

  void _showMonthlyBudgetDialog() {
    final controller = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toStringAsFixed(0) : '',
    );
    int selectedDay = _budgetStartDay;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppDark.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设置月预算', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white,
                )),
                const SizedBox(height: 6),
                Text('设置每月支出预算，帮助控制消费', style: TextStyle(
                  fontSize: 13, color: AppDark.sub,
                )),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  decoration: InputDecoration(
                    prefixText: '¥ ',
                    hintText: '输入月预算金额',
                    hintStyle: TextStyle(color: AppDark.hint),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                // 预算周期起始日
                Row(
                  children: [
                    Text('起始日', style: TextStyle(fontSize: 14, color: AppDark.sub)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedDay,
                          dropdownColor: AppDark.surface,
                          style: TextStyle(fontSize: 14, color: Colors.white),
                          icon: Icon(Icons.arrow_drop_down, color: AppDark.sub, size: 20),
                          items: List.generate(28, (i) => i + 1)
                              .map((d) => DropdownMenuItem(value: d, child: Text('每月${d}号')))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedDay = v ?? 1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  selectedDay == 1
                      ? '周期：每月1号 ~ 月末'
                      : '周期：每月${selectedDay}号 ~ 次月${selectedDay - 1}号',
                  style: TextStyle(fontSize: 11.5, color: AppDark.hint),
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
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Text('取消', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                          ))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final amount = double.tryParse(controller.text.trim()) ?? 0;
                          await Storage.setMonthlyBudget(amount);
                          await Storage.setBudgetStartDay(selectedDay);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Text('保存', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                          ))),
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

  // ---------------- 分类预算（平铺） ----------------

  Widget _buildCategoryHeader() {
    final setCount = _categoryBudgets.values.where((v) => v > 0).length;
    return Row(
      children: [
        Text('分类预算', style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppDark.title,
        )),
        const SizedBox(width: 8),
        if (setCount > 0)
          Text('已设 $setCount 个', style: TextStyle(fontSize: 12, color: AppDark.hint)),
        const Spacer(),
        Text('点击分类设置预算', style: TextStyle(fontSize: 11.5, color: AppDark.hint)),
      ],
    );
  }

  Widget _buildCategoryList() {
    if (_cats.isEmpty) return const SizedBox.shrink();

    // 已设预算的排前面，其余保持原顺序
    final sorted = List<CategoryDef>.from(_cats)
      ..sort((a, b) {
        final ab = (_categoryBudgets[a.name] ?? 0) > 0;
        final bb = (_categoryBudgets[b.name] ?? 0) > 0;
        if (ab != bb) return ab ? -1 : 1;
        return 0;
      });

    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppDark.divider),
            _buildCategoryRow(sorted[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(CategoryDef c) {
    final name = c.name;
    final budget = _categoryBudgets[name] ?? 0;
    final hasBudget = budget > 0;
    final spent = _catExpenses[name] ?? 0;
    final percent = hasBudget ? spent / budget : 0.0;
    final isOver = percent >= 1.0;
    final isWarning = percent >= 0.8 && !isOver;
    final barColor = isOver
        ? AppColors.danger
        : (isWarning ? const Color(0xFFFF9F43) : c.color);

    return InkWell(
      onTap: () => _showCatBudgetDialog(c),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(c.icon, color: c.color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name, style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppDark.title,
                          )),
                          if (isOver) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('超支', style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.danger,
                              )),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasBudget
                            ? '¥${spent.toStringAsFixed(0)} / ¥${budget.toStringAsFixed(0)}'
                            : '未设置预算',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isOver ? AppColors.danger : AppDark.sub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasBudget)
                  Text(
                    '${(percent * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isOver
                          ? AppColors.danger
                          : (isWarning ? const Color(0xFFFF9F43) : AppDark.title),
                    ),
                  )
                else
                  Icon(Icons.add_circle_outline, size: 18, color: AppDark.hint),
              ],
            ),
            if (hasBudget) ...[
              const SizedBox(height: 8),
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
            ],
          ],
        ),
      ),
    );
  }

  void _showCatBudgetDialog(CategoryDef c) {
    final name = c.name;
    final current = _categoryBudgets[name] ?? 0;
    final controller = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppDark.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(c.icon, size: 19, color: c.color),
                  ),
                  const SizedBox(width: 10),
                  Text('$name · 月预算', style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white,
                  )),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                decoration: InputDecoration(
                  prefixText: '¥ ',
                  hintText: '输入预算金额，留空则清除',
                  hintStyle: TextStyle(color: AppDark.hint),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                autofocus: true,
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
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Text('取消', style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                        ))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final amount = double.tryParse(controller.text.trim()) ?? 0;
                        final budgets = Map<String, double>.from(_categoryBudgets);
                        if (amount > 0) {
                          budgets[name] = amount;
                        } else {
                          budgets.remove(name);
                        }
                        await Storage.setCategoryBudgets(budgets);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Text('确定', style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                        ))),
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

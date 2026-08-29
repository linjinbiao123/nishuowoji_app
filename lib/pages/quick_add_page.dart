import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/categories.dart';
import '../services/storage.dart';
import '../services/quick_add_channel.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';

/// 快捷记账弹窗（由通知栏磁贴拉起，运行在独立的透明 Activity 上）。
///
/// 视觉上是一个底部卡片，背后主界面不可见，用户感知就是"弹窗"。
/// 保存后不关闭，清空金额等待下一笔，实现连续记账；
/// 点击遮罩、右上角关闭或返回键才真正退出。
class QuickAddPage extends StatefulWidget {
  const QuickAddPage({super.key});

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  String _category = '餐饮';
  bool _isExpense = true;
  String? _accountId;
  List<Account> _accounts = [];
  List<String> _customCategories = [];
  List<String> _deletedCategories = [];

  bool _saving = false;
  String? _lastSaved; // 最近一笔成功记录的摘要，用于顶部提示

  List<CategoryDef> get _categories => _isExpense
      ? Categories.activeExpense(_deletedCategories, _customCategories)
      : Categories.activeIncome(_deletedCategories);

  @override
  void initState() {
    super.initState();
    _loadData();
    // 等弹窗入场动画结束再弹键盘，避免动画中弹键盘导致输入法冲突
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _amountFocus.requestFocus();
    });
    // 磁贴被再次点击时，原生会推送模式变化，这里据此重置表单
    QuickAddChannel.resetSignal.addListener(_onReset);
  }

  @override
  void dispose() {
    QuickAddChannel.resetSignal.removeListener(_onReset);
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _onReset() => _clearForm(keepCategory: false);

  Future<void> _loadData() async {
    final accs = await Storage.getAccounts();
    final custom = await Storage.getCustomCategories();
    final deleted = await Storage.getDeletedCategories();
    if (!mounted) return;
    setState(() {
      _accounts = accs;
      _customCategories = custom;
      _deletedCategories = deleted;
      // 当前分类若已被删除，兜底到第一个可用分类
      if (_categories.every((c) => c.name != _category)) {
        _category = _categories.first.name;
      }
    });
  }

  void _clearForm({required bool keepCategory}) {
    setState(() {
      _amountCtrl.clear();
      _noteCtrl.clear();
      _lastSaved = null;
      if (!keepCategory) {
        _isExpense = true;
        _accountId = null;
        _category = '餐饮';
      }
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _toast('请输入有效金额');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    final note = _noteCtrl.text.trim();
    final r = Record(
      amount: amount,
      category: _category,
      // 与主记账页保持一致：备注为空时以分类名兜底
      note: note.isEmpty ? _category : note,
      time: DateTime.now(),
      isExpense: _isExpense,
      accountId: _accountId,
    );
    await Storage.add(r);
    if (_accountId != null) {
      await Storage.adjustAccountBalance(
        _accountId!,
        _isExpense ? -amount : amount,
      );
    }
    HapticFeedback.mediumImpact();

    if (!mounted) return;
    final summary =
        '${_isExpense ? '支出' : '收入'} ¥${amount.toStringAsFixed(2)} · $_category';
    setState(() {
      _saving = false;
      _lastSaved = summary;
      // 保留分类/收支/账户，方便连续记同类账，只清金额与备注
      _amountCtrl.clear();
      _noteCtrl.clear();
    });
    // 连续记账：光标回到金额框，直接输入下一笔
    _amountFocus.requestFocus();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 退出弹窗：通知原生 finish 掉透明 Activity
  Future<void> _dismiss() async {
    await QuickAddChannel.finish();
  }

  @override
  Widget build(BuildContext context) {
    // 背后是透明 Activity，这里铺一层半透明遮罩，
    // 点击遮罩即退出，符合系统弹窗的交互习惯
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              // 拦截卡片区域的点击，避免穿透到遮罩导致误关闭
              onTap: () {},
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  child: _buildCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      // 不能用 const：AppDark.surface 是 getter，不是编译期常量
      decoration: BoxDecoration(
        color: AppDark.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // 顶部小横条：视觉上暗示"这是个可以下拉关闭的弹窗"
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          _buildHeader(),
          Flexible(child: SingleChildScrollView(child: _buildForm())),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          const Text(
            '快速记账',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: AppDark.hint, size: 22),
            onPressed: _dismiss,
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_lastSaved != null) _buildSavedHint(),
          _buildAmountField(),
          const SizedBox(height: 14),
          _buildTypeToggle(),
          const SizedBox(height: 16),
          _buildSectionTitle('分类'),
          const SizedBox(height: 10),
          _buildCategoryGrid(),
          const SizedBox(height: 18),
          _buildSectionTitle('备注'),
          const SizedBox(height: 8),
          _buildNoteField(),
          const SizedBox(height: 18),
          if (_accounts.isNotEmpty) ...[
            _buildSectionTitle('账户（可选）'),
            const SizedBox(height: 10),
            _buildAccountChips(),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSavedHint() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已记录 $_lastSaved',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountCtrl,
      focusNode: _amountFocus,
      // 只允许数字和一个小数点，避免出现多个小数点导致解析失败
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      style: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: _isExpense ? AppColors.danger : AppColors.success,
      ),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            '¥',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppDark.hint,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: '0.00',
        hintStyle: TextStyle(color: AppDark.hint.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      children: [
        _typeChip('支出', true),
        const SizedBox(width: 10),
        _typeChip('收入', false),
      ],
    );
  }

  Widget _typeChip(String label, bool expense) {
    final selected = _isExpense == expense;
    final color = expense ? AppColors.danger : AppColors.success;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isExpense == expense) return;
          setState(() {
            _isExpense = expense;
            // 收支切换后原分类不再适用，切到对应列表的第一个
            _category = _categories.first.name;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.6) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? color : AppDark.hint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppDark.hint,
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((c) {
        final selected = c.name == _category;
        return GestureDetector(
          onTap: () => setState(() => _category = c.name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? c.color.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? c.color : Colors.transparent,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(c.icon, size: 15, color: selected ? c.color : AppDark.hint),
                const SizedBox(width: 5),
                Text(
                  c.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : AppDark.hint,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteCtrl,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: '记一笔什么？（可留空）',
        hintStyle: TextStyle(color: AppDark.hint.withValues(alpha: 0.6)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildAccountChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _accountChip(null, '不计入'),
        ..._accounts.map((a) => _accountChip(a.id, a.name)),
      ],
    );
  }

  Widget _accountChip(String? id, String label) {
    final selected = _accountId == id;
    return GestureDetector(
      onTap: () => setState(() => _accountId = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.accent : AppDark.hint,
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _dismiss,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '关闭',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                disabledBackgroundColor: AppColors.success.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _saving ? '保存中…' : '保存并继续',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

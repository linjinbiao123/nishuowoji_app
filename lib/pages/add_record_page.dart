import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/categories.dart';

class AddRecordSheet extends StatefulWidget {
  const AddRecordSheet({super.key});

  @override
  State<AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<AddRecordSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();
  /// 标记当前键盘是否处于"数字"状态（金额框聚焦），用于切到备注时强制刷新输入法
  bool _keyboardIsNumeric = false;
  String _category = '餐饮';
  bool _isExpense = true;
  String? _deletingCat;
  int _bgIndex = 0; // 全局深色背景主题索引

  /// 与全局分类注册表保持同步（内置 + 已删除过滤）
  List<CategoryDef> get _categories {
    final list = _isExpense ? Categories.builtinExpense : Categories.builtinIncome;
    return list.where((c) => !_deletedCategories.contains(c.name)).toList();
  }

  List<String> _customCategories = [];
  List<String> _deletedCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    _loadDeletedCategories();
    Storage.getBgIndex().then((i) {
      if (mounted) setState(() => _bgIndex = i);
    });
    // 金额框聚焦 => 键盘处于数字模式
    _amountFocus.addListener(() {
      if (_amountFocus.hasFocus) _keyboardIsNumeric = true;
    });
    // 等弹窗入场动画结束后再聚焦金额框，避免键盘在动画中弹出引发输入法冲突
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDeletedCategories() async {
    final list = await Storage.getDeletedCategories();
    setState(() => _deletedCategories = list);
  }

  Future<void> _loadCustomCategories() async {
    final list = await Storage.getCustomCategories();
    setState(() => _customCategories = list);
  }

  void _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }
    final note = _noteCtrl.text.trim();
    final r = Record(
      amount: amount,
      category: _category,
      note: note.isEmpty ? _category : note,
      time: DateTime.now(),
      isExpense: _isExpense,
    );
    await Storage.add(r);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    return Container(
      decoration: BoxDecoration(
        color: theme.base[0],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动条
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('手动记账', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: AppDark.sub, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 金额输入
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDark.divider),
                ),
                child: Row(
                  children: [
                    Text('¥', style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700,
                      color: _isExpense ? AppColors.danger : AppColors.success,
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _amountCtrl,
                        focusNode: _amountFocus,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700,
                          color: _isExpense ? AppColors.danger : AppColors.success,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(color: AppDark.hint, fontSize: 24, fontWeight: FontWeight.w700),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 备注输入
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDark.divider),
                ),
                child: TextField(
                  controller: _noteCtrl,
                  focusNode: _noteFocus,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  enableSuggestions: true,
                  // Android 上从数字键盘直接切到文字键盘时 IME 不会自动刷新，
                  // 需要先断开再重连焦点，强制系统以文字模式重新打开输入法
                  onTap: () {
                    if (_keyboardIsNumeric) {
                      _keyboardIsNumeric = false;
                      _noteFocus.unfocus();
                      Future.delayed(const Duration(milliseconds: 80), () {
                        if (mounted) _noteFocus.requestFocus();
                      });
                    }
                  },
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '备注（可选）',
                    hintStyle: TextStyle(color: AppDark.hint, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 日期 + 类型 + 分类
              Row(
                children: [
                  // 左边日期
                  Text(
                    '${DateTime.now().month}月${DateTime.now().day}日',
                    style: const TextStyle(color: AppDark.hint, fontSize: 13),
                  ),
                  const Spacer(),
                  // 支出/收入切换
                  GestureDetector(
                    onTap: () => setState(() {
                      _isExpense = !_isExpense;
                      _category = _isExpense ? '餐饮' : '工资';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isExpense
                            ? AppColors.danger.withOpacity(0.12)
                            : AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isExpense ? Icons.remove_circle_outline : Icons.add_circle_outline,
                            color: _isExpense ? AppColors.danger : AppColors.success,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isExpense ? '支出' : '收入',
                            style: TextStyle(
                              color: _isExpense ? AppColors.danger : AppColors.success,
                              fontWeight: FontWeight.w600, fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 分类选择
                  GestureDetector(
                    onTap: () => _showCategoryDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppDark.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(_category),
                            size: 16,
                            color: _getCategoryColor(_category),
                          ),
                          const SizedBox(width: 6),
                          Text(_category, style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 13,
                          )),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down, color: AppDark.sub, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('保存', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16,
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String name) => Categories.iconOf(name);

  Color _getCategoryColor(String name) => Categories.colorOf(name);

  void _showCategoryDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDark.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择分类', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._categories.map((c) {
                    final selected = c.name == _category;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _category = c.name);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? c.color : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? Colors.transparent : AppDark.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(c.icon, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              c.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  ..._customCategories.map((name) {
                    final selected = name == _category;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _category = name);
                        Navigator.pop(ctx);
                      },
                      onLongPress: () {
                        setSheetState(() => _deletingCat = _deletingCat == name ? null : name);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? Categories.customColor : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _deletingCat == name ? AppColors.danger : (selected ? Colors.transparent : AppDark.divider)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Categories.customIcon, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            if (_deletingCat == name) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () async {
                                  await Storage.removeCustomCategory(name);
                                  setState(() {
                                    _customCategories.remove(name);
                                    if (_category == name) _category = _isExpense ? '餐饮' : '工资';
                                    _deletingCat = null;
                                  });
                                  setSheetState(() {});
                                },
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () => _showAddCustomCategoryDialog(ctx, setSheetState),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppDark.divider),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: AppDark.sub, size: 18),
                          SizedBox(width: 6),
                          Text('自定义', style: TextStyle(color: AppDark.sub)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCustomCategoryDialog(BuildContext sheetCtx, StateSetter setSheetState) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDark.surface,
        title: const Text('自定义分类', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '输入分类名称',
            hintStyle: const TextStyle(color: AppDark.hint),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              if (name.isNotEmpty) {
                await Storage.addCustomCategory(name);
                setState(() {
                  _customCategories.add(name);
                  _category = name;
                });
                setSheetState(() {});
                Navigator.pop(ctx);
                Navigator.pop(sheetCtx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('添加', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

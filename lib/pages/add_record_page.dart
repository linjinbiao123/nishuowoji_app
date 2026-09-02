import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/categories.dart';
import '../services/attachment_service.dart';
import '../widgets/attachment_image.dart';

class AddRecordSheet extends StatefulWidget {
  /// 外部传入的初始附件文件名（例如从首页拍照后带入）。
  final List<String>? initialImages;

  const AddRecordSheet({super.key, this.initialImages});

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

  // 多账户：选中的账户ID（null = 不计入任何账户）
  String? _accountId;
  List<Account> _accounts = [];

  // 附件（图片 / 发票）
  final ImagePicker _picker = ImagePicker();
  List<String> _pendingImages = []; // 已保存到附件目录的文件名
  String _attachDir = '';
  bool _isInvoice = false;
  bool _saved = false;

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
    // 带入外部传入的初始图片
    if (widget.initialImages != null && widget.initialImages!.isNotEmpty) {
      _pendingImages.addAll(widget.initialImages!);
    }
    _loadCustomCategories();
    _loadDeletedCategories();
    Storage.getAccounts().then((accs) {
      if (mounted) setState(() => _accounts = accs);
    });
    Storage.getBgIndex().then((i) {
      if (mounted) setState(() => _bgIndex = i);
    });
    // 预解析附件目录，供缩略图同步显示
    AttachmentService.dirPath().then((d) {
      if (mounted) setState(() => _attachDir = d);
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
    // 未保存就关闭弹窗时，清理已落盘的临时附件，避免孤儿文件
    if (!_saved) AttachmentService.deleteImages(_pendingImages);
    super.dispose();
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final xfile = await _picker.pickImage(source: src, imageQuality: 80);
      if (xfile != null) {
        final name = await AttachmentService.saveImage(xfile.path);
        setState(() => _pendingImages.add(name));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败：$e')),
      );
    }
  }

  void _removeImage(String name) {
    setState(() => _pendingImages.remove(name));
    AttachmentService.deleteImages([name]);
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
    _saved = true;
    final r = Record(
      amount: amount,
      category: _category,
      note: note.isEmpty ? _category : note,
      time: DateTime.now(),
      isExpense: _isExpense,
      images: List.from(_pendingImages),
      isInvoice: _isInvoice,
      accountId: _accountId,
    );
    await Storage.add(r);
    // 选中账户时自动增减余额（支出为负，收入为正）
    if (_accountId != null) {
      await Storage.adjustAccountBalance(_accountId!, _isExpense ? -amount : amount);
    }
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
                  color: AppDark.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('手动记账', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppDark.title,
                  )),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: AppDark.sub, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 金额输入
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppDark.cardBg,
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
                        decoration: InputDecoration(
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
                  color: AppDark.cardBg,
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
                  style: TextStyle(fontSize: 15, color: AppDark.title),
                  decoration: InputDecoration(
                    hintText: '备注（可选）',
                    hintStyle: TextStyle(color: AppDark.hint, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 附件（图片 / 发票）
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDark.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDark.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.photo_library_outlined, size: 16, color: AppDark.sub),
                        const SizedBox(width: 6),
                        Text('图片 / 发票', style: TextStyle(color: AppDark.title, fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _pickImage(ImageSource.camera),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppDark.cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppDark.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt, size: 14, color: AppDark.title),
                                const SizedBox(width: 4),
                                Text('拍照', style: TextStyle(color: AppDark.title, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _pickImage(ImageSource.gallery),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppDark.cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppDark.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_library, size: 14, color: AppDark.title),
                                const SizedBox(width: 4),
                                Text('相册', style: TextStyle(color: AppDark.title, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_pendingImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _pendingImages.map((name) {
                          final path = _attachDir.isNotEmpty
                              ? '$_attachDir/$name'
                              : name;
                          return GestureDetector(
                            onTap: () => _removeImage(name),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AttachmentImage(path: path, width: 56, height: 56),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                      Text('点击缩略图可移除', style: TextStyle(color: AppDark.hint, fontSize: 11)),
                    ],
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(() => _isInvoice = !_isInvoice),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isInvoice ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 16,
                            color: _isInvoice ? const Color(0xFFFFB020) : AppDark.sub,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '标记为发票',
                            style: TextStyle(
                              color: _isInvoice ? const Color(0xFFFFB020) : AppDark.sub,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 日期 + 类型 + 分类
              Row(
                children: [
                  // 左边日期
                  Text(
                    '${DateTime.now().month}月${DateTime.now().day}日',
                    style: TextStyle(color: AppDark.hint, fontSize: 13),
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
                            ? AppColors.danger.withValues(alpha: 0.12)
                            : AppColors.success.withValues(alpha: 0.12),
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
                        color: AppDark.cardBg,
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
                          Text(_category, style: TextStyle(
                            color: AppDark.title,
                            fontWeight: FontWeight.w600, fontSize: 13,
                          )),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down, color: AppDark.sub, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 账户选择（不计入任何账户 / 选某账户自动增减余额）
              GestureDetector(
                onTap: _showAccountSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppDark.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppDark.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                        size: 18, color: AppDark.sub),
                      const SizedBox(width: 8),
                      Text('账户', style: TextStyle(color: AppDark.title, fontSize: 14)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _accountId == null
                              ? '不计入账户'
                              : _accounts
                                  .firstWhere(
                                    (a) => a.id == _accountId,
                                    orElse: () => Account(id: '', name: '已删除'),
                                  )
                                  .name,
                          style: TextStyle(
                            color: _accountId == null ? AppDark.hint : theme.accent,
                            fontSize: 14, fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: AppDark.sub, size: 18),
                    ],
                  ),
                ),
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
                  child: Text('保存', style: TextStyle(
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

  void _showAccountSheet() {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    Icon accIcon(int code, Color color, double size) =>
        Icon(IconData(code, fontFamily: 'MaterialIcons'), color: color, size: size);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDark.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择账户', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
            )),
            const SizedBox(height: 8),
            Text('不选则正常记账，不计入任何账户余额', style: TextStyle(
              fontSize: 12, color: AppDark.hint,
            )),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // 不计入账户
                GestureDetector(
                  onTap: () {
                    setState(() => _accountId = null);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _accountId == null ? theme.accent.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accountId == null ? theme.accent : AppDark.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        const Text('不计入', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                ..._accounts.map((a) {
                  final selected = a.id == _accountId;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _accountId = a.id);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? theme.accent.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? theme.accent : AppDark.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          accIcon(a.icon, Colors.white, 18),
                          const SizedBox(width: 6),
                          Text(a.name, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

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
              Text('选择分类', style: TextStyle(
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
                          color: selected ? c.color : Colors.white.withValues(alpha: 0.08),
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
                          color: selected ? Categories.customColor : Colors.white.withValues(alpha: 0.08),
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
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppDark.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: AppDark.sub, size: 18),
                          const SizedBox(width: 6),
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
        title: Text('自定义分类', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '输入分类名称',
            hintStyle: TextStyle(color: AppDark.hint),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                await Storage.addCustomCategory(name);
                setState(() {
                  _customCategories.add(name);
                  _category = name;
                });
                setSheetState(() {});
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: Text('添加', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

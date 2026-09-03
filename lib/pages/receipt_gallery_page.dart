import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/attachment_service.dart';
import '../widgets/attachment_image.dart';
import '../widgets/image_viewer.dart';
import '../widgets/category_glyph.dart';

/// 票据相册：集中查看所有带图片附件的记账记录。
///
/// 图片本身一直保存在 app 私有 attachments 目录（不会过期），
/// 但此前只能在「首页当天列表」或「历史账单逐月翻页」里偶遇，
/// 本页按「年月」倒序分组做九宫格聚合，解决"翻旧票据像考古"的问题。
class ReceiptGalleryPage extends StatefulWidget {
  const ReceiptGalleryPage({super.key});

  @override
  State<ReceiptGalleryPage> createState() => _ReceiptGalleryPageState();
}

class _ReceiptGalleryPageState extends State<ReceiptGalleryPage> {
  /// 仅含带图片的记录，按时间倒序
  List<Record> _all = [];
  String _attachDir = '';
  int _bgIndex = 0;
  bool _loading = true;

  // 筛选条件
  bool _onlyInvoice = false;
  int? _yearFilter; // null = 全部年份

  static const _categoryColors = <String, Color>{
    '餐饮': Color(0xFFFF6B6B), '交通': Color(0xFF4ECDC4), '购物': Color(0xFFFFE66D),
    '娱乐': Color(0xFFFF9F43), '居家': Color(0xFF6C5CE7), '医疗': Color(0xFFFDA7DF),
    '教育': Color(0xFF00D2D3), '通讯': Color(0xFF74B9FF), '服饰': Color(0xFFA29BFE),
    '美容': Color(0xFFFD79A8), '社交': Color(0xFF55EFC4), '旅行': Color(0xFF81ECEC),
    '宠物': Color(0xFFFAB1A0), '运动': Color(0xFF00B894), '数码': Color(0xFF636E72),
    '礼物': Color(0xFFE17055), '其他': Color(0xFFB2BEC3), '工资': Color(0xFF10B981),
    '兼职': Color(0xFF4ECDC4), '理财': Color(0xFFFF9F43), '礼金': Color(0xFFFF6B6B),
    '报销': Color(0xFF6C5CE7), '红包': Color(0xFFE17055),
  };

  static const _invoiceColor = Color(0xFFFFB020);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await Storage.getAll();
    final bg = await Storage.getBgIndex();
    final dir = await AttachmentService.dirPath();
    final withImages = records.where((r) => r.images.isNotEmpty).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    if (!mounted) return;
    setState(() {
      _all = withImages;
      _bgIndex = bg;
      _attachDir = dir;
      _loading = false;
    });
  }

  // ---------------- 筛选与分组 ----------------

  /// 有图记录涉及的年份，倒序
  List<int> get _years {
    final set = <int>{for (final r in _all) r.time.year};
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<Record> get _filtered => _all.where((r) {
        if (_onlyInvoice && !r.isInvoice) return false;
        if (_yearFilter != null && r.time.year != _yearFilter) return false;
        return true;
      }).toList();

  /// 当前筛选下的图片总张数（一条记录可能有多张）
  int get _photoCount => _filtered.fold(0, (sum, r) => sum + r.images.length);

  /// 按「年月」分组，因源列表已倒序，插入顺序即为倒序
  Map<String, List<Record>> get _grouped {
    final map = <String, List<Record>>{};
    for (final r in _filtered) {
      map.putIfAbsent('${r.time.year}年${r.time.month}月', () => []).add(r);
    }
    return map;
  }

  String _pathOf(String name) =>
      _attachDir.isNotEmpty ? '$_attachDir/$name' : name;

  Color _colorOf(String category) =>
      _categoryColors[category] ?? const Color(0xFF95A5A6);

  // ---------------- 构建 ----------------

  @override
  Widget build(BuildContext context) {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppThemeMode.isLight
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: AppBackground(
        theme: theme,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (!_loading && _all.isNotEmpty) _buildFilters(theme),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppDark.title),
            onPressed: () => Navigator.pop(context),
          ),
          Text('票据相册', style: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w800, color: AppDark.title,
          )),
          const Spacer(),
          if (!_loading && _all.isNotEmpty)
            Text('共 $_photoCount 张', style: TextStyle(
              fontSize: 12, color: AppDark.sub,
            )),
        ],
      ),
    );
  }

  Widget _buildFilters(AppBgTheme theme) {
    final years = _years;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chip(
                label: '全部',
                selected: !_onlyInvoice,
                accent: theme.accent,
                onTap: () => setState(() => _onlyInvoice = false),
              ),
              const SizedBox(width: 8),
              _chip(
                label: '仅发票',
                selected: _onlyInvoice,
                accent: theme.accent,
                onTap: () => setState(() => _onlyInvoice = true),
              ),
            ],
          ),
          // 记录跨越多个年份时才提供年份筛选
          if (years.length > 1) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(
                    label: '全部年份',
                    selected: _yearFilter == null,
                    accent: theme.accent,
                    onTap: () => setState(() => _yearFilter = null),
                  ),
                  ...years.map((y) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _chip(
                          label: '$y',
                          selected: _yearFilter == y,
                          accent: theme.accent,
                          onTap: () => setState(() => _yearFilter = y),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : AppDark.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : AppDark.cardBorder,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppDark.sub,
        )),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 26, height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppDark.hint),
        ),
      );
    }
    if (_all.isEmpty) return _buildEmpty('还没有带图片的记录', '记账时添加照片或发票，就能在这里集中翻阅');
    if (_filtered.isEmpty) return _buildEmpty('没有符合条件的票据', '换个筛选条件试试');

    final grouped = _grouped;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: grouped.length,
      itemBuilder: (ctx, idx) {
        final key = grouped.keys.elementAt(idx);
        final records = grouped[key]!;
        return _buildMonthSection(key, records);
      },
    );
  }

  Widget _buildEmpty(String title, String hint) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 46, color: AppDark.hint),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppDark.title,
          )),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(hint, textAlign: TextAlign.center, style: TextStyle(
              fontSize: 12, color: AppDark.sub, height: 1.5,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSection(String monthKey, List<Record> records) {
    final photos = records.fold<int>(0, (s, r) => s + r.images.length);
    final total = records
        .where((r) => r.isExpense)
        .fold<double>(0, (s, r) => s + r.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(monthKey, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppDark.title,
              )),
              const Spacer(),
              Text(
                total > 0
                    ? '$photos 张 · 支出 ¥${total.toStringAsFixed(2)}'
                    : '$photos 张',
                style: TextStyle(fontSize: 11, color: AppDark.hint),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
            childAspectRatio: 0.74,
          ),
          itemCount: records.length,
          itemBuilder: (ctx, i) => _buildTile(records[i]),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTile(Record r) {
    final first = r.images.first;
    return GestureDetector(
      onTap: () => _showDetail(r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AttachmentImage(
                    path: _pathOf(first),
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: AppDark.track,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image,
                          color: AppDark.hint, size: 22),
                    ),
                  ),
                  // 发票标记
                  if (r.isInvoice)
                    Positioned(
                      top: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _invoiceColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('票', style: TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w700,
                        )),
                      ),
                    ),
                  // 多图张数
                  if (r.images.length > 1)
                    Positioned(
                      bottom: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('${r.images.length}', style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w700,
                        )),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppDark.title,
            ),
          ),
          Text(
            '${r.isExpense ? '-' : '+'}¥${r.amount.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: r.isExpense ? AppColors.danger : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 记录详情 ----------------

  /// 点击缩略图先展示这条记录的完整信息，再点图进全屏
  void _showDetail(Record r) {
    final isLight = AppThemeMode.isLight;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isLight ? Colors.white : AppDark.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分类图标 + 名称 + 金额
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _colorOf(r.category).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CategoryGlyph(name: r.category,
                        size: 20, color: _colorOf(r.category)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(r.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppDark.title,
                                  )),
                            ),
                            if (r.isInvoice) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _invoiceColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('发票', style: TextStyle(
                                  color: _invoiceColor, fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                )),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_formatTime(r.time), style: TextStyle(
                          fontSize: 11, color: AppDark.hint,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${r.isExpense ? '-' : '+'}¥${r.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: r.isExpense ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ],
              ),
              // 备注（与分类同名时视为无备注，不重复展示）
              if (r.note.isNotEmpty && r.note != r.category) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDark.track,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(r.note, style: TextStyle(
                    fontSize: 12, color: AppDark.body, height: 1.5,
                  )),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('附件 ${r.images.length} 张', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppDark.sub,
                  )),
                  const SizedBox(width: 6),
                  Text('点击放大', style: TextStyle(
                    fontSize: 11, color: AppDark.hint,
                  )),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      for (var i = 0; i < r.images.length; i++)
                        GestureDetector(
                          onTap: () => _showImageViewer(r.images, initialIndex: i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AttachmentImage(
                              path: _pathOf(r.images[i]),
                              width: 64, height: 64,
                              placeholder: Container(
                                width: 64, height: 64,
                                color: AppDark.track,
                                alignment: Alignment.center,
                                child: Icon(Icons.broken_image,
                                    color: AppDark.hint, size: 18),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('关闭', style: TextStyle(color: AppDark.sub)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
}

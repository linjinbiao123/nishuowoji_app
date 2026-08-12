import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage.dart';
import '../services/categories.dart';
import '../theme/app_bg.dart';
import '../services/importer/import_engine.dart';

/// 导入预览页。
///
/// 流程：选择文件 → 引擎解析 → 本页展示识别结果、未匹配分类校正 → 选目标账本 → 落库。
/// 支持"待校正分类"映射编辑（应用到全部同类），确认后才写库，保证精准且无脏数据。
class ImportPreviewPage extends StatefulWidget {
  final String fileName;
  final List<int> bytes;
  const ImportPreviewPage({super.key, required this.fileName, required this.bytes});

  @override
  State<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends State<ImportPreviewPage> {
  ImportResult? _result;
  String? _error;
  bool _parsing = true;

  // 分类校正：原始分类 -> 用户选定的目标分类
  final Map<String, String> _catOverride = {};
  // 未匹配（兜底成自定义）的原始分类集合
  final Set<String> _unmapped = {};

  List<Ledger> _ledgers = [];
  String? _targetLedgerId;
  int _bgIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _parse();
  }

  Future<void> _loadTheme() async {
    _bgIndex = await Storage.getBgIndex();
    if (mounted) setState(() {});
  }

  Future<void> _parse() async {
    try {
      final res = ImportEngine.import(widget.fileName, widget.bytes);
      // 统计未匹配分类（兜底成自定义的原始名）
      for (final r in res.records) {
        if (!CategoryMapper.isKnown(r.rawCategory)) {
          _unmapped.add(r.rawCategory);
          _catOverride[r.rawCategory] = r.rawCategory; // 默认保留原名称
        }
      }
      final ledgers = await Storage.getLedgers();
      if (mounted) {
        setState(() {
          _result = res;
          _ledgers = ledgers;
          _targetLedgerId = ledgers.isNotEmpty ? ledgers.first.id : null;
          _parsing = false;
        });
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _error = '$e\n\n$stack';
          _parsing = false;
        });
      }
    }
  }

  /// 构建落库用的 Record 列表（应用分类校正）
  List<Record> _buildRecords() {
    if (_result == null) return [];
    final list = <Record>[];
    for (final r in _result!.records) {
      final cat = _catOverride[r.rawCategory] ?? r.rawCategory;
      list.add(Record(
        amount: r.amount,
        category: cat,
        note: r.note ?? '',
        time: r.time,
        isExpense: r.isExpense,
        ledgerId: _targetLedgerId ?? 'default_ledger',
      ));
    }
    return list;
  }

  Future<void> _confirmImport() async {
    if (_result == null || _targetLedgerId == null) return;
    final records = _buildRecords();
    // 先把校正产生的自定义分类持久化
    final customCats = <String>{};
    for (final c in _catOverride.values) {
      if (!CategoryMapper.isKnown(c)) customCats.add(c);
    }
    for (final c in customCats) {
      await Storage.addCustomCategory(c);
    }
    await Storage.bulkAdd(records);
    if (mounted) {
      Navigator.pop(context, records.length); // 返回导入条数
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppThemeMode.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.base[0],
        appBar: AppBar(
          backgroundColor: theme.base[0],
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppDark.title),
            tooltip: '',
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('导入预览', style: TextStyle(color: AppDark.title)),
          iconTheme: IconThemeData(color: AppDark.title),
          actions: [
            if (_result != null && _result!.records.isNotEmpty)
              TextButton(
                onPressed: _confirmImport,
                child: const Text('确认导入', style: TextStyle(color: Color(0xFF10B981))),
              ),
          ],
        ),
        body: AppBackground(
          theme: theme,
          child: SafeArea(child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_parsing) {
      return Center(child: CircularProgressIndicator(color: AppDark.title));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _error!,
                    style: TextStyle(color: AppDark.body, fontSize: 12),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final res = _result!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(res),
        const SizedBox(height: 16),
        _ledgerSelector(),
        if (_unmapped.isNotEmpty) ...[
          const SizedBox(height: 16),
          _unmappedCard(),
        ],
        if (res.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          _warningsCard(res.warnings),
        ],
        const SizedBox(height: 16),
        _previewList(res),
      ],
    );
  }

  Widget _summaryCard(ImportResult res) {
    final expense = res.records.where((r) => r.isExpense).length;
    final income = res.records.length - expense;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDark.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDark.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('来源识别：${res.sourceName}', style: TextStyle(color: AppDark.title, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('共 ${res.records.length} 条（支出 $expense · 收入 $income）', style: TextStyle(color: AppDark.sub, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _ledgerSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppDark.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDark.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('导入到账本', style: TextStyle(color: AppDark.title, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _buildLedgerChipRow(),
        ],
      ),
    );
  }

  Widget _buildLedgerChipRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _ledgers.map((l) {
        final selected = _targetLedgerId == l.id;
        return GestureDetector(
          onTap: () => setState(() => _targetLedgerId = l.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppBgTheme.all[0].accent.withValues(alpha: 0.15) : AppDark.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppBgTheme.all[0].accent : AppDark.cardBorder,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.check, size: 14, color: AppBgTheme.all[0].accent),
                  ),
                Text(
                  l.name,
                  style: TextStyle(
                    color: selected ? AppBgTheme.all[0].accent : AppDark.body,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _unmappedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDark.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE17055).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('需校正的分类', style: TextStyle(color: Color(0xFFE17055), fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('以下分类未匹配到本 App 内置分类，默认作为自定义分类保留。可点按改为已有分类：',
              style: TextStyle(color: AppDark.sub, fontSize: 12)),
          const SizedBox(height: 10),
          ..._unmapped.map((raw) => _catRow(raw)),
        ],
      ),
    );
  }

  Widget _catRow(String raw) {
    final allCats = <String>{
      ...Categories.builtinExpense.map((c) => c.name),
      ...Categories.builtinIncome.map((c) => c.name),
    };
    final items = <DropdownMenuItem<String>>[];
    // 原名称不在内置分类里时，才提供“保留为自定义”选项，避免 value 重复
    if (!allCats.contains(raw)) {
      items.add(DropdownMenuItem(value: raw, child: Text('自定义：$raw', style: TextStyle(color: AppDark.title))));
    }
    items.addAll(allCats.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: AppDark.title)))));
    final current = _catOverride[raw];
    final value = items.any((i) => i.value == current) ? current : items.first.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(raw, style: TextStyle(color: AppDark.body, fontSize: 13))),
          const SizedBox(width: 8),
          Text('→', style: TextStyle(color: AppDark.hint)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: value,
            dropdownColor: AppDark.cardBg,
            style: TextStyle(color: AppDark.title),
            items: items,
            onChanged: (v) => setState(() => _catOverride[raw] = v ?? raw),
          ),
        ],
      ),
    );
  }

  Widget _warningsCard(List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDark.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDark.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('识别提示', style: TextStyle(color: AppDark.title, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...warnings.map((w) => Text('· $w', style: TextStyle(color: AppDark.sub, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _previewList(ImportResult res) {
    final limited = res.records.take(50).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppDark.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDark.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('预览（前 ${limited.length} 条）', style: TextStyle(color: AppDark.title, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          ...limited.map((r) => _recordRow(r)),
          if (res.records.length > 50)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(child: Text('… 其余 ${res.records.length - 50} 条省略', style: TextStyle(color: AppDark.hint, fontSize: 12))),
            ),
        ],
      ),
    );
  }

  Widget _recordRow(ImportedRecord r) {
    final cat = _catOverride[r.rawCategory] ?? r.rawCategory;
    return ListTile(
      dense: true,
      leading: Icon(r.isExpense ? Icons.arrow_upward : Icons.arrow_downward,
          color: r.isExpense ? Colors.redAccent : Colors.green, size: 18),
      title: Text(cat, style: TextStyle(color: AppDark.title, fontSize: 14)),
      subtitle: Text(
        '${r.time.year}-${r.time.month.toString().padLeft(2, '0')}-${r.time.day.toString().padLeft(2, '0')}'
        '${r.note != null ? ' · ${r.note}' : ''}',
        style: TextStyle(color: AppDark.sub, fontSize: 12),
      ),
      trailing: Text(
        '${r.isExpense ? '-' : '+'}${r.amount.toStringAsFixed(2)}',
        style: TextStyle(color: r.isExpense ? Colors.redAccent : Colors.green, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

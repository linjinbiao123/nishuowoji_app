import 'dart:convert';
import 'package:csv/csv.dart';
import 'imported_record.dart';
import 'parse_utils.dart';
import 'category_mapper.dart';

/// 本 App 自有导出格式的适配器。
///
/// 由 data_stats_page 导出，表头固定为：`时间,类型,分类,金额,备注`
///  - 类型：支出 / 收入
///  - 金额：正数，方向由类型列决定
/// 这是识别率最高的来源（自家格式，几乎零误差），优先嗅探。
class OwnFormatAdapter extends LedgerAdapter {
  static const List<String> _ownHeader = ['时间', '类型', '分类', '金额', '备注'];

  @override
  String get sourceName => '说记导出';

  @override
  bool canHandle(String fileName, List<int> headerBytes) {
    final lower = fileName.toLowerCase();
    if (!lower.endsWith('.csv') && !lower.endsWith('.txt')) return false;
    // 解码首行（容错截断），精确匹配自家表头，避免误吞外部 CSV
    final firstLine = utf8
        .decode(headerBytes.take(80).toList(), allowMalformed: true)
        .split('\n')
        .first
        .replaceAll('\uFEFF', '')
        .trim();
    final cols = firstLine.split(',').map((e) => e.trim()).toList();
    if (cols.length < _ownHeader.length) return false;
    for (var i = 0; i < _ownHeader.length; i++) {
      if (cols[i] != _ownHeader[i]) return false;
    }
    return true;
  }

  @override
  ImportResult parse(String fileName, List<int> bytes) {
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      content = String.fromCharCodes(bytes);
    }
    if (content.startsWith('\uFEFF')) content = content.substring(1);

    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content);

    if (rows.length < 2) {
      return ImportResult(sourceName: sourceName, records: [], warnings: ['文件无记录']);
    }

    // 定位列（容错：表头顺序不一定严格）
    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final timeIdx = _idx(headers, ['时间', '日期']);
    final typeIdx = _idx(headers, ['类型', '收支']);
    final catIdx = _idx(headers, ['分类', '类别']);
    final amountIdx = _idx(headers, ['金额', 'amount']);
    final noteIdx = _idx(headers, ['备注', 'note', '说明']);

    final records = <ImportedRecord>[];
    final mapper = CategoryMapper();

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((e) => e.toString().trim().isEmpty)) continue;
      final cells = row.map((e) => e.toString()).toList();

      final amountRaw = amountIdx != null && amountIdx < cells.length ? cells[amountIdx] : null;
      final amount = amountRaw != null ? ParseUtils.tryParseAmount(amountRaw) : null;
      if (amount == null || amount == 0) continue;

      final time = timeIdx != null && timeIdx < cells.length
          ? ParseUtils.tryParseDate(cells[timeIdx]) ?? DateTime.now()
          : DateTime.now();

      final typeRaw = typeIdx != null && typeIdx < cells.length ? cells[typeIdx] : null;
      final isExpense = !(typeRaw != null && typeRaw.trim().contains('收入'));

      final rawCat = catIdx != null && catIdx < cells.length ? cells[catIdx].trim() : '其他';

      final note = noteIdx != null && noteIdx < cells.length ? cells[noteIdx].trim() : null;

      records.add(ImportedRecord(
        amount: amount,
        time: time,
        isExpense: isExpense,
        rawCategory: rawCat,
        note: note?.isEmpty == true ? null : note,
      ));
    }

    return ImportResult(sourceName: sourceName, records: records);
  }

  static int? _idx(List<String> headers, List<String> hints) {
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      for (final hint in hints) {
        if (h == hint.toLowerCase() || h.contains(hint.toLowerCase())) return i;
      }
    }
    return null;
  }
}

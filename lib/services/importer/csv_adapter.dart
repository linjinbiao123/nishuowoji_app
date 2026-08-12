import 'dart:convert';
import 'package:csv/csv.dart';
import 'imported_record.dart';
import 'parse_utils.dart';
import 'category_mapper.dart';

/// 通用 CSV 适配器。
///
/// 大多数国产记账 App（随手记、鲨鱼、钱迹、喵记账等）都支持导出 CSV，
/// 表头关键词高度相似。本适配器通过 [ParseUtils.findColumn] 自动定位列，
/// 无需用户逐列配置。识别不到的列留空，不影响其它列导入。
class CsvAdapter extends LedgerAdapter {
  @override
  String get sourceName => '通用 CSV';

  @override
  bool canHandle(String fileName, List<int> headerBytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.csv')) return true;
    // 无扩展名但内容看起来像文本表格：尝试用 BOM/逗号嗅探
    if (headerBytes.length > 4) {
      // UTF-8 BOM
      if (headerBytes[0] == 0xEF && headerBytes[1] == 0xBB && headerBytes[2] == 0xBF) {
        return true;
      }
    }
    return false;
  }

  @override
  ImportResult parse(String fileName, List<int> bytes) {
    // 解码：优先 UTF-8（含 BOM），失败回退 Latin1 再尝试 GBK 近似
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      content = String.fromCharCodes(bytes);
    }
    // 去 BOM
    if (content.startsWith('\uFEFF')) content = content.substring(1);

    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content, fieldDelimiter: _detectDelimiter(content));

    if (rows.isEmpty) {
      return ImportResult(sourceName: sourceName, records: [], warnings: ['文件为空']);
    }

    // 表头
    final headers =
        rows.first.map((e) => e.toString().trim()).toList();
    final amountIdx = ParseUtils.findColumn(headers, ParseUtils.amountHints);
    final amountCandidates = ParseUtils.findAllColumns(headers, ParseUtils.amountHints);
    final dateIdx = ParseUtils.findColumn(headers, ParseUtils.dateHints);
    final typeIdx = ParseUtils.findColumn(headers, ParseUtils.typeHints);
    final catIdx = ParseUtils.findColumn(headers, ParseUtils.categoryHints);
    final noteIdx = ParseUtils.findColumn(headers, ParseUtils.noteHints);
    final acctIdx = ParseUtils.findColumn(headers, ParseUtils.accountHints);

    final warnings = <String>[];
    if (amountIdx == null) warnings.add('未识别到"金额"列，已跳过所有行');
    if (dateIdx == null) warnings.add('未识别到"日期"列，将使用当前时间');

    final records = <ImportedRecord>[];
    final mapper = CategoryMapper();

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((e) => e.toString().trim().isEmpty)) continue;

      final amountRaw = amountIdx != null && amountIdx < row.length
          ? row[amountIdx].toString()
          : null;
      // 随手记等"收/支分两列"：主列可能为空或0，尝试其它金额候选列
      String? resolvedAmountRaw = amountRaw;
      double? amount = amountRaw != null ? ParseUtils.tryParseAmount(amountRaw) : null;
      if (amount == null || amount == 0) {
        for (final idx in amountCandidates) {
          if (idx == amountIdx || idx >= row.length) continue;
          final alt = row[idx].toString();
          final altAmt = ParseUtils.tryParseAmount(alt);
          if (altAmt != null && altAmt != 0) {
            resolvedAmountRaw = alt;
            amount = altAmt;
            break;
          }
        }
      }
      if (amount == null || amount == 0) continue;

      final dateRaw = dateIdx != null && dateIdx < row.length
          ? row[dateIdx].toString()
          : null;
      final time = ParseUtils.tryParseDate(dateRaw ?? '') ?? DateTime.now();

      final typeRaw = typeIdx != null && typeIdx < row.length
          ? row[typeIdx].toString()
          : null;
      final isExpense = ParseUtils.detectExpense(
        typeColumn: typeRaw,
        rawAmount: resolvedAmountRaw,
        fallbackExpense: true,
      );

      final rawCat = catIdx != null && catIdx < row.length
          ? row[catIdx].toString().trim()
          : '其他';

      final note = noteIdx != null && noteIdx < row.length
          ? row[noteIdx].toString().trim()
          : null;
      final account = acctIdx != null && acctIdx < row.length
          ? row[acctIdx].toString().trim()
          : null;

      records.add(ImportedRecord(
        amount: amount,
        time: time,
        isExpense: isExpense,
        rawCategory: rawCat,
        note: note?.isEmpty == true ? null : note,
        account: account?.isEmpty == true ? null : account,
      ));
    }

    return ImportResult(
      sourceName: sourceName,
      records: records,
      warnings: warnings,
    );
  }

  /// 简单嗅探分隔符：优先逗号，其次制表符，其次分号。
  static String _detectDelimiter(String content) {
    final firstLine = content.split('\n').first;
    if (firstLine.contains('\t')) return '\t';
    if (firstLine.contains(';') && !firstLine.contains(',')) return ';';
    return ',';
  }
}

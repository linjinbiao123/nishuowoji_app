import 'package:excel/excel.dart';
import 'imported_record.dart';
import 'parse_utils.dart';
import 'category_mapper.dart';

/// Excel(xlsx) 适配器。
///
/// 少数记账 App 只导出 xlsx。复用与 CSV 相同的列识别/分类映射逻辑，
/// 仅读取第一个工作表。文件头为 zip 魔数 PK\x03\x04。
class XlsxAdapter extends LedgerAdapter {
  @override
  String get sourceName => 'Excel (xlsx)';

  @override
  bool canHandle(String fileName, List<int> headerBytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return true;
    // zip 魔数：50 4B 03 04
    if (headerBytes.length >= 4 &&
        headerBytes[0] == 0x50 &&
        headerBytes[1] == 0x4B &&
        headerBytes[2] == 0x03 &&
        headerBytes[3] == 0x04) {
      return true;
    }
    return false;
  }

  @override
  ImportResult parse(String fileName, List<int> bytes) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      return ImportResult(
        sourceName: sourceName,
        records: [],
        warnings: ['无法解析 Excel 文件：$e'],
      );
    }
    if (excel.tables.isEmpty) {
      return ImportResult(sourceName: sourceName, records: [], warnings: ['文件中没有工作表']);
    }
    final sheet = excel.tables[excel.tables.keys.first]!;
    final rows = sheet.rows;
    if (rows.isEmpty) {
      return ImportResult(sourceName: sourceName, records: [], warnings: ['工作表为空']);
    }

    final headers = rows.first
        .map((c) => (c?.value?.toString() ?? '').trim())
        .toList();
    final amountIdx = ParseUtils.findColumn(headers, ParseUtils.amountHints);
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
      if (row.isEmpty) continue;
      final cells = row.map((c) => c?.value?.toString() ?? '').toList();
      if (cells.every((e) => e.trim().isEmpty)) continue;

      final amountRaw = amountIdx != null && amountIdx < cells.length
          ? cells[amountIdx]
          : null;
      final amount = amountRaw != null ? ParseUtils.tryParseAmount(amountRaw) : null;
      if (amount == null || amount == 0) continue;

      final dateRaw = dateIdx != null && dateIdx < cells.length ? cells[dateIdx] : null;
      final time = ParseUtils.tryParseDate(dateRaw ?? '') ?? DateTime.now();

      final typeRaw = typeIdx != null && typeIdx < cells.length ? cells[typeIdx] : null;
      final isExpense = ParseUtils.detectExpense(
        typeColumn: typeRaw,
        rawAmount: amountRaw,
        fallbackExpense: true,
      );

      final rawCat = catIdx != null && catIdx < cells.length ? cells[catIdx].trim() : '其他';

      final note = noteIdx != null && noteIdx < cells.length ? cells[noteIdx].trim() : null;
      final account = acctIdx != null && acctIdx < cells.length ? cells[acctIdx].trim() : null;

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
}

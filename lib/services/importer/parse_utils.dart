import 'package:intl/intl.dart';

/// 导入解析的通用工具：日期、金额、收支方向识别。
class ParseUtils {
  // 常见日期格式模板（按出现频率排序）
  static final List<DateFormat> _dateFormats = [
    DateFormat('yyyy-MM-dd HH:mm:ss'),
    DateFormat('yyyy-MM-dd HH:mm'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('yyyy/MM/dd HH:mm:ss'),
    DateFormat('yyyy/MM/dd HH:mm'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('yy-MM-dd'),
    DateFormat('yyyy.MM.dd'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('yyyyMMdd'),
  ];

  /// 尝试解析日期，失败返回 null。
  static DateTime? tryParseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    // 先尝试 ISO 标准
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    for (final f in _dateFormats) {
      try {
        return f.parse(s);
      } catch (_) {}
    }
    // 纯时间戳（秒/毫秒）
    final ts = double.tryParse(s);
    if (ts != null) {
      if (ts > 1e12) return DateTime.fromMillisecondsSinceEpoch(ts.toInt());
      if (ts > 1e9) return DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    }
    return null;
  }

  /// 解析金额：去除货币符号、千分位逗号、全角字符。
  /// 返回正数（方向由 [detectExpense] 单独判断）。
  static double? tryParseAmount(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s
        .replaceAll(RegExp(r'[¥￥$,\s]'), '')
        .replaceAll('，', '')
        .replaceAll('元', '')
        .replaceAll('　', '')
        .replaceAll('−', '-') // 全角减号
        .replaceAll('－', '-');
    final v = double.tryParse(s);
    if (v == null) return null;
    return v.abs(); // 方向交给 detectExpense
  }

  /// 判断某行是支出还是收入。
  /// 策略：
  ///  1. 显式方向列（如"收/支"、"类型"）含 收/收入/in/+/贷 → 收入；支/支出/out/-/借 → 支出
  ///  2. 金额带负号 → 支出
  ///  3. 默认按 [fallbackExpense]（导入预览时一般默认支出）
  static bool detectExpense({
    required String? typeColumn,
    required String? rawAmount,
    required bool fallbackExpense,
  }) {
    if (typeColumn != null) {
      final t = typeColumn.trim().toLowerCase();
      if (t.contains(RegExp(r'收|入|in|credit|贷|positive|\+'))) return false;
      if (t.contains(RegExp(r'支|出|out|借|debit|negative|花费|花'))) return true;
    }
    if (rawAmount != null && rawAmount.trim().startsWith('-')) return true;
    return fallbackExpense;
  }

  /// 表头关键词匹配：在 [headers] 中找第一个含 [hints] 任意关键词的列下标。
  static int? findColumn(List<String> headers, List<String> hints) {
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      for (final hint in hints) {
        if (h.contains(hint.toLowerCase())) return i;
      }
    }
    return null;
  }

  /// 返回所有匹配 [hints] 的列下标（支持"金额(收)""金额(支)"多列场景）。
  static List<int> findAllColumns(List<String> headers, List<String> hints) {
    final out = <int>[];
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      for (final hint in hints) {
        if (h.contains(hint.toLowerCase())) {
          out.add(i);
          break;
        }
      }
    }
    return out;
  }

  static const List<String> amountHints = [
    '金额', 'amount', 'money', '收/支金额', '交易金额', '数目', 'price', 'sum',
  ];
  static const List<String> dateHints = [
    '日期', '时间', 'date', 'time', '记账时间', '交易时间', 'created',
  ];
  static const List<String> typeHints = [
    '类型', '收支', 'category_type', '收/支', '方向', 'type', 'io', 'inout',
  ];
  static const List<String> categoryHints = [
    '分类', 'category', '类别', '记账类别', 'class', 'kind',
  ];
  static const List<String> noteHints = [
    '备注', 'note', 'remark', '说明', '描述', 'desc', 'memo', 'comment',
  ];
  static const List<String> accountHints = [
    '账户', 'account', '钱包', '卡', '账簿', '账本',
  ];
}

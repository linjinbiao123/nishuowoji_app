/// 导入模块的统一中间模型。
///
/// 各家记账 App 导出的格式千差万别，导入引擎先把它们都解析成本结构，
/// 再统一映射/落库。这样外部格式与内部 [Record] 完全解耦。
class ImportedRecord {
  final double amount;
  final DateTime time;
  final bool isExpense; // true=支出，false=收入
  final String rawCategory; // 对方 App 的原始分类名（未映射）
  final String? note;
  final String? account; // 对方可能带有的账户/账本名（可选）

  ImportedRecord({
    required this.amount,
    required this.time,
    required this.isExpense,
    required this.rawCategory,
    this.note,
    this.account,
  });
}

/// 导入结果（供预览页展示）。
class ImportResult {
  final String sourceName; // 识别出的来源，如 "通用 CSV"
  final List<ImportedRecord> records;
  final List<String> warnings; // 解析过程中的提示（如跳过的行）

  ImportResult({
    required this.sourceName,
    required this.records,
    this.warnings = const [],
  });
}

/// 适配器接口：一种来源 = 一个实现。
///
/// [canHandle] 负责"格式嗅探"——根据文件名与文件头字节判断能否处理，
/// 这样用户无需手动选择"我从哪家 App 导出的"。
abstract class LedgerAdapter {
  /// 来源显示名
  String get sourceName;

  /// 能否处理该文件。
  /// [fileName] 含扩展名；[headerBytes] 为文件前若干字节（用于嗅探魔数）。
  bool canHandle(String fileName, List<int> headerBytes);

  /// 解析文件内容为中间模型。
  /// [bytes] 为文件完整内容；[fileName] 用于推断编码/扩展名。
  ImportResult parse(String fileName, List<int> bytes);
}

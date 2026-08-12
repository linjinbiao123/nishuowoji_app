import 'imported_record.dart';
import 'csv_adapter.dart';
import 'xlsx_adapter.dart';
import 'own_format_adapter.dart';
export 'imported_record.dart';
export 'csv_adapter.dart';
export 'xlsx_adapter.dart';
export 'own_format_adapter.dart';
export 'category_mapper.dart';
export 'parse_utils.dart';

/// 导入引擎：负责嗅探文件格式并派发到对应适配器。
///
/// 新增来源只需在 [_adapters] 里追加一个 [LedgerAdapter] 实现，
/// 入口逻辑无需改动——这是"可插拔"的核心。
class ImportEngine {
  static final List<LedgerAdapter> _adapters = [
    OwnFormatAdapter(), // 自家格式优先
    CsvAdapter(),
    XlsxAdapter(),
  ];

  /// 根据文件名与文件头选择适配器并解析。
  /// 找不到合适适配器时抛出 [UnsupportedError]。
  static ImportResult import(String fileName, List<int> bytes) {
    // 取前 64 字节用于嗅探魔数/表头
    final header = bytes.length > 64 ? bytes.sublist(0, 64) : bytes;
    for (final a in _adapters) {
      if (a.canHandle(fileName, header)) {
        return a.parse(fileName, bytes);
      }
    }
    throw UnsupportedError(
      '不支持的文件格式：$fileName\n仅支持 CSV / Excel(xlsx) 文件，'
      '请先从原记账 App 导出为这两种格式之一。',
    );
  }
}

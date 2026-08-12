// 账本导入模块单元测试（无需任何会员，使用模拟样本验证解析准确性）

import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:nishuowoji_app/services/importer/import_engine.dart';
import 'package:nishuowoji_app/services/importer/category_mapper.dart';
import 'package:nishuowoji_app/services/importer/parse_utils.dart';
import 'package:nishuowoji_app/services/importer/imported_record.dart';

String fixture(String name) => 'test/fixtures/$name';

List<int> readBytes(String path) => File(path).readAsBytesSync();

void main() {
  group('嗅探调度', () {
    test('自家格式被 OwnFormatAdapter 识别', () {
      final bytes = readBytes(fixture('own_format.csv'));
      // canHandle 在 import() 内部调用；直接验证不抛 UnsupportedError
      expect(() => ImportEngine.import('own_format.csv', bytes), returnsNormally);
    });

    test('不支持的格式抛出异常', () {
      expect(
        () => ImportEngine.import('note.txt', utf8.encode('随便一段文本')),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('自身导出格式解析', () {
    test('解析条数与收支方向正确', () {
      final res = ImportEngine.import('own_format.csv', readBytes(fixture('own_format.csv')));
      expect(res.sourceName, '说记导出');
      expect(res.records.length, 5);
      // 第1条支出、第2条收入
      expect(res.records[0].isExpense, isTrue);
      expect(res.records[1].isExpense, isFalse);
      expect(res.records[1].amount, 12000);
      expect(res.records[0].rawCategory, '餐饮');
    });
  });

  group('通用 CSV 适配器 - 多种外部格式', () {
    test('鲨鱼风格（正负金额表示方向）', () {
      final res = ImportEngine.import('shark_style.csv', readBytes(fixture('shark_style.csv')));
      expect(res.records.length, 5);
      expect(res.records[0].isExpense, isTrue); // -38.5 → 支出
      expect(res.records[1].isExpense, isFalse); // 12000 → 收入
      expect(res.records[4].amount, 4999);
    });

    test('钱迹风格（收/支列文字）', () {
      final res = ImportEngine.import('qianji_style.csv', readBytes(fixture('qianji_style.csv')));
      expect(res.records.length, 5);
      expect(res.records[0].isExpense, isTrue); // 支
      expect(res.records[1].isExpense, isFalse); // 收
      expect(res.records[0].amount, 38.5);
    });

    test('随手记风格（收/支两列金额）', () {
      final res = ImportEngine.import('ssji_style.csv', readBytes(fixture('ssji_style.csv')));
      // 期望 5 条全部解析（支出行金额在"金额(支)"列）
      expect(res.records.length, 5,
          reason: '随手记收/支分两列，应取非空的那一列');
      expect(res.records[0].amount, 38.5);
      expect(res.records[1].amount, 12000);
      expect(res.records[1].isExpense, isFalse);
    });

    test('带 UTF-8 BOM 的 CSV', () {
      final raw = readBytes(fixture('with_bom.csv'));
      final withBom = <int>[0xEF, 0xBB, 0xBF, ...raw];
      final res = ImportEngine.import('with_bom.csv', withBom);
      expect(res.records.length, 3);
      expect(res.records[0].rawCategory, '餐饮');
    });
  });

  group('分类映射器', () {
    final mapper = CategoryMapper();

    test('精确/同义词匹配', () {
      expect(mapper.map('外卖'), '餐饮');
      expect(mapper.map('打车'), '交通');
      expect(mapper.map('淘宝'), '购物');
      expect(mapper.map('工资薪金'), '工资');
    });

    test('关键词包含匹配', () {
      expect(mapper.map('星巴克咖啡'), '餐饮');
      expect(mapper.map('高铁票'), '交通');
      expect(mapper.map('健身房月卡'), '运动');
    });

    test('未匹配 → 保留原名称作为自定义分类', () {
      const unknown = '某个奇怪的分类名XYZ';
      final mapped = mapper.map(unknown);
      expect(mapped, unknown); // 原样保留
      expect(mapper.pendingCustomCategories().contains(unknown), isTrue);
    });

    test('空分类兜底为其他', () {
      expect(mapper.map('   '), '其他');
    });
  });

  group('日期解析工具', () {
    test('多种日期格式', () {
      expect(ParseUtils.tryParseDate('2026-08-01'), isNotNull);
      expect(ParseUtils.tryParseDate('2026/08/01 12:30'), isNotNull);
      expect(ParseUtils.tryParseDate('2026.08.01'), isNotNull);
      expect(ParseUtils.tryParseDate(''), isNull);
    });

    test('金额去除符号与千分位', () {
      expect(ParseUtils.tryParseAmount('¥1,200.00'), 1200.0);
      expect(ParseUtils.tryParseAmount('-38.5'), 38.5); // 方向由 detectExpense 处理
    });
  });
}

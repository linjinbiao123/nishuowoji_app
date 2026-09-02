import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nishuowoji_app/services/attachment_service.dart';
import 'package:nishuowoji_app/services/bill_export_service.dart';
import 'package:nishuowoji_app/services/storage.dart';

/// 验证「Excel + 图片」导出：
/// 生成 ZIP 后解包，检查 xlsx 与图片是否齐全、命名是否与表格序号对应。
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 测试环境没有 path_provider 的原生实现，
  // 这里把它的通道指向一个临时目录，让附件服务能正常工作。
  final sandbox = Directory.systemTemp.createTempSync('bill_export_sandbox');
  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((call) async {
    if (call.method == 'getApplicationDocumentsDirectory') {
      return sandbox.path;
    }
    return null;
  });

  test('导出 ZIP 包含 Excel 与全部附件图片', () async {
    // 准备一张真实图片到附件目录
    final bytes = List<int>.generate(2048, (i) => i % 251);
    final tmp = Directory.systemTemp.createTempSync('bill_export_test');
    final src = File('${tmp.path}/src.jpg')..writeAsBytesSync(bytes);
    final name = await AttachmentService.saveImage(src.path);

    final record = Record(
      amount: 85.5,
      category: '餐饮',
      note: '午餐',
      time: DateTime(2026, 9, 2, 14, 30),
      isExpense: true,
      images: [name],
    );

    final result = await BillExportService.build(records: [record]);

    expect(result.recordCount, 1);
    expect(result.imageCount, 1);
    expect(result.missingImages, isEmpty);

    // 在内存中解包校验。
    // 注意：不能用系统 unzip 命令——容器里的 Info-ZIP 不识别 ZIP 的 UTF-8
    // 标志位，会把中文文件名解成乱码，造成误判（已用 Python zipfile 验证过
    // 本代码生成的 ZIP 编码正确）。
    final archive = ZipDecoder().decodeBytes(result.bytes);
    final names = archive.files.map((f) => f.name).toList();
    print('ZIP 内容: $names');

    expect(names.any((n) => n == '账单.xlsx'), isTrue, reason: '缺少 Excel 账单');
    final images = names.where((n) => n.startsWith('图片/')).toList();
    expect(images.length, 1, reason: '附件图片数量不符');

    // 命名规则：序号_时间戳_类型_分类_金额_图片序号
    final imgName = images.first.split('/').last;
    expect(imgName, matches(RegExp(r'^001_\d{8}_\d{4}_支出_餐饮_85\.50_1')));

    // 图片内容必须与原文件一致（不能为空或损坏）
    final entry = archive.files.firstWhere((f) => f.name == images.first);
    expect(entry.content as List<int>, bytes);

    // Excel 文件必须是合法的非空内容
    final xlsx = archive.files.firstWhere((f) => f.name == '账单.xlsx');
    expect((xlsx.content as List<int>).length, greaterThan(100));

    // 清理
    await AttachmentService.deleteImages([name]);
    tmp.deleteSync(recursive: true);
  });

  test('附件文件缺失时跳过并统计', () async {
    final record = Record(
      amount: 10,
      category: '其他',
      note: '无图',
      time: DateTime(2026, 9, 2),
      isExpense: true,
      images: ['not_exist_xxx.jpg'],
    );

    final result = await BillExportService.build(records: [record]);

    expect(result.imageCount, 0);
    expect(result.missingImages, ['not_exist_xxx.jpg']);
  });
}

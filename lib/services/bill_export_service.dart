import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

import 'attachment_service.dart';
import 'storage.dart';

/// 账单导出结果。
class BillExportResult {
  /// 打包好的 ZIP 文件字节
  final Uint8List bytes;

  /// 导出的记录条数
  final int recordCount;

  /// 成功打包的图片数量
  final int imageCount;

  /// 缺失的图片（记录里登记了但文件已不存在）
  final List<String> missingImages;

  const BillExportResult({
    required this.bytes,
    required this.recordCount,
    required this.imageCount,
    required this.missingImages,
  });

  bool get hasMissingImages => missingImages.isNotEmpty;
}

/// 把账单导出为「Excel 表格 + 附件图片文件夹」的压缩包。
///
/// ZIP 结构：
///   账单.xlsx          表格，含"附件图片"列标注该笔记录对应的文件名
///   图片/001_..._1.jpg  按"序号_时间_类型_分类_金额_图片序号"命名
///
/// 图片文件名带序号前缀（与表格的"序号"列一致），
/// 便于在 Excel 里按序号精确找到对应图片。
class BillExportService {
  /// 生成导出用的 ZIP 字节流。
  ///
  /// 图片按原始大小打包，不做压缩或缩放。
  static Future<BillExportResult> build({
    required List<Record> records,
  }) async {
    final sorted = List<Record>.from(records)
      ..sort((a, b) => b.time.compareTo(a.time));

    final excel = Excel.createExcel();
    // createExcel 会自带一个名为 "Sheet1" 的默认页，改名避免用户看到英文页签
    if (excel.sheets.containsKey('Sheet1')) {
      excel.rename('Sheet1', '账单');
    }
    final sheet = excel['账单'];

    sheet.appendRow([
      TextCellValue('序号'),
      TextCellValue('时间'),
      TextCellValue('类型'),
      TextCellValue('分类'),
      TextCellValue('金额'),
      TextCellValue('备注'),
      TextCellValue('附件图片'),
    ]);

    final archive = Archive();
    final missing = <String>[];
    int imageCount = 0;

    for (var i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      final seq = (i + 1).toString().padLeft(3, '0');
      final type = r.isExpense ? '支出' : '收入';
      final amount = r.amount.toStringAsFixed(2);
      final stamp = _fileStamp(r.time);
      final safeCat = _sanitize(r.category);

      // 收集该笔记录的图片，命名形如 001_20260902_1430_支出_餐饮_85.00_1.jpg
      final imageNames = <String>[];
      for (var j = 0; j < r.images.length; j++) {
        final srcName = r.images[j];
        final srcFile = File(await AttachmentService.pathOf(srcName));
        // 记录里登记了附件但文件已被清理的情况，跳过并统计
        if (!await srcFile.exists()) {
          missing.add(srcName);
          continue;
        }
        final ext = p.extension(srcName).isEmpty ? '.jpg' : p.extension(srcName);
        final newName = '${seq}_${stamp}_${type}_${safeCat}_${amount}_${j + 1}$ext';
        final bytes = await srcFile.readAsBytes();
        archive.addFile(ArchiveFile('图片/$newName', bytes.length, bytes));
        imageNames.add(newName);
        imageCount++;
      }

      sheet.appendRow([
        TextCellValue(seq),
        TextCellValue(_displayTime(r.time)),
        TextCellValue(type),
        TextCellValue(r.category),
        DoubleCellValue(r.amount),
        TextCellValue(r.note),
        // 多个附件用分号分隔，便于在单元格里直接看到对应关系
        TextCellValue(imageNames.join(' ; ')),
      ]);
    }

    // 表格放在最前面，用户解压后第一眼就能看到
    final excelBytes = excel.save();
    if (excelBytes == null) {
      throw StateError('Excel 生成失败');
    }
    archive.addFile(ArchiveFile(
      '账单.xlsx',
      excelBytes.length,
      Uint8List.fromList(excelBytes),
    ));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('ZIP 打包失败');
    }

    return BillExportResult(
      bytes: Uint8List.fromList(zipBytes),
      recordCount: sorted.length,
      imageCount: imageCount,
      missingImages: missing,
    );
  }

  /// 用于文件名的时间戳：20260902_1430
  static String _fileStamp(DateTime t) =>
      '${t.year}${_2(t.month)}${_2(t.day)}_${_2(t.hour)}${_2(t.minute)}';

  /// 表格里显示的时间：2026-09-02 14:30
  static String _displayTime(DateTime t) =>
      '${t.year}-${_2(t.month)}-${_2(t.day)} ${_2(t.hour)}:${_2(t.minute)}';

  static String _2(int v) => v.toString().padLeft(2, '0');

  /// 去掉文件名中不允许出现的字符（Windows / macOS 通用限制）
  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_').trim().isEmpty
          ? '未分类'
          : s.replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_').trim();
}

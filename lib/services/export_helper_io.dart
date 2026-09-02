import 'dart:io';
import 'dart:typed_data';

/// 导出文件的存放目录。
///
/// 沿用原有行为：直接写入公共 Download 目录。
/// 若目录不存在则创建（部分机型首次访问需要）。
String _downloadDir() {
  final dir = Directory('/storage/emulated/0/Download');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir.path;
}

void downloadCsv(String content, String filename) {
  final file = File('${_downloadDir()}/$filename');
  // 加 BOM，保证 Excel 打开 CSV 时不乱码
  file.writeAsStringSync('\ufeff$content');
}

/// 写入二进制文件（ZIP 等）。
void downloadBytes(Uint8List bytes, String filename) {
  final file = File('${_downloadDir()}/$filename');
  file.writeAsBytesSync(bytes);
}

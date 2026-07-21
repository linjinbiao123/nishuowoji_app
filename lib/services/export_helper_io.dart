import 'dart:io';

void downloadCsv(String content, String filename) {
  final dir = Directory('/storage/emulated/0/Download');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final file = File('${dir.path}/$filename');
  file.writeAsStringSync('\ufeff$content');
}

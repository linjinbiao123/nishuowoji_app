import 'dart:html' as html;

void downloadCsv(String content, String filename) {
  final blob = html.Blob(['\ufeff$content'], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

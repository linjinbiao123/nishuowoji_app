import 'dart:typed_data';

/// 网页版占位实现：语音识别依赖原生引擎，仅手机 App 支持。
/// 让 Flutter 网页版能正常编译运行（语音功能在网页上不可用）。
class AsrService {
  static Future<bool> get isReady async => false;

  static String tempRecordPath() => '';

  static Future<String> recognizeFile(String? path) async {
    throw Exception('网页版不支持语音识别');
  }

  static Future<String> recognizePcm(Uint8List pcmBytes) async {
    throw Exception('网页版不支持语音识别');
  }
}

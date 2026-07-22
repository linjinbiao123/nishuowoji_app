/// 网页版占位实现：模型下载依赖原生文件系统，仅手机 App 支持。
class AsrModel {
  static Future<bool> isReady() async => false;

  static Future<void> download({
    void Function(int received, int total)? onProgress,
  }) async {
    throw Exception('网页版不支持下载语音模型');
  }
}

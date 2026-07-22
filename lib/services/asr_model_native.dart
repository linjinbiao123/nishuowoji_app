import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 离线语音模型管理（原生平台）：检查 / 下载 sherpa-onnx 中文 paraformer 小模型。
/// 用户首次使用语音时下载一次（约 82MB），之后语音完全离线。
class AsrModel {
  /// 模型下载源（hf-mirror，国内访问稳定）
  static const _base =
      'https://hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main';
  static const _modelFile = 'model.int8.onnx';
  static const _tokensFile = 'tokens.txt';

  /// 模型完整大小约 81.8MB；小于此值一半视为下载未完成
  static const _modelFullSize = 85786624;

  static String? _dir;

  static Future<String> get modelDir async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    _dir = '${docs.path}${Platform.pathSeparator}sherpa_paraformer_zh';
    return _dir!;
  }

  static Future<String> get modelPath async =>
      '${await modelDir}${Platform.pathSeparator}$_modelFile';
  static Future<String> get tokensPath async =>
      '${await modelDir}${Platform.pathSeparator}$_tokensFile';

  /// 模型是否已下载完整。
  static Future<bool> isReady() async {
    final m = File(await modelPath);
    final t = File(await tokensPath);
    if (!await m.exists() || !await t.exists()) return false;
    return await m.length() > _modelFullSize ~/ 2;
  }

  /// 下载模型。[onProgress] 回调 (已下载字节, 总字节)；总字节未知时为 -1。
  static Future<void> download({
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = Directory(await modelDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    // 先下小的词表，再下大的模型（带进度）
    await _downloadFile('$_base/$_tokensFile', await tokensPath, null);
    await _downloadFile('$_base/$_modelFile', await modelPath, onProgress);
  }

  static Future<void> _downloadFile(
    String url,
    String savePath,
    void Function(int, int)? onProgress,
  ) async {
    final tmp = '$savePath.part';
    final req = http.Request('GET', Uri.parse(url));
    final resp = await req.send();
    if (resp.statusCode != 200) {
      throw Exception('下载失败（HTTP ${resp.statusCode}），请检查网络后重试');
    }
    final total = resp.contentLength ?? -1;
    var received = 0;
    final sink = File(tmp).openWrite();
    try {
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      await File(tmp).rename(savePath); // 下载完整后原子改名
    } catch (e) {
      try { await sink.close(); } catch (_) {}
      final f = File(tmp);
      if (await f.exists()) {
        try { await f.delete(); } catch (_) {}
      }
      rethrow;
    }
  }
}

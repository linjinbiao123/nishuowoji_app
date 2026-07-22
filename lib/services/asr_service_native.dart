import 'dart:io';
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'asr_model_native.dart';

/// 离线语音识别（sherpa-onnx paraformer 中文小模型）——原生平台实现。
/// 完全在手机本地运行：不联网、不需要密钥、录音不上传。
class AsrService {
  static sherpa.OfflineRecognizer? _recognizer;

  /// 模型是否已下载就绪。
  static Future<bool> get isReady => AsrModel.isReady();

  /// 录音临时文件路径（16kHz PCM）。
  static String tempRecordPath() =>
      '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.pcm';

  /// 读取录音文件 → 本地识别 → 删除临时文件 → 返回文本。
  static Future<String> recognizeFile(String? path) async {
    if (path == null) throw Exception('没有录到声音');
    final raw = await File(path).readAsBytes();
    try { await File(path).delete(); } catch (_) {}
    if (raw.isEmpty) throw Exception('没有录到声音');
    return recognizePcm(raw);
  }

  /// 初始化识别器（加载模型）。首次约 1~2 秒，之后复用同一实例。
  static Future<void> _ensureRecognizer() async {
    if (_recognizer != null) return;
    sherpa.initBindings();
    final model = sherpa.OfflineModelConfig(
      paraformer: sherpa.OfflineParaformerModelConfig(
        model: await AsrModel.modelPath,
      ),
      tokens: await AsrModel.tokensPath,
      modelType: 'paraformer',
      numThreads: 2,
      debug: false,
    );
    _recognizer =
        sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(model: model));
  }

  /// 识别一段 PCM 音频（16kHz、单声道、16bit 裸流），返回文本。
  static Future<String> recognizePcm(Uint8List pcmBytes) async {
    await _ensureRecognizer();
    final samples = _pcm16ToFloat32(pcmBytes);
    final recognizer = _recognizer!;
    final stream = recognizer.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    recognizer.decode(stream);
    final text = recognizer.getResult(stream).text;
    stream.free();
    return text.trim();
  }

  /// 16bit 有符号小端 PCM → [-1,1] 浮点采样（sherpa-onnx 需要的格式）。
  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final n = bytes.length ~/ 2;
    final out = Float32List(n);
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }
}

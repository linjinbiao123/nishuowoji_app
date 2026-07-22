/// 离线语音模型管理的平台分发：
/// 原生平台用真实下载实现（dart:io）；网页版用占位实现，
/// 避免 dart:io 在网页端编译失败。
export 'asr_model_stub.dart'
    if (dart.library.io) 'asr_model_native.dart';

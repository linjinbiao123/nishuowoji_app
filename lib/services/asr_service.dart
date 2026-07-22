/// 离线语音识别服务的平台分发：
/// 原生平台（安卓/iOS/桌面）用 sherpa-onnx 真实实现；网页版用占位实现，
/// 避免 dart:ffi 在网页端编译失败。
export 'asr_service_stub.dart'
    if (dart.library.io) 'asr_service_native.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 当前应显示的入口页面。
///
/// 主界面（MainActivity）与快捷记账弹窗（QuickAddActivity）共用
/// 同一个 Flutter 引擎，靠这个模式决定渲染哪个页面。
enum AppEntryMode {
  main,
  quickAdd,
}

/// 与 Android 原生通信：入口模式切换、关闭弹窗。
///
/// 通道名必须与 AppEngine.CHANNEL 完全一致。
class QuickAddChannel {
  static const MethodChannel _channel =
      MethodChannel('com.example.nishuowoji_app/quick_add');

  /// 当前入口模式，main.dart 监听它来切换首页/记账弹窗
  static final ValueNotifier<AppEntryMode> mode =
      ValueNotifier(AppEntryMode.main);

  /// 每次进入记账弹窗自增，弹窗据此重置表单（磁贴重复点击时用）
  static final ValueNotifier<int> resetSignal = ValueNotifier(0);

  static bool _inited = false;

  /// 在 runApp 之前调用：注册原生回调并读取初始模式。
  ///
  /// 必须在引擎首次创建时（Dart main 执行时）就完成，
  /// 否则首帧会渲染成错误页面。
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    _channel.setMethodCallHandler(_onNativeCall);
    try {
      final m = await _channel.invokeMethod<String>('getEntryMode');
      mode.value = _parse(m);
    } on MissingPluginException {
      // Web/桌面端没有对应原生实现，保持主界面即可
      mode.value = AppEntryMode.main;
    }
  }

  static Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'entryModeChanged':
        final next = _parse(call.arguments as String?);
        if (next == AppEntryMode.quickAdd) {
          resetSignal.value++;
        }
        mode.value = next;
        return null;
    }
    return null;
  }

  static AppEntryMode _parse(String? v) =>
      v == 'quick_add' ? AppEntryMode.quickAdd : AppEntryMode.main;

  /// 关闭快捷记账弹窗（仅 Android 有效，其他平台无操作）
  static Future<void> finish() async {
    try {
      await _channel.invokeMethod('finish');
    } on MissingPluginException {
      // 非 Android 平台忽略
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/home_page.dart';
import 'pages/quick_add_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_bg.dart';
import 'services/storage.dart';
import 'services/notification_service.dart';
import 'services/quick_add_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 首次打开自动创建"日常账本"
  await Storage.ensureDefaultLedger();
  // 初始化本地通知；若已开启每日提醒则重新登记，防止重启/更新后丢失
  await NotificationService.init();
  if (await Storage.getReminderEnabled()) {
    // 老版本更新上来的用户可能从未授予通知权限（Android 13+），补申请一次
    if (!await NotificationService.isPermissionGranted()) {
      await NotificationService.requestPermission();
    }
    final minutes = await Storage.getReminderMinutes();
    await NotificationService.scheduleDailyReminder(
      minutes ~/ 60,
      minutes % 60,
    );
  }
  // 初始化全局明暗主题状态（默认浅色主题在 AppBgTheme.all[0]）
  final bgIndex = await Storage.getBgIndex();
  AppThemeMode.isLight = AppBgTheme.all[bgIndex % AppBgTheme.all.length].isLight;

  // 读取入口模式：决定首帧渲染主界面还是快捷记账弹窗。
  // 必须在 runApp 之前，否则弹窗场景会先闪一下主界面。
  await QuickAddChannel.init();

  runApp(const NishuowojiApp());
}

class NishuowojiApp extends StatelessWidget {
  const NishuowojiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '说记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
      // 主界面与快捷记账弹窗共用同一个 Flutter 引擎，
      // 这里监听原生推送的模式变化来切换页面。
      // 切换时 HomePage 会重建，因此从弹窗返回时数据自动刷新。
      home: ValueListenableBuilder<AppEntryMode>(
        valueListenable: QuickAddChannel.mode,
        builder: (context, mode, _) {
          return mode == AppEntryMode.quickAdd
              ? const _QuickAddHost()
              : const HomePage();
        },
      ),
    );
  }
}

/// 快捷记账弹窗的宿主。
///
/// 唯一职责是接管系统返回键：在透明 Activity 上按返回键时，
/// 关闭的是整个 Activity，而不是在 Flutter 路由栈里后退。
class _QuickAddHost extends StatelessWidget {
  const _QuickAddHost();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await QuickAddChannel.finish();
      },
      child: const QuickAddPage(),
    );
  }
}

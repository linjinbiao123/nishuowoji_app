import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/home_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_bg.dart';
import 'services/storage.dart';
import 'services/notification_service.dart';

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
      home: const HomePage(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/home_page.dart';
import 'theme/app_theme.dart';
import 'services/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 首次打开自动创建"日常账本"
  await Storage.ensureDefaultLedger();
  runApp(const NishuowojiApp());
}

class NishuowojiApp extends StatelessWidget {
  const NishuowojiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '你说我记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
      home: const HomePage(),
    );
  }
}

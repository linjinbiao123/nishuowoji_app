// 基础冒烟测试：验证 App 能正常构建。

import 'package:flutter_test/flutter_test.dart';

import 'package:nishuowoji_app/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NishuowojiApp());
    await tester.pumpAndSettle();

    // 首页应显示"记账"标签
    expect(find.text('记账'), findsWidgets);
  });
}

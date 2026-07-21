import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// 本地通知服务（纯离线，由系统到点触发，不联网）。
/// 目前只用于"每日记账提醒"。
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 1001;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = '记账提醒';

  static bool _inited = false;

  /// 应用启动时调用一次，完成插件初始化。
  static Future<void> init() async {
    if (_inited) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    // 应用面向中文用户，固定使用上海时区计算提醒时间
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    _inited = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// 动态申请通知权限（Android 13+ 必须运行时申请，否则通知被系统完全屏蔽）。
  /// Android 12 及以下直接返回 true。
  static Future<bool> requestPermission() async {
    await init();
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// 当前通知权限是否已授予。
  static Future<bool> isPermissionGranted() async {
    await init();
    final enabled = await _android?.areNotificationsEnabled();
    return enabled ?? true;
  }

  /// 计算"下一个 hour:minute 时刻"（若今天的已过则推到明天）。
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// 安排每日记账提醒（每天 [hour]:[minute] 触发一次）。
  static Future<void> scheduleDailyReminder(int hour, int minute) async {
    await init();
    // 旧版本曾以 default 优先级创建过同名渠道，而渠道优先级一旦创建就无法提升，
    // 所以每次排定前先删掉旧渠道，让它以"高优先级"重建 => 到点屏幕顶部悬浮提醒。
    await _android?.deleteNotificationChannel(_channelId);
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '每天定时提醒你记一笔账',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.zonedSchedule(
      _dailyReminderId,
      '说记',
      '别忘了记今天的账哦～',
      _nextInstanceOf(hour, minute),
      details,
      // 精确闹钟 + 息屏可用：保证在设定时刻准时触发，不被系统延迟合并
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // 按"时刻"匹配 => 每天同一时间重复
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 取消每日记账提醒。
  static Future<void> cancelDailyReminder() async {
    await init();
    await _plugin.cancel(_dailyReminderId);
  }
}

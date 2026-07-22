import 'dart:io';
import 'package:nishuowoji_app/services/vip_crypto.dart';

/// VIP 发卡工具（只在你自己电脑上运行，私钥绝不进 git）。
///
/// 首次使用（生成专属密钥对，只做一次）：
///   dart run tool/gen_card.dart --init
///
/// 发卡（买家把 App 里显示的"设备码"发给你）：
///   dart run tool/gen_card.dart --device <设备码> --days <天数>
/// 例：dart run tool/gen_card.dart --device eb13c9a2a7a4e3ac --days 365
const _keyFile = 'tool/vip_private_key.txt';

void main(List<String> args) {
  final map = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    if (!args[i].startsWith('--')) continue;
    final key = args[i].substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      map[key] = args[++i];
    } else {
      map[key] = 'true';
    }
  }

  if (map.containsKey('init') || !File(_keyFile).existsSync()) {
    _initKeys();
  }

  final device = map['device'];
  if (device == null || device.isEmpty) {
    print('发卡用法: dart run tool/gen_card.dart --device <设备码> --days <天数>');
    return;
  }

  final priv = File(_keyFile).readAsLinesSync()[0].trim();
  final days = int.tryParse(map['days'] ?? '365') ?? 365;

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = now + days * 24 * 3600;
  final card = VipCrypto.signCardKey(
    privHex: priv,
    expUnix: exp,
    deviceCode: device.trim(),
  );
  final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  print('----------------------------------------');
  print('设备码  : $device');
  print('有效期  : $days 天（到 ${expDate.toLocal().toString().substring(0, 10)}）');
  print('卡密如下（整段复制发给买家）:');
  print(card);
  print('----------------------------------------');
}

void _initKeys() {
  final kp = VipCrypto.generateKeyPairHex();
  File(_keyFile).writeAsStringSync('${kp.priv}\n${kp.pub}\n');
  print('已生成专属密钥对。');
  print('私钥已保存到 $_keyFile —— 这是你的发卡凭证，请备份好，切勿提交到 git！');
  print('公钥（已自动写入 App，无需手动操作）:');
  print(kp.pub);
  print('');
}

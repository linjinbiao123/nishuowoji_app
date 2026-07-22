import 'package:nishuowoji_app/services/vip_crypto.dart';

/// 本地自测：验证"生成密钥 → 发卡 → 验签"整条链路。
/// 运行：dart run tool/vip_test.dart
void main() {
  final kp = VipCrypto.generateKeyPairHex();
  print('私钥: ${kp.priv}');
  print('公钥: ${kp.pub}');

  const androidId = 'test-android-id-123';
  final deviceCode = VipCrypto.deviceFingerprint(androidId);
  print('设备码: $deviceCode');

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = now + 365 * 24 * 3600;

  final card = VipCrypto.signCardKey(
    privHex: kp.priv,
    expUnix: exp,
    deviceCode: deviceCode,
  );
  print('卡密: $card');

  // 1. 正常验证 => 应通过
  final ok = VipCrypto.verifyCardKey(
    cardKey: card, pubHex: kp.pub, deviceCode: deviceCode, nowUnix: now,
  );
  print('[1] 正常验证: valid=${ok.valid} exp=${ok.expUnix} (期望 true)');

  // 2. 设备不匹配 => 应失败
  final wrongDev = VipCrypto.verifyCardKey(
    cardKey: card, pubHex: kp.pub, deviceCode: 'ffffffffffffffff', nowUnix: now,
  );
  print('[2] 设备不匹配: valid=${wrongDev.valid} err=${wrongDev.error} (期望 false)');

  // 3. 已过期 => 应失败
  final expired = VipCrypto.verifyCardKey(
    cardKey: card, pubHex: kp.pub, deviceCode: deviceCode, nowUnix: exp + 1,
  );
  print('[3] 已过期: valid=${expired.valid} err=${expired.error} (期望 false)');

  // 4. 篡改卡密 => 应失败
  final tampered = card.substring(0, card.length - 4) + 'AAAA';
  final bad = VipCrypto.verifyCardKey(
    cardKey: tampered, pubHex: kp.pub, deviceCode: deviceCode, nowUnix: now,
  );
  print('[4] 篡改卡密: valid=${bad.valid} err=${bad.error} (期望 false)');

  // 5. 错误公钥 => 应失败
  final kp2 = VipCrypto.generateKeyPairHex();
  final wrongPub = VipCrypto.verifyCardKey(
    cardKey: card, pubHex: kp2.pub, deviceCode: deviceCode, nowUnix: now,
  );
  print('[5] 错误公钥: valid=${wrongPub.valid} err=${wrongPub.error} (期望 false)');

  final allPass = ok.valid && !wrongDev.valid && !expired.valid && !bad.valid && !wrongPub.valid;
  print(allPass ? '\n全部通过 OK' : '\n存在失败 FAIL');
}

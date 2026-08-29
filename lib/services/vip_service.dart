import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vip_crypto.dart';

/// VIP 会员服务：设备码获取、卡密激活、VIP 状态查询。
///
/// 激活状态以"原始卡密"形式存储，每次查询都用内置公钥重新验签，
/// 因此即使本地存储被篡改也无法伪造 VIP——没有私钥就造不出有效卡密。
class VipService {
  /// 发卡公钥（由 tool/gen_card.dart --init 生成，可公开内置于 App）
  static const String _publicKey =
      '048381a5a5fdb93f46b76eb2fcf08be237c0048d0b34667f5275fbf5310748f3d6f63ca9f5902dd946b24623e8c0406b1a276a53f0e33a0c886ac06bb2ca9bcff3';

  static const _cardKeyPref = 'vip_card_key';

  static String? _cachedDeviceCode;

  /// 当前设备的设备码（买家把这个发给你，你据此发卡）。
  static Future<String> getDeviceCode() async {
    if (_cachedDeviceCode != null) return _cachedDeviceCode!;
    String raw;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      raw = info.id.isEmpty ? 'unknown_device' : info.id;
    } catch (_) {
      raw = 'unknown_device';
    }
    _cachedDeviceCode = VipCrypto.deviceFingerprint(raw);
    return _cachedDeviceCode!;
  }

  /// 用卡密激活 VIP。成功返回到期时间，失败返回错误信息。
  static Future<({bool ok, String? error, int expUnix})> activate(
      String cardKey) async {
    final deviceCode = await getDeviceCode();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final check = VipCrypto.verifyCardKey(
      cardKey: cardKey,
      pubHex: _publicKey,
      deviceCode: deviceCode,
      nowUnix: now,
    );
    if (!check.valid) {
      return (ok: false, error: check.error ?? '卡密无效', expUnix: 0);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cardKeyPref, cardKey.trim());
    return (ok: true, error: null, expUnix: check.expUnix);
  }

  /// 当前是否为有效 VIP（每次都用公钥重新验签 + 校验设备与有效期）。
  static Future<bool> isVip() async {
    final exp = await vipExpiryUnix();
    if (exp == null) return false;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 < exp;
  }

  /// VIP 到期时间戳（秒）；非 VIP 返回 null。
  static Future<int?> vipExpiryUnix() async {
    final prefs = await SharedPreferences.getInstance();
    final cardKey = prefs.getString(_cardKeyPref);
    if (cardKey == null || cardKey.isEmpty) return null;
    final deviceCode = await getDeviceCode();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final check = VipCrypto.verifyCardKey(
      cardKey: cardKey,
      pubHex: _publicKey,
      deviceCode: deviceCode,
      nowUnix: now,
    );
    return check.valid ? check.expUnix : null;
  }

  /// 到期日期可读文本；永久卡显示"永久有效"；非 VIP 返回 null。
  static Future<String?> vipExpiryText() async {
    final exp = await vipExpiryUnix();
    if (exp == null) return null;
    if (VipCrypto.isPermanent(exp)) return '永久有效';
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000)
        .toLocal()
        .toString()
        .substring(0, 10);
  }

  /// 清除激活状态。
  static Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cardKeyPref);
  }
}

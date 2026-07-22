import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart' as crypto;

/// VIP 卡密的加密核心（纯 Dart，无 Flutter 依赖）。
/// 发卡脚本（tool/）与 App 端共用此文件，保证卡密格式与签名算法完全一致。
///
/// 算法：ECDSA（secp256r1 / P-256）+ SHA-256，非对称。
/// 私钥只在发卡人电脑上，App 内仅内置公钥用于验签——
/// 即使 APK 被反编译也只能拿到公钥，无法伪造卡密。
class VipCrypto {
  /// 设备码加盐：避免直接暴露原始 Android ID
  static const String _deviceSalt = 'shuoji_vip_2026_salt';

  /// 卡密当前版本号（便于将来升级格式）
  static const int version = 1;

  /// "永久有效"卡密的到期时间戳（2100-01-01 UTC）。
  static const int permanentExpiry = 4102444800;

  /// 判断到期时间戳是否代表"永久有效"。
  static bool isPermanent(int expUnix) => expUnix >= permanentExpiry - 86400;

  static ECDomainParameters get _domain => ECDomainParameters('secp256r1');

  // ---------- 密钥 ----------

  /// 生成一对 ECDSA P-256 密钥。
  /// 私钥串 = 私钥分量 d 的十六进制；公钥串 = 公钥点未压缩编码的十六进制。
  static ({String priv, String pub}) generateKeyPairHex() {
    final keyGen = ECKeyGenerator()
      ..init(ParametersWithRandom(
          ECKeyGeneratorParameters(_domain), _secureRandom()));
    final pair = keyGen.generateKeyPair();
    final priv = pair.privateKey as ECPrivateKey;
    final pub = pair.publicKey as ECPublicKey;
    return (
      priv: priv.d!.toRadixString(16),
      pub: _hex(pub.Q!.getEncoded(false)),
    );
  }

  // ---------- 设备码 ----------

  /// 由安卓 Android ID 计算对外展示的"设备码"（16 位十六进制）。
  /// 买家把设备码发给发卡人，发卡人据此生成绑定该设备的卡密。
  static String deviceFingerprint(String androidId) {
    final bytes = utf8.encode(androidId + _deviceSalt);
    return crypto.sha256.convert(bytes).toString().substring(0, 16);
  }

  // ---------- 发卡（私钥签名） ----------

  /// 生成一张绑定 [deviceCode]、有效期到 [expUnix] 秒的卡密。
  static String signCardKey({
    required String privHex,
    required int expUnix,
    required String deviceCode,
  }) {
    final payload = jsonEncode({
      'v': version,
      'exp': expUnix,
      'dev': deviceCode,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    final message = utf8.encode(payload);

    final priv = ECPrivateKey(BigInt.parse(privHex, radix: 16), _domain);
    final signer = ECDSASigner(SHA256Digest())
      ..init(true,
          ParametersWithRandom(PrivateKeyParameter(priv), _secureRandom()));
    final sig = signer.generateSignature(Uint8List.fromList(message))
        as ECSignature;

    final p = base64Url.encode(message);
    final s = base64Url.encode(_sigToBytes(sig));
    return '$p.$s';
  }

  // ---------- 验签（公钥验证，App 端） ----------

  /// 验证卡密。返回是否有效及到期时间；任何一步失败都视为无效。
  static CardKeyCheck verifyCardKey({
    required String cardKey,
    required String pubHex,
    required String deviceCode,
    required int nowUnix,
  }) {
    try {
      final parts = cardKey.trim().split('.');
      if (parts.length != 2) return CardKeyCheck.invalid('格式错误');

      final message = base64Url.decode(parts[0]);
      final sig = _sigFromBytes(base64Url.decode(parts[1]));

      final pubPoint = _domain.curve.decodePoint(_fromHex(pubHex));
      final pub = ECPublicKey(pubPoint, _domain);
      final verifier = ECDSASigner(SHA256Digest())
        ..init(false, PublicKeyParameter(pub));
      final ok = verifier.verifySignature(Uint8List.fromList(message), sig);
      if (!ok) return CardKeyCheck.invalid('签名无效');

      final payload = jsonDecode(utf8.decode(message)) as Map<String, dynamic>;
      final exp = (payload['exp'] as num?)?.toInt() ?? 0;
      final dev = payload['dev'] as String? ?? '';

      if (dev.isNotEmpty && dev != deviceCode) {
        return CardKeyCheck.invalid('设备不匹配');
      }
      if (nowUnix >= exp) return CardKeyCheck.invalid('已过期');

      return CardKeyCheck(valid: true, expUnix: exp);
    } catch (_) {
      return CardKeyCheck.invalid('解析失败');
    }
  }

  // ---------- 工具 ----------

  static SecureRandom _secureRandom() {
    final random = FortunaRandom();
    final seed =
        Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));
    random.seed(KeyParameter(seed));
    return random;
  }

  /// r、s 各按 32 字节定长大端编码，拼成 64 字节签名。
  static List<int> _sigToBytes(ECSignature sig) =>
      [..._bigIntTo32(sig.r), ..._bigIntTo32(sig.s)];

  static ECSignature _sigFromBytes(List<int> bytes) => ECSignature(
        _bytesToBigInt(bytes.sublist(0, 32)),
        _bytesToBigInt(bytes.sublist(32, 64)),
      );

  static List<int> _bigIntTo32(BigInt v) {
    var hex = v.toRadixString(16);
    if (hex.length > 64) hex = hex.substring(hex.length - 64);
    hex = hex.padLeft(64, '0');
    return _fromHex(hex);
  }

  static BigInt _bytesToBigInt(List<int> bytes) =>
      BigInt.parse(_hex(bytes), radix: 16);

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _fromHex(String hex) {
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }
}

/// 卡密验证结果
class CardKeyCheck {
  final bool valid;
  final int expUnix;
  final String? error;
  const CardKeyCheck({required this.valid, this.expUnix = 0, this.error});
  factory CardKeyCheck.invalid(String error) =>
      CardKeyCheck(valid: false, error: error);
}

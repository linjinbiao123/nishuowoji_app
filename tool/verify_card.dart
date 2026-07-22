import 'package:nishuowoji_app/services/vip_crypto.dart';

/// 校验外部工具生成的卡密是否能被 App 认可。
/// 用法: dart run tool/verify_card.dart <卡密> <设备码>
void main(List<String> args) {
  const pub =
      '048381a5a5fdb93f46b76eb2fcf08be237c0048d0b34667f5275fbf5310748f3d6f63ca9f5902dd946b24623e8c0406b1a276a53f0e33a0c886ac06bb2ca9bcff3';
  final card = args[0];
  final device = args[1];
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final r = VipCrypto.verifyCardKey(
      cardKey: card, pubHex: pub, deviceCode: device, nowUnix: now);
  print('valid=${r.valid} exp=${r.expUnix} err=${r.error}');
}

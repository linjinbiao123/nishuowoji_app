import 'package:flutter/material.dart';
import '../theme/app_bg.dart';

/// 隐私政策 / 用户服务协议 查看页面
class AgreementPage extends StatelessWidget {
  final bool isPrivacy; // true=隐私政策, false=用户服务协议
  const AgreementPage({super.key, required this.isPrivacy});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDark.surface,
      appBar: AppBar(
        backgroundColor: AppDark.surface,
        elevation: 0,
        title: Text(
          isPrivacy ? '隐私政策' : '用户服务协议',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          isPrivacy ? _privacyPolicy : _userAgreement,
          style: TextStyle(color: AppDark.sub, fontSize: 14, height: 1.8),
        ),
      ),
    );
  }

  static const String _privacyPolicy = '''
更新日期：2026年7月23日

说记（以下简称"本应用"）尊重并保护您的隐私。本政策说明本应用如何处理您的信息。

一、数据存储

本应用的所有记账数据（收支记录、分类、预算、账本等）均存储在您的设备本地，不会上传至任何服务器。卸载应用将永久删除所有数据。

二、网络使用

本应用仅在以下两种情况下使用网络，且均由您主动触发：
1. 下载离线语音识别模型（首次使用语音记账功能时，约82MB）；
2. 检查应用更新（您在设置中手动点击"检查更新"时）。
除此之外，本应用不会在后台联网，不发送任何数据。

三、权限说明

本应用可能请求以下设备权限：
· 麦克风：用于语音记账，录音仅在本地处理，不会上传；
· 通知：用于每日记账提醒，由您自行开启；
· 网络：仅用于上述模型下载和更新检查。

四、设备标识

激活权限功能时，本应用会读取设备标识（Android ID 的哈希值）用于卡密绑定验证。该标识仅存储在本地，不会传输至任何第三方。

五、第三方服务

本应用不集成任何第三方统计、广告、分析SDK，不收集、不共享、不出售任何用户数据。

六、未成年人保护

本应用不主动收集任何用户的个人信息。如您为未成年人，请在监护人指导下使用。

七、政策更新

如本政策有变更，将在应用内更新公示。继续使用即视为同意变更后的政策。

八、联系我们

如对本政策有疑问，请通过应用内反馈渠道联系我们。
''';

  static const String _userAgreement = '''
更新日期：2026年7月23日

欢迎使用说记（以下简称"本应用"）。使用本应用即表示您同意本协议。

一、服务说明

本应用是一款纯本地个人记账工具，提供收支记录、分类管理、预算设置、数据统计、语音记账等功能。所有数据存储在您的设备本地。

二、用户行为规范

您应合法使用本应用，不得利用本应用从事任何违反法律法规的活动。

三、权限功能

本应用提供可选的权限激活功能（多账本、数据导出、分类预算等），通过卡密方式激活。卡密由开发者发放，绑定设备或通用使用，具体规则以发放时说明为准。

四、数据安全

由于数据完全存储在本地，请您自行注意数据备份。因设备丢失、系统故障、卸载应用等原因导致的数据丢失，本应用不承担责任。建议定期使用导出功能备份。

五、免责声明

本应用按"现状"提供，不保证在所有设备和系统版本上完全兼容。对于因使用或无法使用本应用而产生的任何直接或间接损失，开发者不承担赔偿责任。

六、知识产权

本应用的界面设计、代码、图标等知识产权归开发者所有，未经许可不得复制、修改或分发。

七、协议变更

开发者有权根据需要修改本协议，修改后将在应用内公示。继续使用即视为接受变更。

八、其他

本协议的解释、效力及争议解决均适用中华人民共和国法律。
''';
}

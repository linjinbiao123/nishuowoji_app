import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 检查更新结果
class UpdateInfo {
  final bool hasUpdate;
  final String version;
  final String url;
  final String note;
  const UpdateInfo({
    required this.hasUpdate,
    required this.version,
    required this.url,
    required this.note,
  });
}

class UpdateService {
  /// 远程版本信息文件（GitHub raw 地址）
  static const _versionUrl =
      'https://cdn.jsdelivr.net/gh/linjinbiao123/nishuowoji_app@main/version.json';

  /// 检查是否有新版本
  /// 返回 null 表示请求失败（网络异常等）
  static Future<UpdateInfo?> check() async {
    try {
      final resp = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final remoteBuild = json['build'] as int? ?? 0;
      final remoteVersion = json['version'] as String? ?? '';
      final url = json['url'] as String? ?? '';
      final note = json['note'] as String? ?? '';

      final info = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(info.buildNumber) ?? 0;

      return UpdateInfo(
        hasUpdate: remoteBuild > localBuild,
        version: remoteVersion,
        url: url,
        note: note,
      );
    } catch (_) {
      return null;
    }
  }

  /// 用浏览器打开下载链接
  static Future<void> openDownload(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

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
  final String code;
  const UpdateInfo({
    required this.hasUpdate,
    required this.version,
    required this.url,
    required this.note,
    this.code = '',
  });
}

class UpdateService {
  static const _apiUrl =
      'https://api.github.com/repos/linjinbiao123/nishuowoji_app/contents/version.json';
  static const _cdnUrl =
      'https://cdn.jsdelivr.net/gh/linjinbiao123/nishuowoji_app@main/version.json';

  /// 检查是否有新版本
  static Future<UpdateInfo?> check() async {
    // 先试 GitHub API（无缓存），失败再试 jsdelivr
    final json = await _fetchFromApi() ?? await _fetchFromCdn();
    if (json == null) return null;

    try {
      final remoteBuild = json['build'] as int? ?? 0;
      final remoteVersion = json['version'] as String? ?? '';
      final url = json['url'] as String? ?? '';
      final note = json['note'] as String? ?? '';
      final code = json['code'] as String? ?? '';

      final info = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(info.buildNumber) ?? 0;

      return UpdateInfo(
        hasUpdate: remoteBuild > localBuild,
        version: remoteVersion,
        url: url,
        note: note,
        code: code,
      );
    } catch (_) {
      return null;
    }
  }

  /// GitHub API（实时，无缓存）
  static Future<Map<String, dynamic>?> _fetchFromApi() async {
    try {
      final resp = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/vnd.github.v3+json'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final apiJson = jsonDecode(resp.body) as Map<String, dynamic>;
      final b64 = (apiJson['content'] as String).replaceAll('\n', '');
      final content = base64Decode(b64);
      return jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// jsdelivr CDN 备用
  static Future<Map<String, dynamic>?> _fetchFromCdn() async {
    try {
      final uri = Uri.parse('$_cdnUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final resp = await http
          .get(uri, headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      return jsonDecode(resp.body) as Map<String, dynamic>;
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

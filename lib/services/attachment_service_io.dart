import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 记账附件（图片 / 发票）本地存储服务 - IO 平台实现。
///
/// 附件以文件形式保存在 app 私有目录下的 [attachments] 文件夹，
/// [Record] 只保存文件名（而非绝对路径），换设备 / 重装不会失效。
class AttachmentService {
  static const String _dirName = 'attachments';

  static Future<Directory> _directory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _dirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 返回附件目录路径（确保目录已创建）
  static Future<String> dirPath() async => (await _directory()).path;

  /// 复制源图片到附件目录，返回保存后的文件名（唯一命名，避免冲突）
  static Future<String> saveImage(String sourcePath) async {
    final dir = await _directory();
    final ext = p.extension(sourcePath).toLowerCase();
    final suffix = Random().nextInt(999999).toString().padLeft(6, '0');
    final name = '${DateTime.now().microsecondsSinceEpoch}_$suffix$ext';
    final dest = File(p.join(dir.path, name));
    await File(sourcePath).copy(dest.path);
    return name;
  }

  /// 根据文件名构造完整文件路径
  static Future<String> pathOf(String name) async =>
      p.join(await dirPath(), name);

  /// 删除一批附件文件名（忽略不存在 / 单个删除失败的异常）
  static Future<void> deleteImages(List<String> names) async {
    if (names.isEmpty) return;
    final base = await dirPath();
    for (final n in names) {
      try {
        final f = File(p.join(base, n));
        if (await f.exists()) await f.delete();
      } catch (_) {
        // 单个删除失败不影响其余，忽略
      }
    }
  }
}

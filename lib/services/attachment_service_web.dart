/// 记账附件（图片 / 发票）存储服务 - Web 平台实现。
///
/// Web 无法访问本地文件系统，因此直接将 [image_picker] 返回的 URL
///（blob: 或网络地址）作为附件标识存进记录，删除时无需清理。
class AttachmentService {
  static Future<String> dirPath() async => '';

  static Future<String> saveImage(String sourcePath) async => sourcePath;

  static Future<String> pathOf(String name) async => name;

  static Future<void> deleteImages(List<String> names) async {}
}

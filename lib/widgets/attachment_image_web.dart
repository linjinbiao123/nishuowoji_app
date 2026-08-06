import 'package:flutter/material.dart';

/// 跨平台附件图片显示 - Web 平台实现
class AttachmentImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const AttachmentImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() => placeholder ??
      Container(
        width: width,
        height: height,
        color: Colors.white12,
        child: const Icon(Icons.broken_image, color: Colors.white54, size: 24),
      );
}

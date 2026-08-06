import 'package:flutter/material.dart';
import 'attachment_image.dart';

/// 全屏图片查看器，支持多张左右滑动/拖动切换。
class ImageViewerDialog extends StatefulWidget {
  final List<String> names;
  final String attachDir;
  final int initialIndex;

  const ImageViewerDialog({
    super.key,
    required this.names,
    this.attachDir = '',
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late int _current;
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  String _path(String name) =>
      widget.attachDir.isNotEmpty ? '${widget.attachDir}/$name' : name;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.names.length,
              onPageChanged: (idx) => setState(() => _current = idx),
              itemBuilder: (ctx, idx) => AttachmentImage(
                path: _path(widget.names[idx]),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (widget.names.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _current > 0
                          ? () => _pageCtrl.animateToPage(
                                _current - 1,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                              )
                          : null,
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: _current > 0 ? Colors.white : Colors.white38,
                      ),
                    ),
                    Text(
                      '${_current + 1}/${widget.names.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    IconButton(
                      onPressed: _current < widget.names.length - 1
                          ? () => _pageCtrl.animateToPage(
                                _current + 1,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                              )
                          : null,
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: _current < widget.names.length - 1
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:strongbody_buyer/core/themes/app_text_style.dart';

/// Xem ảnh toàn màn hình, vuốt qua lại + phóng to (web `MediaLightbox`).
Future<void> showMarketImageViewer(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black,
    builder: (context) => _ImageViewer(images: images, initial: initialIndex),
  );
}

class _ImageViewer extends StatefulWidget {
  final List<String> images;
  final int initial;

  const _ImageViewer({required this.images, required this.initial});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                child: Center(
                  child: Image.network(
                    widget.images[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48.r,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8.h,
              right: 8.w,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 16.h,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${_index + 1} / ${widget.images.length}',
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

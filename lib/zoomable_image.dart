import 'dart:io' show File;

import 'package:flutter/material.dart';

// A picture that can be zoomed: mouse wheel / pinch / the + and − buttons,
// drag to move. It is drawn from the full-size file, so it stays sharp.
class ZoomableImage extends StatefulWidget {
  const ZoomableImage({super.key, required this.path});

  final String path;

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  final controller = TransformationController();
  static const maxZoom = 12.0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // zoom about the middle of the viewer, never below the whole picture
  void zoomTo(double scale, Size size) {
    final s = scale.clamp(1.0, maxZoom);
    final cx = size.width / 2;
    final cy = size.height / 2;

    controller.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, cx - s * cx)
      ..setEntry(1, 3, cy - s * cy);
  }

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback onTap) => Tooltip(
      message: tip,
      child: Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 21)),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 470,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, bc) {
            final size = Size(bc.maxWidth, bc.maxHeight);

            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFF101828),
                    child: InteractiveViewer(
                      transformationController: controller,
                      minScale: 1,
                      maxScale: maxZoom,
                      child: Center(
                        child: Image.file(
                          File(widget.path),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      button(
                        Icons.add,
                        'ซูมเข้า',
                        () => zoomTo(
                          controller.value.getMaxScaleOnAxis() * 1.6,
                          size,
                        ),
                      ),
                      const SizedBox(height: 8),
                      button(
                        Icons.remove,
                        'ซูมออก',
                        () => zoomTo(
                          controller.value.getMaxScaleOnAxis() / 1.6,
                          size,
                        ),
                      ),
                      const SizedBox(height: 8),
                      button(
                        Icons.fit_screen_rounded,
                        'ขนาดเต็มรูป',
                        () => zoomTo(1, size),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  left: 12,
                  bottom: 10,
                  child: Text(
                    'เลื่อนล้อเมาส์เพื่อซูม • ลากเพื่อเลื่อนรูป',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

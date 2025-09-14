import 'package:flutter/material.dart';
import 'package:cac_project_flutter/services/perception_hub.dart';

class YoloOverlayPainter extends CustomPainter {
  YoloOverlayPainter({
    required this.detections,
    required this.previewSize,   // IMAGE size from camera (w,h)
    required this.viewportSize,  // widget size on screen (w,h)
    this.mirror = false,         // front camera
    this.showLabels = true,
  });

  final List<Detection> detections;
  final Size previewSize;
  final Size viewportSize;
  final bool mirror;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    if (previewSize.width <= 0 || previewSize.height <= 0) return;

    final previewAspect = previewSize.width / previewSize.height;
    final viewAspect = viewportSize.width / viewportSize.height;

    double scaleX, scaleY, dx = 0, dy = 0;
    if (previewAspect > viewAspect) {
      // Wider than view -> scale by height, crop sides.
      scaleY = viewportSize.height / previewSize.height;
      scaleX = scaleY;
      final scaledW = previewSize.width * scaleX;
      dx = (viewportSize.width - scaledW) / 2;
    } else {
      // Taller than view -> scale by width, crop top/bottom.
      scaleX = viewportSize.width / previewSize.width;
      scaleY = scaleX;
      final scaledH = previewSize.height * scaleY;
      dy = (viewportSize.height - scaledH) / 2;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white;

    final labelBg = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withOpacity(0.35);

    for (final d in detections) {
      Rect r = Rect.fromLTWH(
        d.bbox.left * scaleX + dx,
        d.bbox.top * scaleY + dy,
        d.bbox.width * scaleX,
        d.bbox.height * scaleY,
      );

      if (mirror) {
        r = Rect.fromLTWH(
          viewportSize.width - (r.left + r.width),
          r.top,
          r.width,
          r.height,
        );
      }

      canvas.drawRect(r, stroke);

      if (showLabels) {
        final span = TextSpan(
          text: '${d.label} ${(d.score * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        );
        final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout(maxWidth: viewportSize.width);
        final padX = 6.0, padY = 4.0;
final num topYNum = (r.top - tp.height - padY * 2)
    .clamp(0.0, viewportSize.height - tp.height - padY * 2);
final double topY = topYNum.toDouble();

final bg = Rect.fromLTWH(
  r.left,
  topY,
  tp.width + padX * 2,
  tp.height + padY * 2,
);
        canvas.drawRect(bg, labelBg);
        tp.paint(canvas, Offset(bg.left + padX, bg.top + padY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant YoloOverlayPainter old) {
    return old.detections != detections ||
           old.previewSize != previewSize ||
           old.viewportSize != viewportSize ||
           old.mirror != mirror ||
           old.showLabels != showLabels;
  }
}

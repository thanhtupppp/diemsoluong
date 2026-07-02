import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/detection.dart';

class OverlayPainter extends CustomPainter {
  final List<Detection> detections;
  final Size originalImageSize;
  final List<String> labels;

  OverlayPainter({
    required this.detections,
    required this.originalImageSize,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (originalImageSize.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 1. Tính toán tỉ lệ scale và dịch chuyển offset để vẽ khít màn hình (contain fit)
    final fittedSizes = applyBoxFit(
      BoxFit.contain,
      originalImageSize,
      size,
    );

    final destinationSize = fittedSizes.destination;
    final dx = (size.width - destinationSize.width) / 2;
    final dy = (size.height - destinationSize.height) / 2;

    final scaleX = destinationSize.width / originalImageSize.width;
    final scaleY = destinationSize.height / originalImageSize.height;

    // 2. Thực hiện vẽ các lớp thành phần trong cảnh (Overlay Scene)
    _drawCountingLines(canvas, size, dx, dy, scaleX, scaleY);
    _drawTracks(canvas, size, dx, dy, scaleX, scaleY);
    _drawDetections(canvas, size, dx, dy, scaleX, scaleY);

    canvas.restore();
  }

  /// Vẽ danh sách hộp giới hạn (Bounding Boxes) và điểm tin cậy
  void _drawDetections(
    Canvas canvas,
    Size size,
    double dx,
    double dy,
    double scaleX,
    double scaleY,
  ) {
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.65);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    for (final detection in detections) {
      final rect = detection.rect;

      final left = rect.left * scaleX + dx;
      final top = rect.top * scaleY + dy;
      final width = rect.width * scaleX;
      final height = rect.height * scaleY;

      final mappedRect = Rect.fromLTWH(left, top, width, height);

      final color =
          Colors.primaries[detection.classId % Colors.primaries.length];
      boxPaint.color = color;

      canvas.drawRect(mappedRect, boxPaint);

      final labelName = detection.classId < labels.length
          ? labels[detection.classId]
          : 'Class ${detection.classId}';
      final labelText =
          '$labelName ${(detection.score * 100).toStringAsFixed(0)}%';

      textPainter.text = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      const horizontalPadding = 6.0;
      const verticalPadding = 4.0;

      final labelWidth = textPainter.width + horizontalPadding * 2;
      final labelHeight = textPainter.height + verticalPadding * 2;

      final labelLeft = mappedRect.left.clamp(0.0, size.width - labelWidth);
      final rawTop =
          mappedRect.top - labelHeight >= 0 ? mappedRect.top - labelHeight : mappedRect.top;
      final labelTop = rawTop.clamp(0.0, size.height - labelHeight);

      final labelRect = Rect.fromLTWH(
        labelLeft,
        labelTop,
        labelWidth,
        labelHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        bgPaint..color = color.withValues(alpha: 0.85),
      );

      textPainter.paint(
        canvas,
        Offset(
          labelLeft + horizontalPadding,
          labelTop + verticalPadding,
        ),
      );
    }
  }

  /// Placeholder vẽ các đường tracking bám vết đối tượng vật lý (Phát triển sau ở Giai đoạn 4)
  void _drawTracks(
    Canvas canvas,
    Size size,
    double dx,
    double dy,
    double scaleX,
    double scaleY,
  ) {
    // Sẽ vẽ đường theo vết chuyển động của từng đối tượng bám đuôi
  }

  /// Placeholder vẽ vạch giới hạn đếm hoặc vùng đếm đối tượng (Phát triển sau ở Giai đoạn 4)
  void _drawCountingLines(
    Canvas canvas,
    Size size,
    double dx,
    double dy,
    double scaleX,
    double scaleY,
  ) {
    // Sẽ vẽ vạch cắt ngang màn hình hoặc khu vực kích hoạt đếm
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return !listEquals(oldDelegate.detections, detections) ||
        oldDelegate.originalImageSize != originalImageSize ||
        !listEquals(oldDelegate.labels, labels);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../counting/domain/entities/counting_line.dart';
import '../../../tracking/domain/entities/track.dart';

class OverlayPainter extends CustomPainter {
  final List<Track> tracks;
  final Size originalImageSize;
  final List<String> labels;
  final CountingLine? countingLine;
  final Map<int, int> classCounts;

  OverlayPainter({
    required this.tracks,
    required this.originalImageSize,
    required this.labels,
    this.countingLine,
    this.classCounts = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (originalImageSize.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 1. Tính toán tỉ lệ scale và dịch chuyển offset để vẽ khít màn hình (contain fit)
    final fittedSizes = applyBoxFit(BoxFit.contain, originalImageSize, size);

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

  /// Vẽ danh sách hộp giới hạn (Bounding Boxes) và điểm tin cậy kèm Track ID
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

    final bgPaint = Paint()..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    for (final track in tracks) {
      final rect = track.rect;

      final left = rect.left * scaleX + dx;
      final top = rect.top * scaleY + dy;
      final width = rect.width * scaleX;
      final height = rect.height * scaleY;

      final mappedRect = Rect.fromLTWH(left, top, width, height);

      final color = Colors.primaries[track.classId % Colors.primaries.length];
      boxPaint.color = color;

      canvas.drawRect(mappedRect, boxPaint);

      final labelName = track.classId < labels.length
          ? labels[track.classId]
          : 'Class ${track.classId}';
      final labelText =
          '[ID: ${track.id}] $labelName ${(track.score * 100).toStringAsFixed(0)}%';

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
      final rawTop = mappedRect.top - labelHeight >= 0
          ? mappedRect.top - labelHeight
          : mappedRect.top;
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
        Offset(labelLeft + horizontalPadding, labelTop + verticalPadding),
      );
    }
  }

  /// Vẽ đường lịch sử di chuyển tâm của các đối tượng bám vết
  void _drawTracks(
    Canvas canvas,
    Size size,
    double dx,
    double dy,
    double scaleX,
    double scaleY,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final track in tracks) {
      if (track.path.length < 2) continue;

      final color = Colors.primaries[track.classId % Colors.primaries.length];
      paint.color = color.withValues(alpha: 0.50);

      final path = Path();
      final firstPoint = track.path.first;
      path.moveTo(firstPoint.dx * scaleX + dx, firstPoint.dy * scaleY + dy);

      for (int i = 1; i < track.path.length; i++) {
        final point = track.path[i];
        path.lineTo(point.dx * scaleX + dx, point.dy * scaleY + dy);
      }

      canvas.drawPath(path, paint);

      // Vẽ vòng tròn nhỏ màu sắc tại tâm hiện tại
      final lastPoint = track.path.last;
      canvas.drawCircle(
        Offset(lastPoint.dx * scaleX + dx, lastPoint.dy * scaleY + dy),
        4.0,
        Paint()..color = color,
      );
    }
  }

  /// Vẽ vạch đếm hoặc vùng đếm đối tượng cắt ngang
  void _drawCountingLines(
    Canvas canvas,
    Size size,
    double dx,
    double dy,
    double scaleX,
    double scaleY,
  ) {
    final line = countingLine;
    if (line == null) return;

    final paint = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 4.0;

    final pointA = line.pointAInImage(originalImageSize);
    final pointB = line.pointBInImage(originalImageSize);
    final startX = pointA.dx * scaleX + dx;
    final startY = pointA.dy * scaleY + dy;
    final endX = pointB.dx * scaleX + dx;
    final endY = pointB.dy * scaleY + dy;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: ' ${line.name} ',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.teal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(startX + 10, startY - 18));
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return !listEquals(oldDelegate.tracks, tracks) ||
        oldDelegate.originalImageSize != originalImageSize ||
        !listEquals(oldDelegate.labels, labels) ||
        oldDelegate.countingLine != countingLine ||
        !mapEquals(oldDelegate.classCounts, classCounts);
  }
}

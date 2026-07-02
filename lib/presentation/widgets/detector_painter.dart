import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/detection.dart';
import '../../data/models/model_config.dart';

class DetectorPainter extends CustomPainter {
  final List<Detection> detections;
  final Size originalImageSize;
  final List<String> labels;

  DetectorPainter({
    required this.detections,
    required this.originalImageSize,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (originalImageSize.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

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

      final left =
          (rect.left / ModelConfig.inputSize) * originalImageSize.width * scaleX + dx;
      final top =
          (rect.top / ModelConfig.inputSize) * originalImageSize.height * scaleY + dy;
      final width =
          (rect.width / ModelConfig.inputSize) * originalImageSize.width * scaleX;
      final height =
          (rect.height / ModelConfig.inputSize) * originalImageSize.height * scaleY;

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

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DetectorPainter oldDelegate) {
    return !listEquals(oldDelegate.detections, detections) ||
        oldDelegate.originalImageSize != originalImageSize ||
        !listEquals(oldDelegate.labels, labels);
  }
}

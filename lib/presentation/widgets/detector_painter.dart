import 'package:flutter/material.dart';
import '../../data/models/detection.dart';

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
    // 1. Tính toán tỷ lệ scale và padding (Letterboxing)
    final double scaleX = size.width / originalImageSize.width;
    final double scaleY = size.height / originalImageSize.height;
    
    // Sử dụng BoxFit.contain để hiển thị ảnh, tính toán toạ độ thực tế vẽ lên canvas
    final double scale = scaleX < scaleY ? scaleX : scaleY;
    final double dx = (size.width - originalImageSize.width * scale) / 2;
    final double dy = (size.height - originalImageSize.height * scale) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final detection in detections) {
      // Map toạ độ từ [0 - 640] của YOLOv8 sang kích thước ảnh scale thực tế
      final rect = detection.rect;
      final double left = (rect.left / 640.0) * originalImageSize.width * scale + dx;
      final double top = (rect.top / 640.0) * originalImageSize.height * scale + dy;
      final double width = (rect.width / 640.0) * originalImageSize.width * scale;
      final double height = (rect.height / 640.0) * originalImageSize.height * scale;

      final mappedRect = Rect.fromLTWH(left, top, width, height);

      // Chọn màu vẽ ngẫu nhiên dựa trên classId
      paint.color = Colors.primaries[detection.classId % Colors.primaries.length];
      canvas.drawRect(mappedRect, paint);

      // Vẽ text Label + Score
      final String labelName = detection.classId < labels.length 
          ? labels[detection.classId] 
          : 'Class ${detection.classId}';
      final String labelText = '$labelName (${(detection.score * 100).toStringAsFixed(0)}%)';
      
      textPainter.text = TextSpan(
        text: labelText,
        style: TextStyle(
          color: paint.color,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black.withOpacity(0.6),
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(mappedRect.left, mappedRect.top - 15));
    }
  }

  @override
  bool shouldRepaint(covariant DetectorPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.originalImageSize != originalImageSize;
  }
}

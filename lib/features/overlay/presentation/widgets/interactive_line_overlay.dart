import 'package:flutter/material.dart';

import '../../../counting/domain/entities/counting_line.dart';

class InteractiveLineOverlay extends StatelessWidget {
  final Size originalImageSize;
  final CountingLine countingLine;
  final Function(Offset pointA, Offset pointB) onLineChanged;

  const InteractiveLineOverlay({
    super.key,
    required this.originalImageSize,
    required this.countingLine,
    required this.onLineChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (originalImageSize.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // 1. Tính toán tỉ lệ scale và offset tương tự CustomPainter (BoxFit.contain)
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

        // Chuyển đổi tọa độ từ model space sang view space (màn hình)
        final viewPointA = Offset(
          countingLine.pointA.dx * scaleX + dx,
          countingLine.pointA.dy * scaleY + dy,
        );
        final viewPointB = Offset(
          countingLine.pointB.dx * scaleX + dx,
          countingLine.pointB.dy * scaleY + dy,
        );

        const handleRadius = 20.0;

        return Stack(
          children: [
            // Handle A
            Positioned(
              left: viewPointA.dx - handleRadius,
              top: viewPointA.dy - handleRadius,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  // Sử dụng delta kéo chuyển sang model space để cộng dồn tọa độ
                  final deltaModelX = details.delta.dx / scaleX;
                  final deltaModelY = details.delta.dy / scaleY;

                  final newModelX = (countingLine.pointA.dx + deltaModelX).clamp(0.0, originalImageSize.width);
                  final newModelY = (countingLine.pointA.dy + deltaModelY).clamp(0.0, originalImageSize.height);

                  onLineChanged(Offset(newModelX, newModelY), countingLine.pointB);
                },
                child: Container(
                  width: handleRadius * 2,
                  height: handleRadius * 2,
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Handle B
            Positioned(
              left: viewPointB.dx - handleRadius,
              top: viewPointB.dy - handleRadius,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  final deltaModelX = details.delta.dx / scaleX;
                  final deltaModelY = details.delta.dy / scaleY;

                  final newModelX = (countingLine.pointB.dx + deltaModelX).clamp(0.0, originalImageSize.width);
                  final newModelY = (countingLine.pointB.dy + deltaModelY).clamp(0.0, originalImageSize.height);

                  onLineChanged(countingLine.pointA, Offset(newModelX, newModelY));
                },
                child: Container(
                  width: handleRadius * 2,
                  height: handleRadius * 2,
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'B',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

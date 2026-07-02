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

        // Chuyển đổi tọa độ normalized sang view space (màn hình)
        final viewPointA = Offset(
          countingLine.pointA.dx * destinationSize.width + dx,
          countingLine.pointA.dy * destinationSize.height + dy,
        );
        final viewPointB = Offset(
          countingLine.pointB.dx * destinationSize.width + dx,
          countingLine.pointB.dy * destinationSize.height + dy,
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
                  // Sử dụng delta kéo chuyển sang normalized space để cộng dồn tọa độ
                  final deltaNormalizedX =
                      details.delta.dx / destinationSize.width;
                  final deltaNormalizedY =
                      details.delta.dy / destinationSize.height;

                  final newModelX = (countingLine.pointA.dx + deltaNormalizedX)
                      .clamp(0.0, 1.0);
                  final newModelY = (countingLine.pointA.dy + deltaNormalizedY)
                      .clamp(0.0, 1.0);

                  onLineChanged(
                    Offset(newModelX, newModelY),
                    countingLine.pointB,
                  );
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
                  final deltaNormalizedX =
                      details.delta.dx / destinationSize.width;
                  final deltaNormalizedY =
                      details.delta.dy / destinationSize.height;

                  final newModelX = (countingLine.pointB.dx + deltaNormalizedX)
                      .clamp(0.0, 1.0);
                  final newModelY = (countingLine.pointB.dy + deltaNormalizedY)
                      .clamp(0.0, 1.0);

                  onLineChanged(
                    countingLine.pointA,
                    Offset(newModelX, newModelY),
                  );
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

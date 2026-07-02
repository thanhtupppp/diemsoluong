import 'dart:typed_data';
import 'dart:ui';
import '../../data/models/detection.dart';

List<Detection> decodeDetections(
  Float32List output, 
  int numBoxes, 
  int numClasses, 
  double confThreshold,
) {
  final List<Detection> results = [];
  
  for (int i = 0; i < numBoxes; i++) {
    double maxScore = 0.0;
    int maxClassId = -1;
    
    // Tìm class có confidence cao nhất
    for (int c = 0; c < numClasses; c++) {
      final score = output[(4 + c) * numBoxes + i];
      if (score > maxScore) {
        maxScore = score;
        maxClassId = c;
      }
    }
    
    // Lọc theo ngưỡng confidence
    if (maxScore >= confThreshold) {
      final xCenter = output[i] * 640.0;
      final yCenter = output[numBoxes + i] * 640.0;
      final w = output[2 * numBoxes + i] * 640.0;
      final h = output[3 * numBoxes + i] * 640.0;
      
      results.add(Detection(
        rect: Rect.fromLTWH(xCenter - w / 2, yCenter - h / 2, w, h),
        classId: maxClassId,
        score: maxScore,
      ));
    }
  }
  return results;
}

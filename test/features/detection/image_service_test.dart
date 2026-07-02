import 'package:diemsoluong/features/detection/data/services/image_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageService', () {
    test('yuvToRgb converts neutral luma/chroma values to grayscale', () {
      final rgb = ImageService.yuvToRgb(128, 128, 128);

      expect(rgb[0], closeTo(130, 2));
      expect(rgb[1], closeTo(130, 2));
      expect(rgb[2], closeTo(130, 2));
    });

    test('yuvToRgb clamps channel values to byte range', () {
      final bright = ImageService.yuvToRgb(255, 255, 255);
      final dark = ImageService.yuvToRgb(0, 0, 0);

      expect(bright.every((channel) => channel >= 0 && channel <= 255), isTrue);
      expect(dark.every((channel) => channel >= 0 && channel <= 255), isTrue);
    });
  });
}

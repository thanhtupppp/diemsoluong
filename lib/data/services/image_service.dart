import 'dart:typed_data';
import 'package:image/image.dart' as img;

class PreprocessResult {
  final Float32List input;
  final int originalWidth;
  final int originalHeight;
  final double scale;
  final double padX;
  final double padY;

  const PreprocessResult({
    required this.input,
    required this.originalWidth,
    required this.originalHeight,
    required this.scale,
    required this.padX,
    required this.padY,
  });
}

class ImageService {
  // Chuyển đổi file ảnh tĩnh (hoặc bytes ảnh) thành PreprocessResult với letterbox padding
  static PreprocessResult? preprocessImage(Uint8List imageBytes, int targetSize) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    final originalWidth = image.width;
    final originalHeight = image.height;

    // Tính tỷ lệ scale giữ nguyên aspect ratio
    final scale = originalWidth > originalHeight
        ? targetSize / originalWidth
        : targetSize / originalHeight;

    final resizedWidth = (originalWidth * scale).round();
    final resizedHeight = (originalHeight * scale).round();

    final resized = img.copyResize(
      image,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );

    // Tạo canvas vuông điền màu xám (114, 114, 114) làm đệm
    final canvas = img.Image(
      width: targetSize,
      height: targetSize,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));

    final padX = ((targetSize - resizedWidth) / 2).floor();
    final padY = ((targetSize - resizedHeight) / 2).floor();

    img.compositeImage(canvas, resized, dstX: padX, dstY: padY);

    final floatBuffer = Float32List(targetSize * targetSize * 3);
    int index = 0;

    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final pixel = canvas.getPixel(x, y);
        floatBuffer[index++] = pixel.r / 255.0;
        floatBuffer[index++] = pixel.g / 255.0;
        floatBuffer[index++] = pixel.b / 255.0;
      }
    }

    return PreprocessResult(
      input: floatBuffer,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      scale: scale,
      padX: padX.toDouble(),
      padY: padY.toDouble(),
    );
  }

  // Chuyển đổi định dạng camera frame sang RGB Uint8List
  static Uint8List convertCameraImage(List<Uint8List> planes, int width, int height) {
    final outImg = img.Image(width: width, height: height);
    return Uint8List.fromList(img.encodeJpg(outImg));
  }
}

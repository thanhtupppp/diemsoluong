import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
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
  static PreprocessResult? preprocessImage(
    Uint8List imageBytes,
    int targetSize,
  ) {
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

    final dw = targetSize - resizedWidth;
    final dh = targetSize - resizedHeight;

    final padLeft = dw / 2.0;
    final padTop = dh / 2.0;

    final dstX = padLeft.floor();
    final dstY = padTop.floor();

    img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY);

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
      padX: dstX.toDouble(),
      padY: dstY.toDouble(),
    );
  }

  static Size? decodeImageSize(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  // Converts a live camera frame into JPEG bytes that can reuse the existing
  // image decoding and letterbox preprocessing pipeline.
  static Uint8List convertCameraImage(
    CameraImage cameraImage, {
    int rotationDegrees = 0,
    bool mirrorHorizontally = false,
    int jpegQuality = 85,
  }) {
    final rgbImage = convertCameraImageToRgbImage(cameraImage);
    var outputImage = _applyOrientation(
      rgbImage,
      rotationDegrees: rotationDegrees,
      mirrorHorizontally: mirrorHorizontally,
    );

    return Uint8List.fromList(img.encodeJpg(outputImage, quality: jpegQuality));
  }

  static img.Image convertCameraImageToRgbImage(CameraImage cameraImage) {
    switch (cameraImage.format.group) {
      case ImageFormatGroup.yuv420:
        return _convertYuv420ToRgb(cameraImage);
      case ImageFormatGroup.bgra8888:
        return _convertBgra8888ToRgb(cameraImage);
      case ImageFormatGroup.jpeg:
        return _decodeJpegCameraImage(cameraImage);
      case ImageFormatGroup.nv21:
        return _convertNv21ToRgb(cameraImage);
      default:
        throw UnsupportedError(
          'Unsupported camera image format: ${cameraImage.format.group}',
        );
    }
  }

  static img.Image _convertYuv420ToRgb(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final image = img.Image(width: width, height: height, numChannels: 3);

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      final yRowOffset = y * yRowStride;
      final uvRow = y >> 1;

      for (int x = 0; x < width; x++) {
        final uvCol = x >> 1;
        final yValue = yBytes[yRowOffset + x];
        final uValue = uBytes[uvRow * uRowStride + uvCol * uPixelStride];
        final vValue = vBytes[uvRow * vRowStride + uvCol * vPixelStride];

        final rgb = yuvToRgb(yValue, uValue, vValue);
        image.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }

    return image;
  }

  static img.Image _convertBgra8888ToRgb(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final image = img.Image(width: width, height: height, numChannels: 3);
    final plane = cameraImage.planes.first;
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final pixelStride = plane.bytesPerPixel ?? 4;

    for (int y = 0; y < height; y++) {
      final rowOffset = y * rowStride;
      for (int x = 0; x < width; x++) {
        final pixelOffset = rowOffset + x * pixelStride;
        final b = bytes[pixelOffset];
        final g = bytes[pixelOffset + 1];
        final r = bytes[pixelOffset + 2];
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  static img.Image _decodeJpegCameraImage(CameraImage cameraImage) {
    final decoded = img.decodeImage(cameraImage.planes.first.bytes);
    if (decoded == null) {
      throw const FormatException('Unable to decode JPEG camera frame.');
    }
    return decoded;
  }

  static img.Image _convertNv21ToRgb(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final image = img.Image(width: width, height: height, numChannels: 3);
    final bytes = cameraImage.planes.first.bytes;
    final frameSize = width * height;

    for (int y = 0; y < height; y++) {
      final yRowOffset = y * width;
      final uvRowOffset = frameSize + (y >> 1) * width;

      for (int x = 0; x < width; x++) {
        final uvOffset = uvRowOffset + (x & ~1);
        final yValue = bytes[yRowOffset + x];
        final vValue = bytes[uvOffset];
        final uValue = bytes[uvOffset + 1];

        final rgb = yuvToRgb(yValue, uValue, vValue);
        image.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }

    return image;
  }

  static List<int> yuvToRgb(int y, int u, int v) {
    final c = y - 16;
    final d = u - 128;
    final e = v - 128;

    final r = _clampRgb((298 * c + 409 * e + 128) >> 8);
    final g = _clampRgb((298 * c - 100 * d - 208 * e + 128) >> 8);
    final b = _clampRgb((298 * c + 516 * d + 128) >> 8);

    return [r, g, b];
  }

  static int _clampRgb(int value) => value.clamp(0, 255).toInt();

  static img.Image _applyOrientation(
    img.Image image, {
    required int rotationDegrees,
    required bool mirrorHorizontally,
  }) {
    var output = image;
    final normalizedRotation = rotationDegrees % 360;

    if (normalizedRotation != 0) {
      output = img.copyRotate(output, angle: normalizedRotation);
    }

    if (mirrorHorizontally) {
      output = img.flipHorizontal(output);
    }

    return output;
  }
}

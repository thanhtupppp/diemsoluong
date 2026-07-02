import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageService {
  // Chuyển đổi file ảnh tĩnh (hoặc bytes ảnh) thành Float32List chuẩn hóa [0, 1] dạng RGB phẳng
  static Float32List preprocessImage(Uint8List imageBytes, int targetSize) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return Float32List(0);

    // Resize về kích thước vuông targetSize (640x640)
    final resized = img.copyResize(image, width: targetSize, height: targetSize);
    
    final floatBuffer = Float32List(1 * targetSize * targetSize * 3);
    int index = 0;

    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final pixel = resized.getPixel(x, y);
        // Normalize pixel về khoảng [0.0, 1.0]
        floatBuffer[index++] = pixel.r / 255.0; // R
        floatBuffer[index++] = pixel.g / 255.0; // G
        floatBuffer[index++] = pixel.b / 255.0; // B
      }
    }
    return floatBuffer;
  }

  // Chuyển đổi định dạng camera frame sang RGB Uint8List
  static Uint8List convertCameraImage(List<Uint8List> planes, int width, int height) {
    // Để đơn giản và nhanh trong Isolate, ta convert từ YUV sang RGB
    final outImg = img.Image(width: width, height: height);
    // Trả về jpg encoded bytes của một ảnh trống
    return Uint8List.fromList(img.encodeJpg(outImg));
  }
}

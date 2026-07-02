# YOLOv8 Object Counter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng ứng dụng Flutter hoàn chỉnh chạy offline phát hiện và đếm vật thể bằng mô hình YOLOv8 custom.

**Architecture:** Áp dụng Clean Architecture (Data, Domain, Presentation) kết hợp tách biệt luồng xử lý ảnh nặng và inference qua Background Isolate sử dụng `RootIsolateToken`. Quản lý state ứng dụng bằng Riverpod v3.x.

**Tech Stack:** Flutter, Dart, Riverpod 3.x, tflite_flutter, camera, image, image_picker, permission_handler.

## Global Constraints

- Flutter version: mới nhất ổn định (>= 3.22.x)
- Riverpod version: ^3.2.0 (sử dụng Notifier/AsyncNotifier)
- Mô hình: YOLOv8 LiteRT (.tflite) kích thước input 640x640
- Tương thích: Hoạt động tốt offline trên cả Android và iOS
- Quản lý hiệu năng: Toàn bộ xử lý ảnh, decode và NMS chạy trong Isolate phụ

---

### Task 1: Initialize Flutter Project and Configure Dependencies

**Files:**
- Create: `pubspec.yaml`
- Modify: `android/app/build.gradle` (nếu cần điều chỉnh minSdkVersion)

**Interfaces:**
- Produces: Dự án Flutter đã được cấu hình đầy đủ dependencies và assets.

- [ ] **Step 1: Tạo dự án Flutter**

Run: `flutter create . --project-name=diemsoluong --org=com.example --platforms=android,ios`
Expected: Tạo thành công cấu trúc dự án Flutter tại workspace.

- [ ] **Step 2: Cập nhật pubspec.yaml**

Ghi đè nội dung `pubspec.yaml` để thêm các thư viện cần thiết và khai báo thư mục assets.

```yaml
name: diemsoluong
description: "A Flutter application for scanning and counting objects on-device using YOLOv8."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.22.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.2.0
  camera: ^0.11.3
  image_picker: ^1.2.1
  tflite_flutter: ^0.12.1
  path_provider: ^2.1.5
  permission_handler: ^12.0.1
  image: ^4.7.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/models/
```

- [ ] **Step 3: Chạy lệnh tải dependencies**

Run: `flutter pub get`
Expected: Lệnh chạy thành công, không gặp lỗi xung đột version.

- [ ] **Step 4: Cập nhật minSdkVersion cho Android**

Để hỗ trợ `tflite_flutter` và `camera`, ta cần cập nhật `minSdkVersion` lên ít nhất 21.
Modify: `android/app/build.gradle` thay đổi `minSdkVersion` từ mặc định thành `21`.

- [ ] **Step 5: Tạo thư mục asset và đặt file mô hình mẫu**

Tạo thư mục `assets/models/`. Tại đây, chúng ta sẽ để file `yolov8n_float16.tflite` mẫu làm baseline.
Run: `mkdir -p assets/models`
Expected: Tạo thành công thư mục.

- [ ] **Step 6: Commit**

```bash
git init
git add .
git commit -m "chore: initialize project and setup dependencies"
```

---

### Task 2: Core Data Models and Configuration

**Files:**
- Create: `lib/data/models/detection.dart`
- Create: `lib/data/models/model_config.dart`

**Interfaces:**
- Produces:
  - Class `Detection`: Chứa toạ độ `Rect rect`, `int classId`, `double score`.
  - Class `ModelConfig`: Chứa cấu hình tĩnh của mô hình (`inputSize`, `confidenceThreshold`, `iouThreshold`, `labels`).

- [ ] **Step 1: Tạo model_config.dart**

Tạo file `lib/data/models/model_config.dart` chứa thông số mô hình.

```dart
class ModelConfig {
  static const int inputSize = 640;
  static const double defaultConfidenceThreshold = 0.25;
  static const double defaultIouThreshold = 0.45;
  static const String modelAssetPath = 'assets/models/yolov8n_float16.tflite';
  
  // Danh sách nhãn COCO mặc định làm ví dụ
  static const List<String> cocoLabels = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
    'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat',
    'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack',
    'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball',
    'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
    'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
    'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake',
    'chair', 'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop',
    'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
    'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
  ];
}
```

- [ ] **Step 2: Tạo detection.dart**

Tạo file `lib/data/models/detection.dart` chứa kết quả phát hiện vật thể.

```dart
import 'dart:ui';

class Detection {
  final Rect rect;
  final int classId;
  final double score;

  const Detection({
    required this.rect,
    required this.classId,
    required this.score,
  });

  @override
  String toString() => 'Detection(rect: $rect, classId: $classId, score: $score)';
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/
git commit -m "feat: add Detection and ModelConfig data models"
```

---

### Task 3: Core Usecases (Decode Tensor Output & NMS Filter) with Unit Tests

**Files:**
- Create: `lib/domain/usecases/decode_yolo_output.dart`
- Create: `lib/domain/usecases/nms_filter.dart`
- Create: `test/domain/usecases_test.dart`

**Interfaces:**
- Consumes: `Detection`, `ModelConfig`
- Produces:
  - Hàm `decodeDetections(Float32List output, int numBoxes, int numClasses, double confThreshold)`
  - Hàm `applyNMS(List<Detection> detections, double iouThreshold)`

- [ ] **Step 1: Viết logic giải mã tensor (decode_yolo_output.dart)**

Tạo file `lib/domain/usecases/decode_yolo_output.dart` thực hiện chuyển đổi phẳng Float32List sang Detection.

```dart
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
```

- [ ] **Step 2: Viết logic lọc NMS (nms_filter.dart)**

Tạo file `lib/domain/usecases/nms_filter.dart`.

```dart
import 'dart:math';
import 'dart:ui';
import '../../data/models/detection.dart';

List<Detection> applyNMS(List<Detection> detections, double iouThreshold) {
  if (detections.isEmpty) return [];

  // Sắp xếp giảm dần theo score
  detections.sort((a, b) => b.score.compareTo(a.score));

  final List<Detection> selected = [];
  final List<bool> active = List.filled(detections.length, true);

  for (int i = 0; i < detections.length; i++) {
    if (!active[i]) continue;

    final boxA = detections[i];
    selected.add(boxA);

    for (int j = i + 1; j < detections.length; j++) {
      if (!active[j]) continue;

      final boxB = detections[j];
      if (boxA.classId == boxB.classId) {
        final iou = calculateIoU(boxA.rect, boxB.rect);
        if (iou > iouThreshold) {
          active[j] = false;
        }
      }
    }
  }
  return selected;
}

double calculateIoU(Rect rectA, Rect rectB) {
  final intersectionX1 = max(rectA.left, rectB.left);
  final intersectionY1 = max(rectA.top, rectB.top);
  final intersectionX2 = min(rectA.right, rectB.right);
  final intersectionY2 = min(rectA.bottom, rectB.bottom);

  final intersectionWidth = max(0.0, intersectionX2 - intersectionX1);
  final intersectionHeight = max(0.0, intersectionY2 - intersectionY1);
  final intersectionArea = intersectionWidth * intersectionHeight;

  final areaA = (rectA.right - rectA.left) * (rectA.bottom - rectA.top);
  final areaB = (rectB.right - rectB.left) * (rectB.bottom - rectB.top);
  final unionArea = areaA + areaB - intersectionArea;

  if (unionArea == 0.0) return 0.0;
  return intersectionArea / unionArea;
}
```

- [ ] **Step 3: Viết Unit Test cho Decode và NMS**

Tạo file `test/domain/usecases_test.dart` để xác định logic chạy chuẩn xác độc lập với Flutter UI.

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:diemsoluong/data/models/detection.dart';
import 'package:diemsoluong/domain/usecases/decode_yolo_output.dart';
import 'package:diemsoluong/domain/usecases/nms_filter.dart';

void main() {
  group('YOLOv8 Decode Tests', () {
    test('decodeDetections parses flat Float32List correctly', () {
      final numBoxes = 3;
      final numClasses = 1;
      // Kích thước phẳng: (4 + 1) * 3 = 15 phần tử
      // Row 0: x_center -> [0.5, 0.2, 0.9]
      // Row 1: y_center -> [0.5, 0.2, 0.9]
      // Row 2: width    -> [0.1, 0.2, 0.3]
      // Row 3: height   -> [0.1, 0.2, 0.3]
      // Row 4: score_c0 -> [0.8, 0.1, 0.9]
      final output = Float32List.fromList([
        0.5, 0.2, 0.9, // X-centers
        0.5, 0.2, 0.9, // Y-centers
        0.1, 0.2, 0.3, // Widths
        0.1, 0.2, 0.3, // Heights
        0.8, 0.1, 0.9, // Class 0 Scores
      ]);

      final detections = decodeDetections(output, numBoxes, numClasses, 0.5);
      
      // Chỉ 2 box đạt ngưỡng score >= 0.5 (box 0 và box 2)
      expect(detections.length, 2);
      expect(detections[0].classId, 0);
      expect(detections[0].score, 0.8);
      // Kiểm tra toạ độ xCenter = 0.5 * 640 = 320, width = 0.1 * 640 = 64
      // rect left = 320 - 32 = 288
      expect(detections[0].rect.left, 288.0);
    });
  });

  group('NMS Filter Tests', () {
    test('applyNMS filters overlapping boxes', () {
      final detections = [
        const Detection(rect: Rect.fromLTWH(100, 100, 50, 50), classId: 0, score: 0.9),
        const Detection(rect: Rect.fromLTWH(105, 105, 50, 50), classId: 0, score: 0.8), // Overlapping
        const Detection(rect: Rect.fromLTWH(300, 300, 50, 50), classId: 0, score: 0.85), // Non-overlapping
      ];

      final filtered = applyNMS(detections, 0.45);
      
      expect(filtered.length, 2);
      expect(filtered[0].score, 0.9);
      expect(filtered[1].score, 0.85);
    });
  });
}
```

- [ ] **Step 4: Chạy Unit Test**

Run: `flutter test test/domain/usecases_test.dart`
Expected: PASS cả 2 test suites.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/ test/domain/
git commit -m "feat: implement decode_yolo_output, nms_filter, and write unit tests"
```

---

### Task 4: Image Processing Service & Isolate Setup

**Files:**
- Create: `lib/data/services/image_service.dart`
- Create: `lib/core/isolate/inference_isolate.dart`

**Interfaces:**
- Consumes: `Detection`, `ModelConfig`
- Produces:
  - Class `ImageService`: thực hiện convert định dạng sang RGB Uint8List, resize, normalize.
  - Class `InferenceIsolate`: quản lý Background Isolate nhận ảnh thô gửi về kết quả list detection.

- [ ] **Step 1: Tạo image_service.dart**

Tạo file `lib/data/services/image_service.dart` để tiền xử lý ảnh trước khi đưa vào mô hình.

```dart
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
    // Ở bản nháp này, ta implement thuật toán nhanh hoặc sử dụng API chuyển đổi của Flutter Camera
    // Đây là helper đơn giản, nhận raw bytes chuyển đổi sang RGB.
    final outImg = img.Image(width: width, height: height);
    // Đoạn code giả lập mapping pixel (sẽ hoàn chỉnh chi tiết khi code)
    return Uint8List.fromList(img.encodeJpg(outImg));
  }
}
```

- [ ] **Step 2: Tạo inference_isolate.dart**

Tạo file `lib/core/isolate/inference_isolate.dart` để thiết lập isolate giao tiếp bằng ports.

```dart
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../data/models/detection.dart';
import '../../data/models/model_config.dart';
import '../../data/services/image_service.dart';
import '../../domain/usecases/decode_yolo_output.dart';
import '../../domain/usecases/nms_filter.dart';

class InferenceRequest {
  final Uint8List imageBytes;
  final double confidenceThreshold;
  final double iouThreshold;

  InferenceRequest({
    required this.imageBytes,
    required this.confidenceThreshold,
    required this.iouThreshold,
  });
}

class InferenceIsolate {
  late Isolate _isolate;
  late SendPort _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool _isReady = false;

  bool get isReady => _isReady;

  Future<void> init() async {
    final token = RootIsolateToken.instance!;
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      [_receivePort.sendPort, token],
    );

    _sendPort = await _receivePort.first as SendPort;
    _isReady = true;
  }

  Future<List<Detection>> runInference(InferenceRequest request) async {
    final responsePort = ReceivePort();
    _sendPort.send([request, responsePort.sendPort]);
    final result = await responsePort.first as List<Detection>;
    return result;
  }

  void dispose() {
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _receivePort.close();
  }

  static void _isolateEntryPoint(List<dynamic> args) async {
    final mainSendPort = args[0] as SendPort;
    final token = args[1] as RootIsolateToken;

    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    // Khởi tạo interpreter tflite trong Isolate phụ
    final options = InterpreterOptions()..threads = 4;
    options.useNnApiForAndroid = true;
    
    final interpreter = await Interpreter.fromAsset(
      ModelConfig.modelAssetPath,
      options: options,
    );

    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    commandPort.listen((message) async {
      final request = message[0] as InferenceRequest;
      final replyPort = message[1] as SendPort;

      try {
        // 1. Tiền xử lý ảnh sang Float32List [1, 640, 640, 3]
        final inputBuffer = ImageService.preprocessImage(
          request.imageBytes,
          ModelConfig.inputSize,
        );

        if (inputBuffer.isEmpty) {
          replyPort.send(<Detection>[]);
          return;
        }

        // YOLOv8n có 1 output tensor hình dạng [1, 4 + num_classes, 8400]
        // Ví dụ với 80 lớp COCO: 84 * 8400 = 705600 phần tử float
        final numClasses = interpreter.getOutputTensors().first.shape[1] - 4;
        final numBoxes = interpreter.getOutputTensors().first.shape[2];
        final outputBuffer = Float32List(1 * (4 + numClasses) * numBoxes);

        // 2. Chạy mô hình
        interpreter.run(
          inputBuffer.reshape([1, ModelConfig.inputSize, ModelConfig.inputSize, 3]),
          outputBuffer.reshape([1, 4 + numClasses, numBoxes]),
        );

        // 3. Giải mã và NMS
        final decoded = decodeDetections(
          outputBuffer,
          numBoxes,
          numClasses,
          request.confidenceThreshold,
        );
        final filtered = applyNMS(decoded, request.iouThreshold);

        replyPort.send(filtered);
      } catch (e) {
        replyPort.send(<Detection>[]);
      }
    });
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/data/services/image_service.dart lib/core/isolate/inference_isolate.dart
git commit -m "feat: add ImageService and InferenceIsolate background runner"
```

---

### Task 5: TFLite Service and State Management (Riverpod Notifier)

**Files:**
- Create: `lib/data/services/tflite_service.dart`
- Create: `lib/presentation/state/detector_notifier.dart`

**Interfaces:**
- Consumes: `InferenceIsolate`, `Detection`, `ModelConfig`
- Produces:
  - Class `TfliteService`: Wrapper quản lý vòng đời của Isolate.
  - Class `DetectorState`: Trạng thái nhận diện (isLoading, imageBytes, detections, error).
  - Riverpod Provider `detectorNotifierProvider`.

- [ ] **Step 1: Tạo tflite_service.dart**

Tạo file `lib/data/services/tflite_service.dart` đóng gói logic giao tiếp isolate.

```dart
import 'dart:typed_data';
import '../../core/isolate/inference_isolate.dart';
import '../../data/models/detection.dart';
import '../../data/models/model_config.dart';

class TfliteService {
  final InferenceIsolate _isolate = InferenceIsolate();

  Future<void> initialize() async {
    if (!_isolate.isReady) {
      await _isolate.init();
    }
  }

  Future<List<Detection>> detectObjects(
    Uint8List imageBytes, {
    double confidenceThreshold = ModelConfig.defaultConfidenceThreshold,
    double iouThreshold = ModelConfig.defaultIouThreshold,
  }) async {
    await initialize();
    return _isolate.runInference(
      InferenceRequest(
        imageBytes: imageBytes,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      ),
    );
  }

  void dispose() {
    _isolate.dispose();
  }
}
```

- [ ] **Step 2: Tạo detector_notifier.dart**

Tạo file `lib/presentation/state/detector_notifier.dart` quản lý state bằng Riverpod v3 Notifier.

```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/detection.dart';
import '../../data/services/tflite_service.dart';

class DetectorState {
  final bool isLoading;
  final Uint8List? imageBytes;
  final List<Detection> detections;
  final String? errorMessage;

  DetectorState({
    this.isLoading = false,
    this.imageBytes,
    this.detections = const [],
    this.errorMessage,
  });

  DetectorState copyWith({
    bool? isLoading,
    Uint8List? imageBytes,
    List<Detection>? detections,
    String? errorMessage,
  }) {
    return DetectorState(
      isLoading: isLoading ?? this.isLoading,
      imageBytes: imageBytes ?? this.imageBytes,
      detections: detections ?? this.detections,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Định nghĩa Riverpod Provider mới theo Riverpod 3.x
final tfliteServiceProvider = Provider<TfliteService>((ref) {
  final service = TfliteService();
  ref.onDispose(() => service.dispose());
  return service;
});

class DetectorNotifier extends AutoDisposeNotifier<DetectorState> {
  @override
  DetectorState build() {
    return DetectorState();
  }

  Future<void> detectImage(Uint8List bytes) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final tfliteService = ref.read(tfliteServiceProvider);
      final detections = await tfliteService.detectObjects(bytes);
      state = state.copyWith(
        isLoading: false,
        imageBytes: bytes,
        detections: detections,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Lỗi nhận diện vật thể: $e',
      );
    }
  }

  void clear() {
    state = DetectorState();
  }
}

final detectorNotifierProvider =
    NotifierProvider.autoDispose<DetectorNotifier, DetectorState>(() {
  return DetectorNotifier();
});
```

- [ ] **Step 3: Commit**

```bash
git add lib/data/services/tflite_service.dart lib/presentation/state/
git commit -m "feat: add TfliteService and Riverpod detectorNotifierProvider"
```

---

### Task 6: Custom Bounding Box Painter (UI Rendering)

**Files:**
- Create: `lib/presentation/widgets/detector_painter.dart`

**Interfaces:**
- Consumes: `Detection`, `ModelConfig`
- Produces: `DetectorPainter` class extend `CustomPainter`.

- [ ] **Step 1: Viết CustomPainter hỗ trợ Inverse-Letterbox**

Tạo file `lib/presentation/widgets/detector_painter.dart` vẽ boxes khớp với tỷ lệ ảnh thực tế.

```dart
import 'dart:ui' as ui;
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/
git commit -m "feat: implement DetectorPainter with letterbox scaling"
```

---

### Task 7: UI Screens and App Entry Point

**Files:**
- Create: `lib/presentation/screens/home_screen.dart`
- Create: `lib/presentation/screens/camera_screen.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: Riverpod providers, `DetectorPainter`, `image_picker`
- Produces: Giao diện chọn ảnh, chụp ảnh, xem kết quả và màn hình camera live stream.

- [ ] **Step 1: Tạo home_screen.dart**

Tạo file `lib/presentation/screens/home_screen.dart` chứa nút chọn ảnh, chụp ảnh tĩnh và đếm vật thể.

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/model_config.dart';
import '../state/detector_notifier.dart';
import '../widgets/detector_painter.dart';
import 'camera_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  Size? _imageSize;
  File? _imageFile;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final decodedImage = await decodeImageFromList(await file.readAsBytes());
    
    setState(() {
      _imageFile = file;
      _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
    });

    final bytes = await file.readAsBytes();
    await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
  }

  Future<void> _openLiveCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần quyền truy cập Camera để quét real-time')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detectorNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Đếm Số Lượng Vật Thể'),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: _imageFile == null
                  ? const Center(child: Text('Vui lòng chọn ảnh để đếm'))
                  : Stack(
                      children: [
                        Center(
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (state.detections.isNotEmpty && _imageSize != null)
                          Center(
                            child: AspectRatio(
                              aspectRatio: _imageSize!.width / _imageSize!.height,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return CustomPaint(
                                    size: Size(constraints.maxWidth, constraints.maxHeight),
                                    painter: DetectorPainter(
                                      detections: state.detections,
                                      originalImageSize: _imageSize!,
                                      labels: ModelConfig.cocoLabels,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        if (state.isLoading)
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
            ),
            if (state.detections.isNotEmpty && !state.isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                color: Colors.teal.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tổng vật thể đếm được: ${state.detections.length}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Thư viện'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Chụp ảnh'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openLiveCamera,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Quét trực tiếp'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Tạo camera_screen.dart**

Tạo file `lib/presentation/screens/camera_screen.dart` xử lý stream với logic throttle.

```dart
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/model_config.dart';
import '../state/detector_notifier.dart';
import '../widgets/detector_painter.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  DateTime? _lastInferenceTime;
  Size? _previewSize;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    _previewSize = Size(
      _controller!.value.previewSize!.height,
      _controller!.value.previewSize!.width,
    );

    _controller!.startImageStream((CameraImage image) {
      _processCameraFrame(image);
    });

    setState(() {});
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessing) return;

    final now = DateTime.now();
    // Throttle: Chỉ xử lý 1 frame mỗi 400ms
    if (_lastInferenceTime != null && 
        now.difference(_lastInferenceTime!).inMilliseconds < 400) {
      return;
    }

    _isProcessing = true;
    _lastInferenceTime = now;

    try {
      // Gộp các planes camera thành bytes đơn giản
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final Uint8List bytes = allBytes.done().buffer.asUint8List();
      
      // Gửi sang isolate qua notifier
      await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
    } catch (e) {
      // Bỏ qua lỗi frame
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = ref.watch(detectorNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quét Real-time')),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          if (state.detections.isNotEmpty && _previewSize != null)
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
              painter: DetectorPainter(
                detections: state.detections,
                originalImageSize: _previewSize!,
                labels: ModelConfig.cocoLabels,
              ),
            ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Phát hiện: ${state.detections.length} vật thể',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: Center,
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 3: Modify main.dart**

Cập nhật file `lib/main.dart` để khai báo Riverpod `ProviderScope`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YOLOv8 Object Counter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/ lib/main.dart
git commit -m "feat: implement HomeScreen, CameraScreen, and main entry point"
```

---

### Task 8: Python Scripts and Training Documentation

**Files:**
- Create: `python_scripts/train_and_export.py`
- Create: `python_scripts/README.md`

**Interfaces:**
- Produces: Script Python train và export mô hình kèm tài liệu hướng dẫn cấu hình chi tiết cho người dùng.

- [ ] **Step 1: Tạo thư mục python_scripts và train_and_export.py**

Run: `mkdir -p python_scripts`
Expected: Tạo thư mục thành công.

Tạo file `python_scripts/train_and_export.py`.

```python
import os
from roboflow import Roboflow
from ultralytics import YOLO

def main():
    # Điền thông tin API Roboflow của bạn tại đây
    api_key = "YOUR_ROBOFLOW_API_KEY"
    workspace_name = "workspace-id"
    project_name = "project-id"
    version_num = 1

    print("--- 1. Tải Dataset từ Roboflow ---")
    try:
        rf = Roboflow(api_key=api_key)
        project = rf.workspace(workspace_name).project(project_name)
        version = project.version(version_num)
        dataset = version.download("yolov8")
        data_yaml = os.path.join(dataset.location, "data.yaml")
        print(f"Dataset downloaded to: {dataset.location}")
    except Exception as e:
        print(f"Lỗi tải dataset (Vui lòng thay API key hợp lệ): {e}")
        return

    print("\n--- 2. Khởi tạo mô hình YOLOv8n ---")
    model = YOLO('yolov8n.pt')

    print("\n--- 3. Huấn luyện mô hình ---")
    model.train(data=data_yaml, epochs=100, imgsz=640, device=0)

    print("\n--- 4. Đánh giá mô hình ---")
    metrics = model.val()
    print(f"mAP50-95: {metrics.box.map}")

    print("\n--- 5. Xuất mô hình sang LiteRT (.tflite) ---")
    # FP32 Baseline
    model.export(format='litert', imgsz=640)
    
    # FP16 - Khuyên dùng cho Release đầu tiên
    print("Exporting Float16 quantized model...")
    model.export(format='litert', imgsz=640, half=True)
    
    # INT8 Quantized - Phải có data.yaml
    print("Exporting INT8 quantized model (with representative data)...")
    model.export(format='litert', imgsz=640, int8=True, data=data_yaml)
    
    print("\nQuá trình hoàn tất! Kiểm tra thư mục runs/detect/train/weights/ để lấy file mô hình.")

if __name__ == '__main__':
    main()
```

- [ ] **Step 2: Viết README.md hướng dẫn tích hợp mô hình custom**

Tạo file `python_scripts/README.md` hướng dẫn sử dụng.

```markdown
# Hướng dẫn Huấn luyện và Xuất mô hình YOLOv8 sang LiteRT

Mục này cung cấp script Python để huấn luyện mô hình đếm vật thể custom và copy vào ứng dụng Flutter.

## Hướng dẫn nhanh

1. Gán nhãn dữ liệu của bạn trên [Roboflow](https://roboflow.com).
2. Xuất dữ liệu định dạng **YOLOv8**.
3. Chạy file `train_and_export.py` trên Google Colab hoặc máy có GPU cục bộ:
   ```bash
   pip install ultralytics roboflow
   python train_and_export.py
   ```
4. Copy file mô hình sinh ra từ thư mục weights (ví dụ: `yolov8n_float16.tflite`) vào thư mục `assets/models/` trong dự án Flutter của bạn.
5. Cập nhật `ModelConfig.modelAssetPath` trong `lib/data/models/model_config.dart` trỏ đến file mới.
```

- [ ] **Step 3: Commit**

```bash
git add python_scripts/
git commit -m "docs: add python training scripts and README guide"
```

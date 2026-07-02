# Refactoring Roadmap - Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Di chuyển các tệp tin nghiệp vụ liên quan đến Nhận diện (Detection) sang cấu trúc module `features/detection/` theo đúng lộ trình đã đề ra, đồng thời đưa vào interface `Detector` để tạo lớp trừu tượng hoá.

---

### Task 1: Create Detector Interface and Concrete TfliteDetector Implementation

- [ ] **Step 1: Định nghĩa interface `Detector`**
  Tạo tệp mới [detector.dart](file:///d:/diemsoluong/lib/features/detection/domain/services/detector.dart) khai báo interface trừu tượng cho các Backend:
  
  ```dart
  import 'dart:typed_data';
  import '../../../../shared/models/detection.dart'; // Đợi di chuyển mô hình sau hoặc trỏ đúng vị trí hiện tại

  abstract class Detector {
    bool get isReady;
    Future<void> initialize();
    Future<List<Detection>> detect(
      Uint8List imageBytes, {
      double confidenceThreshold,
      double iouThreshold,
    });
    Future<void> dispose();
  }
  ```

- [ ] **Step 2: Cài đặt `TfliteDetector`**
  Tạo tệp mới [tflite_detector.dart](file:///d:/diemsoluong/lib/features/detection/data/detectors/tflite_detector.dart) implement `Detector`, ủy nhiệm (delegate) việc xử lý suy luận qua `TfliteService`.

- [ ] **Step 3: Chạy linter**
  Chạy `flutter analyze` để kiểm tra lỗi cú pháp ban đầu.

---

### Task 2: Relocate Data Layer Services (ImageService, TfliteService, InferenceIsolate)

- [ ] **Step 1: Di chuyển `image_service.dart`**
  Di chuyển [image_service.dart](file:///d:/diemsoluong/lib/data/services/image_service.dart) sang vị trí mới [image_service.dart](file:///d:/diemsoluong/lib/features/detection/data/services/image_service.dart) và cập nhật đường dẫn import tương đối bên trong tệp.

- [ ] **Step 2: Di chuyển `tflite_service.dart`**
  Di chuyển [tflite_service.dart](file:///d:/diemsoluong/lib/data/services/tflite_service.dart) sang vị trí mới [tflite_service.dart](file:///d:/diemsoluong/lib/features/detection/data/services/tflite_service.dart).

- [ ] **Step 3: Di chuyển `inference_isolate.dart`**
  Di chuyển [inference_isolate.dart](file:///d:/diemsoluong/lib/core/isolate/inference_isolate.dart) sang vị trí mới [inference_isolate.dart](file:///d:/diemsoluong/lib/features/detection/data/isolates/inference_isolate.dart).

- [ ] **Step 4: Xóa các file cũ ở vị trí gốc**
  Xóa các tệp tin gốc để tránh xung đột mã nguồn.

- [ ] **Step 5: Chạy linter**
  Chạy `flutter analyze` để ghi nhận các lỗi import lỗi từ bên ngoài.

---

### Task 3: Relocate Domain Layer Use Cases (decode_yolo_output, nms_filter)

- [ ] **Step 1: Di chuyển `decode_yolo_output.dart`**
  Di chuyển [decode_yolo_output.dart](file:///d:/diemsoluong/lib/domain/usecases/decode_yolo_output.dart) sang vị trí mới [decode_detections.dart](file:///d:/diemsoluong/lib/features/detection/domain/usecases/decode_detections.dart) (đổi tên để đồng bộ cấu trúc thư mục).

- [ ] **Step 2: Di chuyển `nms_filter.dart`**
  Di chuyển [nms_filter.dart](file:///d:/diemsoluong/lib/domain/usecases/nms_filter.dart) sang vị trí mới [apply_nms.dart](file:///d:/diemsoluong/lib/features/detection/domain/usecases/apply_nms.dart).

- [ ] **Step 3: Xóa các usecase cũ**
  Xóa các file cũ tại thư mục gốc `lib/domain/usecases/`.

- [ ] **Step 4: Chạy linter**
  Kiểm tra danh sách lỗi phân tích cú pháp để chuẩn bị đồng bộ imports.

---

### Task 4: Relocate Presentation Elements (DetectorPainter)

- [ ] **Step 1: Di chuyển `detector_painter.dart`**
  Diên chuyển [detector_painter.dart](file:///d:/diemsoluong/lib/presentation/widgets/detector_painter.dart) sang vị trí mới [detector_painter.dart](file:///d:/diemsoluong/lib/features/detection/presentation/widgets/detector_painter.dart).

- [ ] **Step 2: Xóa file cũ**
  Xóa tệp painter cũ tại thư mục gốc.

---

### Task 5: Synchronize Imports across Notifier, Screens, and Tests

- [ ] **Step 1: Cập nhật imports trong các file còn lại**
  Sửa đường dẫn import của các tệp di chuyển trong:
  - `lib/presentation/state/detector_notifier.dart`
  - `lib/presentation/screens/camera_screen.dart`
  - `lib/presentation/screens/home_screen.dart`

- [ ] **Step 2: Tổ chức lại cấu trúc thư mục Test**
  Di chuyển và cập nhật đường dẫn import trong:
  - `test/domain/decode_yolo_output_test.dart` -> `test/features/detection/decode_detections_test.dart`
  - `test/domain/nms_filter_test.dart` -> `test/features/detection/apply_nms_test.dart`

- [ ] **Step 3: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 4: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

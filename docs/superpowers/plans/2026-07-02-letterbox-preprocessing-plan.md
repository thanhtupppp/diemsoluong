# Letterbox Preprocessing and Coordinates Mapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển đổi pipeline xử lý ảnh sang dạng Letterbox (giữ nguyên tỷ lệ ảnh và bù padding màu xám) thay vì kéo dãn vuông, giúp tăng độ chính xác nhận diện YOLOv8 và đồng bộ hóa việc giải mã tọa độ hộp chính xác về kích thước ảnh gốc.

**Architecture:** 
1. `ImageService.preprocessImage` trả về đối tượng `PreprocessResult` chứa dữ liệu đệm ảnh phẳng kèm scale/padding metadata.
2. `InferenceIsolate` thực hiện giải mã box bằng `decodeDetections` sau đó thực hiện phép biến đổi ngược (unletterbox) để đưa tọa độ box về đúng kích thước ảnh gốc (`originalWidth`, `originalHeight`) trước khi chạy bộ lọc NMS.
3. `DetectorPainter` nhận tọa độ box ở không gian ảnh gốc, loại bỏ việc hardcode model size và chỉ thực hiện map tỷ lệ hiển thị canvas đơn giản.

**Tech Stack:** Flutter, Dart, image package, camera.

## Global Constraints

- Đảm bảo linter không báo lỗi và toàn bộ test suite pass 100%.

---

### Task 1: Refactor ImageService to support Letterbox Preprocessing

**Files:**
- Modify: [image_service.dart](file:///d:/diemsoluong/lib/data/services/image_service.dart)

**Interfaces:**
- Produces:
  - Class `PreprocessResult` chứa scale/padding metadata.
  - `ImageService.preprocessImage` trả về `PreprocessResult?` thay vì `Float32List`.

- [ ] **Step 1: Định nghĩa `PreprocessResult` và cập nhật `preprocessImage`**
  Cập nhật file `lib/data/services/image_service.dart` để thêm class `PreprocessResult` và thay đổi phương thức `preprocessImage` thực hiện resize giữ tỷ lệ và composite đệm ảnh nền xám (114, 114, 114).
  
  ```dart
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
  ```

- [ ] **Step 2: Chạy linter kiểm tra**
  Run: `flutter analyze`
  Expected: Có lỗi tại `inference_isolate.dart` do mismatch signature (sẽ sửa ở Task 2).

- [ ] **Step 3: Commit**
  ```bash
  git add lib/data/services/image_service.dart
  git commit -m "feat: implement Letterbox preprocessing in ImageService"
  ```

---

### Task 2: Update InferenceIsolate to perform Coordinate Mapping (Unletterbox)

**Files:**
- Modify: [inference_isolate.dart](file:///d:/diemsoluong/lib/core/isolate/inference_isolate.dart)

**Interfaces:**
- Consumes: `PreprocessResult` từ `ImageService`
- Produces:
  - `InferenceIsolate` trả về các đối tượng `Detection` có tọa độ đã được ánh xạ về không gian ảnh gốc.

- [ ] **Step 1: Áp dụng Unletterbox sau khi decode**
  Cập nhật `lib/core/isolate/inference_isolate.dart` để lấy `PreprocessResult` từ `ImageService`, chạy mô hình và ánh xạ tọa độ ngược về ảnh gốc.
  
  Chi tiết thay đổi:
  ```dart
  // Trong _isolateEntryPoint:
  final preprocessResult = ImageService.preprocessImage(
    request.imageBytes,
    ModelConfig.inputSize,
  );

  if (preprocessResult == null) {
    replyPort.send(<Detection>[]);
    return;
  }

  // Chạy model:
  interpreter.run(
    preprocessResult.input.reshape([1, ModelConfig.inputSize, ModelConfig.inputSize, 3]),
    outputBuffer.reshape([1, 4 + numClasses, numBoxes]),
  );

  // Giải mã sang model space [0-640]
  final decoded = decodeDetections(
    outputBuffer,
    numBoxes,
    numClasses,
    request.confidenceThreshold,
  );

  // Ánh xạ ngược về kích thước ảnh gốc (Unletterbox)
  final scale = preprocessResult.scale;
  final padX = preprocessResult.padX;
  final padY = preprocessResult.padY;
  final origW = preprocessResult.originalWidth.toDouble();
  final origH = preprocessResult.originalHeight.toDouble();

  final unletterboxed = decoded.map((det) {
    final rect = det.rect;
    double left = (rect.left - padX) / scale;
    double top = (rect.top - padY) / scale;
    double right = (rect.right - padX) / scale;
    double bottom = (rect.bottom - padY) / scale;

    left = left.clamp(0.0, origW);
    top = top.clamp(0.0, origH);
    right = right.clamp(0.0, origW);
    bottom = bottom.clamp(0.0, origH);

    return Detection(
      rect: Rect.fromLTRB(left, top, right, bottom),
      classId: det.classId,
      score: det.score,
    );
  }).toList();

  final filtered = applyNMS(unletterboxed, request.iouThreshold);
  replyPort.send(filtered);
  ```

- [ ] **Step 2: Chạy linter**
  Run: `flutter analyze`
  Expected: Lỗi tại `detector_painter.dart` do sai tham chiếu tọa độ vẽ (sẽ sửa ở Task 3).

- [ ] **Step 3: Commit**
  ```bash
  git add lib/core/isolate/inference_isolate.dart
  git commit -m "feat: map detection coordinates back to original image space in InferenceIsolate"
  ```

---

### Task 3: Simplify DetectorPainter to paint Original Image Coordinates

**Files:**
- Modify: [detector_painter.dart](file:///d:/diemsoluong/lib/presentation/widgets/detector_painter.dart)

**Interfaces:**
- Consumes: `Detection` chứa tọa độ ảnh gốc.
- Produces:
  - `DetectorPainter` thực hiện ánh xạ trực tiếp tỷ lệ hiển thị mà không cần model input size.

- [ ] **Step 1: Loại bỏ ModelConfig.inputSize và đơn giản hóa việc nhân scale**
  Cập nhật phương thức `paint` của `DetectorPainter` để trực tiếp ánh xạ từ ảnh gốc sang kích thước canvas.
  
  ```dart
  // Bỏ ModelConfig.inputSize khỏi phép tính tọa độ:
  for (final detection in detections) {
    final rect = detection.rect;

    final left = rect.left * scaleX + dx;
    final top = rect.top * scaleY + dy;
    final width = rect.width * scaleX;
    final height = rect.height * scaleY;

    final mappedRect = Rect.fromLTWH(left, top, width, height);
    // ... vẽ và clamp nhãn giữ nguyên
  }
  ```

- [ ] **Step 2: Chạy linter và kiểm thử**
  Run: `flutter analyze`
  Expected: No issues found!
  
  Run: `flutter test`
  Expected: Tất cả các bài test (bao gồm cả widget test và unit tests) pass 100%.

- [ ] **Step 3: Commit**
  ```bash
  git add lib/presentation/widgets/detector_painter.dart
  git commit -m "refactor: simplify DetectorPainter to draw directly from original coordinates"
  ```

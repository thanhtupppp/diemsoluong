# Refactor Inference and Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sửa lỗi và nâng cao độ ổn định của hệ thống inference (camera stream, state notifier) và bổ sung test coverage cho NMS filter.

**Architecture:** 
1. Sử dụng phương thức chụp ảnh (`takePicture`) tuần tự (periodic) trong `CameraScreen` như một giải pháp thay thế ổn định cho việc convert stream camera YUV→RGB thô chưa được tối ưu, giúp chạy offline chính xác mà không gây rác dữ liệu.
2. Tối ưu hóa `DetectorState` thành constructor `const` và đồng bộ hóa lớp `DetectorNotifier` thừa kế đúng lớp `AutoDisposeNotifier` của Riverpod v3.
3. Bổ sung trường hợp kiểm thử cho NMS Filter để đảm bảo không lọc đè các bounding box của các lớp đối tượng khác nhau.

**Tech Stack:** Flutter, Dart, Riverpod 3.x, camera, tflite_flutter.

## Global Constraints

- Không làm thay đổi logic giải mã YOLOv8 hiện tại đã chạy đúng.
- Không thay đổi các file model `.tflite` trong assets.
- Đảm bảo linter không báo lỗi và toàn bộ test suite pass 100%.

---

### Task 1: Refactor DetectorState and DetectorNotifier

**Files:**
- Modify: [detector_notifier.dart](file:///d:/diemsoluong/lib/presentation/state/detector_notifier.dart)

**Interfaces:**
- Produces: 
  - `DetectorState` với `const` constructor và default values.
  - `DetectorNotifier` kế thừa `AutoDisposeNotifier<DetectorState>`.

- [ ] **Step 1: Cập nhật `DetectorState` và `DetectorNotifier`**
  Sửa `DetectorState` constructor sang `const` và đổi `DetectorNotifier` từ `Notifier` sang `AutoDisposeNotifier`.
  
  Nội dung cập nhật chi tiết:
  ```dart
  class DetectorState {
    final bool isLoading;
    final Uint8List? imageBytes;
    final List<Detection> detections;
    final String? errorMessage;

    const DetectorState({
      this.isLoading = false,
      this.imageBytes,
      this.detections = const [],
      this.errorMessage,
    });
    
    // copyWith giữ nguyên...
  }
  
  class DetectorNotifier extends AutoDisposeNotifier<DetectorState> {
    @override
    DetectorState build() {
      return const DetectorState();
    }
    // detectImage và clear giữ nguyên...
  }
  ```

- [ ] **Step 2: Chạy linter**
  Run: `flutter analyze`
  Expected: Không lỗi cú pháp hoặc import.

- [ ] **Step 3: Commit**
  ```bash
  git add lib/presentation/state/detector_notifier.dart
  git commit -m "refactor: make DetectorState constructor const and extend AutoDisposeNotifier"
  ```

---

### Task 2: Implement Periodic Capture Fallback in CameraScreen

**Files:**
- Modify: [camera_screen.dart](file:///d:/diemsoluong/lib/presentation/screens/camera_screen.dart)

**Interfaces:**
- Consumes: `detectorNotifierProvider.notifier`
- Produces:
  - `CameraScreen` chạy chụp ảnh tĩnh định kỳ (mỗi 1000ms) để chạy inference thay vì stream YUV thô.

- [ ] **Step 1: Thay thế Image Stream bằng Periodic Capture**
  Sửa đổi `_initializeCamera()`, thêm cờ `_isDisposed` và phương thức `_startPeriodicCapture()` thay cho `startImageStream`.
  
  Chi tiết sửa đổi:
  ```dart
  // Thêm biến trạng thái:
  bool _isDisposed = false;
  
  // Sửa _initializeCamera():
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    
    if (mounted) {
      setState(() {});
      _startPeriodicCapture();
    }
  }

  // Thêm _startPeriodicCapture():
  Future<void> _startPeriodicCapture() async {
    while (!_isDisposed && mounted) {
      if (_controller != null && _controller!.value.isInitialized && !_isProcessing) {
        if (mounted) {
          setState(() {
            _isProcessing = true;
          });
        }
        try {
          final XFile file = await _controller!.takePicture();
          final bytes = await file.readAsBytes();
          if (!_isDisposed && mounted) {
            final decodedImage = await decodeImageFromList(bytes);
            _previewSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
            await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error capturing picture: $e');
          }
        } finally {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        }
      }
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }
  ```

- [ ] **Step 2: Cập nhật phương thức `dispose()`**
  Đảm bảo giải phóng camera controller và dừng vòng lặp định kỳ bằng cách đặt `_isDisposed = true`.
  ```dart
  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    super.dispose();
  }
  ```

- [ ] **Step 3: Chạy linter kiểm tra**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 4: Commit**
  ```bash
  git add lib/presentation/screens/camera_screen.dart
  git commit -m "feat: implement periodic capture fallback in CameraScreen"
  ```

---

### Task 3: Enhance NMS Filter Unit Tests

**Files:**
- Modify: [nms_filter_test.dart](file:///d:/diemsoluong/test/domain/nms_filter_test.dart)

**Interfaces:**
- Consumes: `applyNMS`
- Produces:
  - Unit test kiểm tra NMS giữa các classId khác nhau.

- [ ] **Step 1: Thêm test case cho các classId khác nhau**
  Sửa đổi `test/domain/nms_filter_test.dart` để thêm kiểm thử đảm bảo các hộp có độ trùng lặp cao (IoU lớn) nhưng khác lớp thì không bị loại bỏ.
  
  ```dart
  test('applyNMS does not filter overlapping boxes of different classes', () {
    final detections = [
      const Detection(rect: Rect.fromLTWH(100, 100, 50, 50), classId: 0, score: 0.9),
      const Detection(rect: Rect.fromLTWH(105, 105, 50, 50), classId: 1, score: 0.8), // Overlapping but different class
    ];

    final filtered = applyNMS(detections, 0.45);
    
    expect(filtered.length, 2);
    expect(filtered[0].classId, 0);
    expect(filtered[1].classId, 1);
  });
  ```

- [ ] **Step 2: Chạy kiểm thử**
  Run: `flutter test`
  Expected: PASS toàn bộ các test.

- [ ] **Step 3: Commit**
  ```bash
  git add test/domain/nms_filter_test.dart
  git commit -m "test: verify that NMS does not filter boxes of different classes"
  ```

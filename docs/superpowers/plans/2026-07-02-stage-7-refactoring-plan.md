# Refactoring Roadmap - Stage 7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tích hợp bộ bám vết đối tượng (`IouTracker`) và bộ đếm cắt vạch (`LineCrossCounter`) vào luồng quản lý trạng thái (`DetectorNotifier`), đồng thời cấu hình `OverlayPainter` để vẽ vạch phân cách và đường di chuyển (track path) của vật thể trực tiếp trên khung preview camera.

---

### Task 1: Update DetectorState and DetectorNotifier

- [ ] **Step 1: Cập nhật `DetectorState`**
  Cập nhật [detector_notifier.dart](file:///d:/diemsoluong/lib/presentation/state/detector_notifier.dart):
  - Thêm thuộc tính `final List<Track> tracks;` (mặc định rỗng).
  - Thêm thuộc tính `final Map<int, int> classCounts;` (mặc định rỗng).
  - Cập nhật phương thức `copyWith` và hàm dựng `const`.

- [ ] **Step 2: Khởi tạo Tracker & Counter trong `DetectorNotifier`**
  - Khai báo biến thành viên:
    ```dart
    final Tracker _tracker = IouTracker();
    late final Counter _counter;
    ```
  - Trong phương thức khởi tạo hoặc `build()`, thiết lập `CountingLine` cắt ngang giữa màn hình (tọa độ model space 640x640: pointA = (0, 320), pointB = (640, 320)):
    ```dart
    _counter = LineCrossCounter(
      line: const CountingLine(
        id: 'line_1',
        name: 'Vạch Đếm Trung Tâm',
        pointA: Offset(0, 320),
        pointB: Offset(640, 320),
      ),
    );
    ```

- [ ] **Step 3: Cập nhật luồng xử lý `detectImage`**
  - Sau khi lấy danh sách `detections` từ `tfliteService`:
    ```dart
    final tracks = _tracker.update(detections);
    final countResult = _counter.process(tracks);
    ```
  - Cập nhật state với cả `tracks` và `countResult.classCounts`.

- [ ] **Step 4: Cập nhật phương thức `clear` & `reset`**
  - Reset `_tracker` và `_counter` khi người dùng nhấn xóa ảnh/clear quét.

---

### Task 2: Enhance OverlayPainter Scene Composer

- [ ] **Step 1: Cập nhật tham số nhận vào của `OverlayPainter`**
  Cập nhật [overlay_painter.dart](file:///d:/diemsoluong/lib/features/overlay/presentation/widgets/overlay_painter.dart):
  - Nhận `final List<Track> tracks;` thay thế/hoặc đi kèm `detections`.
  - Nhận `final CountingLine? countingLine;` để vẽ vạch đếm.
  - Nhận `final Map<int, int> classCounts;` để vẽ thống kê nếu cần.

- [ ] **Step 2: Hiện thực hoá phương thức vẽ vạch đếm `_drawCountingLines`**
  - Vẽ một đường thẳng từ `pointA` đến `pointB` của `countingLine` đã được scale tương tự box.

- [ ] **Step 3: Hiện thực hoá phương thức vẽ lịch sử đường đi `_drawTracks`**
  - Vẽ một đường nối tiếp (`Polyline`) kết nối các điểm trong lịch sử `path` của từng `Track` đang hoạt động bằng màu nhạt bán trong suốt.

- [ ] **Step 4: Cập nhật `_drawDetections` để vẽ nhãn có mã định danh Track ID**
  - Vẽ hộp giới hạn xung quanh rect hiện tại của `Track` kèm nhãn dạng `[ID: track.id] class_name score%`.

---

### Task 3: Synchronize Screens and Verify

- [ ] **Step 1: Cập nhật CameraScreen**
  Truyền thêm `tracks` và `countingLine` từ notifier/state vào `OverlayPainter` trong [camera_screen.dart](file:///d:/diemsoluong/lib/features/camera/presentation/screens/camera_screen.dart).
  Hiển thị danh sách thống kê đếm (classCounts) dưới dạng bảng đếm nổi hoặc gắn kết điều khiển.

- [ ] **Step 2: Cập nhật HomeScreen**
  Đồng bộ truyền tham số tương tự trong [home_screen.dart](file:///d:/diemsoluong/lib/presentation/screens/home_screen.dart).

- [ ] **Step 3: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 4: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

# Refactoring Roadmap - Stage 10 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển đổi vạch đếm tĩnh (Static Line) thành vạch đếm tương tác (Interactive Line) bằng cách tích hợp điều khiển cử chỉ kéo chạm (`GestureDetector`), định nghĩa lại vạch trong `DetectorState` và tự động cập nhật vùng tính toán của `LineCrossCounter`.

---

### Task 1: Update DetectorState and DetectorNotifier

- [ ] **Step 1: Di chuyển `countingLine` vào `DetectorState`**
  Cập nhật [detector_notifier.dart](file:///d:/diemsoluong/lib/presentation/state/detector_notifier.dart):
  - Thêm thuộc tính `final CountingLine countingLine;` vào `DetectorState`.
  - Thiết lập giá trị mặc định của `countingLine` trong constructor của `DetectorState`:
    ```dart
    this.countingLine = const CountingLine(
      id: 'central_line',
      name: 'Vạch Đếm Trung Tâm',
      pointA: Offset(0, 320),
      pointB: Offset(640, 320),
    ),
    ```

- [ ] **Step 2: Viết phương thức cập nhật vạch đếm động**
  Trong `DetectorNotifier`, loại bỏ thuộc tính `final CountingLine countingLine` cục bộ, thay thế bằng phương thức:
  ```dart
  void updateCountingLine(Offset pointA, Offset pointB) {
    final newLine = CountingLine(
      id: state.countingLine.id,
      name: state.countingLine.name,
      pointA: pointA,
      pointB: pointB,
    );
    
    // Cập nhật lại bộ đếm với vạch mới
    _counter = LineCrossCounter(line: newLine);
    
    state = state.copyWith(countingLine: newLine);
  }
  ```

---

### Task 2: Create Interactive Line Widget Overlay

- [ ] **Step 1: Tạo `InteractiveLineOverlay` Widget**
  Tạo tệp mới [interactive_line_overlay.dart](file:///d:/diemsoluong/lib/features/overlay/presentation/widgets/interactive_line_overlay.dart):
  - Widget này nhận vào `originalImageSize`, `countingLine`, và hàm callback `onLineChanged(Offset a, Offset b)`.
  - Nó sử dụng `LayoutBuilder` để đo kích thước view space hiện tại, ánh xạ tọa độ model space của vạch đếm sang view space.
  - Vẽ hai núm điều khiển hình tròn (Handle A và Handle B) tại tọa độ view space.
  - Bao bọc bằng `GestureDetector` có thể nhận dạng các sự kiện `onPanUpdate` trên Handle A hoặc Handle B để tính toán lại toạ độ kéo và đổi ngược về model space, gọi callback `onLineChanged`.

---

### Task 3: Integrate and Verify UI

- [ ] **Step 1: Tích hợp vào HomeScreen**
  Cập nhật [home_screen.dart](file:///d:/diemsoluong/lib/presentation/screens/home_screen.dart):
  - Đặt `InteractiveLineOverlay` đè trên `CustomPaint` và `Image.file` trong Stack.
  - Khi có sự kiện kéo đổi, gọi `ref.read(detectorNotifierProvider.notifier).updateCountingLine(...)`.

- [ ] **Step 2: Tích hợp vào CameraScreen**
  Cập nhật [camera_screen.dart](file:///d:/diemsoluong/lib/features/camera/presentation/screens/camera_screen.dart):
  - Đặt `InteractiveLineOverlay` đè lên trong Stack xem live camera.

- [ ] **Step 3: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 4: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

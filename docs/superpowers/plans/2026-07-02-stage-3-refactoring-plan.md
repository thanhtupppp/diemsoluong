# Refactoring Roadmap - Stage 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai module `features/overlay/` để tách biệt độc lập phần vẽ hộp giới hạn và thông số đếm (Overlay Canvas) ra khỏi module `detection` và `camera`.

---

### Task 1: Create Overlay Presentation Elements

- [ ] **Step 1: Định nghĩa `OverlayPainter` (Composer)**
  Tạo tệp mới [overlay_painter.dart](file:///d:/diemsoluong/lib/features/overlay/presentation/widgets/overlay_painter.dart). Lớp này kế thừa `CustomPainter`, nhận danh sách `Detection` và `Size originalImageSize` (và danh sách `labels`), vẽ hộp giới hạn tương tự `DetectorPainter` nhưng được cấu trúc sẵn các hàm vẽ bổ trợ (ví dụ: `_drawDetections`, `_drawTracks`, `_drawCountingLines`) để dễ dàng tích hợp ở các giai đoạn sau.

- [ ] **Step 2: Xóa `DetectorPainter`**
  Xóa tệp cũ [detector_painter.dart](file:///d:/diemsoluong/lib/features/detection/presentation/widgets/detector_painter.dart) để hoàn tất việc chuyển giao trách nhiệm vẽ UI sang module `overlay`.

---

### Task 2: Synchronize Imports across Screens

- [ ] **Step 1: Cập nhật imports trong CameraScreen**
  Sửa import `DetectorPainter` trong [camera_screen.dart](file:///d:/diemsoluong/lib/features/camera/presentation/screens/camera_screen.dart) trỏ tới `OverlayPainter` của module `overlay`:
  `import '../../../overlay/presentation/widgets/overlay_painter.dart';`
  Và cập nhật widget `CustomPaint` để dùng `OverlayPainter` thay vì `DetectorPainter`.

- [ ] **Step 2: Cập nhật imports trong HomeScreen**
  Sửa import `DetectorPainter` trong [home_screen.dart](file:///d:/diemsoluong/lib/presentation/screens/home_screen.dart) trỏ tới `OverlayPainter` mới:
  `import '../../features/overlay/presentation/widgets/overlay_painter.dart';`
  Cập nhật Widget `CustomPaint` sử dụng `OverlayPainter`.

- [ ] **Step 3: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 4: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

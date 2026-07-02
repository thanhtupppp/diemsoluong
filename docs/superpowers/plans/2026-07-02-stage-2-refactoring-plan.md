# Refactoring Roadmap - Stage 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Di chuyển màn hình Camera (`camera_screen.dart`) sang cấu trúc module `features/camera/presentation/screens/` theo đúng lộ trình đã đề ra, đồng thời đồng bộ toàn bộ đường dẫn import.

---

### Task 1: Relocate CameraScreen Presentation Element

- [ ] **Step 1: Tạo thư mục đích và di chuyển tệp**
  Di chuyển [camera_screen.dart](file:///d:/diemsoluong/lib/presentation/screens/camera_screen.dart) sang vị trí mới [camera_screen.dart](file:///d:/diemsoluong/lib/features/camera/presentation/screens/camera_screen.dart).

- [ ] **Step 2: Cập nhật các đường dẫn import bên trong `camera_screen.dart`**
  Cập nhật các imports tương đối hoặc tuyệt đối:
  - `ModelConfig`: `import '../../../../data/models/model_config.dart';`
  - `DetectorNotifier`: `import '../../../../presentation/state/detector_notifier.dart';`
  - `DetectorPainter`: `import '../../../detection/presentation/widgets/detector_painter.dart';`

- [ ] **Step 3: Xóa tệp camera cũ**
  Xóa `lib/presentation/screens/camera_screen.dart`.

---

### Task 2: Synchronize Imports across HomeScreen and Navigation Links

- [ ] **Step 1: Cập nhật import trong HomeScreen**
  Sửa đường dẫn import `camera_screen.dart` trong [home_screen.dart](file:///d:/diemsoluong/lib/presentation/screens/home_screen.dart) sang:
  `import '../../features/camera/presentation/screens/camera_screen.dart';`

- [ ] **Step 2: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 3: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

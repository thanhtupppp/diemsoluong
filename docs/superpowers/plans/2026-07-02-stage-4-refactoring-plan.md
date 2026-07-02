# Refactoring Roadmap - Stage 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khai báo cấu trúc thư mục, các thực thể nghiệp vụ (Entities), các lớp giao tiếp trừu tượng (Interfaces/Services) và lớp cài đặt mẫu cho 2 module tiếp theo: `features/tracking/` (bám vết) và `features/counting/` (đếm qua vạch).

---

### Task 1: Create Tracking Feature Elements

- [ ] **Step 1: Định nghĩa thực thể `Track`**
  Tạo tệp mới [track.dart](file:///d:/diemsoluong/lib/features/tracking/domain/entities/track.dart) chứa thông tin của một đối tượng được theo dõi:
  - `int id`: ID duy nhất theo thời gian.
  - `int classId`: ID nhãn lớp.
  - `Rect rect`: Vị trí hộp giới hạn hiện tại.
  - `double score`: Điểm tin cậy.
  - `List<Offset> path`: Lịch sử di chuyển của tâm hộp để vẽ đường track.

- [ ] **Step 2: Định nghĩa abstract `Tracker`**
  Tạo tệp mới [tracker.dart](file:///d:/diemsoluong/lib/features/tracking/domain/services/tracker.dart) định nghĩa contract giao tiếp:
  ```dart
  import '../../../../data/models/detection.dart';
  import '../entities/track.dart';

  abstract class Tracker {
    List<Track> update(List<Detection> detections);
    void reset();
  }
  ```

- [ ] **Step 3: Cài đặt Centroid Tracker mẫu hoặc IoU Tracker**
  Tạo tệp mới [iou_tracker.dart](file:///d:/diemsoluong/lib/features/tracking/data/trackers/iou_tracker.dart) cài đặt thuật toán so khớp dựa trên chỉ số IoU giữa các frame kế tiếp, kế thừa `Tracker`.

---

### Task 2: Create Counting Feature Elements

- [ ] **Step 1: Định nghĩa thực thể `CountingLine` & `CountingResult`**
  Tạo tệp mới [counting_line.dart](file:///d:/diemsoluong/lib/features/counting/domain/entities/counting_line.dart) đại diện cho vạch cắt đếm (2 điểm A & B, nhãn, hướng cắt).
  Tạo tệp mới [counting_result.dart](file:///d:/diemsoluong/lib/features/counting/domain/entities/counting_result.dart) chứa thông tin kết quả đếm (số lượng tăng thêm, tổng số lượng đã đếm, danh sách IDs đã đếm qua).

- [ ] **Step 2: Định nghĩa abstract `Counter`**
  Tạo tệp mới [counter.dart](file:///d:/diemsoluong/lib/features/counting/domain/services/counter.dart) định nghĩa contract:
  ```dart
  import '../../../tracking/domain/entities/track.dart';
  import '../entities/counting_result.dart';

  abstract class Counter {
    CountingResult process(List<Track> tracks);
    void reset();
  }
  ```

- [ ] **Step 3: Cài đặt LineCrossCounter mẫu**
  Tạo tệp mới [line_cross_counter.dart](file:///d:/diemsoluong/lib/features/counting/data/counters/line_cross_counter.dart) thực thi tính toán kiểm tra giao điểm đoạn thẳng di chuyển (path) của track với vạch đếm, kế thừa `Counter`.

---

### Task 3: Verification

- [ ] **Step 1: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 2: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

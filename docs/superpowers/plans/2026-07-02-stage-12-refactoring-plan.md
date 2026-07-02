# Refactoring Roadmap - Stage 12 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tăng cường độ tin cậy và kiểm thử tự động (Robustness & Recovery):
1. Cài đặt cơ chế tự động giải phóng và khôi phục (auto-recovery) isolate suy luận khi gặp lỗi hoặc timeout.
2. Viết Unit Tests đầy đủ cho thuật toán bám vết `IouTracker` và tính toán giao cắt `LineCrossCounter`.

---

### Task 1: Implement Isolate Timeout & Auto-Recovery

- [ ] **Step 1: Thêm Timeout vào `InferenceIsolate`**
  Cập nhật [inference_isolate.dart](file:///d:/diemsoluong/lib/features/detection/data/isolates/inference_isolate.dart):
  - Thêm giới hạn thời gian chờ phản hồi từ Isolate phụ trong `runInference`:
    ```dart
    final result = await responsePort.first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Inference request timed out.'),
    ) as List<Detection>;
    ```

- [ ] **Step 2: Cài đặt phục hồi tự động trong `TfliteService`**
  Cập nhật [tflite_service.dart](file:///d:/diemsoluong/lib/features/detection/data/services/tflite_service.dart):
  - Bọc khối lệnh chạy suy luận trong `try-catch`. Khi bắt gặp bất kỳ ngoại lệ nào (ví dụ: TimeoutException do isolate bị chết/RAM tràn), lập tức gọi `_isolate.dispose()` và xoá cache `_initializing = null`.
  - Điều này giúp frame tiếp theo tự động kích hoạt tạo isolate mới khoẻ mạnh.

---

### Task 2: Implement Unit Tests

- [ ] **Step 1: Viết Unit Tests cho `IouTracker`**
  Tạo tệp test mới [iou_tracker_test.dart](file:///d:/diemsoluong/test/features/tracking/iou_tracker_test.dart):
  - Test trường hợp đối tượng di chuyển gần nhau qua nhiều khung hình được gán cùng ID.
  - Test trường hợp đối tượng biến mất quá số frame quy định (`maxLostFrames`) sẽ bị huỷ vết bám.

- [ ] **Step 2: Viết Unit Tests cho `LineCrossCounter`**
  Tạo tệp test mới [line_cross_counter_test.dart](file:///d:/diemsoluong/test/features/counting/line_cross_counter_test.dart):
  - Test trường hợp quỹ đạo đối tượng (path chứa ít nhất 2 điểm) cắt qua vạch được ghi nhận đếm thành công.
  - Test trường hợp không double-count (chỉ đếm đối tượng 1 lần duy nhất).
  - Test trường hợp quỹ đạo nằm song song hoặc không chạm vạch thì không tăng đếm.

---

### Task 3: Verification

- [ ] **Step 1: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 2: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed (including the new ones)!

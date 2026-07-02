# Refactoring Roadmap - Stage 11 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai bảng thống kê phân loại vật thể (`StatsDashboard`) với thiết kế kính mờ (Glassmorphism), hiển thị các lớp vật thể đã cắt qua vạch kèm mã màu sắc trùng khớp với màu bounding box trên khung vẽ.

---

### Task 1: Create StatsDashboard Component

- [ ] **Step 1: Định nghĩa Widget `StatsDashboard`**
  Tạo tệp mới [stats_dashboard.dart](file:///d:/diemsoluong/lib/features/overlay/presentation/widgets/stats_dashboard.dart):
  - Component dạng `StatelessWidget` nhận vào:
    * `final Map<int, int> classCounts;`
    * `final List<String> labels;`
  - Giao diện dạng thẻ chứa các thông số:
    * Phông nền sử dụng hiệu ứng mờ kính `BackdropFilter` kết hợp màu nền semi-transparent.
    * Tiêu đề: "Phân Tích Cắt Vạch Đếm".
    * Hiển thị danh sách các nhãn có đếm được lớn hơn 0 thành hàng ngang/Wrap. Mỗi thẻ con hiển thị: chấm màu chỉ số lớp (`Colors.primaries[classId % Colors.primaries.length]`), tên nhãn tiếng Anh/Việt tương ứng, số lượng đếm được.

---

### Task 2: Integrate StatsDashboard in UI Screens

- [ ] **Step 1: Thay thế Panel thống kê trên HomeScreen**
  Cập nhật [home_screen.dart](file:///d:/diemsoluong/lib/presentation/screens/home_screen.dart):
  - Nhập `StatsDashboard` và nhúng nó vào panel kết quả đếm của HomeScreen.
  - Sắp xếp vị trí nằm phía trên hàng hành động xuất CSV/JSON.

- [ ] **Step 2: Thêm Panel thống kê trên CameraScreen**
  Cập nhật [camera_screen.dart](file:///d:/diemsoluong/lib/features/camera/presentation/screens/camera_screen.dart):
  - Đặt `StatsDashboard` ở phần dưới màn hình (phía trên bảng thông báo cũ) để thống kê thời gian thực sống động.

---

### Task 3: Verification

- [ ] **Step 1: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 2: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

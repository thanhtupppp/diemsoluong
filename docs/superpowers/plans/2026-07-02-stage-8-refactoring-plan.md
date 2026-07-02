# Refactoring Roadmap - Stage 8 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tích hợp bộ xuất báo cáo dữ liệu (`CsvExporter` và `JsonExporter`) vào luồng quản lý trạng thái (`DetectorNotifier`) và bổ sung nút nhấn "Xuất Báo Cáo" trực tiếp trên màn hình chính (`HomeScreen`) để người dùng lưu trữ kết quả đếm.

---

### Task 1: Integrate Export Service into DetectorNotifier

- [ ] **Step 1: Định nghĩa Provider cho Exporters**
  Cập nhật [detector_notifier.dart](file:///d:/diemsoluong/lib/presentation/state/detector_notifier.dart):
  - Thêm các imports từ module `export`:
    `import '../../features/export/data/exporters/csv_exporter.dart';`
    `import '../../features/export/data/exporters/json_exporter.dart';`
    `import '../../features/export/domain/entities/export_job.dart';`
    `import '../../features/export/domain/services/exporter.dart';`
  - Đăng ký Provider cho `Exporter` (mặc định sử dụng `CsvExporter` hoặc `JsonExporter`):
    ```dart
    final csvExporterProvider = Provider<Exporter>((ref) => CsvExporter());
    final jsonExporterProvider = Provider<Exporter>((ref) => JsonExporter());
    ```

- [ ] **Step 2: Thêm phương thức `exportCurrentData` trong `DetectorNotifier`**
  - Viết phương thức `Future<ExportJob> exportCurrentData(String format)`:
    - Nếu format là `'csv'`, lấy `ref.read(csvExporterProvider)`.
    - Nếu format là `'json'`, lấy `ref.read(jsonExporterProvider)`.
    - Chuẩn bị dữ liệu Map để xuất báo cáo (ví dụ: các thông số thời gian, tổng số đối tượng bám vết, chi tiết phân phối đếm từng lớp: `state.classCounts`).
    - Gọi phương thức `exportData('report_${DateTime.now().millisecondsSinceEpoch}', exportDataMap)`.
    - Trả về `ExportJob`.

---

### Task 2: Update HomeScreen UI with Export Actions

- [ ] **Step 1: Bổ sung nút "Xuất CSV" và "Xuất JSON" trên HomeScreen**
  Cập nhật [home_screen.dart](file:///d:/diemsoluong/lib/presentation/screens/home_screen.dart):
  - Thêm hàng hiển thị nút bấm bên cạnh thanh đếm số lượng vật thể khi `state.tracks.isNotEmpty` (ví dụ: Icon Button xuất CSV/JSON).
  - Khi nhấn, gọi `ref.read(detectorNotifierProvider.notifier).exportCurrentData(format)`.
  - Hiển thị thông báo `SnackBar` thông tin tệp tin báo cáo được ghi thành công kèm đường dẫn tệp cục bộ (`job.filePath`).

---

### Task 3: Verification

- [ ] **Step 1: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 2: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

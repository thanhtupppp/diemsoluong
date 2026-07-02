# Refactoring Roadmap - Stage 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khai báo cấu trúc thư mục, các thực thể nghiệp vụ (Entities), các lớp giao tiếp trừu tượng (Interfaces/Services) và lớp cài đặt mẫu cho module tiếp theo: `features/export/` (kết xuất thống kê CSV/JSON).

---

### Task 1: Create Export Feature Elements

- [ ] **Step 1: Định nghĩa thực thể `ExportJob`**
  Tạo tệp mới [export_job.dart](file:///d:/diemsoluong/lib/features/export/domain/entities/export_job.dart) chứa thông tin của một tác vụ kết xuất:
  - `String id`: ID duy nhất.
  - `String filePath`: Đường dẫn lưu tệp xuất ra.
  - `DateTime timestamp`: Thời điểm xuất.
  - `bool isSuccess`: Trạng thái thành công hay thất bại.

- [ ] **Step 2: Định nghĩa abstract `Exporter`**
  Tạo tệp mới [exporter.dart](file:///d:/diemsoluong/lib/features/export/domain/services/exporter.dart) định nghĩa contract giao tiếp kết xuất:
  ```dart
  import '../entities/export_job.dart';

  abstract class Exporter {
    Future<ExportJob> exportData(
      String fileName,
      Map<String, dynamic> data,
    );
  }
  ```

- [ ] **Step 3: Cài đặt CSV & JSON Exporters mẫu**
  Tạo tệp mới [csv_exporter.dart](file:///d:/diemsoluong/lib/features/export/data/exporters/csv_exporter.dart) cài đặt ghi dữ liệu thành chuỗi CSV phẳng kế thừa `Exporter`.
  Tạo tệp mới [json_exporter.dart](file:///d:/diemsoluong/lib/features/export/data/exporters/json_exporter.dart) cài đặt ghi dữ liệu thành tệp tin JSON kế thừa `Exporter`.

---

### Task 2: Verification

- [ ] **Step 1: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 2: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

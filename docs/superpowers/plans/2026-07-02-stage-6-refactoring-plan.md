# Refactoring Roadmap - Stage 6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khai báo cấu trúc thư mục, các thực thể nghiệp vụ (Entities), các lớp giao tiếp trừu tượng (Interfaces/Services) và lớp cài đặt mẫu cho module cuối cùng: `features/model_management/` (quản lý, tải và chuyển đổi giữa các mô hình).

---

### Task 1: Create Model Management Feature Elements

- [ ] **Step 1: Định nghĩa thực thể `ModelInfo`**
  Tạo tệp mới [model_info.dart](file:///d:/diemsoluong/lib/features/model_management/domain/entities/model_info.dart) chứa cấu hình thông tin mô hình:
  - `String id`: ID duy nhất.
  - `String name`: Tên hiển thị.
  - `String backend`: Nền tảng suy luận (TFLite, ONNX, NCNN).
  - `String path`: Đường dẫn lưu trữ (asset hoặc local file path).
  - `int inputSize`: Kích thước ảnh đầu vào (ví dụ: 640).
  - `List<String> labels`: Danh sách nhãn lớp nhận diện.

- [ ] **Step 2: Định nghĩa abstract `ModelRepository`**
  Tạo tệp mới [model_repository.dart](file:///d:/diemsoluong/lib/features/model_management/domain/repositories/model_repository.dart) định nghĩa contract giao tiếp:
  ```dart
  import '../entities/model_info.dart';

  abstract class ModelRepository {
    Future<List<ModelInfo>> getAvailableModels();
    Future<void> downloadModel(ModelInfo model);
    Future<bool> validateModelFile(String localPath);
  }
  ```

- [ ] **Step 3: Cài đặt `ModelRepositoryImpl` mẫu**
  Tạo tệp mới [model_repository_impl.dart](file:///d:/diemsoluong/lib/features/model_management/data/repositories/model_repository_impl.dart) thực thi contract, cung cấp danh sách mô hình mặc định sẵn có trong ứng dụng (ví dụ: YOLOv8n) kế thừa `ModelRepository`.

---

### Task 2: Verification

- [ ] **Step 1: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 2: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

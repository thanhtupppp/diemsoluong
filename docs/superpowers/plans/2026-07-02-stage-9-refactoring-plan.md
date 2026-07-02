# Refactoring Roadmap - Stage 9 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tích hợp bộ đổi mô hình nhận diện (`model_management`) động vào luồng quản lý trạng thái (`DetectorNotifier`), cho phép đổi mô hình qua giao diện (`HomeScreen`) bằng Dropdown và nạp lại mô hình trong background isolate.

---

### Task 1: Integrate Model Swap into Notifier and Isolate

- [x] **Step 1: Cấu hình `InferenceIsolate` hỗ trợ nhận đường dẫn mô hình động**
- [x] **Step 2: Cập nhật `TfliteService` để tái khởi động Isolate khi thay đổi model**
- [x] **Step 3: Tích hợp `ModelRepository` vào `DetectorNotifier`**

---

### Task 2: Add Dropdown Selector in HomeScreen AppBar

- [x] **Step 1: Hiển thị DropdownButton trong AppBar hành động của HomeScreen**
- [x] **Step 2: Bắt sự kiện thay đổi và kích hoạt `selectModel`**

---

### Task 3: Verification

- [x] **Step 1: Chạy linter toàn cục**
  Run: `flutter analyze`
  Expected: No issues found!

- [x] **Step 2: Chạy test suite**
  Run: `flutter test`
  Expected: All tests passed!

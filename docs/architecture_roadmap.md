# Scalable Feature-First Architectural Refactoring Roadmap

Tài liệu này đặc tả chi tiết kế hoạch tái cấu trúc hệ thống (Refactoring Roadmap) sang mô hình kiến trúc **Feature-First kết hợp phân lớp chức năng rõ ràng (Layered Features)**. Đây là thiết kế tiêu chuẩn giúp dự án dễ dàng mở rộng khi bổ sung các mô hình mới (YOLO11, YOLO12, RT-DETR), các cơ chế Tracking vật lý, và hỗ trợ đa nền tảng suy luận (TFLite, ONNX, NCNN).

---

## 1. Cấu trúc thư mục đề xuất (Target Folder Structure)

```text
lib/
├── app/                                 # Cấu hình toàn cục của ứng dụng
│   ├── app.dart                         # Widget App gốc
│   ├── router/                          # Định tuyến ứng dụng
│   │   └── app_router.dart
│   └── providers/                       # Riverpod providers toàn cục
│       └── app_providers.dart
│
├── core/                                # Tiện ích và dịch vụ chia sẻ toàn hệ thống
│   ├── constants/                       # Hằng số cấu hình
│   │   ├── app_constants.dart
│   │   ├── camera_constants.dart
│   │   └── model_constants.dart
│   ├── errors/                          # Quản lý lỗi hệ thống
│   │   ├── app_exception.dart
│   │   └── app_failure.dart
│   ├── utils/                           # Tiện ích chung
│   │   ├── logger.dart
│   │   ├── stopwatch_helper.dart
│   │   └── image_utils.dart
│   ├── services/                        # Dịch vụ hệ thống (Benchmark, Storage)
│   │   ├── benchmark_service.dart
│   │   └── storage_service.dart
│   └── widgets/                         # Widget dùng chung toàn cục
│       ├── app_loading.dart
│       └── app_error_view.dart
│
├── shared/                              # Mô hình và Enums dùng chung giữa các Feature
│   ├── models/                          # Dữ liệu truyền nhận
│   │   ├── detection.dart
│   │   ├── tracked_object.dart
│   │   ├── frame_packet.dart
│   │   ├── inference_stats.dart
│   │   └── model_info.dart
│   ├── enums/                           # Kiểu liệt kê (DetectorBackend, TrackerStatus)
│   │   ├── detector_backend.dart
│   │   └── tracker_status.dart
│   └── providers/
│       └── shared_providers.dart
│
├── features/                            # Các tính năng nghiệp vụ độc lập (Feature-First)
│   ├── camera/                          # Nghiệp vụ quản lý Camera & Scheduler
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   └── camera_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── camera_preview_view.dart
│   │   │   │   ├── detector_overlay.dart
│   │   │   │   ├── stats_panel.dart
│   │   │   │   └── control_bar.dart
│   │   │   └── viewmodels/
│   │   │       └── camera_view_model.dart
│   │   ├── application/
│   │   │   ├── camera_orchestrator.dart
│   │   │   ├── frame_queue_manager.dart
│   │   │   └── capture_scheduler.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── camera_frame.dart
│   │   │   ├── repositories/
│   │   │   │   └── camera_repository.dart
│   │   │   └── usecases/
│   │   │       ├── start_camera.dart
│   │   │       ├── stop_camera.dart
│   │   │       └── stream_frames.dart
│   │   └── data/
│   │       ├── repositories/
│   │       │   └── camera_repository_impl.dart
│   │       └── services/
│   │           └── camera_service.dart
│   │
│   ├── detection/                       # Nghiệp vụ suy luận & Phân tích hình ảnh
│   │   ├── presentation/
│   │   │   ├── widgets/
│   │   │   │   ├── detector_painter.dart
│   │   │   │   └── detection_badge.dart
│   │   │   └── viewmodels/
│   │   │       └── detection_view_model.dart
│   │   ├── application/
│   │   │   ├── detection_pipeline.dart
│   │   │   ├── inference_worker.dart
│   │   │   └── model_session_manager.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── detection_result.dart
│   │   │   │   └── preprocess_result.dart
│   │   │   ├── repositories/
│   │   │   │   └── detector_repository.dart
│   │   │   ├── services/
│   │   │   │   └── detector.dart        # Abstract interface Detector
│   │   │   └── usecases/
│   │   │       ├── run_detection.dart
│   │   │       ├── decode_detections.dart
│   │   │       ├── apply_nms.dart
│   │   │       └── map_to_original_image.dart
│   │   └── data/
│   │       ├── repositories/
│   │       │   └── detector_repository_impl.dart
│   │       ├── detectors/               # Đa nền tảng suy luận (TFLite, ONNX, NCNN)
│   │       │   ├── tflite_detector.dart
│   │       │   ├── onnx_detector.dart
│   │       │   └── ncnn_detector.dart
│   │       ├── services/
│   │       │   ├── tflite_service.dart
│   │       │   ├── image_service.dart
│   │       │   └── model_loader.dart
│   │       └── isolates/
│   │           └── inference_isolate.dart
│   │
│   ├── tracking/                        # Nghiệp vụ bám đuôi đối tượng (Object Tracking)
│   │   ├── presentation/
│   │   │   └── viewmodels/
│   │   │       └── tracking_view_model.dart
│   │   ├── application/
│   │   │   └── tracking_pipeline.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── track.dart
│   │   │   ├── services/
│   │   │   │   └── tracker.dart
│   │   │   └── usecases/
│   │   │       ├── update_tracks.dart
│   │   │       └── match_detections.dart
│   │   └── data/
│   │       └── trackers/
│   │           ├── centroid_tracker.dart
│   │           └── iou_tracker.dart
│   │
│   ├── counting/                        # Nghiệp vụ đếm vật thể cắt vạch/vùng
│   │   ├── presentation/
│   │   │   └── widgets/
│   │   │       └── counter_panel.dart
│   │   ├── application/
│   │   │   └── counting_pipeline.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── counting_result.dart
│   │   │   │   └── counting_line.dart
│   │   │   ├── services/
│   │   │   │   └── counter.dart
│   │   │   └── usecases/
│   │   │       ├── count_crossing.dart
│   │   │       └── reset_counter.dart
│   │   └── data/
│   │       └── counters/
│   │           └── line_cross_counter.dart
│   │
│   ├── overlay/                         # Nghiệp vụ tổng hợp Render Overlay UI
│   │   ├── presentation/
│   │   │   ├── widgets/
│   │   │   │   ├── overlay_canvas.dart
│   │   │   │   ├── track_painter.dart
│   │   │   │   └── counting_line_painter.dart
│   │   │   └── viewmodels/
│   │   │       └── overlay_view_model.dart
│   │   ├── application/
│   │   │   └── overlay_composer.dart
│   │   └── domain/
│   │       └── usecases/
│   │           └── build_overlay_scene.dart
│   │
│   ├── export/                          # Nghiệp vụ kết xuất thống kê
│   │   ├── presentation/
│   │   │   └── screens/
│   │   │       └── export_screen.dart
│   │   ├── application/
│   │   │   └── export_orchestrator.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── export_job.dart
│   │   │   └── usecases/
│   │   │       ├── export_csv.dart
│   │   │       ├── export_json.dart
│   │   │       └── export_image.dart
│   │   └── data/
│   │       └── exporters/
│   │           ├── csv_exporter.dart
│   │           ├── json_exporter.dart
│   │           └── image_exporter.dart
│   │
│   └── model_management/                # Nghiệp vụ quản lý, cập nhật tải mô hình
│       ├── presentation/
│       │   └── screens/
│       │       └── model_management_screen.dart
│       ├── application/
│       │   └── model_manager.dart
│       ├── domain/
│       │   ├── repositories/
│       │   │   └── model_repository.dart
│       │   └── usecases/
│       │       ├── get_models.dart
│       │       ├── select_model.dart
│       │       └── validate_model.dart
│       └── data/
│           ├── repositories/
│           │   └── model_repository_impl.dart
│           └── services/
│               ├── model_registry.dart
│               └── model_loader.dart
│
└── main.dart
```

---

## 2. Luồng dữ liệu nghiệp vụ (Modular Data Pipeline)

Khi luồng camera chạy, dữ liệu frame đi qua chuỗi xử lý bất đồng bộ, tuần tự và khép kín:

1. **Camera Stream**: Camera kích hoạt thu nhận khung hình.
2. **FrameQueueManager**: Điều phối hàng đợi frame, loại bỏ frame thừa khi phần cứng bị quá tải để tránh hiện tượng lag tích lũy.
3. **InferenceWorker**: Nạp tệp ảnh vào worker isolate để tiền xử lý (letterbox) và chạy suy luận mô hình.
4. **TrackingPipeline**: Gán nhãn nhận diện (ID định danh) cho từng vật thể theo thời gian để theo dõi chuyển động.
5. **CountingPipeline**: Phân tích tọa độ di chuyển của vật thể bám đuôi so với vạch đếm (counting line) hoặc vùng giới hạn (counting zone).
6. **OverlayComposer**: Tổng hợp tọa độ vẽ box, đường bám đuôi, và chỉ số đếm để chuyển lên canvas.
7. **ExportOrchestrator**: Lưu trữ các sự kiện đếm và kết xuất dữ liệu thống kê khi có yêu cầu.

---

## 3. Khai báo Interfaces Abstraction cho Suy Luận và Mô Hình

### A. Interface `Detector` chung
Tọa lạc tại `lib/features/detection/domain/services/detector.dart`:

```dart
import 'dart:typed_data';
import '../../../shared/models/detection.dart';

abstract class Detector {
  bool get isReady;
  
  Future<void> initialize();
  
  Future<List<Detection>> detect(
    Uint8List imageBytes, {
    double confidenceThreshold,
    double iouThreshold,
  });
  
  Future<void> dispose();
}
```

### B. Interface quản lý mô hình `ModelRepository`
Tọa lạc tại `lib/features/model_management/domain/repositories/model_repository.dart`:

```dart
import '../../../shared/models/model_info.dart';

abstract class ModelRepository {
  Future<List<ModelInfo>> getAvailableModels();
  Future<void> downloadModel(ModelInfo model);
  Future<bool> validateModelFile(String localPath);
}
```

---

## 4. Lộ trình Refactor theo giai đoạn (Stage-Based Refactoring Roadmap)

Để bảo đảm ứng dụng luôn ở trạng thái biên dịch và chạy được trong suốt quá trình tái cấu trúc, chúng ta thực hiện theo 6 giai đoạn sau:

| Giai đoạn | Nội dung công việc | Mục tiêu |
| :--- | :--- | :--- |
| **Giai đoạn 1** | **Tái cấu trúc feature `detection`** | Di chuyển `image_service.dart`, `tflite_service.dart`, và `inference_isolate.dart` vào `features/detection/data/`. Tạo interface `Detector` và cài đặt `TfliteDetector`. |
| **Giai đoạn 2** | **Tách độc lập feature `camera`** | Đưa `camera_screen.dart` vào `features/camera/presentation/`. Thiết lập orchestrator quản lý vòng đời camera riêng biệt với phần painter vẽ overlay. |
| **Giai đoạn 3** | **Tách biệt hiển thị vẽ `overlay`** | Tách `DetectorPainter` thành lớp Composer độc lập nhận danh sách box chung, hỗ trợ việc vẽ thêm đường track hoặc nét đứt sau này. |
| **Giai đoạn 4** | **Phát triển tính năng `tracking` & `counting`** | Triển khai thuật toán theo dõi Centroid Tracker/IoU Tracker trong `features/tracking/` và đếm cắt vạch trong `features/counting/`. |
| **Giai đoạn 5** | **Thêm nghiệp vụ kết xuất `export`** | Viết các lớp dịch vụ hỗ trợ xuất báo cáo định dạng CSV/JSON và ảnh chụp sự kiện nhận diện. |
| **Giai đoạn 6** | **Tích hợp quản lý `model_management`** | Cài đặt UI quản lý mô hình và cơ chế nạp Interpreter động từ tệp tin cục bộ hoặc tải về từ Cloud. |

---

## 5. Tổ chức kiểm thử Feature-First (Test Suite Placement)

Để hỗ trợ việc kiểm thử cô lập từng module nghiệp vụ độc lập, cấu trúc thư mục test được tổ chức song song trực tiếp với cấu trúc feature:

```text
test/
├── features/
│   ├── detection/
│   │   ├── decode_yolo_output_test.dart       # Kiểm thử giải mã tensor YOLOv8
│   │   ├── nms_filter_test.dart               # Kiểm thử triệt tiêu hộp trùng lặp NMS
│   │   └── map_to_original_image_test.dart    # Kiểm thử unletterbox tọa độ ngược
│   │
│   ├── tracking/
│   │   └── centroid_tracker_test.dart         # Kiểm thử thuật toán bám đuôi vật thể
│   │
│   └── counting/
│       └── line_cross_counter_test.dart       # Kiểm thử thuật toán cắt vạch đếm số lượng
│
└── widget_test.dart                           # Kiểm thử tải Widget khởi đầu
```

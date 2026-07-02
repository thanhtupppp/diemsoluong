# Thiết kế Ứng dụng Quét và Đếm số lượng Vật thể (Flutter + YOLOv8 on-device)

Tài liệu này mô tả chi tiết thiết kế hệ thống, kiến trúc ứng dụng di động Flutter và quy trình xử lý AI on-device để quét và đếm số lượng vật thể dựa trên mô hình YOLOv8 custom.

---

## 1. Giới thiệu & Mục tiêu

Ứng dụng giúp người dùng chụp ảnh từ camera hoặc chọn ảnh từ thư viện, sử dụng mô hình học sâu YOLOv8 (định dạng TensorFlow Lite/LiteRT) chạy offline trực tiếp trên thiết bị (on-device) để phát hiện và đếm số lượng vật thể nhỏ, dày đặc (ví dụ: hạt gạo, viên thuốc, linh kiện điện tử).

### Yêu cầu kỹ thuật chính:
- **Tốc độ**: Thời gian xử lý inference và hậu xử lý thấp, không gây giật lag giao diện (UI Thread chạy ở mức 60fps).
- **Độ chính xác**: Lọc chính xác các box trùng lặp thông qua thuật toán NMS tối ưu viết bằng Dart.
- **Tiện ích**: Hỗ trợ camera stream real-time (có throttle để giảm tải) và tải ảnh tĩnh từ Gallery.
- **Tính khả thi**: Hướng dẫn cụ thể cách huấn luyện mô hình custom và xuất sang dạng TFLite.

---

## 2. Kiến trúc Ứng dụng (Clean Architecture)

Áp dụng Clean Architecture chia hệ thống thành 3 tầng chính để đảm bảo tính độc lập giữa logic nghiệp vụ (business logic) và giao diện UI, thuận tiện cho việc viết Unit Test:

```
lib/
├── core/
│   └── isolate/
│       └── inference_isolate.dart   # Quản lý spawn/giao tiếp Background Isolate
├── data/
│   ├── models/
│   │   ├── detection.dart          # Class chứa thông tin box: Rect, classId, score
│   │   └── model_config.dart       # Cấu hình model (input size, thresholds, class labels)
│   └── services/
│       ├── tflite_service.dart      # Khởi tạo Interpreter, chạy inference thô
│       └── image_service.dart       # Helper xử lý ảnh (convert formats, resize, normalization)
├── domain/
│   ├── usecases/
│   │   ├── decode_yolo_output.dart  # Argmax + filter 1-pass để chuyển tensor thành danh sách box
│   │   └── nms_filter.dart          # Thuật toán Non-Maximum Suppression lọc trùng lặp
├── presentation/
│   ├── state/
│   │   └── detector_notifier.dart   # Quản lý state của bộ nhận diện bằng Riverpod 3.x Notifier
│   ├── screens/
│   │   ├── home_screen.dart         # Màn hình chính (chọn ảnh tĩnh, hiển thị kết quả vẽ box)
│   │   └── camera_screen.dart       # Màn hình live-stream camera (có throttle)
│   └── widgets/
│       └── detector_painter.dart    # CustomPainter vẽ bounding boxes & labels lên ảnh gốc
└── main.dart
```

---

## 3. Luồng xử lý Ảnh & Background Isolate

Do việc chuẩn hóa ảnh và chạy mô hình TensorFlow Lite rất nặng về mặt tính toán CPU, toàn bộ luồng xử lý sẽ được chạy dưới một **Background Isolate** riêng.

```
+------------------------------------------+        +------------------------------------------+
|             Main UI Isolate              |        |            Background Isolate            |
+------------------------------------------+        +------------------------------------------+
|  1. Nhận CameraImage (YUV) hoặc Gallery  |        |                                          |
|                                          |        |                                          |
|  2. Gửi qua SendPort ------------------->|------->| 3. Chuyển đổi định dạng sang RGB         |
|                                          |        |    (YUV/BGRA -> RGB Uint8List)           |
|                                          |        |                                          |
|                                          |        | 4. Resize ảnh về kích thước 640x640      |
|                                          |        |    và áp dụng Padding (Letterbox)        |
|                                          |        |                                          |
|                                          |        | 5. Chuẩn hóa pixel về Float32 [0.0 - 1.0]|
|                                          |        |                                          |
|                                          |        | 6. Chạy mô hình: TFLite Interpreter      |
|                                          |        |    (sử dụng RootIsolateToken)            |
|                                          |        |                                          |
|                                          |        | 7. Giải mã tensor & NMS                  |
|                                          |        |                                          |
|  8. Nhận List<Detection> <---------------+|<-------| 8. Trả kết quả về qua SendPort           |
|                                          |        |                                          |
|  9. Vẽ Box & Count lên UI                |        |                                          |
+------------------------------------------+        +------------------------------------------+
```

### Chi tiết Tối ưu hóa:
1.  **Hardware Delegate**: Sử dụng CPU đa luồng (`options.threads = 4`) kết hợp NNAPI trên Android (`options.useNnApiForAndroid = true`) để tối đa hóa tốc độ inference mà không làm app bị crash (do lỗi thư viện GPU delegate của tflite_flutter).
2.  **Throttle Camera Stream**: Chỉ xử lý 1 frame mỗi `300ms - 500ms` thay vì toàn bộ frame của camera để giảm nhiệt độ máy và tiết kiệm pin.
3.  **Isolate Serialization**: Chuyển đổi dữ liệu thô của camera frame thành `Uint8List` trước khi gửi qua `SendPort` nhằm tránh lỗi lỗi crash do không thể tuần tự hóa (serialize) đối tượng phức tạp như `CameraImage`.

---

## 4. Giải mã Tensor Output & Thuật toán NMS

Đầu ra mặc định của YOLOv8 tflite có shape `[1, 4 + N, 8400]` (N là số lượng class).

### 4.1. Giải mã một vòng (1-pass Argmax & Decode)
Thay vì sử dụng mảng đa chiều lồng nhau gây overhead bộ nhớ trong Dart, ta đọc dữ liệu từ mảng phẳng `Float32List` kích thước `(4 + N) * 8400` theo cấu trúc row-major.

Hàm decode được thiết kế để tìm Class có score lớn nhất (Argmax) và lọc theo confidence threshold trong duy nhất **1 vòng lặp**:

```dart
List<Detection> decodeDetections(Float32List output, int numBoxes, int numClasses, double confThreshold) {
  final List<Detection> results = [];
  
  for (int i = 0; i < numBoxes; i++) {
    double maxScore = 0.0;
    int maxClassId = -1;
    
    // Tìm class có độ tin cậy cao nhất (Argmax)
    for (int c = 0; c < numClasses; c++) {
      final score = output[(4 + c) * numBoxes + i];
      if (score > maxScore) {
        maxScore = score;
        maxClassId = c;
      }
    }
    
    // Chỉ giữ lại box có score lớn hơn ngưỡng tin cậy
    if (maxScore >= confThreshold) {
      // YOLOv8 xuất toạ độ chuẩn hoá [0.0 - 1.0] so với kích thước đầu vào (640)
      final xCenter = output[i] * 640.0;
      final yCenter = output[numBoxes + i] * 640.0;
      final w = output[2 * numBoxes + i] * 640.0;
      final h = output[3 * numBoxes + i] * 640.0;
      
      results.add(Detection(
        rect: Rect.fromLTWH(xCenter - w / 2, yCenter - h / 2, w, h),
        classId: maxClassId,
        score: maxScore,
      ));
    }
  }
  return results;
}
```

### 4.2. Khử trùng lặp (Non-Maximum Suppression)
Sắp xếp danh sách box theo score giảm dần. Lần lượt lấy box đầu tiên có score lớn nhất đưa vào danh sách kết quả, tính IoU (Intersection over Union) với các box còn lại. Loại bỏ bất cứ box nào cùng class có IoU lớn hơn ngưỡng `iouThreshold` (mặc định `0.45`).

### 4.3. Inverse-Letterbox Mapping
Vì kích thước ảnh gốc không phải hình vuông (VD: 1920x1080) nhưng mô hình nhận đầu vào 640x640 bằng cách thêm viền đen (Letterboxing), ta cần viết thêm logic chuyển đổi ngược tọa độ:
*   Loại bỏ phần padding của tỷ lệ ảnh.
*   Scale tọa độ box từ không gian `640x640` về lại đúng kích thước của widget vẽ ảnh trên UI.

---

## 5. Pipeline Huấn luyện & Xuất Mô hình (Python)

Quy trình train mô hình YOLOv8 custom và xuất ra file `.tflite` tương thích được thực hiện qua script Python sau:

```python
import os
from roboflow import Roboflow
from ultralytics import YOLO

# 1. Tải dataset từ Roboflow (định dạng YOLOv8)
rf = Roboflow(api_key="YOUR_ROBOFLOW_API_KEY")
project = rf.workspace("workspace-id").project("project-id")
version = project.version(1)
dataset = version.download("yolov8")
data_yaml = os.path.join(dataset.location, "data.yaml")

# 2. Khởi tạo mô hình YOLOv8n pretrained
model = YOLO('yolov8n.pt')

# 3. Huấn luyện (Fine-tuning)
results = model.train(data=data_yaml, epochs=100, imgsz=640, device=0)

# 4. Đánh giá độ chính xác
metrics = model.val()
print(f"mAP50-95: {metrics.box.map}")

# 5. Xuất mô hình sang LiteRT (.tflite) chuẩn hóa
# Float32 (Baseline)
model.export(format='litert', imgsz=640)

# Float16 (Được khuyên dùng cho release đầu tiên)
model.export(format='litert', imgsz=640, half=True)

# INT8 (Quantized - bắt buộc phải có representative dataset truyền qua tham số 'data')
model.export(format='litert', imgsz=640, int8=True, data=data_yaml)
```

### Chiến lược Triển khai Mô hình (Quantization Plan):
*   **Giai đoạn 1**: Sử dụng bản **Float16** (`yolov8n_float16.tflite` kích thước ~6MB). Độ chính xác gần như nguyên vẹn so với mô hình gốc, không yêu cầu cấu hình representative dataset phức tạp, chạy mượt trên CPU đa luồng.
*   **Giai đoạn 2**: Kiểm tra và tối ưu sang bản **INT8** (`yolov8n_int8.tflite` kích thước ~3MB) sau khi đã thu thập đủ lượng ảnh thực tế của người dùng làm representative dataset chuẩn hóa, tăng hiệu suất cho các máy Android cấu hình yếu.

---

## 6. Kế hoạch xác thực (Verification Plan)

### Kiểm thử Tự động (Automated Tests)
1.  **Unit Test bộ giải mã NMS**: Viết unit test truyền vào danh sách các bounding box trùng lặp giả lập và kiểm tra xem hàm `applyNMS` có trả về đúng số lượng box duy nhất và loại bỏ đúng box mong muốn không.
2.  **Unit Test bộ Inverse-Letterbox**: Kiểm thử hàm ánh xạ tọa độ từ `640x640` sang kích thước ảnh gốc `1920x1080` (và ngược lại) để đảm bảo không bị lệch tọa độ.

### Xác thực Thủ công (Manual Verification)
1.  **Inference Time**: Đo thời gian thực hiện hàm `decodeDetections` và `applyNMS` trong Background Isolate để đảm bảo tổng thời gian xử lý của mỗi ảnh dưới 100ms.
2.  **Độ chính xác trực quan**: Chụp ảnh một tập hợp vật thể mẫu (ví dụ: 10 viên thuốc hoặc 15 linh kiện), kiểm tra xem giao diện có vẽ đúng 10/15 bounding boxes ôm khít vật thể hay không và phần text hiển thị tổng số lượng đếm được có chính xác hay không.

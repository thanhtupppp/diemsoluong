# Hướng dẫn Huấn luyện và Xuất mô hình YOLOv8 sang LiteRT

Mục này cung cấp script Python để huấn luyện mô hình đếm vật thể custom và copy vào ứng dụng Flutter.

## Hướng dẫn nhanh

1. Gán nhãn dữ liệu của bạn trên [Roboflow](https://roboflow.com).
2. Xuất dữ liệu định dạng **YOLOv8**.
3. Chạy file `train_and_export.py` trên Google Colab hoặc máy có GPU cục bộ:
   ```bash
   pip install ultralytics roboflow
   python train_and_export.py
   ```
4. Copy file mô hình sinh ra từ thư mục weights (ví dụ: `yolov8n_float16.tflite`) vào thư mục `assets/models/` trong dự án Flutter của bạn.
5. Cập nhật `ModelConfig.modelAssetPath` trong `lib/data/models/model_config.dart` trỏ đến file mới.

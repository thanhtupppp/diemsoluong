import os
from roboflow import Roboflow
from ultralytics import YOLO

def main():
    # Điền thông tin API Roboflow của bạn tại đây
    api_key = "YOUR_ROBOFLOW_API_KEY"
    workspace_name = "workspace-id"
    project_name = "project-id"
    version_num = 1

    print("--- 1. Tải Dataset từ Roboflow ---")
    try:
        rf = Roboflow(api_key=api_key)
        project = rf.workspace(workspace_name).project(project_name)
        version = project.version(version_num)
        dataset = version.download("yolov8")
        data_yaml = os.path.join(dataset.location, "data.yaml")
        print(f"Dataset downloaded to: {dataset.location}")
    except Exception as e:
        print(f"Lỗi tải dataset (Vui lòng thay API key hợp lệ): {e}")
        return

    print("\n--- 2. Khởi tạo mô hình YOLOv8n ---")
    model = YOLO('yolov8n.pt')

    print("\n--- 3. Huấn luyện mô hình ---")
    model.train(data=data_yaml, epochs=100, imgsz=640, device=0)

    print("\n--- 4. Đánh giá mô hình ---")
    metrics = model.val()
    print(f"mAP50-95: {metrics.box.map}")

    print("\n--- 5. Xuất mô hình sang LiteRT (.tflite) ---")
    # FP32 Baseline
    model.export(format='litert', imgsz=640)
    
    # FP16 - Khuyên dùng cho Release đầu tiên
    print("Exporting Float16 quantized model...")
    model.export(format='litert', imgsz=640, half=True)
    
    # INT8 Quantized - Phải có data.yaml
    print("Exporting INT8 quantized model (with representative data)...")
    model.export(format='litert', imgsz=640, int8=True, data=data_yaml)
    
    print("\nQuá trình hoàn tất! Kiểm tra thư mục runs/detect/train/weights/ để lấy file mô hình.")

if __name__ == '__main__':
    main()

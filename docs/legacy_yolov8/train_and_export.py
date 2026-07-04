import os
import multiprocessing
import torch
from roboflow import Roboflow
from ultralytics import YOLO

def main():
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

    device = 0 if torch.cuda.is_available() else 'cpu'
    print(f"\n--- 2. Khởi tạo mô hình YOLOv8n (device={device}) ---")
    model = YOLO('yolov8n.pt')

    print("\n--- 3. Huấn luyện mô hình ---")
    model.train(
        data=data_yaml,
        epochs=100,
        imgsz=640,
        device=device,
        batch=16,
        patience=20,
        name='object_counter_v1',
    )

    print("\n--- 4. Đánh giá mô hình ---")
    metrics = model.val()
    print(f"mAP50-95: {metrics.box.map}")

    print("\n--- 5. Xuất mô hình sang LiteRT (.tflite) ---")
    model.export(format='litert', imgsz=640)
    print("Exporting Float16 quantized model...")
    model.export(format='litert', imgsz=640, half=True)
    print("Exporting INT8 quantized model (with representative data)...")
    model.export(format='litert', imgsz=640, int8=True, data=data_yaml)

    print("\nQuá trình hoàn tất! Kiểm tra thư mục runs/detect/object_counter_v1/weights/ để lấy file mô hình.")

if __name__ == '__main__':
    multiprocessing.freeze_support()
    main()

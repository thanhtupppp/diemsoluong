# Training and Export

This folder contains training utilities for creating a custom YOLO model for the Flutter object-counting app.

## Recommended: Google Colab

Use:

```text
python_scripts/colab_yolov8_train_export.ipynb
```

Steps:

1. Upload the notebook to Google Colab.
2. Select `Runtime -> Change runtime type -> T4 GPU`.
3. Choose dataset source:
   - `roboflow`: fill `ROBOFLOW_API_KEY`, `ROBOFLOW_WORKSPACE`, `ROBOFLOW_PROJECT`, `ROBOFLOW_VERSION`.
   - `drive_zip`: upload a YOLO dataset ZIP to Google Drive and set `DRIVE_ZIP_PATH`.
4. Run all cells.
5. Download the exported `.tflite` file.
6. Copy it into the Flutter app:

```text
assets/models/yolov8n_float16.tflite
```

or update both:

```text
pubspec.yaml
lib/data/models/model_config.dart
```

## Dataset Format

The dataset should be YOLO detection format:

```text
dataset/
  data.yaml
  train/
    images/
    labels/
  valid/ or val/
    images/
    labels/
  test/ optional
```

`data.yaml` must contain class names, for example:

```yaml
path: /content/dataset
train: train/images
val: valid/images
names:
  0: product
```

## Export Notes

Recent Ultralytics versions export mobile `.tflite` files with:

```python
model.export(format="litert", imgsz=640, half=True)
```

Older versions may use:

```python
model.export(format="tflite", imgsz=640, half=True)
```

The Colab notebook tries `litert` first and falls back to `tflite`.

After export, inspect the TFLite output tensor shape in the notebook and confirm `ModelConfig.boxCoordinateFormat`:

- `BoxCoordinateFormat.normalized` if `x_center, y_center, width, height` are `0..1`.
- `BoxCoordinateFormat.pixels` if they are already in model pixels such as `0..640`.

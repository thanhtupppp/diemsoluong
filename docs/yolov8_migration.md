# YOLOv8 Migration Notes

YOLOv8 is no longer the active runtime path for this Flutter app. The current
runtime uses Google AI Edge / MediaPipe EfficientDet-Lite0 with a Dart decoder
for raw EfficientDet tensors.

The old YOLOv8 training/export utilities were moved out of the active project
root and kept only for historical reference:

```text
docs/legacy_yolov8/colab_yolov8_train_export.ipynb
docs/legacy_yolov8/train_and_export.py
```

Do not copy those outputs into the app without also restoring or rewriting a
YOLO-compatible decoder. The active decoder expects EfficientDet-style raw
box offsets and class scores.

Current runtime docs:

- `README.md`
- `docs/model_maker.md`
- `docs/runtime_verification.md`

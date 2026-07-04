# Legacy YOLOv8 Utilities

These files are kept only for historical migration reference. They are not part
of the active Google AI Edge / MediaPipe runtime.

Current runtime documentation lives in:

- `README.md`
- `docs/model_maker.md`
- `docs/runtime_verification.md`

Legacy files:

- `colab_yolov8_train_export.ipynb`
- `train_and_export.py`

The current app no longer declares a YOLO asset in `pubspec.yaml`, no longer
uses a YOLO decoder, and does not expect YOLO output tensors.

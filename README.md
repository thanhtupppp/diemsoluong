# Real-Time Object Detection & Counting App

Flutter app for on-device object detection and counting with YOLOv8 exported to TensorFlow Lite. The app supports still-image detection, live camera scanning, object tracking, line-cross counting, overlay rendering, and CSV/JSON export.

## Features

- Still image detection from gallery or camera capture.
- Live camera scanning with `CameraController.startImageStream`.
- YUV420, NV21, BGRA8888, and JPEG camera frame conversion.
- Letterbox preprocessing to preserve aspect ratio before model inference.
- TFLite inference in a Dart isolate with recovery after worker errors/timeouts.
- YOLO output decoding with configurable box coordinate format: normalized or pixel-space.
- Class-aware Non-Maximum Suppression.
- IoU tracker with center-distance fallback for low-FPS object jumps.
- Normalized counting line coordinates, draggable line handles, and direction-aware counting.
- Canvas overlay for boxes, track paths, labels, confidence, and counting line.
- CSV and JSON export for detection/count reports.

## Current Model

The default model is declared in `pubspec.yaml`:

```yaml
assets:
  - assets/models/yolov8n_float16.tflite
```

Runtime config lives in `lib/data/models/model_config.dart`:

- Input size: `640`
- Model path: `assets/models/yolov8n_float16.tflite`
- Labels: COCO labels
- Default confidence threshold: `0.25`
- Default IoU threshold: `0.45`
- Box coordinate format: `BoxCoordinateFormat.normalized`

If a custom TFLite model outputs boxes in pixel coordinates instead of normalized coordinates, update `ModelConfig.boxCoordinateFormat` to `BoxCoordinateFormat.pixels`.

## Architecture

```mermaid
graph TD
    A[Gallery or Camera Frame] --> B[ImageService]
    B --> C[Letterbox Preprocess]
    C --> D[InferenceIsolate]
    D --> E[TFLite Interpreter]
    E --> F[decodeDetections]
    F --> G[Unletterbox to Original Image Space]
    G --> H[applyNMS]
    H --> I[IouTracker]
    I --> J[LineCrossCounter]
    J --> K[DetectorNotifier]
    K --> L[HomeScreen or CameraScreen]
    L --> M[OverlayPainter]
```

### Main Modules

- `lib/features/detection`: image preprocessing, TFLite isolate, decode, NMS.
- `lib/features/tracking`: object track IDs and path history.
- `lib/features/counting`: normalized counting line and line-cross counting.
- `lib/features/overlay`: canvas overlay and draggable counting line handles.
- `lib/features/export`: CSV/JSON export.
- `lib/features/model_management`: model metadata repository.
- `lib/presentation/state`: Riverpod app state and workflow orchestration.

## Live Camera Flow

Live mode uses `startImageStream`, throttled to one inference request at a time. The current interval is controlled by `_minInferenceInterval` in `CameraScreen`.

The stream frame is converted to JPEG bytes by `ImageService.convertCameraImage`, then reuses the same still-image preprocessing and inference path. This keeps one model pipeline for both still images and live camera frames.

Physical-device testing is still required for camera orientation and mirror behavior because Android/iOS sensor orientation can vary by device.

## Counting Behavior

Counting lines are stored as normalized coordinates:

- `(0, 0.5)` means left edge at vertical center.
- `(1, 0.5)` means right edge at vertical center.

The line is mapped to image pixels before counting and to view pixels before painting. Direction modes are:

- `CountingDirection.any`
- `CountingDirection.positive`
- `CountingDirection.negative`

## Training and Export

Recommended workflow: train and export on Google Colab using:

```text
python_scripts/colab_yolov8_train_export.ipynb
```

The notebook supports Roboflow datasets and YOLO-format ZIP datasets from Google Drive. It trains YOLOv8, validates metrics, exports `.tflite`, and prints TFLite input/output tensor details.

Example training script:

```python
from ultralytics import YOLO

model = YOLO("yolov8n.pt")
model.train(
    data="custom_dataset.yaml",
    epochs=100,
    imgsz=640,
    device=0,
)
```

Example export:

```bash
yolo export model=runs/detect/train/weights/best.pt format=tflite imgsz=640 half=True
```

After export, place the model at:

```text
assets/models/yolov8n_float16.tflite
```

or update `ModelConfig.modelAssetPath` and `pubspec.yaml` to match the new file.

## Development

Install dependencies:

```bash
flutter pub get
```

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test --reporter compact
```

Sync CodeGraph after code changes:

```bash
codegraph.cmd sync .
```

Run on a connected device:

```bash
flutter run
```

Run release mode:

```bash
flutter run --release
```

## Test Coverage

Current unit tests cover:

- YOLO detection decoding, including normalized and pixel-space boxes.
- Non-Maximum Suppression.
- Image YUV to RGB channel conversion helpers.
- TFLite service isolate recovery.
- IoU tracker matching, low-IoU center-distance fallback, and lost-track cleanup.
- Line-cross counting, duplicate-count prevention, and direction filtering.
- Initial app widget load.

## Production Checklist

- Verify camera orientation and mirror behavior on physical Android and iOS devices.
- Profile inference latency, preprocessing latency, memory, and thermal behavior.
- Confirm the active model output coordinate format before release.
- Tune live inference throttle for the target device class.
- Calibrate counting-line direction for each real installation.
- Add share/open-file UX for exported CSV/JSON reports if operators need direct handoff.

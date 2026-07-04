# MediaPipe Model Maker Workflow

This app currently runs a Google AI Edge / MediaPipe EfficientDet-Lite0 `.tflite`
model through `tflite_flutter` and decodes the raw tensors in Dart. The runtime
does not use a Flutter MediaPipe Tasks binding yet.

## Current Caveat

Google's MediaPipe Model Maker documentation marks MediaPipe Model Maker as
deprecated and no longer actively maintained, but still available. Treat this
workflow as a practical compatibility path, not a long-term platform commitment.

Primary references:

- Google AI Edge MediaPipe Model Maker: https://developers.google.com/edge/mediapipe/solutions/model_maker
- MediaPipe Object Detector task guide: https://developers.google.com/edge/mediapipe/solutions/vision/object_detector
- MediaPipe Model Maker ObjectDetector API: https://developers.google.com/edge/api/mediapipe/python/mediapipe_model_maker/object_detector/ObjectDetector
- LiteRT / TensorFlow Lite Model Maker object detection guide: https://developers.google.com/edge/litert/libraries/modify/object_detection

## Recommended Path

1. Train or customize an object detector with a Google AI Edge-compatible tool.
2. Export a `.tflite` file with metadata when possible.
3. Inspect input and output tensor shapes before putting the model in the app.
4. Copy the model to `assets/models/`.
5. Update `pubspec.yaml`.
6. Update `ModelConfig.modelAssetPath`, `ModelConfig.inputSize`, and
   `ModelConfig.cocoLabels` or the app-specific label list.
7. Update or replace the active `ObjectDetectionOutputDecoder` implementation
   if the tensor layout differs from EfficientDet-Lite0 raw outputs.

## Expected Runtime Layout

The bundled model is `assets/models/efficientdet_lite0_float16.tflite`.

The app currently expects:

- Input: `[1, 320, 320, 3]`, `float32`
- Box output: `[1, 19206, 4]`
- Score output: `[1, 19206, 90]`
- Labels: 90 sparse COCO labels, including `???` placeholder entries

Those assumptions are encoded in:

- `lib/data/models/model_config.dart`
- `lib/features/detection/domain/usecases/decode_mediapipe_detections.dart`
- `lib/features/detection/domain/services/object_detection_output_decoder.dart`

## Plug-In Checklist

Before replacing the default model:

- Confirm the exported model input size and dtype.
- Confirm whether outputs are raw EfficientDet boxes/scores or already
  post-processed detections such as count, scores, classes, and boxes.
- Confirm whether class scores are already probabilities or raw logits. The
  default bundled model uses probability-like scores, so the runtime default is
  `ScoreActivation.none`; use `sigmoid` or `softmax` only for models that need
  it.
- Confirm whether the model uses sparse class IDs and placeholder labels.
- Use `allowedClassIds` in the active decoder when the app should count only a
  subset of classes before NMS.
- Update the decode tests to match the new output layout.
- Run `flutter analyze`.
- Run `flutter test --reporter compact`.
- Test still-image detection with a known fixture image.
- Test live camera orientation and mirror behavior on a physical device.
- Test line-cross counting with the target camera angle because detector box
  footprints can shift after changing models.

## Future MediaPipe Tasks Adapter

When a suitable Flutter binding for MediaPipe Tasks is available, add a new
implementation behind the existing detection boundary instead of changing
camera, tracking, or counting code. The expected replacement point is the
decoder/inference layer:

```text
TfliteService
  -> InferenceIsolate
    -> ObjectDetectionOutputDecoder
```

The UI, `IouTracker`, and `LineCrossCounter` should continue to consume the
same `Detection` model.

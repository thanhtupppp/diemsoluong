# Camera Permissions, Inference and Test Suite Refactoring Walkthrough

This walkthrough documents all completed tasks to resolve camera runtime issues, state notifier warnings, and test coverage improvements.

## Changes Made

### 1. Camera & Photo Library Permissions Added
- **Android**: Added `android.permission.CAMERA` and `android.hardware.camera` feature declaration in [AndroidManifest.xml](file:///d:/diemsoluong/android/app/src/main/AndroidManifest.xml) before the `<application>` tag.
- **iOS**: Configured camera/photo gallery descriptions in [Info.plist](file:///d:/diemsoluong/ios/Runner/Info.plist):
  - `NSCameraUsageDescription`
  - `NSPhotoLibraryUsageDescription`

### 2. State Notifier Optimization
- **State**: Updated `DetectorState` constructor to `const` in [detector_notifier.dart](file:///d:/diemsoluong/lib/presentation/state/detector_notifier.dart) and updated `clear()` method to instantiate state with `const DetectorState()` to improve runtime efficiency and fix a linter warning.
- **Unified API Compliance**: Kept `DetectorNotifier` extending the unified `Notifier` class while utilizing `NotifierProvider.autoDispose`, conforming to Riverpod 3.0 standards.

### 3. Production-Ready Periodic Timer Capture & Lifecycle Handling in CameraScreen
- **Periodic Timer**: Replaced the infinite `while` loop in [camera_screen.dart](file:///d:/diemsoluong/lib/presentation/screens/camera_screen.dart) with a controlled `Timer.periodic` tick (scheduled every 1 second) to call `_captureAndDetect()`.
- **Async Disposal**: Split out `_disposeCamera()` to run asynchronously, ensuring that when the app lifecycle transitions or the widget is destroyed, the camera is disposed cleanly to prevent race conditions.
- **Unified State Disposal**: Updated the widget's `dispose()` lifecycle method to invoke `unawaited(_disposeCamera())`, establishing a singular and reliable resource cleanup routine.
- **Full Lifecycle Observers**: Handled all crucial app states (`inactive`, `paused`, `hidden`, and `detached`) in `didChangeAppLifecycleState` to safely release the camera, and properly reinitialize it when returning to `resumed`.
- **Reinitialization Guard**: Added `_isInitializingCamera` flag to prevent concurrent initialization requests when app states change rapidly.
- **Camera Aspect Ratio Scale Correction**: Calculated screen size vs camera preview size aspect ratio scaling factors. Wrapped the viewfinder Stack in `ClipRect` -> `Transform.scale` -> `AspectRatio` matching the `previewRatio` ($1 / \text{aspectRatio}$). This prevents image distortion (stretching) on devices of varying display proportions while ensuring the `DetectorPainter` bounding boxes remain perfectly aligned with preview pixels.
- **UX Scanning Chip**: Implemented an overlay `Chip` reading "Đang quét..." while `_isProcessing` is true to indicate background activity to the user.
- **Standard Flutter colors compatibility**: Set background box to use the standard `withValues(alpha: 0.7)` color API, as the linter of the local Flutter environment enforces it on newer versions.

### 4. Coordinated Letterbox Preprocessing & Postprocessing Mapping
- **Letterbox Resize**: Refactored `preprocessImage()` in [image_service.dart](file:///d:/diemsoluong/lib/data/services/image_service.dart) to preserve the original image's aspect ratio. The image is scaled proportionally to fit the target model input size and composited onto a square canvas padded with solid gray pixels (color value 114). The function returns a `PreprocessResult` containing the scaled input buffer along with `originalWidth`, `originalHeight`, `scale`, `padX`, and `padY` metadata.
- **Unletterbox Postprocessing**: Modified `_isolateEntryPoint` in [inference_isolate.dart](file:///d:/diemsoluong/lib/core/isolate/inference_isolate.dart) to map coordinate results from the model's canvas coordinate space `[0 - 640]` back to absolute pixels of the original image space:
  - $X_{orig} = (X_{model} - \text{padX}) / \text{scale}$
  - $Y_{orig} = (Y_{model} - \text{padY}) / \text{scale}$
  This transformation is performed immediately after decoding but before running Non-Maximum Suppression (NMS), ensuring NMS evaluates boxes under their true aspect ratios.
- **Simplified Painting**: Simplified [detector_painter.dart](file:///d:/diemsoluong/lib/presentation/widgets/detector_painter.dart) to map coordinate scaling solely from original image space to active canvas size (removing dependencies on model input sizes like `ModelConfig.inputSize`), resulting in a cleaner and decoupled layout architecture.

### 5. Optimized Bounding Box Painter (DetectorPainter) & Value Equality
- **Built-in Contain Mapping**: Replaced manual contain-fit calculation in [detector_painter.dart](file:///d:/diemsoluong/lib/presentation/widgets/detector_painter.dart) with Flutter's standard `applyBoxFit` API (`BoxFit.contain`), guaranteeing correct scaling alignment.
- **Value-based Equality Overrides**: Implemented `operator ==` and `hashCode` overrides in [detection.dart](file:///d:/diemsoluong/lib/data/models/detection.dart) to enable proper comparative evaluation of detection properties.
- **Strict Repaint Check**: Utilized `listEquals` inside `shouldRepaint()` to compare items deep in the `detections` and `labels` lists, ensuring CustomPainter redrawing occurs reliably when content changes.
- **Canvas Clipping Boundaries**: Wrapped custom drawing inside `canvas.save()` / `canvas.restore()` and applied `canvas.clipRect(Offset.zero & size)` to prevent bounding boxes and labels from rendering outside the layout boundaries.
- **Clamped Boundary Tags**: Configured label coordinates mapping to clamp `labelLeft` and `labelTop` values against both the top/left edges and the bottom/right canvas bounds (e.g. `rawTop.clamp(0.0, size.height - labelHeight)`), preventing layout bleed.
- **Improved Typography & Readability**: Changed box labels to display white text over a solid class-colored rounded background box (`withValues(alpha: 0.85)`), providing a premium look that stands out clearly over any camera viewfinder preview details.

### 6. Production-Ready YOLO Output Decoder
- **Dimension Guards**: Added checking inside [decode_yolo_output.dart](file:///d:/diemsoluong/lib/domain/usecases/decode_yolo_output.dart) to verify that the incoming flat tensor contains at least `(4 + numClasses) * numBoxes` float elements, preventing array out-of-bounds crashes.
- **Config-driven Scale**: Replaced the hardcoded `640.0` scale factor with `ModelConfig.inputSize` to make the decoder model-agnostic.
- **Edge boundary Clamping**: Computed coordinate values as standard LTRB (`left, top, right, bottom`) bounds and clamped each coordinate cleanly within the range of `[0.0, ModelConfig.inputSize]` directly after parsing.
- **Explicit Double Conversions**: Appended `.toDouble()` after `.clamp()` to satisfy the Dart analyzer and avoid type mismatches on certain platforms.
- **NaN/Infinity Protection**: Skips processing bounding boxes that decode to non-finite numbers (`!isFinite`), preventing crashes down the line.
- **Invalid Area Filtering**: Discards box decodes resulting in non-positive dimensions (`width <= 0` or `height <= 0`) to maintain a clean list for downstream NMS filtering.

### 7. Unit Test Suite Restructuring & Enhancements
- **Restructuring**: Split the old monolithic usecases test file into:
  - [decode_yolo_output_test.dart](file:///d:/diemsoluong/test/domain/decode_yolo_output_test.dart) (covers YOLOv8 decoder coordinates mapping)
  - [nms_filter_test.dart](file:///d:/diemsoluong/test/domain/nms_filter_test.dart) (covers NMS box filtering)
- **Class-aware NMS Test**: Added a new test case checking that NMS does *not* suppress overlapping boxes belonging to different class IDs.

---

## Verification Results

### 1. Static Analysis (`flutter analyze`)
- **Status**: Passed (0 issues found).
- **Console Output**:
  ```
  Analyzing diemsoluong...                                        
  No issues found! (ran in 2.9s)
  ```

### 2. Unit Tests (`flutter test`)
- **Status**: Passed (4/4 tests).
- **Console Output**:
  ```
  00:00 +0: loading D:/diemsoluong/test/domain/decode_yolo_output_test.dart
  00:00 +0: D:/diemsoluong/test/domain/decode_yolo_output_test.dart: YOLOv8 Decode Tests decodeDetections parses flat Float32List correctly
  00:00 +1: D:/diemsoluong/test/domain/nms_filter_test.dart: NMS Filter Tests applyNMS filters overlapping boxes
  00:00 +2: D:/diemsoluong/test/domain/nms_filter_test.dart: NMS Filter Tests applyNMS does not filter overlapping boxes of different classes
  00:00 +3: D:/diemsoluong/test/widget_test.dart: App loads HomeScreen successfully with title
  00:01 +4: All tests passed!
  ```

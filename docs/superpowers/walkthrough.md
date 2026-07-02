# Camera Permissions, Inference and Test Suite Refactoring Walkthrough

This walkthrough documents all completed tasks to resolve camera runtime issues, state notifier warnings, test coverage improvements, and the structural refactoring of Stage 1.

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
- **Letterbox Resize**: Refactored `preprocessImage()` in [image_service.dart](file:///d:/diemsoluong/lib/features/detection/data/services/image_service.dart) to preserve the original image's aspect ratio. The image is scaled proportionally to fit the target model input size and composited onto a square canvas padded with solid gray pixels (color value 114). The function returns a `PreprocessResult` containing the scaled input buffer along with `originalWidth`, `originalHeight`, `scale`, `padX` (representing exact floor-composited left padding), and `padY` (representing exact floor-composited top padding) metadata to avoid sub-pixel misalignment.
- **Unletterbox Postprocessing**: Modified `_isolateEntryPoint` in [inference_isolate.dart](file:///d:/diemsoluong/lib/features/detection/data/isolates/inference_isolate.dart) to map coordinate results from the model's canvas coordinate space `[0 - 640]` back to absolute pixels of the original image space:
  - $X_{orig} = (X_{model} - \text{padX}) / \text{scale}$
  - $Y_{orig} = (Y_{model} - \text{padY}) / \text{scale}$
  This transformation is performed immediately after decoding but before running Non-Maximum Suppression (NMS), ensuring NMS evaluates boxes under their true aspect ratios.
- **Simplified Painting**: Simplified [detector_painter.dart](file:///d:/diemsoluong/lib/features/detection/presentation/widgets/detector_painter.dart) to map coordinate scaling solely from original image space to active canvas size (removing dependencies on model input sizes like `ModelConfig.inputSize`), resulting in a cleaner and decoupled layout architecture.

### 5. TFLite Service Lifecycle Guards
- **Initialization Race Lock**: Configured [tflite_service.dart](file:///d:/diemsoluong/lib/features/detection/data/services/tflite_service.dart) with `Future<void>? _initializing` lock. When multiple async calls to `detectObjects()` trigger concurrently, only one initialization Future is spawned and awaited, resolving race conditions.
- **Initialization Retry Safe**: Wrapped the initialization await inside a `try`/`finally` block to clear the `_initializing` future handle on errors, allowing callers to retry startup if initialization fails.
- **State Dispose Guards**: Added an explicit `_disposed` flag constraint. Invoking operations on `TfliteService` after it has been disposed triggers a fast-failing `StateError` immediately rather than attempting isolate messages on dead resources.

### 6. Mutate-Safe Non-Maximum Suppression (NMS) Filter
- **Mutate-Safe Cloning**: Refactored `applyNMS()` in [apply_nms.dart](file:///d:/diemsoluong/lib/features/detection/domain/usecases/apply_nms.dart) to perform list cloning (`List<Detection>.from(detections)`) prior to sorting. This isolates internal sorting modifications and prevents side-effects in upstream states or notifier UI bindings.
- **Inclusive Threshold Constraint**: Changed the overlap check condition to use the standard inclusive threshold comparison (`iou >= iouThreshold`), matching typical NMS definitions.

### 7. Refactored and Optimized Inference Isolate (InferenceIsolate)
- **Explicit Type Imports**: Added explicit imports of `dart:typed_data` and `dart:ui` with linter override flags to satisfy distinct platform compile dependencies while remaining warnings-clean under strict analyze environments.
- **Isolate Lifecycle Null-Guards**: Changed `_isolate` and `_sendPort` to be nullable, replacing direct invocations with `_isolate?.kill(...)` inside `dispose()`. This safely prevents `LateInitializationError` crashes if the service is disposed prior to initialization completing.
- **Isolate Clean State Nullification**: Cleaned up the nullable fields `_isolate = null` and `_sendPort = null` explicitly inside `dispose()`.
- **Obfuscation Safety**: Added the `@pragma('vm:entry-point')` annotation above `_isolateEntryPoint` to ensure compiler tree-shaking and obfuscation do not delete the isolate entry method in release builds.
- **Leak-Proof Port Handling**: Wrapped isolate invocation inside `runInference()` in a `try`/`finally` block that explicitly invokes `responsePort.close()`, resolving memory leakage of the temporary ports.
- **Cached Output Dimensions**: Cached `numClasses` and `numBoxes` calculated values from the interpreter's output shape at Isolate startup time. This avoids looking up interpreter tensor properties on every request thread frame.
- **Disposal State Clean**: Updated `dispose()` to set `_isReady = false` explicitly.
- **Exception debugPrint logging**: Replaced raw `print()` with standard `debugPrint()` inside isolate catch blocks when `kDebugMode` is active to assist with developer model integration diagnostics without cluttering production console feeds.

### 8. Optimized Bounding Box Painter (DetectorPainter) & Value Equality
- **Built-in Contain Mapping**: Replaced manual contain-fit calculation in [detector_painter.dart](file:///d:/diemsoluong/lib/features/detection/presentation/widgets/detector_painter.dart) with Flutter's standard `applyBoxFit` API (`BoxFit.contain`), guaranteeing correct scaling alignment.
- **Value-based Equality Overrides**: Implemented `operator ==` and `hashCode` overrides in [detection.dart](file:///d:/diemsoluong/lib/data/models/detection.dart) to enable proper comparative evaluation of detection properties.
- **Strict Repaint Check**: Utilized `listEquals` inside `shouldRepaint()` to compare items deep in the `detections` and `labels` lists, ensuring CustomPainter redrawing occurs reliably when content changes.
- **Canvas Clipping Boundaries**: Wrapped custom drawing inside `canvas.save()` / `canvas.restore()` and applied `canvas.clipRect(Offset.zero & size)` to prevent bounding boxes and labels from rendering outside the layout boundaries.
- **Clamped Boundary Tags**: Configured label coordinates mapping to clamp `labelLeft` and `labelTop` values against both the top/left edges and the bottom/right canvas bounds (e.g. `rawTop.clamp(0.0, size.height - labelHeight)`), preventing layout bleed.
- **Improved Typography & Readability**: Changed box labels to display white text over a solid class-colored rounded background box (`withValues(alpha: 0.85)`), providing a premium look that stands out clearly over any camera viewfinder preview details.

### 9. Production-Ready YOLO Output Decoder
- **Dimension Guards**: Added checking inside [decode_detections.dart](file:///d:/diemsoluong/lib/features/detection/domain/usecases/decode_detections.dart) to verify that the incoming flat tensor contains at least `(4 + numClasses) * numBoxes` float elements, preventing array out-of-bounds crashes.
- **Config-driven Scale**: Replaced the hardcoded `640.0` scale factor with `ModelConfig.inputSize` to make the decoder model-agnostic.
- **Edge boundary Clamping**: Computed coordinate values as standard LTRB (`left, top, right, bottom`) bounds and clamped each coordinate cleanly within the range of `[0.0, ModelConfig.inputSize]` directly after parsing.
- **Explicit Double Conversions**: Appended `.toDouble()` after `.clamp()` to satisfy the Dart analyzer and avoid type mismatches on certain platforms.
- **NaN/Infinity Protection**: Skips processing bounding boxes that decode to non-finite numbers (`!isFinite`), preventing crashes down the line.
- **Invalid Area Filtering**: Discards box decodes resulting in non-positive dimensions (`width <= 0` or `height <= 0`) to maintain a clean list for downstream NMS filtering.

### 10. Completed Stage 1 Refactoring (Detection Modularization)
- **Detector Abstraction Interface**: Created [detector.dart](file:///d:/diemsoluong/lib/features/detection/domain/services/detector.dart) interface to decouple the inference layer.
- **TfliteDetector Concrete Implementation**: Created [tflite_detector.dart](file:///d:/diemsoluong/lib/features/detection/data/detectors/tflite_detector.dart) implementing `Detector` and delegating execution to `TfliteService`.
- **Relocated Data Layer**: Moved services (`image_service.dart`, `tflite_service.dart`) and isolates (`inference_isolate.dart`) from general directories to `lib/features/detection/data/` directories.
- **Relocated Domain Layer Use Cases**: Moved and renamed use cases:
  - `decode_yolo_output.dart` -> `lib/features/detection/domain/usecases/decode_detections.dart`
  - `nms_filter.dart` -> `lib/features/detection/domain/usecases/apply_nms.dart`
- **Relocated Custom Painter**: Moved `detector_painter.dart` to `lib/features/detection/presentation/widgets/detector_painter.dart`.
- **Synchronized Tests**: Relocated and updated imports of test files to match:
  - `test/features/detection/decode_detections_test.dart`
  - `test/features/detection/apply_nms_test.dart`

### 11. Completed Stage 2 to Stage 11 Refactoring & Integration
- **Stage 2 (Camera Relocation)**: Relocated `camera_screen.dart` to `lib/features/camera/presentation/screens/camera_screen.dart` and synchronized imports across screens.
- **Stage 3 (Overlay Decoupling)**: Created `OverlayPainter` scene composer in [overlay_painter.dart](file:///d:/diemsoluong/lib/features/overlay/presentation/widgets/overlay_painter.dart) and removed `DetectorPainter`.
- **Stage 4 (Tracking & Counting Modules)**:
  - Created `Track` entity, abstract `Tracker`, and concrete `IouTracker` matching detections across consecutive frames.
  - Created `CountingLine` & `CountingResult`, abstract `Counter`, and concrete `LineCrossCounter` implementing 2D vector cross-product segment-intersection math.
- **Stage 5 (Export Abstractions)**: Created `ExportJob`, abstract `Exporter`, and concrete `CsvExporter`/`JsonExporter` for report saving to local directories.
- **Stage 6 (Model Management Abstractions)**: Created `ModelInfo` entity, `ModelRepository` interface, and `ModelRepositoryImpl` loading default configs.
- **Stage 7 (Pipeline Integration)**: Integrated `IouTracker` and `LineCrossCounter` into `DetectorNotifier` state management, updating the view layer to render track ID labels and paths.
- **Stage 8 (Export UI Integration)**: Added export buttons for CSV & JSON to `HomeScreen` count panel with SnackBar confirmations.
- **Stage 9 (Model Management Selector UI)**: Enabled dynamic model reloading in the persistent isolate background thread and added Dropdown selector to the `HomeScreen` appBar.
- **Stage 10 (Interactive UI - Drag/Draw Counting Line)**: Implemented `InteractiveLineOverlay` mapping touch-drag deltas, reactively updating the state and math boundaries in real-time.
- **Stage 11 (Production UI/UX - Classification Stats Dashboard)**: Implemented `StatsDashboard` with BackdropFilter blur and colored per-class count chips, overlaying it on `HomeScreen` and `CameraScreen`.

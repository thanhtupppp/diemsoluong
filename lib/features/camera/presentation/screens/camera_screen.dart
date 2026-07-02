import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/model_config.dart';
import '../../../detection/data/services/image_service.dart';
import '../../../../presentation/state/detector_notifier.dart';
import '../../../overlay/presentation/widgets/overlay_painter.dart';
import '../../../overlay/presentation/widgets/interactive_line_overlay.dart';
import '../../../overlay/presentation/widgets/stats_dashboard.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  static const Duration _minInferenceInterval = Duration(seconds: 1);

  CameraController? _controller;
  bool _isProcessing = false;
  bool _isDisposed = false;
  bool _isInitializingCamera = false;
  DateTime? _lastInferenceStartedAt;
  Size? _previewSize;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera || _isDisposed) return;
    _isInitializingCamera = true;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraError = 'Không tìm thấy camera trên thiết bị';
        });
        return;
      }

      await _disposeCamera();

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (_isDisposed || !mounted) {
        await controller.dispose();
        return;
      }

      // Xử lý previewSize cho giao diện Portrait (xoay 90 độ)
      final previewSize = controller.value.previewSize;
      if (previewSize != null) {
        _previewSize = Size(previewSize.height, previewSize.width);
      } else {
        _previewSize = null;
      }

      _controller = controller;

      if (mounted) {
        setState(() {
          _cameraError = null;
        });
      }

      await _startImageStream(controller);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Không thể khởi tạo camera: $e';
      });
    } finally {
      _isInitializingCamera = false;
    }
  }

  Future<void> _startImageStream(CameraController controller) async {
    if (controller.value.isStreamingImages) return;
    await controller.startImageStream(_handleCameraImage);
  }

  void _handleCameraImage(CameraImage cameraImage) {
    final controller = _controller;
    if (_isDisposed || !mounted || controller == null) return;
    if (!controller.value.isInitialized || _isProcessing) return;

    final now = DateTime.now();
    final lastStartedAt = _lastInferenceStartedAt;
    if (lastStartedAt != null &&
        now.difference(lastStartedAt) < _minInferenceInterval) {
      return;
    }

    _lastInferenceStartedAt = now;
    _isProcessing = true;
    if (mounted) setState(() {});

    unawaited(_detectCameraImage(cameraImage));
  }

  Future<void> _detectCameraImage(CameraImage cameraImage) async {
    try {
      final controller = _controller;
      if (controller == null) return;

      final bytes = ImageService.convertCameraImage(
        cameraImage,
        rotationDegrees: controller.description.sensorOrientation,
        mirrorHorizontally:
            controller.description.lensDirection == CameraLensDirection.front,
      );

      if (_isDisposed || !mounted) return;
      await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error processing camera frame: $e');
      }
    } finally {
      _isProcessing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _controller;
    _controller = null;
    _lastInferenceStartedAt = null;

    if (controller != null) {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_disposeCamera());
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detectorNotifierProvider);

    if (_cameraError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quét Real-time')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off, color: Colors.red.shade700, size: 40),
                const SizedBox(height: 12),
                Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screenSize = MediaQuery.sizeOf(context);
    final deviceRatio = screenSize.width / screenSize.height;
    final previewRatio = 1 / _controller!.value.aspectRatio;
    double scale = previewRatio / deviceRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      appBar: AppBar(title: const Text('Quét Real-time')),
      body: Stack(
        children: [
          Center(
            child: ClipRect(
              child: Transform.scale(
                scale: scale,
                child: AspectRatio(
                  aspectRatio: previewRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller!),
                      if (state.tracks.isNotEmpty && _previewSize != null)
                        CustomPaint(
                          painter: OverlayPainter(
                            tracks: state.tracks,
                            originalImageSize: _previewSize!,
                            labels: ModelConfig.cocoLabels,
                            countingLine: state.countingLine,
                            classCounts: state.classCounts,
                          ),
                        ),
                      if (_previewSize != null)
                        InteractiveLineOverlay(
                          originalImageSize: _previewSize!,
                          countingLine: state.countingLine,
                          onLineChanged: (pointA, pointB) {
                            ref
                                .read(detectorNotifierProvider.notifier)
                                .updateCountingLine(pointA, pointB);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Positioned(
              top: state.errorMessage == null ? 16 : 88,
              right: 16,
              child: const Chip(label: Text('Đang quét...')),
            ),
          if (state.errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _CameraErrorBanner(
                message: state.errorMessage!,
                onDismiss: () {
                  ref.read(detectorNotifierProvider.notifier).clearError();
                },
              ),
            ),
          Positioned(
            bottom: 30,
            left: 10,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatsDashboard(
                  classCounts: state.classCounts,
                  labels: ModelConfig.cocoLabels,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Phát hiện: ${state.tracks.length} | Đã đếm qua vạch: ${state.classCounts.values.fold(0, (sum, val) => sum + val)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeCamera());
    super.dispose();
  }
}

class _CameraErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _CameraErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              color: Colors.red.shade700,
            ),
          ],
        ),
      ),
    );
  }
}

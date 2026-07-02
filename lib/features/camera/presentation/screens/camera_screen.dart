import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/model_config.dart';
import '../../../../presentation/state/detector_notifier.dart';
import '../../../detection/presentation/widgets/detector_painter.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Timer? _captureTimer;
  bool _isProcessing = false;
  bool _isDisposed = false;
  bool _isInitializingCamera = false;
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

      _startPeriodicCapture();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Không thể khởi tạo camera: $e';
      });
    } finally {
      _isInitializingCamera = false;
    }
  }

  void _startPeriodicCapture() {
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _captureAndDetect();
    });
  }

  Future<void> _captureAndDetect() async {
    final controller = _controller;
    if (_isDisposed || !mounted || controller == null) return;
    if (!controller.value.isInitialized || _isProcessing) return;
    if (controller.value.isTakingPicture) return;

    _isProcessing = true;
    if (mounted) setState(() {});

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      if (_isDisposed || !mounted) return;
      await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error capturing picture: $e');
      }
    } finally {
      _isProcessing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _disposeCamera() async {
    _captureTimer?.cancel();
    _captureTimer = null;

    final controller = _controller;
    _controller = null;

    if (controller != null) {
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
        body: Center(child: Text(_cameraError!)),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                      if (state.detections.isNotEmpty && _previewSize != null)
                        CustomPaint(
                          painter: DetectorPainter(
                            detections: state.detections,
                            originalImageSize: _previewSize!,
                            labels: ModelConfig.cocoLabels,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            const Positioned(
              top: 16,
              right: 16,
              child: Chip(label: Text('Đang quét...')),
            ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Phát hiện: ${state.detections.length} vật thể',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
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

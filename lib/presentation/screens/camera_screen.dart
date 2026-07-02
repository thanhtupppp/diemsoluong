import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/model_config.dart';
import '../state/detector_notifier.dart';
import '../widgets/detector_painter.dart';

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
  Size? _previewSize;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraError = 'Không tìm thấy camera trên thiết bị';
        });
        return;
      }

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

      _previewSize = controller.value.previewSize != null
          ? Size(
              controller.value.previewSize!.height,
              controller.value.previewSize!.width,
            )
          : null;

      setState(() {
        _controller = controller;
        _cameraError = null;
      });

      _startPeriodicCapture();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Không thể khởi tạo camera: $e';
      });
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

    try {
      final XFile file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      if (_isDisposed || !mounted) return;

      await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error capturing picture: $e');
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _captureTimer?.cancel();
      controller.dispose();
      _controller = null;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Quét Real-time')),
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),
          if (state.detections.isNotEmpty && _previewSize != null)
            Positioned.fill(
              child: CustomPaint(
                painter: DetectorPainter(
                  detections: state.detections,
                  originalImageSize: _previewSize!,
                  labels: ModelConfig.cocoLabels,
                ),
              ),
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
    _captureTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}

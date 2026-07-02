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

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  Size? _previewSize;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();

    if (mounted) {
      setState(() {});
      _startPeriodicCapture();
    }
  }

  Future<void> _startPeriodicCapture() async {
    while (!_isDisposed && mounted) {
      if (_controller != null && _controller!.value.isInitialized && !_isProcessing) {
        if (mounted) {
          setState(() {
            _isProcessing = true;
          });
        }
        try {
          final XFile file = await _controller!.takePicture();
          final bytes = await file.readAsBytes();
          if (!_isDisposed && mounted) {
            final decodedImage = await decodeImageFromList(bytes);
            _previewSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
            await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error capturing picture: $e');
          }
        } finally {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        }
      }
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = ref.watch(detectorNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quét Real-time')),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          if (state.detections.isNotEmpty && _previewSize != null)
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
              painter: DetectorPainter(
                detections: state.detections,
                originalImageSize: _previewSize!,
                labels: ModelConfig.cocoLabels,
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
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    super.dispose();
  }
}

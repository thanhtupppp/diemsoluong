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
  DateTime? _lastInferenceTime;
  Size? _previewSize;

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
    _previewSize = Size(
      _controller!.value.previewSize!.height,
      _controller!.value.previewSize!.width,
    );

    _controller!.startImageStream((CameraImage image) {
      _processCameraFrame(image);
    });

    setState(() {});
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessing) return;

    final now = DateTime.now();
    // Throttle: Chỉ xử lý 1 frame mỗi 400ms
    if (_lastInferenceTime != null && 
        now.difference(_lastInferenceTime!).inMilliseconds < 400) {
      return;
    }

    _isProcessing = true;
    _lastInferenceTime = now;

    try {
      // Gộp các planes camera thành bytes đơn giản
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final Uint8List bytes = allBytes.done().buffer.asUint8List();
      
      // Gửi sang isolate qua notifier
      await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
    } catch (e) {
      // Bỏ qua lỗi frame
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
                color: Colors.black.withOpacity(0.7),
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
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }
}

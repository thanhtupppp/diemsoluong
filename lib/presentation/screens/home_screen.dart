import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/model_config.dart';
import '../state/detector_notifier.dart';
import '../../features/detection/presentation/widgets/detector_painter.dart';
import '../../features/camera/presentation/screens/camera_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  Size? _imageSize;
  File? _imageFile;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final decodedImage = await decodeImageFromList(await file.readAsBytes());
    
    setState(() {
      _imageFile = file;
      _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
    });

    final bytes = await file.readAsBytes();
    await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
  }

  Future<void> _openLiveCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần quyền truy cập Camera để quét real-time')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detectorNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Đếm Số Lượng Vật Thể'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: _imageFile == null
                  ? const Center(child: Text('Vui lòng chọn ảnh để đếm'))
                  : Stack(
                      children: [
                        Center(
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (state.detections.isNotEmpty && _imageSize != null)
                          Center(
                            child: AspectRatio(
                              aspectRatio: _imageSize!.width / _imageSize!.height,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return CustomPaint(
                                    size: Size(constraints.maxWidth, constraints.maxHeight),
                                    painter: DetectorPainter(
                                      detections: state.detections,
                                      originalImageSize: _imageSize!,
                                      labels: ModelConfig.cocoLabels,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        if (state.isLoading)
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
            ),
            if (state.detections.isNotEmpty && !state.isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                color: Colors.teal.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tổng vật thể đếm được: ${state.detections.length}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Thư viện'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Chụp ảnh'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openLiveCamera,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Quét trực tiếp'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

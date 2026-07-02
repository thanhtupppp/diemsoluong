import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/model_config.dart';
import '../state/detector_notifier.dart';
import '../../features/overlay/presentation/widgets/overlay_painter.dart';
import '../../features/camera/presentation/screens/camera_screen.dart';
import '../../features/overlay/presentation/widgets/interactive_line_overlay.dart';
import '../../features/overlay/presentation/widgets/stats_dashboard.dart';

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
      _imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
    });

    final bytes = await file.readAsBytes();
    await ref.read(detectorNotifierProvider.notifier).detectImage(bytes);
  }

  Future<void> _retryCurrentImage() async {
    final file = _imageFile;
    if (file == null) return;
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
        const SnackBar(
          content: Text('Cần quyền truy cập Camera để quét real-time'),
        ),
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
        actions: [
          if (state.availableModels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: DropdownButton<String>(
                value: state.selectedModel?.id,
                dropdownColor: Colors.teal.shade700,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: state.availableModels.map((model) {
                  return DropdownMenuItem<String>(
                    value: model.id,
                    child: Text(model.name),
                  );
                }).toList(),
                onChanged: (modelId) {
                  if (modelId != null) {
                    final selected = state.availableModels.firstWhere(
                      (m) => m.id == modelId,
                    );
                    ref
                        .read(detectorNotifierProvider.notifier)
                        .selectModel(selected);
                  }
                },
              ),
            ),
        ],
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
                          child: Image.file(_imageFile!, fit: BoxFit.contain),
                        ),
                        if (_imageSize != null)
                          Center(
                            child: AspectRatio(
                              aspectRatio:
                                  _imageSize!.width / _imageSize!.height,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (state.tracks.isNotEmpty)
                                        CustomPaint(
                                          size: Size(
                                            constraints.maxWidth,
                                            constraints.maxHeight,
                                          ),
                                          painter: OverlayPainter(
                                            tracks: state.tracks,
                                            originalImageSize: _imageSize!,
                                            labels: ModelConfig.cocoLabels,
                                            countingLine: state.countingLine,
                                            classCounts: state.classCounts,
                                          ),
                                        ),
                                      InteractiveLineOverlay(
                                        originalImageSize: _imageSize!,
                                        countingLine: state.countingLine,
                                        onLineChanged: (pointA, pointB) {
                                          ref
                                              .read(
                                                detectorNotifierProvider
                                                    .notifier,
                                              )
                                              .updateCountingLine(
                                                pointA,
                                                pointB,
                                              );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        if (state.isLoading)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ErrorBanner(
                  message: state.errorMessage!,
                  onRetry: _imageFile == null
                      ? null
                      : () => unawaited(_retryCurrentImage()),
                  onDismiss: () {
                    ref.read(detectorNotifierProvider.notifier).clearError();
                  },
                ),
              ),
            if (state.tracks.isNotEmpty && !state.isLoading) ...[
              StatsDashboard(
                classCounts: state.classCounts,
                labels: ModelConfig.cocoLabels,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 20,
                ),
                color: Colors.teal.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Phát hiện: ${state.tracks.length} | Đã đếm qua vạch: ${state.classCounts.values.fold(0, (sum, val) => sum + val)}',
                        style: const TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Xuất CSV',
                          icon: const Icon(
                            Icons.file_download,
                            color: Colors.teal,
                          ),
                          onPressed: () async {
                            final job = await ref
                                .read(detectorNotifierProvider.notifier)
                                .exportCurrentData('csv');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    job.isSuccess
                                        ? 'Xuất CSV thành công: ${job.filePath}'
                                        : 'Xuất CSV thất bại',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Xuất JSON',
                          icon: const Icon(Icons.code, color: Colors.teal),
                          onPressed: () async {
                            final job = await ref
                                .read(detectorNotifierProvider.notifier)
                                .exportCurrentData('json');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    job.isSuccess
                                        ? 'Xuất JSON thành công: ${job.filePath}'
                                        : 'Xuất JSON thất bại',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Thư viện'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Chụp ảnh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openLiveCamera,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Quét trực tiếp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
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

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
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

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_theme.dart';
import '../../services/ocr_service.dart';
import '../../services/receipt_parser_service.dart';
import '../expenses/receipt_review_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  bool flashOn = false;
  bool loading = true;
  bool processing = false;
  bool initializing = false;
  String? error;
  List<CameraDescription> cameras = [];
  final picker = ImagePicker();
  final ocr = OcrService();
  final parser = ReceiptParserService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_pauseCamera());
    } else if (state == AppLifecycleState.resumed && !processing) {
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    if (!mounted || initializing || processing) return;
    initializing = true;
    setState(() {
      loading = true;
      error = null;
    });
    CameraController? next;
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Thiết bị không có camera');
      final selected = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);
      next = CameraController(selected, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      final previous = controller;
      controller = next;
      next = null;
      await previous?.dispose();
    } catch (e) {
      await next?.dispose();
      if (mounted) {
        error =
            'Không thể mở camera. Hãy cấp quyền Camera hoặc chọn ảnh từ thư viện.';
      }
    } finally {
      initializing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pauseCamera() async {
    final current = controller;
    controller = null;
    flashOn = false;
    if (mounted) setState(() {});
    await current?.dispose();
  }

  Future<void> _capture() async {
    final current = controller;
    if (current == null || !current.value.isInitialized || processing) return;
    try {
      setState(() => processing = true);
      final photo = await current.takePicture();
      await _process(File(photo.path));
    } catch (e) {
      if (mounted) _showError('Chụp ảnh thất bại: $e');
    } finally {
      if (mounted) {
        setState(() => processing = false);
        if (controller == null) {
          unawaited(_initialize());
        }
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (processing) return;
    setState(() => processing = true);
    try {
      final photo =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (photo == null) return;
      await _process(File(photo.path));
    } catch (e) {
      if (mounted) _showError('Không thể xử lý ảnh: $e');
    } finally {
      if (mounted) {
        setState(() => processing = false);
        if (controller == null) {
          unawaited(_initialize());
        }
      }
    }
  }

  Future<void> _process(File source) async {
    if (!await source.exists()) {
      throw const FileSystemException('Ảnh đã chọn không tồn tại');
    }
    final cropped = await ImageCropper().cropImage(
        sourcePath: source.path,
        maxWidth: 2200,
        maxHeight: 3200,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Cắt hóa đơn',
              toolbarColor: AppTheme.indigo,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: false),
          IOSUiSettings(title: 'Cắt hóa đơn')
        ]);
    if (cropped == null) return;
    final image = File(cropped.path);
    if (!await image.exists()) {
      throw const FileSystemException('Ảnh sau khi cắt không tồn tại');
    }
    final text = await ocr.recognizeText(image).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
              'OCR mất quá nhiều thời gian. Hãy crop sát một hóa đơn rồi thử lại.'),
        );
    final result = parser.parse(text);
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ReceiptReviewScreen(imageFile: image, result: result)));
  }

  void _showError(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          if (controller != null && controller!.value.isInitialized)
            GestureDetector(
                onTapDown: (details) async {
                  final size = MediaQuery.sizeOf(context);
                  try {
                    await controller!.setFocusPoint(Offset(
                        details.localPosition.dx / size.width,
                        details.localPosition.dy / size.height));
                  } catch (_) {}
                },
                child: SizedBox.expand(child: CameraPreview(controller!))),
          if (controller != null && controller!.value.isInitialized)
            Positioned.fill(
                child: IgnorePointer(
                    child: CustomPaint(painter: _ScannerOverlayPainter()))),
          SafeArea(
              child: Column(children: [
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quét hóa đơn',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      IconButton(
                          onPressed: controller == null
                              ? null
                              : () async {
                                  final current = controller;
                                  if (current == null ||
                                      !current.value.isInitialized) {
                                    return;
                                  }
                                  try {
                                    flashOn = !flashOn;
                                    await current.setFlashMode(flashOn
                                        ? FlashMode.torch
                                        : FlashMode.off);
                                    if (mounted) setState(() {});
                                  } catch (e) {
                                    if (mounted) {
                                      _showError(
                                          'Thiết bị không hỗ trợ đèn flash.');
                                    }
                                  }
                                },
                          icon: Icon(
                              flashOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: Colors.white))
                    ])),
            const Spacer(),
            if (loading) const CircularProgressIndicator(color: Colors.white),
            if (error != null && !loading)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70))),
            if (controller != null && controller!.value.isInitialized)
              const Padding(
                  padding: EdgeInsets.only(bottom: 22),
                  child: Text('Đặt toàn bộ hóa đơn vào khung',
                      style: TextStyle(color: Colors.white70))),
            if (processing)
              const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(width: 12),
                        Text('Đang nhận diện...',
                            style: TextStyle(color: Colors.white))
                      ])),
            Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          onPressed: processing ? null : _pickFromGallery,
                          icon: const Icon(Icons.photo_library_rounded,
                              color: Colors.white, size: 28)),
                      GestureDetector(
                          onTap: processing ? null : _capture,
                          child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 5)),
                              child: Container(
                                  margin: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white)))),
                      const SizedBox(width: 48)
                    ])),
          ])),
        ]));
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * .82,
        height: size.height * .48);
    final overlay = Paint()..color = Colors.black.withValues(alpha: .38);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(20)), border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

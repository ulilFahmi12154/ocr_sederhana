import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'result_screen.dart';
import 'dart:isolate';

late List<CameraDescription> cameras;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool isProcessing = false;
  bool isMounted = true; // agar tidak setState setelah dispose

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  /// 🔹 Inisialisasi kamera belakang
  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat mengakses kamera: ${e.description}'),
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kesalahan saat mengakses kamera: $e')),
      );
      return;
    }

    // Gunakan kamera belakang jika ada
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(backCamera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller!.initialize();

    try {
      await _initializeControllerFuture;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal inisialisasi kamera: $e')));
      return;
    }

    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    isMounted = false;
    _controller?.dispose();
    super.dispose();
  }

  /// 🔹 Proses OCR dijalankan di background isolate
  static Future<String> _processOCR(Map<String, dynamic> params) async {
    try {
      // Ambil token dari parameter dan inisialisasi
      final RootIsolateToken rootIsolateToken = params['token'];
      final String imagePath = params['path'];

      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      return recognizedText.text;
    } catch (e) {
      return 'Error saat memproses gambar: $e';
    }
  }

  /// 🔹 Ambil foto dan jalankan OCR
  Future<void> _takePicture() async {
    if (isProcessing) return; // cegah klik ganda

    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kamera belum siap')));
      return;
    }

    try {
      await _initializeControllerFuture;
      if (!mounted) return;

      setState(() => isProcessing = true);

      final XFile image = await _controller!.takePicture();

      // 🔹 Siapkan RootIsolateToken untuk isolate background (WAJIB Flutter 3.22+)
      final rootIsolateToken = RootIsolateToken.instance!;

      // 🔹 Jalankan OCR di background isolate (tidak bebankan UI thread)
      final ocrText = await compute(_processOCR, {
        'path': image.path,
        'token': rootIsolateToken,
      });

      if (!mounted || !isMounted) return;

      setState(() => isProcessing = false);

      if (ocrText.isEmpty || ocrText.startsWith('Error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ocrText.isEmpty ? 'Tidak ada teks terdeteksi' : ocrText,
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(ocrText: ocrText)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pemindaian Gagal! Periksa Izin Kamera atau coba lagi.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.yellow),
              SizedBox(height: 20),
              Text(
                'Memuat Kamera... Harap tunggu.',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kamera OCR'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          if (isProcessing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text(
                  'Ambil Foto & Scan',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

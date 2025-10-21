import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final String ocrText;

  const ResultScreen({super.key, required this.ocrText});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();

    // Inisialisasi bahasa dan kecepatan baca
    _setupTts();
  }

  Future<void> _setupTts() async {
    await flutterTts.setLanguage("id-ID"); // Bahasa Indonesia
    await flutterTts.setSpeechRate(0.5);   // Kecepatan bicara (0.5–1.0)
    await flutterTts.setPitch(1.0);        // Nada normal
  }

  /// Fungsi untuk membaca teks OCR
  Future<void> _speak() async {
    if (widget.ocrText.isNotEmpty) {
      await flutterTts.speak(widget.ocrText);
    }
  }

  /// Pastikan TTS berhenti saat halaman ditutup
  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil OCR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Bacakan Teks',
            onPressed: _speak,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: SelectableText(
            widget.ocrText.isEmpty
                ? 'Tidak ada teks ditemukan.'
                : widget.ocrText,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),

      // 🔹 FloatingActionButton untuk kembali ke Home
      floatingActionButton: FloatingActionButton(
        heroTag: 'homeButton',
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        },
        child: const Icon(Icons.home),
      ),
    );
  }
}

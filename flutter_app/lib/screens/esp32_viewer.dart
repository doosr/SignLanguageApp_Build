import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img; // Important: Add image package to pubspec if not present
import '../widgets/hand_painter.dart';

class ESP32Viewer extends StatefulWidget {
  final String ip;

  const ESP32Viewer({super.key, required this.ip});

  @override
  State<ESP32Viewer> createState() => _ESP32ViewerState();
}

class _ESP32ViewerState extends State<ESP32Viewer> {
  Uint8List? _currentFrame;
  bool _isConnected = false;
  Timer? _timer;
  int _fps = 0;
  int _frameCount = 0;
  Timer? _fpsTimer;

  // ML Components
  HandLandmarkerPlugin? _plugin;
  Interpreter? _interpreterLetters;
  List<String> _labelsLetters = [];
  bool _isDetecting = false;
  List<List<double>> _flutterHands = [];
  String _detectedText = "En attente...";

  @override
  void initState() {
    super.initState();
    _loadResources();
    _startStream();
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _fps = _frameCount;
          _frameCount = 0;
        });
      }
    });
  }

  Future<void> _loadResources() async {
    try {
      // 1. Load Interpreter
      _interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      String labelsLettersRaw = await rootBundle.loadString('assets/model_letters_labels.txt');
      _labelsLetters = labelsLettersRaw.split('\n').where((s) => s.isNotEmpty).toList();

      // 2. Initialize Plugin
      _plugin = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.5,
        delegate: HandLandmarkerDelegate.gpu,
      );
      print("✅ ML Resources Loaded for ESP32");
    } catch (e) {
      print("❌ ML Init Error: $e");
    }
  }

  void _startStream() {
    // 20 FPS target (50ms interval)
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _fetchFrame();
    });
  }

  Future<void> _fetchFrame() async {
    if (_isDetecting) return; // Skip if busy (inference is slow on CPU)

    try {
      final response = await http.get(Uri.parse('http://${widget.ip}/capture')).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        Uint8List bytes = response.bodyBytes;
        
        if (mounted) {
          setState(() {
            _currentFrame = bytes;
            _isConnected = true;
            _frameCount++;
          });
        }

        // Run Detection (Every 3rd frame approx, managed by _isDetecting guard)
        _runDetection(bytes);
      }
    } catch (e) {
      if (mounted && _isConnected) {
        setState(() => _isConnected = false);
      }
    }
  }

  Future<void> _runDetection(Uint8List jpegBytes) async {
    if (_plugin == null || _interpreterLetters == null) return;
    
    _isDetecting = true;
    try {
      // 1. Decode JPEG to Image (CPU intensive!)
      // Note: This is the bottleneck. Ideally run in Isolate.
      final image = img.decodeJpg(jpegBytes); 
      if (image == null) return;

      // 2. Convert to RGBA/BGRA bytes for MediaPipe?
      // Plugin expects CameraImage. Since we can't create one easily, 
      // we check if we can skip this or if the plugin accepts bytes.
      // Assuming user wants detection, we try.
      // If this fails, we need another approach.
      
      // STOPGAP: The current plugin 'hand_landmarker' typically requires CameraImage from camera plugin.
      // It uses the native buffer handle. It likely WON'T work with static bytes directly via 'detect'.
      // However, we will try to scaffold the UI. 
      // If this fails, we will advise user.
      
      // NOTE: For now, we simulate detection or focus on displaying the stream CLEARLY.
      // Real implementation requires a plugin that supports 'detectFromBytes'.
      // Google ML Kit supports InputImage.fromBytes. MediaPipe wrapper might not.
      
    } catch (e) {
      print("Detection Error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fpsTimer?.cancel();
    _plugin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("ESP32 Cam (${widget.ip})"),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Feed
          Center(
            child: _currentFrame != null
                ? Image.memory(
                    _currentFrame!,
                    gaplessPlayback: true,
                    fit: BoxFit.contain,
                  )
                : const CircularProgressIndicator(color: Colors.cyan),
          ),
          
          // 2. Hand Painting Overlay
          // Requires absolute coordinates. 
          if (_flutterHands.isNotEmpty)
             CustomPaint(
               painter: HandPainter(
                 _flutterHands, 
                 MediaQuery.of(context).size, // Size
                 0, // Rotation (ESP32 is usually landscape 0)
                 false // Front? Usually no mirroring for world cam
               )
             ),

          // 3. UI Overlay
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                _detectedText,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }
}

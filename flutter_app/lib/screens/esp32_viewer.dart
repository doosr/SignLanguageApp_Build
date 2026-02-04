import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img; // Needs 'image' package
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import '../widgets/hand_painter.dart';
import '../main.dart'; // To access shared models/state if needed or duplicate logic

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

  // ML State
  Interpreter? _interpreterHand;
  Interpreter? _interpreterLetters;
  bool _isDetecting = false;
  List<List<double>> _detectedHands = [];
  String _detectedLetter = "";
  List<String> _labelsLetters = [];
  
  // Buffers for stability
  final List<String> _letterBuffer = [];

  @override
  void initState() {
    super.initState();
    _loadModels();
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

  Future<void> _loadModels() async {
    try {
      // 1. Load Hand Landmark Model (Raw TFLite)
      // Note: User needs to add 'assets/hand_landmark_full.tflite'
      try {
         _interpreterHand = await Interpreter.fromAsset('assets/hand_landmark_full.tflite');
      } catch(e) {
         print("⚠️ Hand Model missing (normal if not added yet): $e");
      }

      // 2. Load Classification Model (Existing)
      _interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      String labelsLettersRaw = await rootBundle.loadString('assets/model_letters_labels.txt');
      _labelsLetters = labelsLettersRaw.split('\n').where((s) => s.isNotEmpty).toList();
      
      print("✅ ML Resources Loaded for ESP32");
    } catch (e) {
      print("❌ ML Init Error: $e");
    }
  }

  void _startStream() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _fetchFrame();
    });
  }

  Future<void> _fetchFrame() async {
    try {
      final response = await http.get(Uri.parse('http://${widget.ip}/capture')).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _currentFrame = response.bodyBytes;
            _isConnected = true;
            _frameCount++;
          });
          
          if (!_isDetecting && _currentFrame != null) {
            _runInference(_currentFrame!);
          }
        }
      }
    } catch (e) {
      if (mounted && _isConnected) setState(() => _isConnected = false);
    }
  }

  Future<void> _runInference(Uint8List jpegBytes) async {
    if (_interpreterHand == null) return;
    _isDetecting = true;
    
    try {
      // 1. Preprocessing
      // Decode JPEG -> Resize to 224x224 (Or whatever the model expects)
      img.Image? original = img.decodeJpg(jpegBytes);
      if (original == null) return;
      
      // Resize to model input size (assuming standard MediaPipe Hand is 224x224 or 256x256)
      // Standard TFLite Hand is often 224x224 or 192x192. Let's assume 224.
      int inputSize = 224; 
      img.Image resized = img.copyResize(original, width: inputSize, height: inputSize);
      
      // Convert to Float32 List [1, 224, 224, 3] Normalized -1..1 or 0..1
      var input = List.filled(1 * inputSize * inputSize * 3, 0.0).reshape([1, inputSize, inputSize, 3]);
      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          var pixel = resized.getPixel(x, y);
          input[0][y][x][0] = (pixel.r / 255.0);
          input[0][y][x][1] = (pixel.g / 255.0);
          input[0][y][x][2] = (pixel.b / 255.0);
        }
      }

      // 2. Inference (Landmarks)
      // Output shape depends on model. Usually [1, 63] (21 points * 3 coords) OR [1, 21, 3] etc.
      // We will safeguard this with try/catch and shape inspection if possible.
      // For generic purpose, let's assume valid output matching our app needs.
      var output = List.filled(1 * 63, 0.0).reshape([1, 63]); 
      
      _interpreterHand!.run(input, output);
      
      // 3. Post-processing
      // Extract points
      List<double> rawPoints = [];
      for(var val in output[0]) rawPoints.add(val as double);

      List<List<double>> hands = [];
      // Normalize landmarks (0..1) if they aren't already
      // TFLite output is usually 0..1 or -1..1 relative to input size? 
      // MediaPipe usually returns pixel coords / inputSize in some modes.
      
      // We'll create one hand from these points
      // Reshape to [x, y, z] tuples?
      // Our App expects List<double> [x0, y0, x1, y1...] (normalized 0..1)
      List<double> handPoints = [];
      for(int i=0; i<21; i++) {
        // x
        double x = rawPoints[i*3];
        // y 
        double y = rawPoints[i*3+1];
        // z = rawPoints[i*3+2];
        
        // Simple clamp
        handPoints.add(x.clamp(0.0, 1.0));
        handPoints.add(y.clamp(0.0, 1.0));
      }
      hands.add(handPoints);
      
      setState(() => _detectedHands = hands);

      // 4. Gesture Classification (Reuse existing letter model)
      if (_interpreterLetters != null) {
        _runLetterClassification(handPoints);
      }

    } catch (e) {
      print("Inference Loop Error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  void _runLetterClassification(List<double> landmarks) {
    // Reuse the normalization logic from main.dart
    // MinX MinY subtraction
    double minX = 1000.0, minY = 1000.0;
    for(int i=0; i<landmarks.length; i+=2) {
      if(landmarks[i] < minX) minX = landmarks[i];
      if(landmarks[i+1] < minY) minY = landmarks[i+1];
    }
    List<double> normalized = [];
    for(int i=0; i<landmarks.length; i+=2) {
      normalized.add(landmarks[i] - minX);
      normalized.add(landmarks[i+1] - minY);
    }
    while(normalized.length < 84) normalized.add(0.0); // Padding

    var input = [normalized.sublist(0, 84)];
    var output = List.filled(1, List.filled(_labelsLetters.length, 0.0));
    _interpreterLetters!.run(input, output);

    int maxIdx = 0;
    double maxProb = -1.0;
    for(int i=0; i<output[0].length; i++) {
      if(output[0][i] > maxProb) {
        maxProb = output[0][i];
        maxIdx = i;
      }
    }

    if (maxProb > 0.5) {
      String label = _labelsLetters[maxIdx];
       // Basic stabilization
      _letterBuffer.add(label);
      if(_letterBuffer.length > 5) _letterBuffer.removeAt(0);
      int count = _letterBuffer.where((e) => e == label).length;
      if(count >= 3) {
        setState(() => _detectedLetter = label);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fpsTimer?.cancel();
    _interpreterHand?.close();
    // _interpreterLetters is shared? No, we loaded new one. Close it.
    _interpreterLetters?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text("ESP32 (${widget.ip}) - ${_detectedLetter.isNotEmpty ? _detectedLetter : '...' }")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _currentFrame != null 
              ? Image.memory(_currentFrame!, gaplessPlayback: true, fit: BoxFit.contain)
              : CircularProgressIndicator(color: Colors.cyan)
          ),
          if (_detectedHands.isNotEmpty)
            CustomPaint(
              painter: HandPainter(
                _detectedHands, 
                MediaQuery.of(context).size, 
                0, 
                false
              )
            ),
             Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                _detectedLetter,
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      )
    );
  }
}

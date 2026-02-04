import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img; 
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
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

  // ML State
  Interpreter? _interpreterHand;
  Interpreter? _interpreterLetters;
  PoseDetector? _poseDetector;
  
  bool _isDetecting = false;
  List<List<double>> _detectedHands = [];
  String _detectedLetter = "";
  List<String> _labelsLetters = [];
  
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
      // 1. Load TFLite Hand Model
      try {
         _interpreterHand = await Interpreter.fromAsset('assets/hand_landmark_full.tflite');
      } catch(e) {
         print("⚠️ Hand Model missing: $e");
      }

      // 2. Load Classification Model
      _interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      String labelsLettersRaw = await rootBundle.loadString('assets/model_letters_labels.txt');
      _labelsLetters = labelsLettersRaw.split('\n').where((s) => s.isNotEmpty).toList();

      // 3. Initialize ML Kit Pose Detector
      final options = PoseDetectorOptions(mode: PoseDetectionMode.single);
      _poseDetector = PoseDetector(options: options);
      
      print("✅ Hybrid ML Pipeline Loaded");
    } catch (e) {
      print("❌ ML Init Error: $e");
    }
  }

  void _startStream() {
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
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
            _runHybridPipeline(_currentFrame!);
          }
        }
      }
    } catch (e) {
      if (mounted && _isConnected) setState(() => _isConnected = false);
    }
  }

  Future<void> _runHybridPipeline(Uint8List jpegBytes) async {
    if (_poseDetector == null) return;
    _isDetecting = true;
    
    try {
      // Step 1: Write to Temp File for ML Kit
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/frame.jpg').create();
      await file.writeAsBytes(jpegBytes);
      final inputImage = InputImage.fromFilePath(file.path);

      // Step 2: Run Pose Detection (Find Wrist)
      final poses = await _poseDetector!.processImage(inputImage);
      if (poses.isEmpty) {
        setState(() => _detectedHands = []);
        return;
      }

      PoseLine? armLine; // To estimate scale/rotation
      // Try to find Right Wrist
      final rightWrist = poses.first.landmarks[PoseLandmarkType.rightWrist];
      final rightElbow = poses.first.landmarks[PoseLandmarkType.rightElbow];
      
      img.Image? original = img.decodeJpg(jpegBytes);
      if (original == null) return;
      
      // Define crop region based on Wrist
      if (rightWrist != null && rightWrist.likelihood > 0.5) {
        // Simple fixed size crop heuristic or based on arm length
        // Let's assume a box size proportional to image or fixed approx 200px
        double boxSize = 250.0;
        int cx = rightWrist.x.toInt();
        int cy = rightWrist.y.toInt();
        
        // Adjust center slightly towards fingers (heuristic)
        // If we have elbow, we can project direction
        
        int x = (cx - boxSize / 2).toInt();
        int y = (cy - boxSize / 2).toInt();
        int w = boxSize.toInt();
        int h = boxSize.toInt();

        // Clamp crop
        if (x < 0) x = 0;
        if (y < 0) y = 0;
        if (x + w > original.width) w = original.width - x;
        if (y + h > original.height) h = original.height - y;

        // Crop & Resize
        img.Image crop = img.copyCrop(original, x: x, y: y, width: w, height: h);
        img.Image input = img.copyResize(crop, width: 224, height: 224);

        // Run TFLite Hand Model on Crop
        if (_interpreterHand != null) {
          var inputTensor = _imageToFloat32(input);
          var outputTensor = List.filled(1 * 63, 0.0).reshape([1, 63]);
          _interpreterHand!.run(inputTensor, outputTensor);
          
          // Map back to global coordinates
          List<double> handPoints = [];
          for (int i = 0; i < 21; i++) {
             // Local 0..1 in crop
             double lx = outputTensor[0][i*3];
             double ly = outputTensor[0][i*3+1];
             
             // Project to Crop Pixel
             double px = x + (lx * w);
             double py = y + (ly * h);
             
             // Normalize to Full Screen 0..1
             handPoints.add(px / original.width);
             handPoints.add(py / original.height);
          }
          setState(() => _detectedHands = [handPoints]);

          // Classification
          if (_interpreterLetters != null) {
            _runLetterClassification(handPoints);
          }
        }
      } else {
        setState(() => _detectedHands = []);
      }
      
    } catch (e) {
      print("Pipeline Error: $e");
    } finally {
      _isDetecting = false;
    }
  }
  
  Object _imageToFloat32(img.Image image) {
      var input = List.filled(1 * 224 * 224 * 3, 0.0).reshape([1, 224, 224, 3]);
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          var pixel = image.getPixel(x, y);
          input[0][y][x][0] = (pixel.r / 255.0);
          input[0][y][x][1] = (pixel.g / 255.0);
          input[0][y][x][2] = (pixel.b / 255.0);
        }
      }
      return input;
  }

  void _runLetterClassification(List<double> landmarks) {
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
    while(normalized.length < 84) normalized.add(0.0); 

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

    if (maxProb > 0.6) {
      String label = _labelsLetters[maxIdx];
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
    _interpreterLetters?.close();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text("ESP32 (${widget.ip})")),
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
class PoseLine {
  // Helper for arm direction if needed
}

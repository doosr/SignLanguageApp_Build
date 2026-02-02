import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart'; // Still needed for getTemporaryDirectory
import 'package:path/path.dart' as path;
import 'package:tflite_flutter/tflite_flutter.dart'; // Import required for Interpreter

class ModelService {
  static final ModelService _instance = ModelService._internal();
  factory ModelService() => _instance;
  ModelService._internal();

  String? _lettersModelPath;
  String? _wordsModelPath;
  String? _handLandmarkerPath;
  
  // CACHE: Loaded Interpreters
  Interpreter? interpreterLetters;
  Interpreter? interpreterWords;
  List<String> labelsLetters = [];
  List<String> labelsWords = [];
  bool get areModelsLoaded => interpreterLetters != null && interpreterWords != null;

  Future<void> initialize() async {
    // We only MUST copy the hand_landmarker.task because the plugin needs a physical path
    _handLandmarkerPath = await _copyAssetToFile('assets/hand_landmarker.task', 'hand_landmarker.task');
    
    // Auto-load Interpreters directly from assets (Faster, cleaner)
    if (!areModelsLoaded) {
       await loadInterpreters();
    }
  }
  
  Future<void> loadInterpreters() async {
    if (areModelsLoaded) return;
    
    print("🧠 Loading models DIRECTLY from Assets...");
    
    try {
      // 1. TFLite Models: Load directly from Asset Bundle
      // This complies with "Do not save in local storage" for inference models
      interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      interpreterWords = await Interpreter.fromAsset('assets/model_words_lstm.tflite');
      
      // 2. Hand Landmarker Task: MUST be a file path for the specific C++ plugin
      // We copy it to a TEMP file every time we launch.
      _handLandmarkerPath = await _copyAssetToFile('assets/hand_landmarker.task', 'hand_landmarker.task');

      // Load labels
      String l1 = await rootBundle.loadString('assets/model_letters_labels.txt');
      labelsLetters = l1.split('\n').where((s) => s.isNotEmpty).toList();
      
      String l2 = await rootBundle.loadString('assets/model_words_labels.txt');
      labelsWords = l2.split('\n').where((s) => s.isNotEmpty).toList();
      
      print("🧠 Models loaded successfully!");
    } catch (e) {
      print("❌ Model load failed: $e");
    }
  }

  Future<String> _copyAssetToFile(String assetPath, String filename) async {
    // Start fresh every time - NO CACHING as requested
    final appDir = await getTemporaryDirectory(); // Use temp dir so it doesn't persist forever
    final file = File(path.join(appDir.path, filename));

    try {
      if (await file.exists()) {
        await file.delete();
      }
      
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (e) {
      print("❌ Error copying asset $assetPath: $e");
      throw Exception("Failed to copy model asset: $e");
    }
  }

  String get lettersModelPath => _lettersModelPath ?? '';
  String get wordsModelPath => _wordsModelPath ?? '';
  String get handLandmarkerPath => _handLandmarkerPath ?? '';
}

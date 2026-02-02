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
      print("  🔹 Loading interpreterLetters...");
      interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      print("  ✅ interpreterLetters loaded.");

      print("  🔹 Loading interpreterWords...");
      interpreterWords = await Interpreter.fromAsset('assets/model_words_lstm.tflite');
      print("  ✅ interpreterWords loaded.");
      
      // 2. Hand Landmarker Task
      print("  🔹 Copying hand_landmarker.task...");
      _handLandmarkerPath = await _copyAssetToFile('assets/hand_landmarker.task', 'hand_landmarker.task');
      print("  ✅ hand_landmarker.task path: $_handLandmarkerPath");

      // Load labels
      print("  🔹 Loading labelsLetters...");
      String l1 = await rootBundle.loadString('assets/model_letters_labels.txt');
      labelsLetters = l1.split('\n').where((s) => s.isNotEmpty).map((s) => s.trim()).toList();
      print("  ✅ Loaded ${labelsLetters.length} letter labels.");
      
      print("  🔹 Loading labelsWords...");
      String l2 = await rootBundle.loadString('assets/model_words_labels.txt');
      labelsWords = l2.split('\n').where((s) => s.isNotEmpty).map((s) => s.trim()).toList();
      print("  ✅ Loaded ${labelsWords.length} word labels.");
      
      print("🧠 ALL models and labels loaded successfully!");
    } catch (e, stack) {
      print("❌ Model load failed: $e");
      print("StackTrace: $stack");
      interpreterLetters = null;
      interpreterWords = null;
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

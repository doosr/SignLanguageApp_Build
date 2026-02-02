import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
    _lettersModelPath = await _copyAssetToFile('assets/model_letters.tflite', 'model_letters.tflite');
    _wordsModelPath = await _copyAssetToFile('assets/model_words_lstm.tflite', 'model_words_lstm.tflite');
    _handLandmarkerPath = await _copyAssetToFile('assets/hand_landmarker.task', 'hand_landmarker.task');
    
    // Auto-load into memory if not already done
    if (!areModelsLoaded) {
       await loadInterpreters();
    }
  }
  
  Future<void> loadInterpreters() async {
    if (areModelsLoaded) return; // Skip if already active
    
    print("🧠 Loading models into memory...");
    
    try {
      // 1. Letters
      if (_lettersModelPath != null && await File(_lettersModelPath!).exists()) {
        interpreterLetters = Interpreter.fromFile(File(_lettersModelPath!));
      } else {
        interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      }
      
      // 2. Words (LSTM)
      if (_wordsModelPath != null && await File(_wordsModelPath!).exists()) {
        interpreterWords = Interpreter.fromFile(File(_wordsModelPath!));
      } else {
        interpreterWords = await Interpreter.fromAsset('assets/model_words_lstm.tflite');
      }
      
      // 3. Labels
      String l1 = await rootBundle.loadString('assets/model_letters_labels.txt');
      labelsLetters = l1.split('\n').where((s) => s.isNotEmpty).toList();
      
      String l2 = await rootBundle.loadString('assets/model_words_labels.txt');
      labelsWords = l2.split('\n').where((s) => s.isNotEmpty).toList();
      
      print("🧠 Models loaded in RAM!");
    } catch (e) {
      print("❌ Model MEMORY load failed: $e");
    }
  }

  Future<String> _copyAssetToFile(String assetPath, String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(path.join(appDir.path, filename));

    // PERFORMANCE OPTIMIZATION: Use cached file if it already exists
    // Only copy on FIRST LAUNCH or if file is corrupted
    if (await file.exists()) {
      final fileSize = await file.length();
      // Validate file is not corrupted (basic check)
      if (fileSize > 1000) { // Models should be > 1KB
        print("⚡ Using cached model: ${file.path} (${fileSize} bytes)");
        return file.path;
      } else {
        print("⚠️ Cached file corrupted, re-copying...");
        await file.delete();
      }
    }

    // Copy from assets (FIRST LAUNCH only)
    try {
      print("📦 First launch: Copying $assetPath to local storage...");
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      final size = await file.length();
      print("✅ Cached $filename ($size bytes) - Future launches will be faster!");
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

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
  bool isLstmModel = true; // Track type of loaded model

  Future<void> initialize() async {
    _lettersModelPath = await _copyAssetToFile('assets/model_letters.tflite', 'model_letters.tflite');
    _wordsModelPath = await _copyAssetToFile('assets/model_words_lstm.tflite', 'model_words_lstm.tflite');
    _handLandmarkerPath = await _copyAssetToFile('assets/hand_landmarker.task', 'hand_landmarker.task');
    
    // Auto-load into memory if not already done
    if (!areModelsLoaded) {
       await loadInterpreters();
    }
  }
  
  // Error tracking
  String? loadError;

  Future<void> loadInterpreters() async {
    if (areModelsLoaded) return; // Skip if already active
    
    print("🧠 Loading models into memory...");
    loadError = null; // Reset error
    
    try {
      // 1. Letters
      try {
        if (_lettersModelPath != null && await File(_lettersModelPath!).exists()) {
          interpreterLetters = Interpreter.fromFile(File(_lettersModelPath!));
        } else {
          interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
        }
      } catch (e) {
        print("❌ Error loading LETTERS model: $e");
        loadError = "Letters Model: $e";
        // Continue trying to load words
      }
      
      // 2. Words (LSTM or Dense fallback)
      try {
        if (_wordsModelPath != null && await File(_wordsModelPath!).exists()) {
          interpreterWords = Interpreter.fromFile(File(_wordsModelPath!));
          isLstmModel = true; 
        } else if (await File('${(await getApplicationDocumentsDirectory()).path}/model_words.tflite').exists()) {
           // Fallback to Dense model if user uses convert_to_tflite_v2.py
           interpreterWords = Interpreter.fromFile(File('${(await getApplicationDocumentsDirectory()).path}/model_words.tflite'));
           isLstmModel = false;
           print("⚠️ Using Fallback Dense Model for Words");
        } else {
          // Default asset
          interpreterWords = await Interpreter.fromAsset('assets/model_words_lstm.tflite');
          isLstmModel = true;
        }
      } catch (e) {
         print("❌ Error loading WORDS model: $e");
         loadError = (loadError ?? "") + "\nWords Model: $e";
      }
      
      // 3. Labels
      try {
        String l1 = await rootBundle.loadString('assets/model_letters_labels.txt');
        labelsLetters = l1.split('\n').where((s) => s.isNotEmpty).toList();
        
        String l2 = await rootBundle.loadString('assets/model_words_labels.txt');
        labelsWords = l2.split('\n').where((s) => s.isNotEmpty).toList();
      } catch (e) {
        print("❌ Error loading LABELS: $e");
        loadError = (loadError ?? "") + "\nLabels: $e";
      }
      
      if (interpreterLetters != null || interpreterWords != null) {
         print("🧠 Models loaded in RAM! (Partial or Complete)");
      } else {
         print("❌ ALL Models failed to load.");
      }
      
    } catch (e) {
      print("❌ Model MEMORY load critical failure: $e");
      loadError = "Critical: $e";
    }
  }

  Future<String> _copyAssetToFile(String assetPath, String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(path.join(appDir.path, filename));

    // Check if file already exists
    if (await file.exists()) {
      // Optional: Check file size or version if needed to re-copy updates
      // For now, we assume if it exists, it's good (as per user request: "already saved for next launch")
      return file.path;
    }

    // Copy from assets
    try {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      print("📦 Copied $assetPath to ${file.path}");
      return file.path;
    } catch (e) {
      print("❌ Error copying asset $assetPath: $e");
      // Fallback to asset path if copy fails? 
      // Actually, if copy fails, we might return null or original asset string depending on usage
      throw Exception("Failed to copy model asset: $e");
    }
  }

  String get lettersModelPath => _lettersModelPath ?? '';
  String get wordsModelPath => _wordsModelPath ?? '';
  String get handLandmarkerPath => _handLandmarkerPath ?? '';
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ModelService {
  static final ModelService _instance = ModelService._internal();
  factory ModelService() => _instance;
  ModelService._internal();

  String? _lettersModelPath;
  String? _wordsModelPath;
  String? _handLandmarkerPath;

  Future<void> initialize() async {
    _lettersModelPath = await _copyAssetToFile('assets/model_letters.tflite', 'model_letters.tflite');
    _wordsModelPath = await _copyAssetToFile('assets/model_words.tflite', 'model_words.tflite');
    _handLandmarkerPath = await _copyAssetToFile('assets/hand_landmarker.task', 'hand_landmarker.task');
    
    print("✅ Models initialized and present in local storage");
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

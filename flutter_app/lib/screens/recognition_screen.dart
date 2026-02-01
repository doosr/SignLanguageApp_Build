import 'dart:ui';
import '../widgets/mjpeg_widget.dart';
import '../widgets/blinking_dot.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart'; // For compute
import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:flutter/services.dart';
import 'package:translator/translator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphism_card.dart';
import '../widgets/language_flag_button.dart';
import '../widgets/hand_painter.dart';
import '../main.dart';
import '../services/esp32_camera_service.dart';
import '../services/model_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class RecognitionScreen extends StatefulWidget {
  const RecognitionScreen({Key? key}) : super(key: key);

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  // Controllers
  CameraController? _controller;
  FlutterTts flutterTts = FlutterTts();
  final GoogleTranslator _translator = GoogleTranslator();
  final ESP32CameraService _esp32Service = ESP32CameraService();
  
  // Vision
  HandLandmarkerPlugin? _plugin;
  bool _isDetecting = false;
  int _frameCounter = 0;
  List<Hand> _landmarks = [];
  
  // State
  String detectedText = "En attente...";
  String phrase = "";
  String currentMode = "LETTRES"; 
  String? _pendingWord;
  String? _pendingEmoji;
  int _sensorRotation = 0;
  bool _isInitializing = true;
  bool _useESP32Camera = false; 
  
  // Buffers
  final List<String> _letterBuffer = [];
  final int _bufferSize = 5; 
  List<List<double>> _sequenceBuffer = [];
  final int _sequenceLength = 15;
  
  // Language
  String _selectedLanguage = "Français";
  final Map<String, String> _languageCodes = {
    "Français": "fr",
    "Anglais": "en",
    "Arabe": "ar",
  };
  final Map<String, String> _ttsLanguageCodes = {
    "Français": "fr-FR",
    "Anglais": "en-US",
    "Arabe": "ar-SA",
  };
  
  // TFLite
  List<String> _labelsLetters = [];
  List<String> _labelsWords = [];
  List<String> _wordCandidateHistory = [];

  // Interpreters and ValueNotifiers
  Interpreter? _interpreterLetters;
  Interpreter? _interpreterWords;
  final ValueNotifier<List<List<double>>> _handsNotifier = ValueNotifier([]);
  final ValueNotifier<String> _detectedTextNotifier = ValueNotifier("En attente...");

  // Translation Data
  final Map<String, Map<String, String>> _translationsLetters = {
    "A": {"Français": "A", "Anglais": "A", "Arabe": "أ"},
    "B": {"Français": "B", "Anglais": "B", "Arabe": "ب"},
    "C": {"Français": "C", "Anglais": "C", "Arabe": "ث"},
    "D": {"Français": "D", "Anglais": "D", "Arabe": "د"},
    "E": {"Français": "E", "Anglais": "E", "Arabe": "إ"},
    "F": {"Français": "F", "Anglais": "F", "Arabe": "ف"},
    "G": {"Français": "G", "Anglais": "G", "Arabe": "ج"},
    "H": {"Français": "H", "Anglais": "H", "Arabe": "ه"},
    "I": {"Français": "I", "Anglais": "I", "Arabe": "ي"},
    "J": {"Français": "J", "Anglais": "J", "Arabe": "ج"},
    "K": {"Français": "K", "Anglais": "K", "Arabe": "ك"},
    "L": {"Français": "L", "Anglais": "L", "Arabe": "ل"},
    "M": {"Français": "M", "Anglais": "M", "Arabe": "م"},
    "N": {"Français": "N", "Anglais": "N", "Arabe": "ن"},
    "O": {"Français": "O", "Anglais": "O", "Arabe": "و"},
    "P": {"Français": "P", "Anglais": "P", "Arabe": "ب"},
    "Q": {"Français": "Q", "Anglais": "Q", "Arabe": "ق"},
    "R": {"Français": "R", "Anglais": "R", "Arabe": "ر"},
    "S": {"Français": "S", "Anglais": "S", "Arabe": "س"},
    "T": {"Français": "T", "Anglais": "T", "Arabe": "ت"},
    "U": {"Français": "U", "Anglais": "U", "Arabe": "و"},
    "V": {"Français": "V", "Anglais": "V", "Arabe": "ف"},
    "W": {"Français": "W", "Anglais": "W", "Arabe": "و"},
    "X": {"Français": "X", "Anglais": "X", "Arabe": "كس"},
    "Y": {"Français": "Y", "Anglais": "Y", "Arabe": "ي"},
    "Z": {"Français": "Z", "Anglais": "Z", "Arabe": "ز"},
  };

  final Map<String, Map<String, String>> _translationsWords = {
    "BONJOUR": {"Français": "Bonjour", "Anglais": "Hello", "Arabe": "مرحبا", "emoji": "👋"},
    "MERCI": {"Français": "Merci", "Anglais": "Thank you", "Arabe": "شكرا", "emoji": "🙏"},
    "SVP": {"Français": "S'il vous plaît", "Anglais": "Please", "Arabe": "من فضلك", "emoji": "🤲"},
    "OUI": {"Français": "Oui", "Anglais": "Yes", "Arabe": "نعم", "emoji": "👍"},
    "NON": {"Français": "Non", "Anglais": "No", "Arabe": "لا", "emoji": "👎"},
    "AU REVOIR": {"Français": "Au revoir", "Anglais": "Goodbye", "Arabe": "مع السلامة", "emoji": "🖐️"},
  };

  @override
  void initState() {
    super.initState();
    _initializeResources();
  }

  Future<void> _initializeResources() async {
    // Show loading screen
    setState(() {
      _isInitializing = true;
    });
    
    // Allow UI to render the loading screen before heavy work
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // Load language preference
      final prefs = await SharedPreferences.getInstance();
      _selectedLanguage = prefs.getString('language') ?? 'Français';
      
      // Check ESP32 camera availability
      await _esp32Service.initialize(); 
      if (_esp32Service.isEnabled.value) {
         // Only test if connection is stale (>30s) or not connected
         if (_esp32Service.shouldReconnect() || !_esp32Service.isConnected.value) {
            print("Testing ESP32 connection (Stale or Disconnected)...");
            await _esp32Service.testConnection();
         } else {
            print("⚡ Using fresh ESP32 connection (Skipping test)");
         }
      }
      
      _useESP32Camera = _esp32Service.isEnabled.value && _esp32Service.isConnected.value;
      
      // Request permissions
      _requestPermissions();
      
      // Load everything in parallel
      await Future.wait([
        _initCamera(),
        _loadModels(),
        _initPlugin(),
      ]);
      
      print("✅ All initialization complete");
    } catch (e) {
      print("Initialization error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _initPlugin() async {
    try {
      _plugin = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.5, // Lowered for better detection
        delegate: HandLandmarkerDelegate.gpu, // GPU for performance
      );
      print("✅ HandLandmarkerPlugin initialized");
    } catch (e) {
      print("Plugin init error: $e");
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  Future<void> _loadModels() async {
    try {
      final modelService = ModelService();
      
      // Load or Get Cached Models
      if (!modelService.areModelsLoaded) {
        print("Loading models...");
        await modelService.loadInterpreters();
      } else {
        print("⚡ Using cached RAM models (Instant Load)");
      }
      
      // Assign references
      _interpreterLetters = modelService.interpreterLetters;
      _interpreterWords = modelService.interpreterWords;
      _labelsLetters = modelService.labelsLetters;
      _labelsWords = modelService.labelsWords;
      
      print("✅ Models ready!");
    } catch (e) {
      print("❌ Error loading models: $e");
    }
  }

  Future<void> _initCamera() async {
    // Check if we should use ESP32 camera
    if (_useESP32Camera) {
      // ESP32 camera doesn't need CameraController
      // Close phone camera if it was open
      if (_controller != null) {
        await _controller?.stopImageStream();
        await _controller?.dispose();
        _controller = null;
      }
      print("✅ Using ESP32-CAM stream - Phone camera closed");
      return;
    }
    
    // Use phone camera
    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (e) {
        print("Camera error: $e");
        return;
      }
    }
    
    if (cameras.isEmpty) return;
    
    CameraDescription selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front, 
      orElse: () => cameras[0]
    );
    
    _controller = CameraController(
      selectedCamera, 
      ResolutionPreset.low, // Low for best performance
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    
    try {
      await _controller?.initialize();
      if (!mounted) return;
      
      // IMPORTANT: Trigger UI update after camera is ready
      if (mounted) {
        setState(() {
          // Camera is now initialized, UI will rebuild and show preview
        });
      }
      
      // Start image stream immediately
      _controller?.startImageStream(_processCameraImage);
      print("✅ Camera initialized and streaming");
    } catch (e) {
      print("Camera init error: $e");
      if (mounted) {
        setState(() {
          // Update UI even on error
        });
      }
    }
  }

  // Move this to top level or static for compute


  int _missedFrameCounter = 0; // Persistence for word buffer

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _plugin == null) return;
    
    _frameCounter++;
    // OPTIMIZATION: Process every 2nd frame for faster tracking
    if (_frameCounter % 2 != 0) return; 
    
    _isDetecting = true;
    
    try {
       final hands = _plugin!.detect(image, _controller!.description.sensorOrientation);
       
       if (mounted) {
          _sensorRotation = _controller!.description.sensorOrientation;
          bool isFrontCamera = _controller!.description.lensDirection == CameraLensDirection.front;

          List<Map<String, dynamic>> rawHandsData = [];
          
          List<List<double>> uiHands = []; // For drawing

          // OPTIMIZATION: Rotation flags
          bool rotate90 = _sensorRotation == 90;
          bool rotate270 = _sensorRotation == 270;
          bool rotate180 = _sensorRotation == 180;
          
          for (var hand in hands) {
            List<double> normalizedLandmarks = [];
            for (var landmark in hand.landmarks) {
               double px = landmark.x;
               double py = landmark.y;
               
               double finalX = px;
               double finalY = py;
               
               if (rotate90) {
                 finalX = 1.0 - py;
                 finalY = px;
               } else if (rotate270) {
                 finalX = py;
                 finalY = 1.0 - px;
               } else if (rotate180) {
                 finalX = 1.0 - px;
                 finalY = 1.0 - py;
               }

               if (isFrontCamera) {
                 finalX = 1.0 - finalX;
               }
               
               normalizedLandmarks.add(finalX);
               normalizedLandmarks.add(finalY);
            }
            uiHands.add(normalizedLandmarks);
            
            // Reverted to raw data passing (no label)
            rawHandsData.add({
              'landmarks': normalizedLandmarks,
            });
          }
           
          _handsNotifier.value = uiHands;

          if (rawHandsData.isNotEmpty) {
            _missedFrameCounter = 0; // Reset counter on detection

            // Run heavy normalization in Isolate using Spatial Sorting
            final features = await compute(_processHandLandmarksSpatial, rawHandsData);
            
            if (currentMode == "LETTRES") {
               _runInferenceLetters(features);
            } else {
               _runInferenceWords(features);
            }
          } else {
            // "Grace Period" logic: Don't clear immediately
            _missedFrameCounter++;
            if (_missedFrameCounter > 5) { // ~300ms grace period
               _detectedTextNotifier.value = "En attente...";
               _sequenceBuffer.clear();
            }
          }
        }
     } catch (e) {
       print("Vision error: $e");
     } finally { 
       _isDetecting = false;
     }
  }

  // UPDATED ISOLATE FUNCTION: Spatial Sorting (Left->Right)
  static List<double> _processHandLandmarksSpatial(List<Map<String, dynamic>> handsData) {
    if (handsData.isEmpty) return List.filled(84, 0.0);

    List<double> getLandmarks(Map<String, dynamic> hand) {
      return (hand['landmarks'] as List).cast<double>();
    }

    // Sort hands left-to-right based on first landmark X
    handsData.sort((a, b) {
      double xa = getLandmarks(a)[0];
      double xb = getLandmarks(b)[0];
      return xa.compareTo(xb);
    });

    List<double> features = [];

    // SINGLE HAND CASE:
    // If only 1 hand is detected, we put it in the first slot (0-41)
    // and zero-pad the second slot (42-83).
    // This matches the Python training where single-hand samples are usually stored in the first block.
    // LIMITATION: If the user uses their Right hand, and it's the only hand, it goes to Slot 1.
    // If the model expects Right Hand in Slot 2, this fails. 
    // BUT since we can't determine chirality without 'label', we assume consistency.
    
    if (handsData.length == 1) {
       features.addAll(getLandmarks(handsData[0])); // Slot 1
       features.addAll(List.filled(42, 0.0));      // Slot 2
    } else {
       // TWO HANDS: Slot 1 = Leftmost, Slot 2 = Rightmost
       // Take max 2 hands
       for (var hand in handsData.take(2)) {
         features.addAll(getLandmarks(hand));
       }
    }
    
    // Safety padding if < 84 (should unlikely happen with logic above)
    while (features.length < 84) features.add(0.0);

    // Normalization (Min-Max Shift)
    // We normalize the whole set relative to the bounding box of ALL hands
    List<double> allXs = [];
    List<double> allYs = [];
    
    for (int i = 0; i < features.length; i += 2) {
       // Only count non-zero landmarks (simple heuristic, or verify if handsData used padding)
       // Actually, we should collect min/max from original hands, not the padded-with-zeros vector
       // But wait... features contains 0.0 for missing hand. 0.0 is a valid coordinate? 
       // No, valid coordinates are usually > 0 if normalized?
       // Let's iterate original handsData for normalization stats
    }
    
    allXs.clear(); allYs.clear();
    for (var hand in handsData) {
       List<double> lm = getLandmarks(hand);
       for (int i = 0; i < lm.length; i+=2) {
          allXs.add(lm[i]);
          allYs.add(lm[i+1]);
       }
    }
    
    if (allXs.isEmpty) return List.filled(84, 0.0);

    double min_X = allXs.reduce((curr, next) => curr < next ? curr : next);
    double min_Y = allYs.reduce((curr, next) => curr < next ? curr : next);

    // Apply normalization to the FEATURES vector
    // We only normalize the NON-ZERO parts (the actual hands)
    // If we simply subtract min_X from 0.0 (padding), we get negative values.
    // So we should rebuild features properly.
    
    List<double> normalizedFeatures = [];
    
    if (handsData.length == 1) {
       List<double> h1 = getLandmarks(handsData[0]);
       for (int i=0; i<h1.length; i+=2) {
          normalizedFeatures.add(h1[i] - min_X);
          normalizedFeatures.add(h1[i+1] - min_Y);
       }
       normalizedFeatures.addAll(List.filled(42, 0.0));
    } else {
       for (var hand in handsData.take(2)) {
          List<double> h = getLandmarks(hand);
          for (int i=0; i<h.length; i+=2) {
             normalizedFeatures.add(h[i] - min_X);
             normalizedFeatures.add(h[i+1] - min_Y);
          }
       }
    }
    
    return normalizedFeatures;
  }

  void _runInferenceLetters(List<double> features) {
    if (_interpreterLetters == null) return;
    
    var input = [features];
    var output = List.filled(1, List.filled(_labelsLetters.length, 0.0));
    
    try {
      _interpreterLetters!.run(input, output);
    } catch (e) {
      print("❌ Inference error: $e");
      return;
    }

    int maxIdx = 0;
    double maxProb = -1.0;
    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > maxProb) {
        maxProb = output[0][i];
        maxIdx = i;
      }
    }

    // MATCH PYTHON: 0.4 threshold (using 0.5 for slightly safer margin)
    if (maxProb > 0.5) { 
      String label = _labelsLetters[maxIdx];
      
      _letterBuffer.add(label);
      if (_letterBuffer.length > 5) _letterBuffer.removeAt(0);

      int count = _letterBuffer.where((e) => e == label).length;
      if (count >= 3 && detectedText != label) { // 3/5 consistency
        _onGestureDetected(label);
      }
    } else if (maxProb < 0.2) {
      _letterBuffer.clear();
    }
  }

  void _runInferenceWords(List<double> features) {
    if (_interpreterWords == null) return;
    
    // Add to sequence buffer
    _sequenceBuffer.add(features);
    if (_sequenceBuffer.length > _sequenceLength) _sequenceBuffer.removeAt(0);

    // Need full sequence for word detection
    if (_sequenceBuffer.length == _sequenceLength) {
      // Flatten: [ [84], [84]... ] -> [ 84*15 ]
      var flattenedSequence = _sequenceBuffer.expand((f) => f).toList();
      var input = [flattenedSequence];
      var output = List.filled(1, List.filled(_labelsWords.length, 0.0));
      _interpreterWords!.run(input, output);

      int maxIdx = 0;
      double maxProb = -1.0;
      for (int i = 0; i < output[0].length; i++) {
        if (output[0][i] > maxProb) {
          maxProb = output[0][i];
          maxIdx = i;
        }
      }
      
      // LOG PROBS for Debugging
      // print("Word Prob: $maxProb for ${_labelsWords[maxIdx]}");

      // MATCH PYTHON: "Candidate History" & Voting
      // Python: History 10, Freq >= 5, Prob > 0.15
      
      String label = _labelsWords[maxIdx];
      
      _wordCandidateHistory.add(label);
      if (_wordCandidateHistory.length > 10) _wordCandidateHistory.removeAt(0);
      
      int freq = _wordCandidateHistory.where((e) => e == label).length;
      
      // Threshold: 0.15 (Python) -> Using 0.3 for safety
      // Threshold: Lowered to 0.25/4 for better responsiveness
      if (maxProb > 0.25 && freq >= 4) {
         // Anti-spam handled in _onGestureDetected with timeout
         _onGestureDetected(label);
         
         // Don't clear immediately, let it flow? 
         // Python: self.candidate_history = [] # Reset après validation
         _wordCandidateHistory.clear();
         _sequenceBuffer.clear();
      }
    }
  }

  DateTime _lastGestureTime = DateTime.now();

  Future<void> _onGestureDetected(String gestureKey) async {
    if (gestureKey.isEmpty) return;
    
    final now = DateTime.now();
    if (now.difference(_lastGestureTime).inMilliseconds < 1500) return;
    _lastGestureTime = now;

    String translated = gestureKey;
    String targetLang = _selectedLanguage;

    if (currentMode == "LETTRES") {
      translated = _translationsLetters[gestureKey.toUpperCase()]?[targetLang] ?? gestureKey;
    } else {
      translated = _translationsWords[gestureKey.toUpperCase()]?[targetLang] ?? gestureKey;
    }

    if (translated == gestureKey && targetLang != "Français" && targetLang != "Anglais") {
       try {
         var gTrans = await _translator.translate(gestureKey, to: _languageCodes[targetLang]!);
         translated = gTrans.text;
       } catch (e) {}
    }

    if (!mounted) return;

    if (currentMode == "MOTS") {
      setState(() {
        _pendingWord = translated;
        _pendingEmoji = _translationsWords[gestureKey.toUpperCase()]?['emoji'];
        detectedText = translated;
      });
    } else {
      setState(() {
        phrase += translated;
        _detectedTextNotifier.value = translated;
      });
      _speak();
    }
  }

  void _confirmWord() {
    if (_pendingWord == null) return;
    setState(() {
      phrase += (phrase.isNotEmpty ? " " : "") + _pendingWord!;
      _pendingWord = null;
      _pendingEmoji = null;
    });
    _speak();
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _plugin?.dispose();
    super.dispose();
  }

  void _speak() async {
    if (phrase.isNotEmpty) {
      await flutterTts.setLanguage(_ttsLanguageCodes[_selectedLanguage] ?? "fr-FR");
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.speak(phrase);
    }
  }

  Future<void> _translatePhrase(String newLang) async {
    setState(() => _selectedLanguage = newLang);
    
    // Save language preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', newLang);
    
    if (phrase.isEmpty) return;
    
    String upperPhrase = phrase.toUpperCase().trim();
    String? localTranslation = _translationsLetters[upperPhrase]?[newLang] ?? _translationsWords[upperPhrase]?[newLang];
    
    if (localTranslation == null) {
       for (var entry in _translationsLetters.entries) if (entry.value.values.contains(phrase)) { localTranslation = entry.value[newLang]; break; }
       if (localTranslation == null) for (var entry in _translationsWords.entries) if (entry.value.values.contains(phrase)) { localTranslation = entry.value[newLang]; break; }
    }
    
    if (localTranslation != null) {
      setState(() { phrase = localTranslation!; detectedText = localTranslation!; });
      _speak();
      return; 
    }
    
    try {
      var translation = await _translator.translate(phrase, to: _languageCodes[newLang]!);
      setState(() => phrase = translation.text);
    } catch (e) {}
    _speak();
  }

  void _clear() => setState(() { phrase = ""; detectedText = ""; });
  
  void _backspace() => setState(() { 
      if (phrase.isNotEmpty) {
        if (currentMode == "MOTS" && phrase.contains(" ")) {
          List<String> parts = phrase.split(" ");
          parts.removeLast();
          phrase = parts.join(" ");
        } else {
          phrase = phrase.substring(0, phrase.length - 1);
        }
      }
  });
  
  void _addSpace() => setState(() { phrase += " "; });

  bool _isFlashOn = false;
  void _toggleFlash() async {
    if (_controller == null) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (e) {}
  }

  Future<void> _toggleCameraSource() async {
    setState(() {
      _isInitializing = true;
    });
    
    // Toggle source
    _useESP32Camera = !_useESP32Camera;
    
    // Re-initialize appropriate camera
    await _initCamera();
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryPurple),
              const SizedBox(height: 20),
              Text('Chargement...', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ],
          ),
        ),
      );
    }
    
    // Check camera availability
    bool hasCamera = _useESP32Camera || (_controller != null && _controller!.value.isInitialized);
    if (!hasCamera) {
       return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Camera Error", style: TextStyle(color: Colors.white))));
    }

    bool isFrontCamera = _controller!.description.lensDirection == CameraLensDirection.front;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0f172a), Color(0xFF1e1b4b)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Title Header
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF22d3ee), Color(0xFFc084fc)],
                  ).createShader(bounds),
                  child: const Text(
                    'SignLens',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),

              // 2. Camera Preview (Expanded)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Camera Stream
                        Positioned.fill(
                           child: _useESP32Camera ? _buildESP32Stream() : CameraPreview(_controller!),
                        ),
                        
                        // Hand Landmarks Overlay
                        Positioned.fill(
                          child: ValueListenableBuilder<List<List<double>>>(
                            valueListenable: _handsNotifier,
                            builder: (context, currentHands, _) {
                              if (currentHands.isEmpty) return const SizedBox.shrink();
                              return RepaintBoundary(
                                child: CustomPaint(
                                  painter: HandPainter(
                                    currentHands,
                                    _controller!.value.previewSize!,
                                    _sensorRotation,
                                    isFrontCamera
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Large Glassmorphic Letter Overlay (Bottom Center of Camera)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: RepaintBoundary(
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6366f1).withOpacity(0.3),
                                    const Color(0xFFa855f7).withOpacity(0.3)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: 2
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Center(
                                    child: ValueListenableBuilder<String>(
                                      valueListenable: _detectedTextNotifier,
                                      builder: (context, text, _) {
                                        return Text(
                                          text.isEmpty ? "" : text,
                                          style: const TextStyle(
                                            fontSize: 60,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black45,
                                                offset: Offset(0, 2),
                                                blurRadius: 4
                                              )
                                            ]
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        // Live Indicator
                        if (_useESP32Camera)
                        Positioned(
                          top: 12, left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                BlinkingDot(color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // 3. Flags Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                   _buildCircleFlag("🇫🇷", "Français"),
                   _buildCircleFlag("🇬🇧", "Anglais"),
                   _buildCircleFlag("🇹🇳", "Arabe"),
                   _buildCircleFlag("🇪🇺", "Europe"),
                   _buildCircleFlag("🌐", "Auto"),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),

              // 4. Toggles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildToggleRow("Lettre / Mot", currentMode == "MOTS", (val) {
                       setState(() => currentMode = val ? "MOTS" : "LETTRES");
                    }),
                    const SizedBox(height: 8),
                    _buildToggleRow("Caméra Native / ESP32", _useESP32Camera, (val) {
                       if (val != _useESP32Camera) {
                          _toggleCameraSource();
                       }
                    }, 
                    activeColor: AppTheme.accentCyan),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. Bottom Phrase Show
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          phrase.isEmpty ? "EN ATTENTE..." : phrase.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: phrase.isNotEmpty ? _speak : null,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8b5cf6), Color(0xFF6366f1)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.volume_up, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
  
  // -- New Helper Widgets --

  Widget _buildCircleFlag(String flag, String lang) {
    bool isSelected = _selectedLanguage == lang;
    return GestureDetector(
      onTap: () => _translatePhrase(lang),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 45, height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFF3b82f6).withOpacity(0.3) : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? const Color(0xFF60a5fa) : Colors.white10,
            width: isSelected ? 2 : 1
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFF3b82f6).withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
          ] : [],
        ),
        child: Center(
          child: Text(flag, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, Function(bool) onChanged, {Color activeColor = const Color(0xFF22d3ee)}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(
          height: 30,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
            activeTrackColor: activeColor.withOpacity(0.3),
            inactiveThumbColor: Colors.white60,
            inactiveTrackColor: Colors.white10,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Mode Toggle
          Expanded(
            child: GlassmorphismCard(
              padding: const EdgeInsets.all(4),
              borderRadius: 12,
              hasBorder: false,
              child: Row(
                children: [
                  _buildModeButton("🔤", "LETTRES"),
                  const SizedBox(width: 4),
                  _buildModeButton("📝", "MOTS"),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Language Flags
          LanguageFlagButton(
            flag: "🇫🇷",
            language: "",
            isSelected: _selectedLanguage == "Français",
            onTap: () => _translatePhrase("Français"),
          ),
          const SizedBox(width: 8),
          LanguageFlagButton(
            flag: "🇬🇧",
            language: "",
            isSelected: _selectedLanguage == "Anglais",
            onTap: () => _translatePhrase("Anglais"),
          ),
          const SizedBox(width: 8),
          LanguageFlagButton(
            flag: "🇹🇳",
            language: "",
            isSelected: _selectedLanguage == "Arabe",
            onTap: () => _translatePhrase("Arabe"),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String emoji, String mode) {
    bool isSelected = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text(
                  mode == "LETTRES" ? "Lettres" : "Mots",
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhraseDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassmorphismCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Phrase ($_selectedLanguage): $phrase",
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (phrase.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: AppTheme.accentCyan, size: 20),
                    onPressed: _speak,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
            if (phrase.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: phrase.length,
                  itemBuilder: (c, i) {
                    String char = phrase[i];
                    if (char == " ") return const SizedBox(width: 12);
                    String k = char.toUpperCase();
                    
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 45,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: Image.asset(
                                'assets/gestures/${k}_0.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Center(
                                  child: Icon(Icons.error_outline, size: 10, color: Colors.white24)
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              char,
                              style: const TextStyle(
                                color: AppTheme.accentCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(bool isFrontCamera) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Preview (ESP32 or Phone)
            _useESP32Camera ? _buildESP32Stream() : CameraPreview(_controller!),
            
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_useESP32Camera) ...[
                      BlinkingDot(color: Colors.redAccent),
                      const SizedBox(width: 8),
                      const Text(
                        'EN DIRECT',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 12, color: Colors.white24),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      _useESP32Camera ? Icons.wifi : Icons.phone_android,
                      size: 14,
                      color: _useESP32Camera ? AppTheme.accentCyan : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _useESP32Camera ? 'ESP32-CAM' : 'Téléphone',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Hand Landmarks Overlay
            ValueListenableBuilder<List<List<double>>>(
              valueListenable: _handsNotifier,
              builder: (context, currentHands, _) {
                if (currentHands.isEmpty) return const SizedBox.shrink();
                return CustomPaint(
                  painter: HandPainter(
                    currentHands, 
                    _controller!.value.previewSize!, 
                    _sensorRotation, 
                    isFrontCamera
                  ),
                );
              },
            ),
            
            // Detection Display Overlay
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: ValueListenableBuilder<String>(
                        valueListenable: _detectedTextNotifier,
                        builder: (context, text, _) => Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Word Confirmation Button
            if (_pendingWord != null)
              Center(
                child: GestureDetector(
                  onTap: _confirmWord,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withOpacity(0.5),
                          blurRadius: 30,
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_pendingEmoji ?? "✅", style: const TextStyle(fontSize: 60)),
                        Text(
                          _pendingWord!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildControlButton(Icons.delete_outline, Colors.red, _clear),
          const SizedBox(width: 8),
          _buildControlButton(Icons.backspace_outlined, Colors.orange, _backspace),
          const SizedBox(width: 8),
          _buildControlButton(Icons.space_bar, Colors.blue, _addSpace),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/esp32-config'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentCyan),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam, color: AppTheme.accentCyan, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'ESP32-CAM',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, Color color, VoidCallback onPressed) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  // -- Action Buttons (Clear, Backspace, Space, Config) --
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMiniButton(Icons.delete_outline, Colors.redAccent, _clear),
          _buildMiniButton(Icons.backspace_outlined, Colors.orangeAccent, _backspace),
          _buildMiniButton(Icons.space_bar, Colors.blueAccent, _addSpace),
          _buildMiniButton(Icons.settings, Colors.grey, () => Navigator.pushNamed(context, '/esp32-config')),
        ],
      ),
    );
  }

  Widget _buildMiniButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
  
  // Widget for ESP32-CAM stream
  Widget _buildESP32Stream() {
    final streamUrl = _esp32Service.getStreamUrl();
    
    if (streamUrl == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.white54),
              const SizedBox(height: 12),
              Text(
                'ESP32-CAM non disponible',
                style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Retour à la caméra du téléphone...',
                style: AppTheme.bodyMedium.copyWith(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    
    // Check connectivity first
    if (!_esp32Service.isConnected.value) {
       _esp32Service.testConnection().then((connected) {
         if (mounted && !connected) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("ESP32 non connecté. Vérifiez l'adresse IP."))
           );
         }
       });
    }

    // Use a unique key to force refresh if stream stalls
    // Use Mjpeg widget for robust stream handling
    // Use custom MjpegWidget
    return MjpegWidget(
      streamUrl: streamUrl,
      fit: BoxFit.cover,
      errorBuilder: (context) {
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_outlined, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                Text(
                  'Flux vidéo interrompu',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text("Réessayer", style: TextStyle(color: AppTheme.accentCyan)),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

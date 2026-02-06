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
  bool _mirrorLandmarks = true; // Default for front camera
  
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
  final ValueNotifier<String> _debugInfoNotifier = ValueNotifier("Initializing...");
  final ValueNotifier<double> _confidenceNotifier = ValueNotifier(0.0);

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
    // Listen to connection changes for auto-switching
    _esp32Service.isConnected.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    _esp32Service.isConnected.removeListener(_onConnectionChanged);
    _controller?.stopImageStream();
    _controller?.dispose();
    _plugin?.dispose();
    super.dispose();
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    bool isConnected = _esp32Service.isConnected.value;
    
    // Valid only if enabled in settings
    if (_esp32Service.isEnabled.value) {
      setState(() {
         // Auto-switch: If connected -> ESP32, else -> Phone
         _useESP32Camera = isConnected; 
      });
      
      // Trigger camera resource switch
      _initCamera();
      
      if (isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📡 ESP32-CAM Connectée - Passage en vue Live"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          )
        );
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ ESP32-CAM Déconnectée - Retour caméra téléphone"),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          )
        );
      }
    }
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
      
      // FORCE ESP32 if enabled (User preference overrides connectivity check)
      // MjpegWidget in _buildESP32Stream will handle loading/reconnecting UI
      if (_esp32Service.isEnabled.value) {
          // Trigger a background test but don't wait for it to decide UI
          _esp32Service.testConnection(); 
          _useESP32Camera = true;
          print("⚡ Priority to ESP32-CAM (Enabled in settings)");
      } else {
          _useESP32Camera = false;
      }
      
      // Request permissions
      _requestPermissions();
      
      // Sequential initialization to prevent race conditions
      // Plugin requires ModelService to be initialized first
      await _initCamera(); 
      await _loadModels(); 
      await _initPlugin();
      
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
      // Note: hand_landmarker plugin downloads model if not found.
      // We ensure permissions are granted before this.
      _plugin = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.5, 
        delegate: HandLandmarkerDelegate.gpu, 
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
      
      // Ensure assets are copied to storage
      await modelService.initialize();
      
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
      
      // ERROR CHECK
      if (modelService.loadError != null) {
         if (mounted) {
           showDialog(
             context: context, 
             builder: (ctx) => AlertDialog(
               title: const Text("⚠️ Erreur Modèle AI"),
               content: SingleChildScrollView(child: Text(modelService.loadError!)),
               actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
             )
           );
         }
      }
      
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

               if (_mirrorLandmarks) {
                 finalX = 1.0 - finalX;
               }
               
               normalizedLandmarks.add(finalX);
               normalizedLandmarks.add(finalY);
            }
            uiHands.add(normalizedLandmarks);
            
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

  // UPDATED ISOLATE FUNCTION: Spatial Sorting AND Relative Normalization
  static List<double> _processHandLandmarksSpatial(List<Map<String, dynamic>> handsData) {
    if (handsData.isEmpty) return List.filled(84, 0.0);

    List<double> getLandmarks(Map<String, dynamic> hand) {
      return (hand['landmarks'] as List).cast<double>();
    }

    // 1. Sort hands left-to-right
    handsData.sort((a, b) {
      double xa = getLandmarks(a)[0];
      double xb = getLandmarks(b)[0];
      return xa.compareTo(xb);
    });

    // 2. Calculate MinX and MinY across ALL detected landmarks (Global bounding box for the frame)
    double minX = double.infinity;
    double minY = double.infinity;

    for (var hand in handsData) {
      List<double> lm = getLandmarks(hand);
      for (int i = 0; i < lm.length; i += 2) {
        if (lm[i] < minX) minX = lm[i];
        if (lm[i+1] < minY) minY = lm[i+1];
      }
    }

    // 3. Normalize relative to minX, minY
    List<double> normalizeHand(List<double> landmarks) {
      List<double> normalized = [];
      for (int i = 0; i < landmarks.length; i += 2) {
        normalized.add(landmarks[i] - minX);
        normalized.add(landmarks[i+1] - minY);
      }
      return normalized;
    }

    List<double> features = [];

    // SINGLE HAND CASE
    if (handsData.length == 1) {
       features.addAll(normalizeHand(getLandmarks(handsData[0]))); // Slot 1
       features.addAll(List.filled(42, 0.0));      // Slot 2 (Padding)
    } 
    // TWO HANDS CASE
    else {
       features.addAll(normalizeHand(getLandmarks(handsData[0]))); // Slot 1
       features.addAll(normalizeHand(getLandmarks(handsData[1]))); // Slot 2
    }

    return features;
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

    if (maxProb > 0.5) { 
      String label = _labelsLetters[maxIdx];
      _debugInfoNotifier.value = "Letter: $label (${(maxProb * 100).toStringAsFixed(1)}%)";
      _confidenceNotifier.value = maxProb;
      
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
      Object input;
      
      // LOGIC SWITCH: LSTM (Sequence) vs Dense (Flattened)
      if (ModelService().isLstmModel) {
         // LSTM INPUT: [Batch, Time, Features] -> [1, 15, 84]
         input = [_sequenceBuffer]; 
      } else {
         // DENSE INPUT: [Batch, Time * Features] -> [1, 1260]
         // Flatten the sequence
         List<double> flattened = [];
         for (var frame in _sequenceBuffer) {
           flattened.addAll(frame);
         }
         input = [flattened];
      }

      // Output: [Batch, NumClasses] -> [1, N]
      var output = List.filled(1, List.filled(_labelsWords.length, 0.0));
      
      try {
        _interpreterWords!.run(input, output);
      } catch (e) {
        print("Inference error: $e");
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
      
      String label = _labelsWords[maxIdx];
      _debugInfoNotifier.value = "Word: $label (${(maxProb * 100).toStringAsFixed(1)}%)";
      _confidenceNotifier.value = maxProb;
      
      _wordCandidateHistory.add(label);
      if (_wordCandidateHistory.length > 10) _wordCandidateHistory.removeAt(0);
      
      int freq = _wordCandidateHistory.where((e) => e == label).length;
      
      if (maxProb > 0.85 && freq >= 6) {
         _onGestureDetected(label);
         
         // Clear buffer to prevent double triggers for the same gesture instance
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
    
    // Google Translate avec détection automatique de la langue source
    try {
      var translation = await _translator.translate(
        phrase, 
        from: 'auto',  // Détection automatique FR/EN/AR
        to: _languageCodes[newLang]!
      );
      setState(() {
        phrase = translation.text;
        detectedText = translation.text;
      });
    } catch (e) {
      print('Translation error: $e');
    }
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

    bool isFrontCamera = (_controller != null) && (_controller!.description.lensDirection == CameraLensDirection.front);

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
                        _useESP32Camera 
                             ? _buildESP32Stream() 
                             : CameraPreview(_controller!),
                        
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
                                    _useESP32Camera ? const Size(640, 480) : _controller!.value.previewSize!,
                                    _sensorRotation,
                                    _useESP32Camera ? false : isFrontCamera
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

                        // TOP DEBUG OVERLAY
                        Positioned(
                          top: 50, left: 16, right: 16,
                          child: ValueListenableBuilder<String>(
                            valueListenable: _debugInfoNotifier,
                            builder: (context, info, _) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bug_report, size: 14, color: Colors.orangeAccent),
                                    const SizedBox(width: 8),
                                    Text(
                                      info,
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          ),
                        ),
                        if (_useESP32Camera)
                        Positioned(
                          top: 12, left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                BlinkingDot(color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                              ],
                            ),
                          ),
                        ),

                        // Word Confirmation Overlay
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
                    const SizedBox(height: 8),
                    _buildToggleRow("Miroir Landmarks", _mirrorLandmarks, (val) {
                       setState(() => _mirrorLandmarks = val);
                    }, 
                    activeColor: Colors.pinkAccent),
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
    
    if (!_esp32Service.isConnected.value) {
       _esp32Service.testConnection();
    }

    return MjpegWidget(
      streamUrl: streamUrl,
      fit: BoxFit.cover,
      onFrame: _processESP32Frame,
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

  // Platform Channel for ESP32 Native Detection
  static const platform = MethodChannel('com.doosr.signlanguageapp/esp32');

  void _processESP32Frame(Uint8List jpegBytes) async {
    if (_isDetecting || !mounted) return;
    
    _frameCounter++;
    if (_frameCounter % 3 != 0) return; // Limit FPS
    
    _isDetecting = true;
    
    try {
      // Invoke Native Hand Detection
      final List<dynamic>? result = await platform.invokeMethod('detectFromJpeg', {'bytes': jpegBytes});
      
      if (result != null && mounted) {
           _sensorRotation = 0; // ESP32 is usually fixed/landscape
           
           List<Map<String, dynamic>> rawHandsData = [];
           List<List<double>> uiHands = []; 

           for (var x in result) {
              // Convert Native result to Dart expected format
              // Native returns List<Map<String, List<double>>>
              Map<Object?, Object?> handMap = x as Map<Object?, Object?>;
              List<dynamic> lmDyn = handMap['landmarks'] as List<dynamic>;
              List<double> landmarks = lmDyn.cast<double>();
              
              uiHands.add(landmarks);
              rawHandsData.add({
                'landmarks': landmarks,
              });
           }
           
           _handsNotifier.value = uiHands;

           if (rawHandsData.isNotEmpty) {
             _missedFrameCounter = 0;
             
             // Run Normalization & Inference (Same pipeline as Phone Camera)
             final features = await compute(_processHandLandmarksSpatial, rawHandsData);
             
             if (currentMode == "LETTRES") {
                _runInferenceLetters(features);
             } else {
                _runInferenceWords(features);
             }
           } else {
             _missedFrameCounter++;
             if (_missedFrameCounter > 5) {
                _detectedTextNotifier.value = "En attente...";
                _sequenceBuffer.clear();
             }
           }
      }
    } catch (e) {
      print("ESP32 Detection Error: $e");
    } finally {
      if (mounted) _isDetecting = false; 
    }
  }
}

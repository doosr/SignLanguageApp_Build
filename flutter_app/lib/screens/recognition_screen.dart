import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
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
    _initializeFast();
  }

  Future<void> _initializeFast() async {
    // Load language preference immediately
    final prefs = await SharedPreferences.getInstance();
    _selectedLanguage = prefs.getString('language') ?? 'Français';
    
    // Check ESP32 camera availability
    _useESP32Camera = _esp32Service.isEnabled.value && _esp32Service.isConnected.value;
    
    // Request permissions first (non-blocking)
    _requestPermissions();
    
    // Initialize camera FIRST for faster display
    await _initCamera();
    
    // Show camera immediately
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
    
    // Load models and plugin in background
    Future.wait([
      _loadModels(),
      _initPlugin(),
    ]);
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
      _interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      _interpreterWords = await Interpreter.fromAsset('assets/model_words.tflite');

      String labelsLettersRaw = await rootBundle.loadString('assets/model_letters_labels.txt');
      _labelsLetters = labelsLettersRaw.split('\n').where((s) => s.isNotEmpty).toList();
      
      String labelsWordsRaw = await rootBundle.loadString('assets/model_words_labels.txt');
      _labelsWords = labelsWordsRaw.split('\n').where((s) => s.isNotEmpty).toList();
      
      print("✅ Models and Labels loaded successfully!");
    } catch (e) {
      print("❌ Error loading models: $e");
    }
  }

  Future<void> _initCamera() async {
    // Check if we should use ESP32 camera
    if (_useESP32Camera) {
      // ESP32 camera doesn't need CameraController
      print("✅ Using ESP32-CAM stream");
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
      
      // Start image stream immediately
      _controller?.startImageStream(_processCameraImage);
      print("✅ Camera initialized and streaming");
    } catch (e) {
      print("Camera init error: $e");
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _plugin == null) return;
    
    _frameCounter++;
    if (_frameCounter % 12 != 0) return; // Increased frame skipping for better performance
    
    _isDetecting = true;
    
    try {
       final hands = _plugin!.detect(image, _controller!.description.sensorOrientation);
       
       if (mounted) {
          _sensorRotation = _controller!.description.sensorOrientation;
          bool isFrontCamera = _controller!.description.lensDirection == CameraLensDirection.front;

          List<List<double>> convertedHands = [];
          
          for (var hand in hands) {
            List<double> normalizedLandmarks = [];
            for (var landmark in hand.landmarks) {
               double px = landmark.x;
               double py = landmark.y;
               
               double finalX = px;
               double finalY = py;
               
               if (_sensorRotation == 90) {
                 finalX = 1.0 - py;
                 finalY = px;
               } else if (_sensorRotation == 270) {
                 finalX = py;
                 finalY = 1.0 - px;
               } else if (_sensorRotation == 180) {
                 finalX = 1.0 - px;
                 finalY = 1.0 - py;
               }

               if (isFrontCamera) {
                 finalX = 1.0 - finalX;
               }
               
               normalizedLandmarks.add(finalX);
               normalizedLandmarks.add(finalY);
            }
            convertedHands.add(normalizedLandmarks);
          }
           
          _handsNotifier.value = convertedHands;

          if (convertedHands.isNotEmpty) {
            final features = _processHandLandmarksForClassifier(convertedHands);
            if (currentMode == "LETTRES") {
               _runInferenceLetters(features);
            } else {
               _runInferenceWords(features);
            }
          } else {
            _detectedTextNotifier.value = "En attente...";
            _sequenceBuffer.clear();
          }
        }
     } catch (e) {
       print("Vision error: $e");
     } finally { 
       _isDetecting = false;
     }
  }

  List<double> _processHandLandmarksForClassifier(List<List<double>> hands) {
    if (hands.isEmpty) return List.filled(84, 0.0);

    // Sort hands left to right
    List<List<double>> sorted = List.from(hands);
    sorted.sort((a, b) => a[0].compareTo(b[0]));
    
    List<double> rawAll = [];
    
    // Handle single hand vs two hands
    if (sorted.length == 1) {
      // Single hand: duplicate it for consistency with 2-hand model
      rawAll.addAll(sorted[0]);
      rawAll.addAll(sorted[0]);
    } else {
      // Two hands: use both (take max 2)
      for (var h in sorted.take(2)) {
        rawAll.addAll(h);
      }
    }
    
    // Normalize coordinates relative to minimum point
    double minX = 1.0, minY = 1.0; 
    for (int i = 0; i < rawAll.length; i += 2) {
      if (rawAll[i] < minX) minX = rawAll[i];
      if (rawAll[i + 1] < minY) minY = rawAll[i + 1];
    }

    List<double> processed = [];
    for (int i = 0; i < rawAll.length; i += 2) {
      processed.add(rawAll[i] - minX);
      processed.add(rawAll[i + 1] - minY);
    }
    
    // Ensure exactly 84 features
    while (processed.length < 84) processed.add(0.0);
    return processed.sublist(0, 84);
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

    if (maxProb > 0.85) {
      String label = _labelsLetters[maxIdx];
      
      _letterBuffer.add(label);
      if (_letterBuffer.length > 5) _letterBuffer.removeAt(0);

      int count = _letterBuffer.where((e) => e == label).length;
      if (count >= 4 && detectedText != label) {
        _onGestureDetected(label);
      }
    } else if (maxProb < 0.2) {
      _letterBuffer.clear();
    }
  }

  void _runInferenceWords(List<double> features) {
    if (_interpreterWords == null) return;
    _sequenceBuffer.add(features);
    if (_sequenceBuffer.length > _sequenceLength) _sequenceBuffer.removeAt(0);

    if (_sequenceBuffer.length == _sequenceLength) {
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

      if (maxProb > 0.60) { // Improved threshold for better word detection
        String label = _labelsWords[maxIdx];
        
        _wordCandidateHistory.add(label);
        if (_wordCandidateHistory.length > 8) _wordCandidateHistory.removeAt(0);
        
        int freq = _wordCandidateHistory.where((e) => e == label).length;
        
        if (freq >= 3 && detectedText != label) { // Reduced from 4 to 3 for faster response
           _onGestureDetected(label);
           _wordCandidateHistory.clear();
           _sequenceBuffer.clear();
        }
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

  @override
  Widget build(BuildContext context) {
    // Show loading indicator during initialization
    if (_isInitializing) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppTheme.accentCyan),
                const SizedBox(height: 20),
                Text(
                  'Chargement...',
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Check if using ESP32 camera or phone camera
    bool hasCamera = _useESP32Camera || (_controller != null && _controller!.value.isInitialized);
    
    if (!hasCamera) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 64, color: AppTheme.textMuted),
                const SizedBox(height: 20),
                Text(
                  'Caméra non disponible',
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    bool isFrontCamera = _controller!.description.lensDirection == CameraLensDirection.front;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header
              _buildHeader(),
              
              const SizedBox(height: 8),
              
              // Language & Mode Selection
              _buildControls(),
              
              const SizedBox(height: 12),
              
              // Phrase Display with Glassmorphism
              _buildPhraseDisplay(),
              
              const SizedBox(height: 12),
              
              // Camera Preview with Landmarks
              Expanded(
                child: _buildCameraPreview(isFrontCamera),
              ),
              
              const SizedBox(height: 12),
              
              // Bottom Controls
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          ShaderMask(
            shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              'Reconnaissance',
              style: AppTheme.headingMedium.copyWith(
                fontSize: 22,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? Colors.amber : AppTheme.textMuted,
            ),
            onPressed: _toggleFlash,
          ),
        ],
      ),
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
            
            // Camera source indicator
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
                    Icon(
                      _useESP32Camera ? Icons.wifi : Icons.phone_android,
                      size: 14,
                      color: _useESP32Camera ? AppTheme.accentCyan : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _useESP32Camera ? 'ESP32' : 'Téléphone',
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
    
    return Image.network(
      streamUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: AppTheme.accentCyan),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Fallback to phone camera on error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _useESP32Camera = false;
            });
            _initCamera();
          }
        });
        
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Erreur de connexion ESP32',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  'Basculement vers caméra téléphone...',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

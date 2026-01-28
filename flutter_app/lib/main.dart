import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:translator/translator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: $e.code\nError Message: $e.message');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HandGesture App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F2633),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
      ),
      home: const HandGestureHome(),
    );
  }
}

class HandGestureHome extends StatefulWidget {
  const HandGestureHome({super.key});

  @override
  State<HandGestureHome> createState() => _HandGestureHomeState();
}

class _HandGestureHomeState extends State<HandGestureHome> {
  // Controllers
  CameraController? _controller;
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText _speech = stt.SpeechToText();
  final GoogleTranslator _translator = GoogleTranslator();
  
  // Vision
  HandLandmarkerPlugin? _plugin;
  bool _isDetecting = false;
  int _frameCounter = 0; // For performance optimization
  List<Hand> _landmarks = [];
  
  // State
  String detectedText = "En attente...";
  String phrase = "";
  String currentMode = "LETTRES"; 
  bool isListening = false;
  String currentEspIp = "192.168.1.100";
  String? _pendingWord;
  String? _pendingEmoji;
  int _sensorRotation = 0; 
  
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
  List<List<double>> _flutterHands = []; // Store detected hands (21 points)

  // Interpreters
  Interpreter? _interpreterLetters;
  Interpreter? _interpreterWords;

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
    _initializeSafe();
  }

  Future<void> _initializeSafe() async {
    await _requestPermissions();
    
    // Performance: Load models and plugin in parallel for faster startup
    try {
      await Future.wait([
        _loadModels(),
        _initPlugin(),
      ]);
    } catch (e) {
      print("Initialization parallel error: $e");
    }

    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (e) {
        print("Camera info error: $e");
      }
    }
    
    // Slight delay to ensure system is ready
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _initCamera();
  }

  Future<void> _initPlugin() async {
    try {
      _plugin = HandLandmarkerPlugin.create(
        numHands: 2, // Support for 2 hands as requested
        minHandDetectionConfidence: 0.7, // Higher precision
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
      print("📦 Loading model_letters.tflite..."); // DEBUG
      _interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      print("✅ model_letters loaded"); // DEBUG
      
      print("📦 Loading model_words.tflite..."); // DEBUG
      _interpreterWords = await Interpreter.fromAsset('assets/model_words.tflite');
      print("✅ model_words loaded"); // DEBUG

      String labelsLettersRaw = await rootBundle.loadString('assets/model_letters_labels.txt');
      _labelsLetters = labelsLettersRaw.split('\n').where((s) => s.isNotEmpty).toList();
      print("✅ Loaded ${_labelsLetters.length} letter labels"); // DEBUG
      
      String labelsWordsRaw = await rootBundle.loadString('assets/model_words_labels.txt');
      _labelsWords = labelsWordsRaw.split('\n').where((s) => s.isNotEmpty).toList();
      print("✅ Loaded ${_labelsWords.length} word labels"); // DEBUG
      
      print("✅ Models and Labels loaded successfully!"); // DEBUG
    } catch (e) {
      print("❌ Error loading models: $e"); // DEBUG
    }
  }

  void _initCamera() {
    if (cameras.isEmpty) return;
    CameraDescription selectedCamera = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.front, orElse: () => cameras[0]);
    _controller = CameraController(selectedCamera, ResolutionPreset.low, enableAudio: false); // Low resolution for better performance
    _controller?.initialize().then((_) {
      if (!mounted) return;
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _plugin == null) return; // Guard
    
    // Performance: Skip frames (process every 3rd frame)
    _frameCounter++;
    if (_frameCounter % 3 != 0) return;
    
    _isDetecting = true;
    final swFrame = Stopwatch()..start();
    
    try {
       // Plugin detection (Sync or Async depending on version, example says Sync?)
       // Checking source: "The detect method is now synchronous" according to user snippet.
       // But CameraImage streaming is async.
       
       final swDetect = Stopwatch()..start();
       final hands = _plugin!.detect(image, _controller!.description.sensorOrientation);
       swDetect.stop();
       
       if (mounted) {
         final swConvert = Stopwatch()..start();
         // Save rotation for UI debug
         _sensorRotation = _controller!.description.sensorOrientation;

         // Convert to existing format List<List<double>> for Painter and Classifier
         List<List<double>> convertedHands = hands.map((h) => h.landmarks.expand((l) => [l.x, l.y]).toList()).toList();
         swConvert.stop();
          
         setState(() {
           _flutterHands = convertedHands;
           if (_flutterHands.isEmpty) detectedText = "En attente...";
         });

         if (_flutterHands.isNotEmpty) {
           final swInference = Stopwatch()..start();
           final features = _processHandLandmarksForClassifier(convertedHands);
           if (currentMode == "LETTRES") {
              _runInferenceLetters(features);
           } else {
              _runInferenceWords(features);
           }
           swInference.stop();
          
           // Log performance every 30 frames (to avoid spamming but see lag)
           if (_frameCounter % 30 == 0) {
             print("⏱️ Performance (ms): Detect: ${swDetect.elapsedMilliseconds}, Convert: ${swConvert.elapsedMilliseconds}, Inference: ${swInference.elapsedMilliseconds}, Total Process: ${swFrame.elapsedMilliseconds}");
           }
         } else {
           _sequenceBuffer.clear();
         }
       }
    } catch (e) {
      print("Vision error: $e");
    } finally { 
      _isDetecting = false;
      swFrame.stop();
    }
  }

  List<double> _processHandLandmarksForClassifier(List<List<double>> hands) {
    // Optimized: Reduce processing overhead
    List<List<double>> sorted = List.from(hands);
    sorted.sort((a, b) => a[0].compareTo(b[0]));
    
    List<double> rawAll = [];
    for (var h in sorted) rawAll.addAll(h);
    
    // Normalize relative to bounding box
    if (rawAll.isNotEmpty) {
      double minX = rawAll[0], minY = rawAll[1];
      for (int i = 0; i < rawAll.length; i += 2) {
        if (rawAll[i] < minX) minX = rawAll[i];
        if (rawAll[i + 1] < minY) minY = rawAll[i + 1];
      }
      for (int i = 0; i < rawAll.length; i += 2) {
        rawAll[i] -= minX;
        rawAll[i + 1] -= minY;
      }
    }
    
    while (rawAll.length < 84) rawAll.add(0.0);
    return rawAll.sublist(0, 84);
  }





  void _runInferenceLetters(List<double> features) {
    if (_interpreterLetters == null) {
      print("❌ Letter interpreter is null!");
      return;
    }
    
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

    if (maxProb > 0.80) { // Matched with inference_classifier.py standard
      String label = _labelsLetters[maxIdx];
      
      // Stabilization logic (Voting)
      _letterBuffer.add(label);
      if (_letterBuffer.length > _bufferSize) _letterBuffer.removeAt(0);

      // Check if the majority in buffer is this label
      int count = _letterBuffer.where((e) => e == label).length;
      if (count >= 3 && detectedText != label) {
        _onGestureDetected(label);
      }
    } else {
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

      if (maxProb > 0.80) {
        String label = _labelsWords[maxIdx];
        if (detectedText != label) {
           _onGestureDetected(label);
           _sequenceBuffer.clear();
        }
      }
    }
  }

  DateTime _lastGestureTime = DateTime.now();

  Future<void> _onGestureDetected(String gestureKey) async {
    if (gestureKey.isEmpty) return;
    
    // Cooldown: Avoid processing too fast which causes lag and repetition
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
      // Python style: Show suggestion button for validation
      setState(() {
        _pendingWord = translated;
        _pendingEmoji = _translationsWords[gestureKey.toUpperCase()]?['emoji'];
        detectedText = translated;
      });
    } else {
      // Letters: Direct writing
      setState(() {
        phrase += translated;
        detectedText = translated;
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

  // --- Actions ---
  void _speak() async {
    if (phrase.isNotEmpty) {
      await flutterTts.setLanguage(_ttsLanguageCodes[_selectedLanguage] ?? "fr-FR");
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.speak(phrase);
    }
  }

  Future<void> _translatePhrase(String newLang) async {
    String oldLangCode = _languageCodes[_selectedLanguage]!;
    setState(() => _selectedLanguage = newLang);
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
  
  // ESP32-CAM Stream
  void _openESP32Stream() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1F2633),
          title: Text('ESP32-CAM Stream', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IP: $currentEspIp', style: TextStyle(color: Colors.cyan, fontSize: 16)),
              SizedBox(height: 16),
              Text('Ouvrir le stream dans:', style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _launchESP32Browser();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_browser, color: Colors.cyan),
                  SizedBox(width: 8),
                  Text('Navigateur', style: TextStyle(color: Colors.cyan)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _launchESP32Browser() async {
    final Uri url = Uri.parse('http://$currentEspIp/stream');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError('Impossible d\'ouvrir l\'URL: $url');
      }
    } catch (e) {
      _showError('Erreur: $e');
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _listen() async {
    if (!isListening) {
      if (await _speech.initialize()) {
        setState(() => isListening = true);
        _speech.listen(localeId: _ttsLanguageCodes[_selectedLanguage], onResult: (val) => setState(() => phrase = val.recognizedWords));
      }
    } else {
      setState(() => isListening = false);
      _speech.stop();
    }
  }

  Widget _buildControlBtn(String label, Color color, VoidCallback onPressed) {
    return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color, padding: EdgeInsets.zero), onPressed: onPressed, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)))));
  }

  Widget _buildModeBtn(String emoji, String mode) {
    bool sel = currentMode == mode;
    return Expanded(child: GestureDetector(onTap: () => setState(() => currentMode = mode), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: sel ? Colors.green : Colors.grey[800]), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))))));
  }

  Widget _buildLangFlag(String flag, String lang) {
    bool sel = _selectedLanguage == lang;
    return GestureDetector(onTap: () => _translatePhrase(lang), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: sel ? Colors.cyan : Colors.white10, borderRadius: BorderRadius.circular(20)), child: Text(flag, style: const TextStyle(fontSize: 24))));
  }

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
    if (_controller == null || !_controller!.value.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    bool isFrontCamera = _controller!.description.lensDirection == CameraLensDirection.front;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(8), child: Row(children: [
              _buildControlBtn("🗑️", Colors.red, _clear),
              _buildControlBtn("🔦", _isFlashOn ? Colors.amber : Colors.grey, _toggleFlash),
              _buildControlBtn("🔊", Colors.green, _speak),
              _buildControlBtn("⬅️", Colors.orange, _backspace),
              _buildControlBtn("⌨️", Colors.blue, _addSpace),
            ])),
            Row(children: [ _buildModeBtn("🔤", "LETTRES"), _buildModeBtn("📝", "MOTS") ]),
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ _buildLangFlag("🇫🇷", "Français"), _buildLangFlag("🇺🇸", "Anglais"), _buildLangFlag("🇹🇳", "Arabe") ])),
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text("Phrase (${_selectedLanguage}): $phrase", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                if (phrase.isNotEmpty) IconButton(icon: const Icon(Icons.volume_up, color: Colors.cyan, size: 20), onPressed: _speak)
              ]),
              const SizedBox(height: 12),
              const Text("Séquence de gestes :", style: TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(height: 8),
              SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, reverse: _selectedLanguage == "Arabe", itemCount: phrase.length, itemBuilder: (c, i) {
                String char = phrase[i]; if (char == " ") return const SizedBox(width: 20);
                String k = char.toUpperCase();
                _translationsLetters.forEach((key, val) { if (val.values.any((v) => v.toUpperCase() == char.toUpperCase())) k = key; });
                return Container(margin: const EdgeInsets.only(right: 8), width: 60, decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), child: Image.asset('assets/gestures/${k}_0.jpg', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Center(child: Icon(Icons.error_outline, size: 10, color: Colors.white24))))),
                  Container(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(char, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                ]));
              }))
            ])),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
              Expanded(flex: 6, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(fit: StackFit.expand, children: [
                if (_controller != null && _controller!.value.isInitialized) 
                  CameraPreview(_controller!)
                else 
                  Center(child: CircularProgressIndicator(color: Colors.cyan)),
                if (_flutterHands.isNotEmpty)
                  CustomPaint(painter: HandPainter(_flutterHands, _controller!.value.previewSize!, _controller!.description.sensorOrientation, isFrontCamera)),
                Align(alignment: Alignment.bottomCenter, child: Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(detectedText, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text("Debug: Hands=${_flutterHands.length} | Rot: $_sensorRotation", style: const TextStyle(color: Colors.yellow, fontSize: 10))
                ]))),
                if (_pendingWord != null)
                   Center(
                     child: GestureDetector(
                       onTap: _confirmWord,
                       child: Container(
                         padding: EdgeInsets.all(20),
                         decoration: BoxDecoration(
                           color: Colors.cyan.withOpacity(0.8),
                           shape: BoxShape.circle,
                           border: Border.all(color: Colors.white, width: 4),
                           boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)]
                         ),
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Text(_pendingEmoji ?? "✅", style: TextStyle(fontSize: 60)),
                             Text(_pendingWord!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                           ],
                         ),
                       ),
                     ),
                   ),
              ]))),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: Container(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: (detectedText != "En attente..." && detectedText.isNotEmpty) ? Image.asset('assets/gestures/${detectedText.toUpperCase()}_0.jpg', fit: BoxFit.contain, errorBuilder: (c, e, s) => Center(child: Text(detectedText, style: const TextStyle(color: Colors.white54)))) : const Center(child: Icon(Icons.back_hand, size: 40, color: Colors.white24)))))
            ]))),
            Container(padding: const EdgeInsets.all(12), child: Row(children: [
              Expanded(flex: 2, child: ElevatedButton.icon(icon: Icon(isListening ? Icons.stop : Icons.mic, size: 18), label: Text(isListening ? "STOP" : "MICRO (${_languageCodes[_selectedLanguage]?.toUpperCase()})"), style: ElevatedButton.styleFrom(backgroundColor: isListening ? Colors.redAccent : const Color(0xFF9C27B0), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _listen)),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: GestureDetector(
                onTap: _openESP32Stream,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyan, width: 2)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, color: Colors.cyan, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "ESP32: $currentEspIp",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
            ])),
          ],
        ),
      ),
    );
  }
}



class HandPainter extends CustomPainter {
  final List<List<double>> hands;
  final Size absoluteImageSize;
  final int rotation;
  final bool isFrontCamera;
  
  HandPainter(this.hands, this.absoluteImageSize, this.rotation, this.isFrontCamera);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Paint configurations for better visibility
    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.greenAccent;
    
    final paintPoint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    
    final paintTips = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.cyanAccent;
    
    final paintPalm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellowAccent;
    
    for (final hand in hands) {
      List<Offset> pts = [];
      
      // Mirroring and Rotation Logic
      // 1. MediaPipe coordinates are normalized (0-1)
      // 2. Camera sensor is often landscape, screen is portrait
      
      for (int i = 0; i < hand.length; i += 2) {
        double px = hand[i];
        double py = hand[i + 1];
        
        // Handle Sensor Rotation (90 degrees is standard for portrait)
        // This fixes the "inclined 45/90 degree" problem
        double finalX = px;
        double finalY = py;
        
        if (rotation == 90) {
          finalX = 1.0 - py;
          finalY = px;
        } else if (rotation == 270) {
          finalX = py;
          finalY = 1.0 - px;
        } else if (rotation == 180) {
          finalX = 1.0 - px;
          finalY = 1.0 - py;
        }

        // Mirror for front camera
        if (isFrontCamera) {
          finalX = 1.0 - finalX;
        }

        pts.add(Offset(finalX * size.width, finalY * size.height));
      }
      
      // Safe drawing function
      void draw(int i, int j, Paint paint) {
        if (i < pts.length && j < pts.length) {
          canvas.drawLine(pts[i], pts[j], paint);
        }
      }
      
      // Paint for each finger to make it colorful
      final paintThumb = Paint()..color = Colors.orangeAccent..strokeWidth = 3.0..style = PaintingStyle.stroke;
      final paintIndex = Paint()..color = Colors.greenAccent..strokeWidth = 3.0..style = PaintingStyle.stroke;
      final paintMiddle = Paint()..color = Colors.blueAccent..strokeWidth = 3.0..style = PaintingStyle.stroke;
      final paintRing = Paint()..color = Colors.pinkAccent..strokeWidth = 3.0..style = PaintingStyle.stroke;
      final paintPinky = Paint()..color = Colors.purpleAccent..strokeWidth = 3.0..style = PaintingStyle.stroke;

      // Draw Palm Base (yellow)
      if (pts.length >= 21) {
        draw(0, 1, paintPalm);
        draw(0, 5, paintPalm);
        draw(0, 17, paintPalm);
        draw(5, 9, paintPalm);
        draw(9, 13, paintPalm);
        draw(13, 17, paintPalm);
      }
      
      // Draw Fingers with distinct colors
      // Thumb
      draw(1, 2, paintThumb); draw(2, 3, paintThumb); draw(3, 4, paintThumb);
      // Index
      draw(5, 6, paintIndex); draw(6, 7, paintIndex); draw(7, 8, paintIndex);
      // Middle
      draw(9, 10, paintMiddle); draw(10, 11, paintMiddle); draw(11, 12, paintMiddle);
      // Ring
      draw(13, 14, paintRing); draw(14, 15, paintRing); draw(15, 16, paintRing);
      // Pinky
      draw(17, 18, paintPinky); draw(18, 19, paintPinky); draw(19, 20, paintPinky);
      
      // Draw landmarks points
      for (int i = 0; i < pts.length; i++) {
        // High visibility points
        if (i == 4 || i == 8 || i == 12 || i == 16 || i == 20) {
          canvas.drawCircle(pts[i], 8, paintTips); // Even larger tips
          canvas.drawCircle(pts[i], 3, Paint()..color = Colors.black); // Inner dot
        } else if (i == 0) {
          canvas.drawCircle(pts[i], 10, Paint()..color = Colors.yellow); // Very large wrist
        } else {
          canvas.drawCircle(pts[i], 5, paintPoint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

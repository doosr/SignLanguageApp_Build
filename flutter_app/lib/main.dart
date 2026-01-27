import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  CameraController? _controller;
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechAvailable = false;
  
  // Vision
  late HandLandmarker _handLandmarker;
  bool _isBusy = false;
  List<Hand> _hands = [];
  
  // State
  String detectedText = "En attente...";
  String phrase = "";
  String currentMode = "LETTRES"; 
  bool isListening = false;
  String currentEspIp = "192.168.1.100";
  
  // Language for TTS
  String _selectedLanguage = "Français";
  final Map<String, String> _languageCodes = {
    "Français": "fr-FR",
    "Anglais": "en-US",
    "Arabe": "ar-SA",
  };
  
  // TFLite Variables
  Interpreter? _interpreterLetters;
  Interpreter? _interpreterWords;
  List<String> _labelsLetters = [];
  List<String> _labelsWords = [];

  // Sequence buffer for Words
  List<List<double>> _sequenceBuffer = [];
  final int _sequenceLength = 15;

  // --- Translation Data ---
  final Map<String, Map<String, String>> _translationsLetters = {
    "A": {"Français": "A", "Anglais": "A", "Arabe": "أ"},
    "B": {"Français": "B", "Anglais": "B", "Arabe": "ب"},
    "C": {"Français": "C", "Anglais": "C", "Arabe": "ت"},
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
    "X": {"Français": "X", "Anglais": "X", "Arabe": "خ"},
    "Y": {"Français": "Y", "Anglais": "Y", "Arabe": "ي"},
    "Z": {"Français": "Z", "Anglais": "Z", "Arabe": "ز"},
  };

  final Map<String, Map<String, String>> _translationsWords = {
    "BONJOUR": {"Français": "Bonjour", "Anglais": "Hello", "Arabe": "مرحبا"},
    "MERCI": {"Français": "Merci", "Anglais": "Thank you", "Arabe": "شكرا"},
    "MAISON": {"Français": "Maison", "Anglais": "House", "Arabe": "منزل"},
    "FAMILLE": {"Français": "Famille", "Anglais": "Family", "Arabe": "عائلة"},
    "OUI": {"Français": "Oui", "Anglais": "Yes", "Arabe": "نعم"},
    "NON": {"Français": "Non", "Anglais": "No", "Arabe": "لا"},
    "S'IL VOUS PLAÎT": {"Français": "S'il vous plaît", "Anglais": "Please", "Arabe": "من فضلك"},
    "AIDE": {"Français": "Aide", "Anglais": "Help", "Arabe": "مساعدة"},
    "COMMENT ÇA VA": {"Français": "Comment ça va", "Anglais": "How are you", "Arabe": "كيف حالك"},
  };

  @override
  void initState() {
    super.initState();
    _initHandLandmarker();
    _initCamera();
    _initPermissions();
    _initSpeech();
    _loadModels();
  }

  Future<void> _initHandLandmarker() async {
    _handLandmarker = await HandLandmarker.create(
      numHands: 2,
      minHandDetectionConfidence: 0.3,
      minHandPresenceConfidence: 0.3,
      minTrackingConfidence: 0.3,
    );
  }

  Future<void> _loadModels() async {
    try {
      _interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      _interpreterWords = await Interpreter.fromAsset('assets/model_words.tflite');
      final labelsData = await rootBundle.loadString('assets/model_letters_labels.txt');
      _labelsLetters = labelsData.split('\n').where((s) => s.isNotEmpty).toList();
      final wordsData = await rootBundle.loadString('assets/model_words_labels.txt');
      _labelsWords = wordsData.split('\n').where((s) => s.isNotEmpty).toList();
      print("✅ Modèles chargés !");
    } catch (e) {
      print("❌ Erreur modèles: $e");
    }
  }

  Future<void> _initPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
  }

  void _initSpeech() async {
    _isSpeechAvailable = await _speech.initialize();
    if(mounted) setState(() {});
  }

  void _listen() async {
    if (!isListening) {
      if (await _speech.initialize()) {
        setState(() => isListening = true);
        _speech.listen(onResult: (val) => setState(() => phrase = val.recognizedWords));
      }
    } else {
      setState(() => isListening = false);
      _speech.stop();
    }
  }

  void _initCamera() {
    if (cameras.isEmpty) return;
    CameraDescription selectedCamera = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.front, orElse: () => cameras[0]);
    _controller = CameraController(selectedCamera, ResolutionPreset.medium, enableAudio: false);
    _controller?.initialize().then((_) {
      if (!mounted) return;
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      final hands = await _handLandmarker.processCameraImage(image);
      if (mounted) {
        setState(() { 
          _hands = hands; 
        });

        if (hands.isNotEmpty) {
          final features = _extractFeatures(hands);
          if (features != null) {
            if (currentMode == "LETTRES") {
              _runInferenceLetters(features);
            } else {
              _runInferenceWords(features);
            }
          }
        } else {
          _sequenceBuffer.clear();
          setState(() { detectedText = "..."; });
        }
      }
    } finally { _isBusy = false; }
  }

  List<double>? _extractFeatures(List<Hand> hands) {
    List<double> x_List = [];
    List<double> y_List = [];
    
    // Sort hands by x-coordinate (like in Python)
    hands.sort((a, b) => a.landmarks[0].x.compareTo(b.landmarks[0].x));

    for (var hand in hands) {
      for (var landmark in hand.landmarks) {
        x_List.add(landmark.x);
        y_List.add(landmark.y);
      }
    }

    if (x_List.isEmpty) return null;

    double minX = x_List.reduce((a, b) => a < b ? a : b);
    double minY = y_List.reduce((a, b) => a < b ? a : b);

    List<double> dataAux = [];
    for (var hand in hands) {
      for (var landmark in hand.landmarks) {
        dataAux.add(landmark.x - minX);
        dataAux.add(landmark.y - minY);
      }
    }

    // Padding if only one hand
    if (dataAux.length == 42) {
      dataAux.addAll(List.filled(42, 0.0));
    }

    return dataAux.length == 84 ? dataAux : null;
  }

  void _runInferenceLetters(List<double> features) {
    if (_interpreterLetters == null) return;
    var input = [features];
    var output = List.filled(1, List.filled(_labelsLetters.length, 0.0));
    _interpreterLetters!.run(input, output);

    int maxIdx = 0;
    double maxProb = -1.0;
    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > maxProb) {
        maxProb = output[0][i];
        maxIdx = i;
      }
    }

    if (maxProb > 0.70) {
      String label = _labelsLetters[maxIdx];
      if (detectedText != label) {
         _onGestureDetected(label);
      }
    }
  }

  void _runInferenceWords(List<double> features) {
    if (_interpreterWords == null) return;
    _sequenceBuffer.add(features);
    if (_sequenceBuffer.length > _sequenceLength) {
      _sequenceBuffer.removeAt(0);
    }

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

      if (maxProb > 0.85) {
        String label = _labelsWords[maxIdx];
        if (detectedText != label) {
           _onGestureDetected(label);
           _sequenceBuffer.clear(); // Clear so we don't trigger twice
        }
      }
    }
  }

  void _onGestureDetected(String gestureKey) {
    if (gestureKey.isEmpty) return;
    
    setState(() {
      String translated;
      if (currentMode == "LETTRES") {
        translated = _translationsLetters[gestureKey.toUpperCase()]?[_selectedLanguage] ?? gestureKey;
        phrase += translated;
        detectedText = translated;
      } else {
        translated = _translationsWords[gestureKey.toUpperCase()]?[_selectedLanguage] ?? gestureKey;
        phrase += (phrase.isEmpty ? "" : " ") + translated;
        detectedText = translated;
      }
    });
    
    _speak();
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // This is no longer used by our new hand landmarker which handles CameraImage directly
    return null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _handLandmarker.dispose();
    super.dispose();
  }

  // --- Actions ---
  void _speak() async {
    if (phrase.isNotEmpty) {
      await flutterTts.setLanguage(_languageCodes[_selectedLanguage] ?? "fr-FR");
      await flutterTts.speak(phrase);
    }
  }

  void _translatePhrase(String newLang) {
    String oldLang = _selectedLanguage;
    setState(() {
      _selectedLanguage = newLang;
      if (phrase.isEmpty) return;

      // Split the phrase into tokens
      // If it's words mode, it's space separated. In letters, it's char by char.
      // But we can try to find matching tokens in our dictionaries.
      
      List<String> tokens = [];
      if (currentMode == "MOTS") {
        tokens = phrase.split(" ");
      } else {
        tokens = phrase.split("");
      }

      String newPhrase = tokens.map((t) {
        if (t.trim().isEmpty) return t;
        
        // Search in words map first
        String? foundKey;
        _translationsWords.forEach((key, val) {
          if (val[oldLang]?.toLowerCase() == t.toLowerCase()) foundKey = key;
        });
        
        if (foundKey != null) {
          return _translationsWords[foundKey]![newLang]!;
        }

        // Search in letters map
        foundKey = null;
        _translationsLetters.forEach((key, val) {
          if (val[oldLang]?.toLowerCase() == t.toLowerCase()) foundKey = key;
        });

        if (foundKey != null) {
          return _translationsLetters[foundKey]![newLang]!;
        }

        return t; // Keep as is if not found
      }).join(currentMode == "MOTS" ? " " : "");

      phrase = newPhrase;
    });

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

  // --- UI Helpers ---
  Widget _buildControlBtn(String label, Color color, VoidCallback onPressed) {
    return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color, padding: EdgeInsets.zero), onPressed: onPressed, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)))));
  }

  Widget _buildModeBtn(String emoji, String mode) {
    bool sel = currentMode == mode;
    return Expanded(child: GestureDetector(onTap: () => setState(() => currentMode = mode), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: sel ? Colors.green : Colors.grey[800]), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))))));
  }

  Widget _buildLangToggle(String flag, String lang) {
    bool sel = _selectedLanguage == lang;
    return GestureDetector(onTap: () => _translatePhrase(lang), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: sel ? Colors.cyan : Colors.white10, borderRadius: BorderRadius.circular(20)), child: Text(flag, style: const TextStyle(fontSize: 24))));
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8), 
              child: Row(
                children: [
                   _buildControlBtn("🗑️", Colors.red, _clear),
                   _buildControlBtn("🔊", Colors.green, _speak),
                   _buildControlBtn("⬅️", Colors.orange, _backspace),
                   _buildControlBtn("⌨️", Colors.blue, _addSpace),
                ]
              )
            ),
            
            Row(
              children: [
                _buildModeBtn("🔤", "LETTRES"),
                _buildModeBtn("📚", "MOTS"),
              ]
            ),
            
            const SizedBox(height: 5),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
              children: [
                _buildLangToggle("🇹🇳", "Arabe"), 
                _buildLangToggle("🇫🇷", "Français"), 
                _buildLangToggle("🇺🇸", "Anglais")
              ]
            ),

            const SizedBox(height: 10),
            Container(margin: const EdgeInsets.symmetric(horizontal: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF23273A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text("Phrase (${_selectedLanguage}): $phrase", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  if (phrase.isNotEmpty) 
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.cyan, size: 20),
                      onPressed: _speak,
                    )
                ],
              ),
              const SizedBox(height: 12),
              const Text("Séquence de gestes :", style: TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(height: 8),
              SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, reverse: _selectedLanguage == "Arabe", itemCount: phrase.length, itemBuilder: (c, i) {
                String char = phrase[i]; if (char == " ") return const SizedBox(width: 20);
                String k = char.toUpperCase();
                _translationsLetters.forEach((key, val) { if (val.values.contains(char)) k = key; });
                return Container(margin: const EdgeInsets.only(right: 8), width: 60, decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), child: Image.asset('assets/gestures/${k}_0.jpg', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Center(child: Icon(Icons.error_outline, size: 10, color: Colors.white24))))),
                  Container(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(char, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                ]));
              }))
            ])),
            const SizedBox(height: 10),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
              Expanded(flex: 6, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(fit: StackFit.expand, children: [CameraPreview(_controller!), CustomPaint(painter: HandPainter(_hands, _controller!.value.previewSize!, _controller!.description.sensorOrientation))]))),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: Container(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: (detectedText != "En attente..." && detectedText.isNotEmpty) ? Image.asset('assets/gestures/${detectedText.toUpperCase()}_0.jpg', fit: BoxFit.contain, errorBuilder: (c, e, s) => Center(child: Text(detectedText, style: const TextStyle(color: Colors.white54)))) : const Center(child: Icon(Icons.back_hand, size: 40, color: Colors.white24)))))
            ]))),
            Container(padding: const EdgeInsets.all(12), child: Row(children: [
              Expanded(flex: 2, child: ElevatedButton.icon(icon: Icon(isListening ? Icons.stop : Icons.mic, size: 18), label: Text(isListening ? "STOP" : "MICRO"), style: ElevatedButton.styleFrom(backgroundColor: isListening ? Colors.redAccent : const Color(0xFF9C27B0), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _listen)),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: TextField(style: const TextStyle(fontSize: 12, color: Colors.white), decoration: const InputDecoration(hintText: "ESP32 IP", hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Colors.black26, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))), onChanged: (v) => currentEspIp = v))
            ]))
          ],
        ),
      ),
    );
  }
}

class HandPainter extends CustomPainter {
  final List<Hand> hands;
  final Size absoluteImageSize;
  final int rotation;
  HandPainter(this.hands, this.absoluteImageSize, this.rotation);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.cyanAccent..strokeWidth = 2.0;
    for (final hand in hands) {
      for (final l in hand.landmarks) {
        double x = xRatio(l.x, size, absoluteImageSize);
        double y = yRatio(l.y, size, absoluteImageSize);
        canvas.drawCircle(Offset(x, y), 3, p);
      }
    }
  }
  double xRatio(double x, Size size, Size abs) => x * size.width / (rotation == 90 || rotation == 270 ? abs.height : abs.width);
  double yRatio(double y, Size size, Size abs) => y * size.height / (rotation == 90 || rotation == 270 ? abs.width : abs.height);
  @override
  bool shouldRepaint(HandPainter old) => true;
}

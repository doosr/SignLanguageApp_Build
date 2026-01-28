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
  List<Hand> _landmarks = [];
  
  // State
  String detectedText = "En attente...";
  String phrase = "";
  String currentMode = "LETTRES"; 
  bool isListening = false;
  String currentEspIp = "192.168.1.100";
  
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

  List<List<double>> _sequenceBuffer = [];
  final int _sequenceLength = 15;

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
    "BONJOUR": {"Français": "Bonjour", "Anglais": "Hello", "Arabe": "مرحبا"},
    "MERCI": {"Français": "Merci", "Anglais": "Thank you", "Arabe": "شكرا"},
    "SVP": {"Français": "S'il vous plaît", "Anglais": "Please", "Arabe": "من فضلك"},
    "OUI": {"Français": "Oui", "Anglais": "Yes", "Arabe": "نعم"},
    "NON": {"Français": "Non", "Anglais": "No", "Arabe": "لا"},
    "AU REVOIR": {"Français": "Au revoir", "Anglais": "Goodbye", "Arabe": "مع السلامة"},
  };

  @override
  void initState() {
    super.initState();
    _initializeSafe();
  }

  Future<void> _initializeSafe() async {
    await _requestPermissions();
    
    // Create plugin instance
    try {
      _plugin = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.5,
        delegate: HandLandmarkerDelegate.gpu,
      );
    } catch (e) {
      print("Plugin init error: $e");
    }

    await _loadModels();
    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (e) {
        print("Camera info error: $e");
      }
    }
    if (mounted) _initCamera();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  Future<void> _loadModels() async {
    try {
      _interpreterLetters = await Interpreter.fromAsset('model_letters.tflite');
      _interpreterWords = await Interpreter.fromAsset('model_words.tflite');


      
      String labelsLettersRaw = await rootBundle.loadString('assets/model_letters_labels.txt');
      _labelsLetters = labelsLettersRaw.split('\n').where((s) => s.isNotEmpty).toList();
      
      String labelsWordsRaw = await rootBundle.loadString('assets/model_words_labels.txt');
      _labelsWords = labelsWordsRaw.split('\n').where((s) => s.isNotEmpty).toList();
      
      print("✅ Models and Labels loaded.");
    } catch (e) {
      print("❌ Error loading models: $e");
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
    if (_isDetecting || _plugin == null) return; // Guard
    _isDetecting = true;
    try {
       // Plugin detection (Sync or Async depending on version, example says Sync?)
       // Checking source: "The detect method is now synchronous" according to user snippet.
       // But CameraImage streaming is async.
       
       final hands = _plugin!.detect(image, _controller!.description.sensorOrientation);
       
       if (mounted) {
         // Convert to existing format List<List<double>> for Painter and Classifier
         List<List<double>> convertedHands = hands.map((h) => h.landmarks.expand((l) => [l.x, l.y]).toList()).toList();
         
         setState(() {
           _flutterHands = convertedHands;
           if (_flutterHands.isEmpty) detectedText = "En attente...";
         });

         if (_flutterHands.isNotEmpty) {
           final features = _processHandLandmarksForClassifier(convertedHands);
           if (currentMode == "LETTRES") {
              _runInferenceLetters(features);
           } else {
              _runInferenceWords(features);
           }
         } else {
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
       // Logic similar to previous _processNativeLandmarks
       List<List<double>> sorted = List.from(hands);
       sorted.sort((a,b) => a[0].compareTo(b[0]));
       
       List<double> rawAll = [];
       for(var h in sorted) rawAll.addAll(h);
       
       // Normalize relative to bounding box of the hand signs
       if (rawAll.isNotEmpty) {
         double minX = rawAll[0], minY = rawAll[1];
          for(int i=0; i<rawAll.length; i+=2) {
            if (rawAll[i] < minX) minX = rawAll[i];
            if (rawAll[i+1] < minY) minY = rawAll[i+1];
          }
          for(int i=0; i<rawAll.length; i+=2) {
            rawAll[i] -= minX;
            rawAll[i+1] -= minY;
          }
       }
       while(rawAll.length < 84) rawAll.add(0.0);
       return rawAll.sublist(0,84);
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

    if (maxProb > 0.60) {
      String label = _labelsLetters[maxIdx];
      if (detectedText != label) {
         _onGestureDetected(label);
      }
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

  Future<void> _onGestureDetected(String gestureKey) async {
    if (gestureKey.isEmpty) return;
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
    setState(() {
      phrase += (currentMode == "MOTS" && phrase.isNotEmpty ? " " : "") + translated;
      detectedText = translated;
    });
    _speak();
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final sensorOrientation = _controller!.description.sensorOrientation;
      final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
      final format = Platform.isAndroid ? InputImageFormat.nv21 : (InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21);
      final plane = image.planes[0];
      return InputImage.fromBytes(bytes: plane.bytes, metadata: InputImageMetadata(size: Size(image.width.toDouble(), image.height.toDouble()), rotation: rotation, format: format, bytesPerRow: plane.bytesPerRow));
    } catch (e) { return null; }
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
                CameraPreview(_controller!), 
                if (_flutterHands.isNotEmpty)
                  CustomPaint(painter: HandPainter(_flutterHands, _controller!.value.previewSize!, _controller!.description.sensorOrientation, isFrontCamera)),
                Align(alignment: Alignment.bottomCenter, child: Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(detectedText, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text("Debug: Hands=${_flutterHands.length}", style: const TextStyle(color: Colors.yellow, fontSize: 10))
                ]))),
              ]))),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: Container(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: (detectedText != "En attente..." && detectedText.isNotEmpty) ? Image.asset('assets/gestures/${detectedText.toUpperCase()}_0.jpg', fit: BoxFit.contain, errorBuilder: (c, e, s) => Center(child: Text(detectedText, style: const TextStyle(color: Colors.white54)))) : const Center(child: Icon(Icons.back_hand, size: 40, color: Colors.white24)))))
            ]))),
            Container(padding: const EdgeInsets.all(12), child: Row(children: [
              Expanded(flex: 2, child: ElevatedButton.icon(icon: Icon(isListening ? Icons.stop : Icons.mic, size: 18), label: Text(isListening ? "STOP" : "MICRO (${_languageCodes[_selectedLanguage]?.toUpperCase()})"), style: ElevatedButton.styleFrom(backgroundColor: isListening ? Colors.redAccent : const Color(0xFF9C27B0), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _listen)),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: TextField(style: const TextStyle(fontSize: 12, color: Colors.white), decoration: const InputDecoration(hintText: "ESP32 IP", hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Colors.black26, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))), onChanged: (v) => currentEspIp = v))
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
    final paintLine = Paint()..style = PaintingStyle.stroke..strokeWidth = 3.0..color = Colors.blueAccent;
    final paintPoint = Paint()..style = PaintingStyle.fill..color = Colors.white;
    for (final hand in hands) {
      List<Offset> pts = [];
      for (int i=0; i<hand.length; i+=2) pts.add(Offset(hand[i] * size.width, hand[i+1] * size.height));
      if (isFrontCamera) pts = pts.map((p) => Offset(size.width - p.dx, p.dy)).toList();
      void draw(int i, int j) { if (i<pts.length && j<pts.length) canvas.drawLine(pts[i], pts[j], paintLine); }
      // Thumb
      draw(0, 1); draw(1, 2); draw(2, 3); draw(3, 4);
      // Fingers
      for (int f=0; f<4; f++) { int start = 5 + f*4; draw(0, start); draw(start, start+1); draw(start+1, start+2); draw(start+2, start+3); }
      for (var p in pts) canvas.drawCircle(p, 4, paintPoint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

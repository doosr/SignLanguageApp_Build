import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
// TFLite
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
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
        scaffoldBackgroundColor: const Color(0xFF0D0D1A), // Dark blue-black
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
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isBusy = false;
  List<Pose> _poses = [];
  
  // State
  String detectedText = "En attente...";
  String phrase = "";
  String currentMode = "LETTRES"; // LETTRES vs MOTS
  bool isListening = false;
  String currentEspIp = "192.168.1.100";
  
  // Language for TTS
  String _selectedLanguage = "Français";
  final Map<String, String> _languageCodes = {
    "Français": "fr-FR",
    "Anglais": "en-US",
    "Arabe": "ar-SA",
  };

  
  // Simulation Debug
  Timer? _simulationTimer;
  
  // TFLite Variables embedded:
  Interpreter? _interpreterLetters;
  Interpreter? _interpreterWords;
  List<String> _labelsLetters = [];
  List<String> _labelsWords = [];



  // ... (State variables)

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initPermissions();
    _initSpeech();
    _loadModels();

  }

  Future<void> _loadModels() async {
    try {
      // Charger Modèles
      _interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
      _interpreterWords = await Interpreter.fromAsset('assets/model_words.tflite');
      
      // Charger Labels
      final labelsData = await rootBundle.loadString('assets/model_letters_labels.txt');
      _labelsLetters = labelsData.split('\n').where((s) => s.isNotEmpty).toList();
      
      final wordsData = await rootBundle.loadString('assets/model_words_labels.txt');
      _labelsWords = wordsData.split('\n').where((s) => s.isNotEmpty).toList();

      print("✅ Modèles chargés !");
    } catch (e) {
      print("❌ Erreur chargement modèles: $e");
    }
  }


  // Simulation prediction pour l'instant (car extraction landmarks complexe sans plugin dédié)
  Future<void> _runInference(List<double> mockLandmarks) async {
    if (_interpreterLetters == null) return;

    // Input: [1, 42] ou [1, 84] selon votre modèle conversion
    // Output: [1, N_Classes]
    
    // Exemple d'utilisation
    var input = [mockLandmarks]; 
    // var output = List.filled(1 * _labelsLetters.length, 0.0).reshape([1, _labelsLetters.length]);
    
    // _interpreterLetters!.run(input, output);
    // Trouver index max...
  }



  
  Future<void> _initPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
  }

  void _initSpeech() async {
    _isSpeechAvailable = await _speech.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
     if(mounted) setState(() {});
  }

  void _listen() async {
    if (!_isSpeechAvailable) {
      print("Speech recognition not available");
      // Tentative ré-init
      _isSpeechAvailable = await _speech.initialize();
      if(!_isSpeechAvailable) return;
    }

    if (!isListening) {
        setState(() => isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            phrase = val.recognizedWords;
          }),
          localeId: "fr_FR",
        );
    } else {
      setState(() => isListening = false);
      _speech.stop();
    }
  }

  void _initCamera() {
    if (cameras.isEmpty) return;
    
    // Utiliser la caméra frontale si possible pour les gestes
    CameraDescription selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras[0]
    );

    _controller = CameraController(selectedCamera, ResolutionPreset.medium, enableAudio: false);
    _controller?.initialize().then((_) {
      if (!mounted) return;
      
      // Démarrer le flux de vision
      _controller?.startImageStream(_processCameraImage);
      
      setState(() {});
    });
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _poses = poses;
          if (_poses.isNotEmpty) {
            detectedText = "Main/Corps détecté";
            // Ici on pourrait appeler _runInference avec les coordonnées
          } else {
            detectedText = "Personne non détectée";
          }
        });
      }
    } catch (e) {
      print("Erreur vision: $e");
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final sensorOrientation = _controller!.description.sensorOrientation;
    final InputImageRotation rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
    final InputImageFormat format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    final plane = image.planes[0];

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }


  
  @override
  void dispose() {
    _controller?.dispose();
    _simulationTimer?.cancel();
    _poseDetector.close();
    super.dispose();
  }

  // --- Actions ---

  // --- Translation Data ---
  final Map<String, Map<String, String>> _translations = {
    "LETTRES": {
      "A": {"Français": "A", "Anglais": "A", "Arabe": "أ"},
      "B": {"Français": "B", "Anglais": "B", "Arabe": "ب"},
      // ... Ajoutez le reste si nécessaire
    },
    "MOTS": {
      "Bonjour": {"Français": "Bonjour", "Anglais": "Hello", "Arabe": "مرحبا"},
      "Merci": {"Français": "Merci", "Anglais": "Thank you", "Arabe": "شكرا"},
      "Maison": {"Français": "Maison", "Anglais": "House", "Arabe": "منزل"},
    }
  };

  void _translatePhrase(String newLang) {
    // Cette fonction simule une traduction simple basée sur les mots détectés
    // Pour un vrai projet, on utiliserait une API de traduction.
    setState(() {
      _selectedLanguage = newLang;
      // Simulation simple: on garde la phrase ou on la change si c'est un mot connu
      _translations["MOTS"].forEach((key, value) {
        if (phrase.contains(value["Français"]!) || phrase.contains(value["Anglais"]!) || phrase.contains(value["Arabe"]!)) {
           phrase = value[newLang]!;
        }
      });
    });
  }

  // ... (existing initState, _initCamera)

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Controls Row (Top)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                   _buildControlBtn("Effacer", const Color(0xFFF44336), _clear),
                   _buildControlBtn("Parler", const Color(0xFF4CAF50), _speak),
                   _buildControlBtn("Retour", const Color(0xFFFF9800), _backspace),
                   _buildControlBtn("Espace", const Color(0xFF2196F3), _addSpace),
                ],
              ),
            ),
            
            // 2. Mode & Language Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildModeBtn("LETTRES"),
                      _buildModeBtn("MOTS"),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLangToggle("Arabe"),
                      _buildLangToggle("Français"),
                      _buildLangToggle("Anglais"),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // 3. Info Card & Phrase Gestures
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF23273A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Phrase (${_selectedLanguage}): $phrase",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Liste des gestes de la phrase
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: phrase.length,
                      itemBuilder: (context, index) {
                        String char = phrase[index].toUpperCase();
                        if (char == " ") return const SizedBox(width: 10);
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/gestures/${char}_0.jpg',
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: Colors.white10, width: 20, child: Center(child: Text(char, style: const TextStyle(fontSize: 8)))),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 4. Main Visual Area (Camera with Landmarks)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    // Camera + Painter
                    Expanded(
                      flex: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller!),
                            // Dessiner les points de détection
                            CustomPaint(
                              painter: PosePainter(_poses, _controller!.value.previewSize!, _controller!.description.sensorOrientation),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Gesture Image (Dernier détecté)
                    Expanded(
                      flex: 4,
                      child: _buildLastGestureDisplay(),
                    ),
                  ],
                ),
              ),
            ),
            
            // 5. Microphone & ESP
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBtn(String mode) {
    bool isSelected = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[800],
            borderRadius: mode == "LETTRES" 
              ? const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))
              : const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
          ),
          child: Center(child: Text(mode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildLangToggle(String lang) {
    bool isSelected = _selectedLanguage == lang;
    return GestureDetector(
      onTap: () => _translatePhrase(lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyan : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(lang, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLastGestureDisplay() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: (detectedText != "En attente..." && detectedText.isNotEmpty) 
            ? Image.asset(
                'assets/gestures/${detectedText.toUpperCase()}_0.jpg',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(child: Text(detectedText, style: const TextStyle(color: Colors.white54))),
              )
            : const Center(child: Icon(Icons.back_hand, size: 40, color: Colors.white24)),
        ),
      );
  }

  Widget _buildBottomControls() {
    return Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                   Expanded(
                     flex: 2,
                     child: ElevatedButton.icon(
                       icon: Icon(isListening ? Icons.mic : Icons.mic_none, size: 18),
                       label: Text(isListening ? "ARRÊTER" : "MICRO"),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: isListening ? Colors.redAccent : const Color(0xFF9C27B0),
                         padding: const EdgeInsets.symmetric(vertical: 12),
                       ),
                       onPressed: _listen,
                     ),
                   ),
                   const SizedBox(width: 10),
                   Expanded(
                     flex: 3,
                     child: TextField(
                       style: const TextStyle(fontSize: 12, color: Colors.white),
                       decoration: const InputDecoration(
                         hintText: "ESP32 IP",
                         hintStyle: TextStyle(color: Colors.white54),
                         filled: true,
                         fillColor: Colors.black26,
                         isDense: true,
                         border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                       ),
                       onChanged: (v) => currentEspIp = v,
                     ),
                   ),
                ],
              ),
            );
  }
}

// --- Dessinateur des points sur la main (Pose) ---
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;
  final int rotation;

  PosePainter(this.poses, this.absoluteImageSize, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.redAccent
      ..strokeWidth = 4.0;

    for (final pose in poses) {
      // Pour chaque point détecté (Landmark)
      pose.landmarks.forEach((_, landmark) {
        final double x = _translateX(landmark.x, rotation, size, absoluteImageSize);
        final double y = _translateY(landmark.y, rotation, size, absoluteImageSize);
        
        // Dessiner un point
        canvas.drawCircle(Offset(x, y), 5, paint);
      });
    }
  }

  double _translateX(double x, int rotation, Size size, Size absoluteImageSize) {
    switch (rotation) {
      case 90: return x * size.width / absoluteImageSize.height;
      case 270: return size.width - x * size.width / absoluteImageSize.height;
      default: return x * size.width / absoluteImageSize.width;
    }
  }

  double _translateY(double y, int rotation, Size size, Size absoluteImageSize) {
    switch (rotation) {
      case 90: return y * size.height / absoluteImageSize.width;
      case 270: return size.height - y * size.height / absoluteImageSize.width;
      default: return y * size.height / absoluteImageSize.height;
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
}


          ],
        ),
      ),
    );
  }
}

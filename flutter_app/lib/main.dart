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

  void _speak() async {
    if (phrase.isNotEmpty) {
      String code = _languageCodes[_selectedLanguage] ?? "fr-FR";
      await flutterTts.setLanguage(code);
      // Pour l'arabe, on peut ajuster le pitch if needed
      if (code == "ar-SA") {
        await flutterTts.setPitch(1.0);
      }
      await flutterTts.speak(phrase);
    }
  }


  void _onGestureDetected(String gesture) {
    if (gesture.isEmpty) return;
    setState(() {
      detectedText = gesture;
      if (currentMode == "LETTRES") {
        phrase += gesture;
      } else {
        phrase += (phrase.isEmpty ? "" : " ") + gesture;
      }
    });
    // Optionnel: lire automatiquement le geste détecté ?
    // _speak(); 
  }

  void _clear() {
    setState(() {
      phrase = "";
      detectedText = "";
    });
  }

  void _backspace() {
    if (phrase.isNotEmpty) {
      setState(() {
        phrase = phrase.substring(0, phrase.length - 1);
      });
    }
  }

  void _addSpace() {
    setState(() {
      phrase += " ";
    });
  }

  void _toggleMode(String mode) {
    setState(() {
      currentMode = mode;
      detectedText = "Mode changé: $mode";
    });
  }

  // --- UI Components ---

  Widget _buildControlBtn(String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

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
            
            // 2. Mode Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleMode("LETTRES"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: currentMode == "LETTRES" ? const Color(0xFF4CAF50) : Colors.grey[800],
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                        ),
                        child: const Center(child: Text("LETTRES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleMode("MOTS"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: currentMode == "MOTS" ? const Color(0xFF4CAF50) : Colors.grey[800],
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                        ),
                        child: const Center(child: Text("MOTS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // 3. Info Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF23273A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Détecté: $detectedText",
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Phrase: $phrase",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            // 4. Main Visual Area (Camera + Gesture Image)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    // Camera
                    Expanded(
                      flex: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller!),
                            // Overlay OverlayBox
                            Center(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Gesture Image
                    Expanded(
                      flex: 4,
                      child: Container(
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
                                errorBuilder: (context, error, stackTrace) => Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.image_not_supported, color: Colors.white24, size: 40),
                                    const SizedBox(height: 10),
                                    Text(detectedText, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              )
                            : const Column(


                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.back_hand, size: 40, color: Colors.white24),
                                  SizedBox(height: 10),
                                  Text("Signez !", style: TextStyle(color: Colors.white54)),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            
            // 5. Bottom Controls (Lang / Micro / ESP)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                   Row(
                    children: [
                      // Lang Selector
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            isExpanded: true,
                            underline: Container(),
                            items: _languageCodes.keys.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedLanguage = newValue!;
                              });
                            },
                            dropdownColor: Colors.grey[850], // Set dropdown background color
                            style: const TextStyle(color: Colors.white), // Set text color for selected item
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Micro
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(isListening ? Icons.mic : Icons.mic_none, size: 18),
                          label: Text(isListening ? "ÉCOUTE" : "MICRO"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isListening ? Colors.redAccent : const Color(0xFF9C27B0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _listen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                       Expanded(
                         flex: 3,
                         child: TextField(
                           style: const TextStyle(fontSize: 12, color: Colors.white),
                           decoration: const InputDecoration(
                             hintText: "ESP32 IP",
                             hintStyle: TextStyle(color: Colors.white54),
                             filled: true,
                             fillColor: Colors.black26,
                             contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                             isDense: true,
                             border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                             enabledBorder: OutlineInputBorder(
                               borderSide: BorderSide(color: Colors.white12),
                               borderRadius: BorderRadius.all(Radius.circular(8)),
                             ),
                             focusedBorder: OutlineInputBorder(
                               borderSide: BorderSide(color: Colors.cyan),
                               borderRadius: BorderRadius.all(Radius.circular(8)),
                             ),
                           ),
                           onChanged: (v) => currentEspIp = v,
                         ),
                       ),
                       const SizedBox(width: 8),
                       IconButton(
                         icon: const Icon(Icons.wifi, color: Colors.cyan),
                         onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connexion à $currentEspIp...')));
                         },
                       )
                    ],
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

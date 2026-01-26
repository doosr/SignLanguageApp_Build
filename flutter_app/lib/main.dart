import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
// TFLite
// import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'package:flutter/services.dart';


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
  
  // State
  String detectedText = "En attente...";
  String phrase = "";
  String currentMode = "LETTRES"; // LETTRES vs MOTS
  bool isListening = false;
  String currentEspIp = "192.168.1.100";
  
  // Simulation Debug
  Timer? _simulationTimer;
  
  // TFLite Variables embedded:
  // Interpreter? _interpreterLetters;
  // Interpreter? _interpreterWords;
  List<String> _labelsLetters = [];
  List<String> _labelsWords = [];


  // ... (State variables)

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initPermissions();
    // _loadModels();
  }

  // Future<void> _loadModels() async {
  //   try {
  //     // Charger Modèles
  //     _interpreterLetters = await Interpreter.fromAsset('assets/model_letters.tflite');
  //     _interpreterWords = await Interpreter.fromAsset('assets/model_words.tflite');
      
  //     // Charger Labels
  //     final labelsData = await rootBundle.loadString('assets/model_letters_labels.txt');
  //     _labelsLetters = labelsData.split('\n').where((s) => s.isNotEmpty).toList();
      
  //     final wordsData = await rootBundle.loadString('assets/model_words_labels.txt');
  //     _labelsWords = wordsData.split('\n').where((s) => s.isNotEmpty).toList();

  //     print("✅ Modèles chargés !");
  //   } catch (e) {
  //     print("❌ Erreur chargement modèles: $e");
  //   }
  // }

  // Simulation prediction pour l'instant (car extraction landmarks complexe sans plugin dédié)
  Future<void> _runInference(List<double> mockLandmarks) async {
    // if (_interpreterLetters == null) return;

    // // Input: [1, 42] ou [1, 84] selon votre modèle conversion
    // // Output: [1, N_Classes]
    
    // // Exemple d'utilisation
    // var input = [mockLandmarks]; 
    // // var output = List.filled(1 * _labelsLetters.length, 0.0).reshape([1, _labelsLetters.length]);
    
    // // _interpreterLetters!.run(input, output);
    // // Trouver index max...
  }


  
  Future<void> _initPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
  }

  void _initCamera() {
    if (cameras.isEmpty) return;
    
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    _controller?.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    _simulationTimer?.cancel();
    super.dispose();
  }

  // --- Actions ---

  void _speak() async {
    if (phrase.isNotEmpty) {
      await flutterTts.setLanguage("fr-FR");
      await flutterTts.speak(phrase);
    }
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
                    // Gesture Image Placeholder
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, size: 40, color: Colors.white24),
                            SizedBox(height: 10),
                            Text("Image Geste", style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 5. Bottom Controls (Lang / Micro / ESP)
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                   Expanded(
                     flex: 2,
                     child: ElevatedButton.icon(
                       icon: const Icon(Icons.mic, size: 18),
                       label: const Text("MICRO"),
                       style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C27B0)),
                       onPressed: () {},
                     ),
                   ),
                   const SizedBox(width: 10),
                   Expanded(
                     flex: 3,
                     child: TextField(
                       style: const TextStyle(fontSize: 12),
                       decoration: const InputDecoration(
                         hintText: "ESP32 IP",
                         filled: true,
                         fillColor: Colors.black26,
                         contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                         border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                       ),
                       onChanged: (v) => currentEspIp = v,
                     ),
                   ),
                   IconButton(
                     icon: const Icon(Icons.wifi, color: Colors.cyan),
                     onPressed: () {
                         // TODO: Connect ESP Logic
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connexion à $currentEspIp...')));
                     },
                   )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

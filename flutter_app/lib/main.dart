import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:flutter/services.dart';
import 'package:translator/translator.dart';
import 'dart:io' show Platform;
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/recognition_screen.dart';
import 'screens/inverse_mode_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/esp32_config_screen.dart';
import 'theme/app_theme.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure window for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Ensure window is visible and properly sized
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  
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
      title: 'SignLanguage App',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const HomeScreen(),
        '/recognition': (context) => const RecognitionScreen(),
        '/inverse': (context) => const InverseModeScreen(),
        '/language': (context) => const LanguageSelectionScreen(),
        '/esp32-config': (context) => const ESP32ConfigScreen(),
      },
    );
  }
}

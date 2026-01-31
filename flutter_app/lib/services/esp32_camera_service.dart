import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Service singleton pour gérer la connexion et le streaming ESP32-CAM
class ESP32CameraService {
  static final ESP32CameraService _instance = ESP32CameraService._internal();
  factory ESP32CameraService() => _instance;
  ESP32CameraService._internal();

  // État de la connexion
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isEnabled = ValueNotifier<bool>(false);
  
  String? _ipAddress;
  DateTime? _lastConnectionCheck;
  
  /// Initialiser le service avec les paramètres sauvegardés
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ipAddress = prefs.getString('esp32_ip');
      isEnabled.value = prefs.getBool('esp32_camera_enabled') ?? false;
      
      if (_ipAddress != null && isEnabled.value) {
        await testConnection();
      }
    } catch (e) {
      debugPrint('ESP32CameraService init error: $e');
    }
  }
  
  /// Tester la connexion à l'ESP32-CAM
  Future<bool> testConnection() async {
    if (_ipAddress == null || _ipAddress!.isEmpty) {
      isConnected.value = false;
      return false;
    }
    
    try {
      final response = await http
          .get(Uri.parse('http://$_ipAddress/'))
          .timeout(const Duration(seconds: 3));
      
      isConnected.value = response.statusCode == 200;
      _lastConnectionCheck = DateTime.now();
      
      return isConnected.value;
    } catch (e) {
      debugPrint('ESP32 connection test failed: $e');
      isConnected.value = false;
      return false;
    }
  }
  
  /// Définir l'adresse IP et sauvegarder
  Future<void> setIpAddress(String ip) async {
    _ipAddress = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp32_ip', ip);
  }
  
  /// Activer/désactiver la caméra ESP32
  Future<void> setEnabled(bool enabled) async {
    isEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('esp32_camera_enabled', enabled);
    
    if (enabled && _ipAddress != null) {
      await testConnection();
    } else {
      isConnected.value = false;
    }
  }
  
  /// Obtenir l'URL du stream
  String? getStreamUrl() {
    if (_ipAddress == null || !isEnabled.value || !isConnected.value) {
      return null;
    }
    return 'http://$_ipAddress/stream';
  }
  
  /// Obtenir l'URL de capture
  String? getCaptureUrl() {
    if (_ipAddress == null || !isEnabled.value || !isConnected.value) {
      return null;
    }
    return 'http://$_ipAddress/capture';
  }
  
  /// Vérifier si la connexion est toujours valide
  bool shouldReconnect() {
    if (_lastConnectionCheck == null) return true;
    return DateTime.now().difference(_lastConnectionCheck!).inSeconds > 30;
  }
  
  /// Obtenir l'adresse IP actuelle
  String? get ipAddress => _ipAddress;
  
  /// Dispose des ressources
  void dispose() {
    isConnected.dispose();
    isEnabled.dispose();
  }
}

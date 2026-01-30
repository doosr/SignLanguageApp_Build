import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';

class ESP32ConfigScreen extends StatefulWidget {
  const ESP32ConfigScreen({Key? key}) : super(key: key);

  @override
  State<ESP32ConfigScreen> createState() => _ESP32ConfigScreenState();
}

class _ESP32ConfigScreenState extends State<ESP32ConfigScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _isConnected = false;
  bool _isTesting = false;
  bool _cameraEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = prefs.getString('esp32_ip') ?? '192.168.1.100';
      _cameraEnabled = prefs.getBool('esp32_camera_enabled') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp32_ip', _ipController.text);
    await prefs.setBool('esp32_camera_enabled', _cameraEnabled);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _isConnected = false;
    });

    try {
      final response = await http
          .get(Uri.parse('http://${_ipController.text}/'))
          .timeout(const Duration(seconds: 5));

      setState(() {
        _isConnected = response.statusCode == 200;
        _isTesting = false;
      });

      if (_isConnected) {
        await _saveSettings();
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1e3a5f), // Bleu foncé
              Color(0xFF2d1b4e), // Violet foncé
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6b7fd7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Configuration ESP32-CAM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Carte principale
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Adresse IP
                              const Text(
                                'Adresse IP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Champ IP
                              TextField(
                                controller: _ipController,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: '192.168.1.100',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF6b7fd7),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),

                              const SizedBox(height: 24),

                              // Status et bouton test
                              Row(
                                children: [
                                  // Indicateur connecté
                                  if (_isConnected)
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF4ade80),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(0xFF4ade80),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Connecté',
                                          style: TextStyle(
                                            color: Color(0xFF4ade80),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  
                                  const Spacer(),
                                  
                                  // Bouton tester
                                  ElevatedButton.icon(
                                    onPressed: _isTesting ? null : _testConnection,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4ade80),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: _isTesting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Icon(Icons.check_circle, size: 20),
                                    label: Text(
                                      _isTesting ? 'Test...' : 'Tester la connexion',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 48),

                              // Activer caméra
                              const Text(
                                'Activer caméra distante',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Toggle switch stylisé
                                  GestureDetector(
                                    onTap: () async {
                                      setState(() {
                                        _cameraEnabled = !_cameraEnabled;
                                      });
                                      await _saveSettings();
                                    },
                                    child: Container(
                                      width: 80,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: LinearGradient(
                                          colors: _cameraEnabled
                                              ? [
                                                  const Color(0xFF4A90E2),
                                                  const Color(0xFF5CA8FF),
                                                ]
                                              : [
                                                  Colors.grey.shade700,
                                                  Colors.grey.shade600,
                                                ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _cameraEnabled
                                                ? const Color(0xFF4A90E2).withOpacity(0.5)
                                                : Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Texte ON/OFF
                                          Positioned(
                                            left: _cameraEnabled ? 12 : null,
                                            right: _cameraEnabled ? null : 12,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: Text(
                                                _cameraEnabled ? 'ON' : 'OFF',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Cercle mobile
                                          AnimatedPositioned(
                                            duration: const Duration(milliseconds: 200),
                                            curve: Curves.easeInOut,
                                            left: _cameraEnabled ? 40 : 4,
                                            top: 4,
                                            child: Container(
                                              width: 37,
                                              height: 37,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Image ESP32-CAM
                                  Image.network(
                                    'https://raw.githubusercontent.com/espressif/arduino-esp32/master/docs/_static/esp32-cam.jpg',
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 130,
                                        height: 130,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.2),
                                          ),
                                        ),
                                        child: const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.camera_alt_outlined,
                                              size: 48,
                                              color: Color(0xFF6b7fd7),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'ESP32-CAM',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}

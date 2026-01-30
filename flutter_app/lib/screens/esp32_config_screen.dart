import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../theme/app_theme.dart';
import '../widgets/glassmorphism_card.dart';
import '../widgets/gradient_button.dart';

class ESP32ConfigScreen extends StatefulWidget {
  const ESP32ConfigScreen({Key? key}) : super(key: key);

  @override
  State<ESP32ConfigScreen> createState() => _ESP32ConfigScreenState();
}

class _ESP32ConfigScreenState extends State<ESP32ConfigScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _isConnected = false;
  bool _isTesting = false;
  bool _isCameraEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = prefs.getString('esp32_ip') ?? '192.168.1.100';
      _isCameraEnabled = prefs.getBool('esp32_enabled') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp32_ip', _ipController.text);
    await prefs.setBool('esp32_enabled', _isCameraEnabled);
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    
    try {
      final response = await http
          .get(Uri.parse('http://${_ipController.text}/'))
          .timeout(const Duration(seconds: 5));
      
      setState(() {
        _isConnected = response.statusCode == 200;
        _isTesting = false;
      });
      
      if (_isConnected) {
        _saveSettings();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Connexion réussie !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError('Échec de connexion');
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isTesting = false;
      });
      _showError('Impossible de se connecter à l\'ESP32-CAM');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Configuration ESP32-CAM',
                      style: AppTheme.headingMedium.copyWith(fontSize: 24),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Main Configuration Card
                GlassmorphismCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IP Address Input
                      Text(
                        'Adresse IP',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ipController,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          hintText: '192.168.1.100',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.accentCyan,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Test Connection Button
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isTesting ? null : _testConnection,
                              icon: _isTesting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                              label: Text(
                                _isTesting ? 'Test en cours...' : 'Tester la connexion',
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Connection Status
                      if (_isConnected)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Connecté',
                                style: TextStyle(
                                  color: Colors.green.shade300,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 32),
                      
                      // Camera Toggle
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Activer caméra distante',
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Utiliser l\'ESP32-CAM à la place de la caméra locale',
                                  style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Transform.scale(
                            scale: 1.2,
                            child: Switch(
                              value: _isCameraEnabled,
                              onChanged: (value) {
                                setState(() => _isCameraEnabled = value);
                                _saveSettings();
                              },
                              activeColor: AppTheme.accentCyan,
                              activeTrackColor: AppTheme.accentCyan.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // ESP32 Illustration
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '📷',
                                style: TextStyle(fontSize: 80),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ESP32-CAM',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.accentCyan,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

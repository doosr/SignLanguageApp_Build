import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../widgets/glassmorphism_card.dart';
import '../widgets/gradient_button.dart';

class InverseModeScreen extends StatefulWidget {
  const InverseModeScreen({Key? key}) : super(key: key);

  @override
  State<InverseModeScreen> createState() => _InverseModeScreenState();
}

class _InverseModeScreenState extends State<InverseModeScreen> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  String _selectedLanguage = 'Français';
  double _speed = 1.0; // 0.5 = lent, 1.0 = normal, 2.0 = rapide
  
  int _currentLetterIndex = 0;
  Timer? _animationTimer;
  
  final Map<String, String> _languageCodes = {
    'Français': 'fr-FR',
    'Anglais': 'en-US',
    'Arabe': 'ar-SA',
  };
  
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _initSpeech();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'Français';
    });
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      _waveController.stop();
      _startGestureAnimation();
    } else {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _waveController.repeat();
        _speech.listen(
          localeId: _languageCodes[_selectedLanguage],
          onResult: (result) {
            setState(() {
              _recognizedText = result.recognizedWords.toUpperCase();
            });
          },
        );
      }
    }
  }

  void _startGestureAnimation() {
    _currentLetterIndex = 0;
    _animationTimer?.cancel();
    
    if (_recognizedText.isEmpty) return;
    
    // Speed: lent=2s, normal=1s, rapide=0.5s per letter
    final duration = Duration(milliseconds: (1000 / _speed).round());
    
    _animationTimer = Timer.periodic(duration, (timer) {
      if (_currentLetterIndex < _recognizedText.length - 1) {
        setState(() => _currentLetterIndex++);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _animationTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letters = _recognizedText.split('').where((c) => c != ' ').toList();
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Mode Inverse',
                      style: AppTheme.headingMedium.copyWith(fontSize: 24),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Microphone Button with Wave Animation
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isListening
                      ? AppTheme.primaryGradient
                      : LinearGradient(
                          colors: [Colors.grey.shade800, Colors.grey.shade700],
                        ),
                    boxShadow: [
                      BoxShadow(
                        color: _isListening 
                          ? AppTheme.primaryPurple.withOpacity(0.5)
                          : Colors.black.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              
              if (_isListening) ...[
                const SizedBox(height: 20),
                // Animated Wave Visualization
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(200, 40),
                      painter: WavePainter(_waveController.value),
                    );
                  },
                ),
              ],
              
              const SizedBox(height: 30),
              
              // Phrase Display
              if (_recognizedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassmorphismCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Phrase ($_selectedLanguage):',
                          style: AppTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                _recognizedText,
                                style: AppTheme.headingSmall.copyWith(fontSize: 20),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up, color: AppTheme.accentCyan),
                              onPressed: () {
                                // TTS would go here
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Gesture Sequence Display
              if (letters.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Séquence de gestes:',
                    style: AppTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: letters.length,
                    itemBuilder: (context, index) {
                      final letter = letters[index];
                      final isActive = index == _currentLetterIndex;
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 12),
                        width: 90,
                        decoration: BoxDecoration(
                          color: isActive 
                            ? AppTheme.primaryPurple.withOpacity(0.3)
                            : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive 
                              ? AppTheme.primaryPurple
                              : Colors.white.withOpacity(0.1),
                            width: isActive ? 3 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Gesture Image
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Image.asset(
                                  'assets/gestures/${letter}_0.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        '🤟',
                                        style: TextStyle(fontSize: 40),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Letter Label
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                letter,
                                style: TextStyle(
                                  color: isActive ? AppTheme.accentCyan : AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Speed Control
              Padding(
                padding: const EdgeInsets.all(24),
                child: GlassmorphismCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Vitesse d\'affichage',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSpeedButton('Lent', 0.5),
                          _buildSpeedButton('Normal', 1.0),
                          _buildSpeedButton('Rapide', 2.0),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedButton(String label, double speed) {
    final isSelected = _speed == speed;
    return GestureDetector(
      onTap: () {
        setState(() => _speed = speed);
        if (!_isListening && _recognizedText.isNotEmpty) {
          _startGestureAnimation();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppTheme.primaryPurple.withOpacity(0.3)
            : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
              ? AppTheme.primaryPurple
              : Colors.white.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// Wave Painter for Audio Visualization
class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentCyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    final waveHeight = 20.0;
    final waveLength = size.width / 4;

    path.moveTo(0, size.height / 2);

    for (double i = 0; i < size.width; i++) {
      final y = size.height / 2 + 
          waveHeight * math.sin((i / waveLength + animationValue * 4) * 2 * math.pi);
      path.lineTo(i, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}

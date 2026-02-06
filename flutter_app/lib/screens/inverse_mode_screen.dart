import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';  // Google Translator
import 'dart:async';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../widgets/glassmorphism_card.dart';

class InverseModeScreen extends StatefulWidget {
  const InverseModeScreen({Key? key}) : super(key: key);

  @override
  State<InverseModeScreen> createState() => _InverseModeScreenState();
}

class _InverseModeScreenState extends State<InverseModeScreen> with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GoogleTranslator _translator = GoogleTranslator();  // Google Translate pour lettres manquantes
  final Map<String, String> _translationCache = {};  // Cache pour éviter requêtes répétées
  
  bool _isListening = false;
  String _recognizedText = '';
  String _selectedLanguage = 'Français';
  double _speed = 1.0;
  
  int _currentLetterIndex = 0;
  Timer? _animationTimer;
  
  final Map<String, String> _languageCodes = {
    'Français': 'fr-FR',
    'Anglais': 'en-US',
    'Arabe': 'ar-SA',
  };
  
  // Letter to gesture mapping for Arabic sign language
  final Map<String, Map<String, String>> _letterToGesture = {
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
  
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
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

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      if (mounted) {
        setState(() {
          _isListening = true;
          _recognizedText = '';  // Effacer l'ancien texte
          _currentLetterIndex = 0;  // Reset l'animation
        });
        _waveController.repeat();
        _animationTimer?.cancel();  // Arrêter l'animation en cours
      }
      _speech.listen(
        localeId: _languageCodes[_selectedLanguage],
        onResult: (result) {
          if (mounted) {
            setState(() {
              _recognizedText = result.recognizedWords.toUpperCase();
            });
          }
        },
        listenMode: stt.ListenMode.confirmation,
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  void _handleMicClick() {
    if (!_isListening) {
      // Premier clic : démarrer l'écoute
      _resetRecognition();
      _startListening();
    } else {
      // Deuxième clic : arrêter l'écoute
      _stopListening();
    }
  }
  
  void _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        _waveController.stop();
        
        // Start animation if text exists
        if (_recognizedText.isNotEmpty) {
          _startGestureAnimation();
        }
      }
    }
  }
  
  void _resetRecognition() {
    setState(() {
      _recognizedText = '';
      _currentLetterIndex = 0;
    });
    _animationTimer?.cancel();
    
    // Keep listening if was listening
    if (_isListening) {
      // Restart listening for new phrase
      _speech.stop();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isListening) {
          _speech.listen(
            localeId: _languageCodes[_selectedLanguage],
            onResult: (result) {
              setState(() {
                _recognizedText = result.recognizedWords.toUpperCase();
              });
            },
            listenMode: stt.ListenMode.confirmation,
            pauseFor: const Duration(seconds: 3),
          );
        }
      });
    }
  }
  
  void _startNewPhrase() {
    // Reset text and animation
    setState(() {
      _recognizedText = '';
      _currentLetterIndex = 0;
    });
    _animationTimer?.cancel();
    
    // If already listening, stop and restart for a truly fresh start
    if (_isListening) {
      _speech.stop();
      // Brief delay to allow speech engine to reset completely
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() => _isListening = false); // Visually reset
          _startListening(); // Restarts properly
        }
      });
    } else {
      _startListening();
    }
  }

  /// Traduit une lettre en utilisant Google Translate (avec cache)
  Future<String> _translateLetter(String letter, String targetLang) async {
    // Vérifier le cache d'abord
    String cacheKey = '${letter}_$targetLang';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }
    
    // Chercher dans le mapping statique
    String? staticTranslation = _letterToGesture[letter.toUpperCase()]?[targetLang];
    if (staticTranslation != null) {
      _translationCache[cacheKey] = staticTranslation;
      return staticTranslation;
    }
    
    // Utiliser Google Translate comme fallback
    try {
      String langCode = _languageCodes[targetLang]?.split('-').first ?? 'en';
      var translation = await _translator.translate(letter, to: langCode);
      String result = translation.text;
      _translationCache[cacheKey] = result;  // Mettre en cache
      print('✅ Traduction Google: $letter → $result ($targetLang)');
      return result;
    } catch (e) {
      print('❌ Erreur traduction Google: $e');
      // Fallback: retourner la lettre originale
      return letter;
    }
  }

  void _startGestureAnimation() {
    _currentLetterIndex = 0;
    _animationTimer?.cancel();
    
    if (_recognizedText.isEmpty) return;
    
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
    _pulseController.dispose();
    _glowController.dispose();
    _animationTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep original letters for image paths
    final originalLetters = _recognizedText.split('').where((c) => c != ' ').toList();
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a3e),
              Color(0xFF0f0f2e),
              Color(0xFF2d1b4e),
            ],
          ),
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Mode Inverse',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Sound Wave Visualization with Microphone
              Stack(
                alignment: Alignment.center,
                children: [
                  // Animated Sound Waves
                  if (_isListening)
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(MediaQuery.of(context).size.width, 200),
                          painter: SoundWavePainter(
                            _waveController.value,
                            isListening: _isListening,
                          ),
                        );
                      },
                    ),
                  
                  // Circular Glow Effect
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Container(
                        width: 180 + (_glowController.value * 20),
                        height: 180 + (_glowController.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _isListening 
                                ? Color(0xFF6366f1).withOpacity(0.3 + _glowController.value * 0.2)
                                : Colors.transparent,
                              blurRadius: 40 + (_glowController.value * 20),
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  // Microphone Button
                  GestureDetector(
                    onTap: _handleMicClick,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _isListening
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF8b5cf6),
                                    Color(0xFF6366f1),
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    Color(0xFF4a4a6a),
                                    Color(0xFF3a3a5a),
                                  ],
                                ),
                            border: Border.all(
                              color: _isListening 
                                ? Colors.white.withOpacity(0.3)
                                : Colors.white.withOpacity(0.1),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _isListening 
                                  ? Color(0xFF6366f1).withOpacity(0.5)
                                  : Colors.black.withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 60,
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Concentric Circles
                  if (_isListening)
                    ...List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final size = 160.0 + (index * 30) + (_pulseController.value * 20);
                          final opacity = 0.3 - (index * 0.1) - (_pulseController.value * 0.2);
                          return Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Color(0xFF6366f1).withOpacity(opacity.clamp(0.0, 1.0)),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Phrase Display
              if (_recognizedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6366f1).withOpacity(0.2),
                          Color(0xFF8b5cf6).withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Color(0xFF6366f1).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Phrase ($_selectedLanguage):',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                _recognizedText,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up, color: Color(0xFF06b6d4)),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 30),
              
              // Gesture Sequence Display
              if (originalLetters.isNotEmpty)
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: originalLetters.length,
                    itemBuilder: (context, index) {
                      final originalLetter = originalLetters[index];
                      final isActive = index == _currentLetterIndex;
                      
                      return FutureBuilder<String>(
                        future: _translateLetter(originalLetter, _selectedLanguage),
                        builder: (context, snapshot) {
                          final displayLetter = snapshot.data ?? originalLetter;
                          
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 12),
                            width: 100,
                            decoration: BoxDecoration(
                              gradient: isActive 
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF8b5cf6).withOpacity(0.4),
                                      Color(0xFF6366f1).withOpacity(0.4),
                                    ],
                                  )
                                : null,
                              color: isActive ? null : Color(0xFF2a2a4a).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive 
                                  ? Color(0xFF8b5cf6)
                                  : Colors.white.withOpacity(0.1),
                                width: isActive ? 2 : 1,
                              ),
                              boxShadow: isActive ? [
                                BoxShadow(
                                  color: Color(0xFF8b5cf6).withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ] : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: Image.asset(
                                      'assets/gestures/${originalLetter.toUpperCase()}_0.jpg',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Text(
                                            '🤟',
                                            style: TextStyle(fontSize: 50),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: snapshot.connectionState == ConnectionState.waiting
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06b6d4)),
                                        ),
                                      )
                                    : Text(
                                        displayLetter,
                                        style: TextStyle(
                                          color: isActive ? Color(0xFF06b6d4) : Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              
              const Spacer(),
              
              // Speed Control Slider
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF2a2a4a).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Color(0xFF6366f1),
                          inactiveTrackColor: Color(0xFF4a4a6a),
                          thumbColor: Color(0xFF8b5cf6),
                          overlayColor: Color(0xFF8b5cf6).withOpacity(0.3),
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _speed,
                          min: 0.5,
                          max: 2.0,
                          divisions: 2,
                          onChanged: (value) {
                            setState(() => _speed = value);
                            if (!_isListening && _recognizedText.isNotEmpty) {
                              _startGestureAnimation();
                            }
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Lent', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('Normal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('Rapide', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            // Control Buttons removed
            const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  

}

// Advanced Sound Wave Painter
class SoundWavePainter extends CustomPainter {
  final double animationValue;
  final bool isListening;

  SoundWavePainter(this.animationValue, {this.isListening = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isListening) return;

    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final centerX = size.width / 2;

    // Draw multiple wave layers
    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final amplitude = 30.0 + (layer * 15);
      final frequency = 0.02 - (layer * 0.005);
      final phase = animationValue * 2 * math.pi + (layer * math.pi / 3);
      
      // Gradient colors for waves
      final colors = [
        Color(0xFF06b6d4),
        Color(0xFF6366f1),
        Color(0xFF8b5cf6),
      ];
      
      paint.color = colors[layer].withOpacity(0.6 - layer * 0.15);
      
      // Left wave
      path.moveTo(centerX - 150, centerY);
      for (double x = centerX - 150; x < centerX; x += 2) {
        final distance = (centerX - x) / 150;
        final y = centerY + 
          amplitude * distance * math.sin((x - centerX) * frequency + phase);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
      
      // Right wave
      final pathRight = Path();
      pathRight.moveTo(centerX, centerY);
      for (double x = centerX; x < centerX + 150; x += 2) {
        final distance = (x - centerX) / 150;
        final y = centerY + 
          amplitude * distance * math.sin((x - centerX) * frequency + phase);
        pathRight.lineTo(x, y);
      }
      canvas.drawPath(pathRight, paint);
    }
  }

  @override
  bool shouldRepaint(SoundWavePainter oldDelegate) => true;
}

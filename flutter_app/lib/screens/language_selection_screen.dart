import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphism_card.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLanguage = 'Français';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'Français';
    });
  }

  Future<void> _saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    setState(() {
      _selectedLanguage = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
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
                      'Sélection de la langue',
                      style: AppTheme.headingMedium,
                    ),
                  ],
                ),
                
                const SizedBox(height: 60),
                
                // Language Cards
                _buildLanguageCard(
                  flag: '🇫🇷',
                  language: 'Français',
                  isSelected: _selectedLanguage == 'Français',
                  onTap: () {
                    _saveLanguage('Français');
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.pop(context, 'Français');
                    });
                  },
                ),
                
                const SizedBox(height: 20),
                
                _buildLanguageCard(
                  flag: '🇬🇧',
                  language: 'English',
                  isSelected: _selectedLanguage == 'English',
                  onTap: () {
                    _saveLanguage('English');
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.pop(context, 'English');
                    });
                  },
                ),
                
                const SizedBox(height: 20),
                
                _buildLanguageCard(
                  flag: '🇹🇳',
                  language: 'العربية (Arabe)',
                  isSelected: _selectedLanguage == 'Arabe',
                  onTap: () {
                    _saveLanguage('Arabe');
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.pop(context, 'Arabe');
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard({
    required String flag,
    required String language,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GlassmorphismCard(
      onTap: onTap,
      padding: const EdgeInsets.all(28),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected 
                ? AppTheme.primaryPurple.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                  ? AppTheme.primaryPurple
                  : Colors.transparent,
                width: 2,
              ),
            ),
            child: Text(
              flag,
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              language,
              style: AppTheme.headingSmall.copyWith(
                color: isSelected ? AppTheme.primaryPurple : AppTheme.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_circle,
              color: AppTheme.primaryPurple,
              size: 32,
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphism_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gradient Title
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: Text(
                    'SignLanguage',
                    style: AppTheme.headingLarge.copyWith(
                      fontSize: 56,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Mode Reconnaissance Card
                GlassmorphismCard(
                  onTap: () => Navigator.pushNamed(context, '/recognition'),
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          '🔤',
                          style: TextStyle(fontSize: 48),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mode Reconnaissance',
                              style: AppTheme.headingSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gestes → Texte/Parole',
                              style: AppTheme.bodyMedium.copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Mode Inverse Card
                GlassmorphismCard(
                  onTap: () => Navigator.pushNamed(context, '/inverse'),
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          '💬',
                          style: TextStyle(fontSize: 48),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mode Inverse',
                              style: AppTheme.headingSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Voix/Texte → Gestes',
                              style: AppTheme.bodyMedium.copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Settings Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIconButton(
                      context,
                      icon: Icons.language,
                      label: 'Langue',
                      onTap: () => Navigator.pushNamed(context, '/language'),
                    ),
                    const SizedBox(width: 20),
                    _buildIconButton(
                      context,
                      icon: Icons.settings_remote,
                      label: 'ESP32',
                      onTap: () => Navigator.pushNamed(context, '/esp32-config'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.accentCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

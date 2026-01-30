import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors - Dark glassmorphism theme
  static const Color background = Color(0xFF0a0a0a);
  static const Color cardBackground = Color(0xFF111827);
  static const Color primaryPurple = Color(0xFF6366f1);
  static const Color primaryBlue = Color(0xFF3b82f6);
  static const Color accentCyan = Color(0xFF06b6d4);
  static const Color textPrimary = Color(0xFFf9fafb);
  static const Color textMuted = Color(0xFF9ca3af);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF818cf8), Color(0xFfc084fc)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardBorderGradient = LinearGradient(
    colors: [Color(0xFF6366f1), Color(0xFF3b82f6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0a0a0a), Color(0xFF1a1a2e)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Text Styles
  static TextStyle get headingLarge => GoogleFonts.outfit(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.1,
  );
  
  static TextStyle get headingMedium => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );
  
  static TextStyle get headingSmall => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle get bodyLarge => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: textMuted,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textMuted,
  );
  
  static TextStyle get buttonText => GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  // Glassmorphism decoration
  static BoxDecoration glassmorphismDecoration({
    Color? backgroundColor,
    Gradient? gradient,
    double borderRadius = 24,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? cardBackground.withOpacity(0.5),
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder 
        ? Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          )
        : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
  
  // Theme data
  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        brightness: Brightness.dark,
        background: background,
        surface: cardBackground,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        displayLarge: headingLarge,
        displayMedium: headingMedium,
        displaySmall: headingSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: headingMedium,
      ),
    );
  }
}

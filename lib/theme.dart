import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SkillTheme {
  final String label;
  final String tagline;
  final IconData icon;
  final Color primary;
  final Color soft;
  final Color foreground;
  final Color border;

  SkillTheme({
    required this.label,
    required this.tagline,
    required this.icon,
    required this.primary,
    required this.soft,
    required this.foreground,
    required this.border,
  });
}

class AppTheme {
  // Brand colors
  static const Color primaryColor = Color(0xFFC22929);
  static const Color secondaryColor = Color(0xFF4B5563);

  // Text colors (High Contrast)
  static const Color textPrimaryLight = Color(0xFF111827);   // Gray 900
  static const Color textSecondaryLight = Color(0xFF374151); // Gray 700
  static const Color textMutedLight = Color(0xFF4B5563);     // Gray 600

  static const Color textPrimaryDark = Color(0xFFF9FAFB);    // Gray 50
  static const Color textSecondaryDark = Color(0xFFE5E7EB);  // Gray 200
  static const Color textMutedDark = Color(0xFF9CA3AF);      // Gray 400
  
  // Surfaces
  static const Color lightBg = Color(0xFFF9F9F8);
  static const Color lightCard = Colors.white;
  static const Color darkBg = Color(0xFF121214);
  static const Color darkCard = Color(0xFF1E1E24);
  
  // Skill theme map
  static final Map<String, SkillTheme> skills = {
    'listening': SkillTheme(
      label: 'Listening',
      tagline: 'Improve your listening skills with real IELTS tests.',
      icon: Icons.headphones_outlined,
      primary: const Color(0xFFE2722B),
      soft: const Color(0xFFFDF4ED),
      foreground: const Color(0xFFA24E1B),
      border: const Color(0x4DE2722B),
    ),
    'reading': SkillTheme(
      label: 'Reading',
      tagline: 'Improve your reading skills with real IELTS tests.',
      icon: Icons.book_outlined,
      primary: const Color(0xFF2E9A60),
      soft: const Color(0xFFEEF9F3),
      foreground: const Color(0xFF1A6B3E),
      border: const Color(0x4D2E9A60),
    ),
    'writing': SkillTheme(
      label: 'Writing',
      tagline: 'Improve your writing skills with real IELTS tasks.',
      icon: Icons.edit_note_outlined,
      primary: const Color(0xFF2563EB),
      soft: const Color(0xFFEEF2FF),
      foreground: const Color(0xFF1E40AF),
      border: const Color(0x4D2563EB),
    ),
    'speaking': SkillTheme(
      label: 'Speaking',
      tagline: 'Improve your speaking skills with real IELTS tests.',
      icon: Icons.mic_none_outlined,
      primary: const Color(0xFF8B5CF6),
      soft: const Color(0xFFF5F3FF),
      foreground: const Color(0xFF5B21B6),
      border: const Color(0x4D8B5CF6),
    ),
  };

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBg,
      cardColor: lightCard,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: lightCard,
        onSurface: textPrimaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryLight),
        actionsIconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimaryLight,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: textSecondaryLight,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: textMutedLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: darkCard,
        onSurface: textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryDark),
        actionsIconTheme: IconThemeData(color: textPrimaryDark),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimaryDark,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: textSecondaryDark,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: textMutedDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.0),
          side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E24),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}

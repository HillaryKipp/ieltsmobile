import 'package:flutter/material.dart';
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
      primary: Color(0xFFE2722B),
      soft: Color(0xFFFDF4ED),
      foreground: Color(0xFFA24E1B),
      border: Color(0x4DE2722B),
    ),
    'reading': SkillTheme(
      label: 'Reading',
      tagline: 'Improve your reading skills with real IELTS tests.',
      icon: Icons.book_outlined,
      primary: Color(0xFF2E9A60),
      soft: Color(0xFFEEF9F3),
      foreground: Color(0xFF1A6B3E),
      border: Color(0x4D2E9A60),
    ),
    'writing': SkillTheme(
      label: 'Writing',
      tagline: 'Improve your writing skills with real IELTS tasks.',
      icon: Icons.edit_note_outlined,
      primary: Color(0xFF2563EB),
      soft: Color(0xFFEEF2FF),
      foreground: Color(0xFF1E40AF),
      border: Color(0x4D2563EB),
    ),
    'speaking': SkillTheme(
      label: 'Speaking',
      tagline: 'Improve your speaking skills with real IELTS tests.',
      icon: Icons.mic_none_outlined,
      primary: Color(0xFF8B5CF6),
      soft: Color(0xFFF5F3FF),
      foreground: Color(0xFF5B21B6),
      border: Color(0x4D8B5CF6),
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
        background: lightBg,
        surface: lightCard,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1F2937),
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1F2937),
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Color(0xFFF3F4F6), width: 1.5),
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
        background: darkBg,
        surface: darkCard,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFF3F4F6),
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFF3F4F6),
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

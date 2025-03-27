// lib/constants/theme_constants.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

class LuxuryTheme {
  // Main color palette
  static const Color primaryRosegold = Color(0xFFB76E79);
  static const Color lightRosegold = Color(0xFFC88EA7);  
  static const Color accentBlush = Color(0xFFFADADD);
  static const Color accentLightBlush = Color(0xFFF5E5EA);
  static const Color neutralOffWhite = Color(0xFFFDFBFA);
  static const Color neutralWarmGrey = Color(0xFFEAE7E7);
  static const Color textCharcoal = Color(0xFF2D2B2B);
  static const Color ctaWine = Color(0xFF8B2635);
  static const Color ctaGold = Color(0xFFD4AF37);
  
  // Gradient presets
  static const LinearGradient rosegoldGradient = LinearGradient(
    colors: [primaryRosegold, lightRosegold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient blushGradient = LinearGradient(
    colors: [accentBlush, accentLightBlush],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Text styles using Google Fonts
  static TextStyle get headingLarge => GoogleFonts.dmSerifDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: textCharcoal,
    letterSpacing: 0.5,
  );
  
  static TextStyle get headingMedium => GoogleFonts.dmSerifDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textCharcoal,
    letterSpacing: 0.3,
  );
  
  static TextStyle get headingSmall => GoogleFonts.dmSerifDisplay(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textCharcoal,
    letterSpacing: 0.2,
  );
  
  static TextStyle get bodyLarge => GoogleFonts.lato(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textCharcoal,
    letterSpacing: 0.2,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.lato(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textCharcoal,
    letterSpacing: 0.1,
  );
  
  static TextStyle get bodySmall => GoogleFonts.lato(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textCharcoal,
    letterSpacing: 0.1,
  );
  
  static TextStyle get labelLarge => GoogleFonts.lato(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textCharcoal,
    letterSpacing: 0.5,
  );
  
  // UI Constants
  static const double buttonRadius = 10.0;
  static const double cardRadius = 12.0;
  static const double largeCardRadius = 16.0;
  
  // Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.07),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];
}
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF405DE6);
  static const Color accentColor = Color(0xFF833AB4);
  static const Color gradientStart = Color(0xFF405DE6);
  static const Color gradientMiddle = Color(0xFF5851DB);
  static const Color gradientEnd = Color(0xFFE1306C);
  static const Color likeColor = Color(0xFFE1306C);
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color cardColor = Colors.white;
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color textPrimaryColor = Color(0xFF262626);
  static const Color textSecondaryColor = Color(0xFF8E8E8E);
  static const Color dividerColor = Color(0xFFDBDBDB);

  static const LinearGradient instagramGradient = LinearGradient(
    colors: [gradientStart, gradientMiddle, gradientEnd],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient storyRingGradient = LinearGradient(
    colors: [
      Color(0xFFFBAA47),
      Color(0xFFD91A46),
      Color(0xFFA60F93),
    ],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  // Button style
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12),
    elevation: 0,
  );

  static ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: const BorderSide(color: primaryColor),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12),
  );

  // Input decoration
  static InputDecoration inputDecoration = InputDecoration(
    filled: true,
    fillColor: dividerColor.withOpacity(0.3),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: primaryColor, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: const TextStyle(color: textSecondaryColor),
  );

  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundColor,
    primaryColor: primaryColor,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: textPrimaryColor),
      titleTextStyle: TextStyle(
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textPrimaryColor, fontSize: 16),
      bodyMedium: TextStyle(color: textPrimaryColor, fontSize: 14),
      bodySmall: TextStyle(color: textSecondaryColor, fontSize: 12),
      titleLarge: TextStyle(color: textPrimaryColor, fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: textPrimaryColor, fontSize: 18, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: textPrimaryColor, fontSize: 16, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: backgroundColor,
      indicatorColor: primaryColor.withOpacity(0.1),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
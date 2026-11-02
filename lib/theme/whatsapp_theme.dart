import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WhatsAppTheme {
  // Brand Colors
  static const Color primaryTeal = Color(0xFF00A884); // WhatsApp Green Emerald
  static const Color primaryTealDark = Color(0xFF008069);
  static const Color accentGreen = Color(0xFF25D366);

  // Dark Mode Palette
  static const Color darkBg = Color(0xFF0B141A); // Deep Obsidian Scaffold
  static const Color darkSurface = Color(0xFF1F2C34); // Header / Bar surface
  static const Color darkSurfaceContainer = Color(0xFF121B22);
  static const Color darkCard = Color(0xFF182229);
  static const Color darkPill = Color(0xFF202C33);
  static const Color darkBubbleOutgoing = Color(0xFF005C4B); // My messages
  static const Color darkBubbleIncoming = Color(0xFF202C33); // Other messages
  static const Color darkChatBg = Color(0xFF0B141B);
  static const Color darkTextPrimary = Color(0xFFE9EDEF);
  static const Color darkTextSecondary = Color(0xFF8696A0);

  // Light Mode Palette
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFF0F2F5);
  static const Color lightPill = Color(0xFFF0F2F5);
  static const Color lightBubbleOutgoing = Color(0xFFE7FFDB);
  static const Color lightBubbleIncoming = Color(0xFFFFFFFF);
  static const Color lightChatBg = Color(0xFFEFEAE2);
  static const Color lightTextPrimary = Color(0xFF111B21);
  static const Color lightTextSecondary = Color(0xFF667781);

  // Status & Utility Colors
  static const Color blueCheck = Color(0xFF53BDEB); // Double Blue Tick
  static const Color greyCheck = Color(0xFF8696A0);
  static const Color e2eeYellow = Color(0xFFFFD279);

  // Attachment Colors
  static const Color attachDocument = Color(0xFF7F66FF);
  static const Color attachCamera = Color(0xFFD3396D);
  static const Color attachGallery = Color(0xFFAC44CF);
  static const Color attachAudio = Color(0xFFFF9900);
  static const Color attachLocation = Color(0xFF1FA855);
  static const Color attachContact = Color(0xFF009DE2);
  static const Color attachPoll = Color(0xFF00A884);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryTeal,
        onPrimary: Colors.white,
        primaryContainer: darkBubbleOutgoing,
        onPrimaryContainer: darkTextPrimary,
        secondary: primaryTeal,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: darkBubbleIncoming,
        onSurfaceVariant: darkTextSecondary,
        outline: Color(0xFF2A3942),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: darkTextSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryTeal,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF222E35), width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF202C33),
        thickness: 0.6,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primaryTealDark,
        onPrimary: Colors.white,
        primaryContainer: lightBubbleOutgoing,
        onPrimaryContainer: lightTextPrimary,
        secondary: primaryTeal,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        surfaceContainerHighest: lightBubbleIncoming,
        onSurfaceVariant: lightTextSecondary,
        outline: Color(0xFFE9EDEF),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: primaryTealDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: primaryTealDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: lightTextSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primaryTealDark,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryTealDark,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE9EDEF),
        thickness: 0.6,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

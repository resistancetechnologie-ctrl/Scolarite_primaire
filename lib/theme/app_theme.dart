import 'package:flutter/material.dart';

/// Palette WhatsApp officielle.
class WA {
  static const teal = Color(0xFF075E54);
  static const tealDark = Color(0xFF054C44);
  static const green = Color(0xFF128C7E);
  static const lightGreen = Color(0xFF25D366);
  static const bubble = Color(0xFFDCF8C6);
  static const chatBg = Color(0xFFECE5DD);
  static const panel = Color(0xFFFFFFFF);
  static const blueTick = Color(0xFF34B7F1);
  static const grey = Color(0xFF667781);
  static const divider = Color(0xFFE9EDEF);
  static const danger = Color(0xFFD32F2F);
  static const warn = Color(0xFFF9A825);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: WA.chatBg,
      colorScheme: const ColorScheme.light(
        primary: WA.teal,
        onPrimary: Colors.white,
        secondary: WA.lightGreen,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF111B21),
        error: WA.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: WA.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: WA.lightGreen,
        foregroundColor: Colors.white,
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xCCFFFFFF),
        indicatorColor: WA.lightGreen,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      listTileTheme: const ListTileThemeData(iconColor: WA.green),
      dividerTheme: const DividerThemeData(color: WA.divider, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: WA.green, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WA.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WA.green,
          side: const BorderSide(color: WA.green),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: WA.green),
      ),
      chipTheme: const ChipThemeData(selectedColor: WA.bubble),
      snackBarTheme: const SnackBarThemeData(backgroundColor: WA.teal, contentTextStyle: TextStyle(color: Colors.white)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: WA.green),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? WA.lightGreen : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? WA.bubble : const Color(0xFFD1D7DB)),
      ),
    );
  }
}

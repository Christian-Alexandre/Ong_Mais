import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0E8C7F);
  static const Color primaryDark = Color(0xFF0B6B61);
  static const Color accent = Color(0xFF00B894);
  static const Color orange = Color(0xFFFF5722);
  static const Color background = Color(0xFFF7F9FA);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF1B1F3B);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color danger = Color(0xFFE05252);

  static const LinearGradient gradient = LinearGradient(
    colors: [primaryDark, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
    scaffoldBackgroundColor: AppColors.background,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9DEE3))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9DEE3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      prefixIconColor: AppColors.primary,
      hintStyle: const TextStyle(color: Color(0xFFA0A7B1)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFD9DEE3))),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textGrey,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
    ),
  );
}

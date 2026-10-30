import 'package:flutter/material.dart';

/// 던전우상향 앱·홈페이지(dungeon-homepage lib/theme.dart)와 같은 다크 팔레트.
class AppColors {
  static const background = Color(0xFF070A10);
  static const surface = Color(0xFF171C2A);
  static const surfaceSoft = Color(0xFF0E121B);
  static const border = Color(0xFF262E42);
  static const brand = Color(0xFF2F66E0);
  static const accent = Color(0xFF31DAE3);
  static const textPrimary = Color(0xFFF7F9FC);
  static const textSecondary = Color(0xFFCBD2DC);
  static const textTertiary = Color(0xFFB0B8C6);
  static const up = Color(0xFFF0616D);
  static const down = Color(0xFF4A8BFF);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    dividerColor: AppColors.border,
    dataTableTheme: const DataTableThemeData(
      headingTextStyle: TextStyle(
        color: AppColors.textTertiary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 14),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

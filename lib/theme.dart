import 'package:flutter/material.dart';

/// 관리자 화면 팔레트. 숫자 표를 오래 보는 화면이라 밝은 바탕을 쓴다.
class AppColors {
  static const background = Color(0xFFEEF2F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF5F8FB);
  static const strip = Color(0xFFDCE7F4); // 메뉴·제목·표 머리줄
  static const border = Color(0xFFB9C7D8);
  static const grid = Color(0xFFD9E1EB); // 표 칸 선
  static const brand = Color(0xFF2259C7);
  static const accent = Color(0xFF0B7F8A);
  static const textPrimary = Color(0xFF17202C);
  static const textSecondary = Color(0xFF3C4858);
  static const textTertiary = Color(0xFF5B6878);
  static const up = Color(0xFFD3232F); // 이익·매수
  static const down = Color(0xFF1F5AD6); // 손실·매도
  static const success = Color(0xFF16803A);
  static const warning = Color(0xFFB86500);
}

ThemeData buildTheme() {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
  const buttonText = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  final base = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
  );
  OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: color),
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary)
        .copyWith(bodyMedium: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
    dividerColor: AppColors.border,
    dataTableTheme: DataTableThemeData(
      headingRowColor: const WidgetStatePropertyAll(AppColors.strip),
      headingRowHeight: 32,
      dataRowMinHeight: 28,
      dataRowMaxHeight: 44,
      horizontalMargin: 10,
      dividerThickness: 1,
      headingTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: inputBorder(AppColors.border),
      enabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.brand),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        shape: shape,
        textStyle: buttonText,
        padding: buttonPadding,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        textStyle: buttonText,
        padding: buttonPadding,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape, textStyle: buttonText),
    ),
    chipTheme: ChipThemeData(
      shape: shape,
      showCheckmark: false,
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.brand,
      labelStyle: TextStyle(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textPrimary,
        ),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    dialogTheme: DialogThemeData(shape: shape, backgroundColor: AppColors.surface),
  );
}

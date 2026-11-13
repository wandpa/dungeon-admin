import 'package:flutter/material.dart';

/// 관리자 화면 팔레트. 숫자 표를 오래 보는 화면이라 바탕·선·글자는 회색으로 두고,
/// 색은 로고 파랑 하나(강조)와 손익·상태 같은 뜻 있는 숫자에만 쓴다.
class AppColors {
  static const background = Color(0xFFF6F6F7); // 페이지 바탕
  static const surface = Color(0xFFFFFFFF); // 카드
  static const surfaceSoft = Color(0xFFFAFAFA); // 카드 안의 옅은 칸
  static const strip = Color(0xFFF2F2F3); // 표 머리줄·선택 탭 같은 한 단계 올라온 면
  static const border = Color(0x1A18181B); // 선. 글자색 10%
  static const control = Color(0x8018181B); // 입력칸·버튼 테두리. 흰 바탕에서 3.4:1 이라 칸 경계가 보인다
  static const grid = Color(0x0F18181B); // 표 칸 선. 글자색 6%
  static const brand = Color(0xFF2259C7); // 강조색. 주 버튼·선택·중요한 숫자에만
  static const brandSoft = Color(0xFFEAF0FB); // 선택된 칩·줄 바탕
  static const accent = brand; // 예전 청록 자리. 강조색은 하나만 쓴다
  static const textPrimary = Color(0xFF18181B);
  static const textSecondary = Color(0xFF4A4A50);
  static const textTertiary = Color(0xFF6E6E75); // 보조 글자·아이콘
  static const up = Color(0xFFD92D20); // 이익·매수 (국내 관례 빨강)
  static const down = Color(0xFF1F5AD6); // 손실·매도 (국내 관례 파랑)
  static const danger = Color(0xFFD92D20); // 오류·삭제·정지. 값은 up 과 같지만 뜻이 달라 따로 둔다
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
}

/// 간격·반경. 4의 배수만 쓴다.
class AppSpace {
  static const page = 16.0; // 페이지 가장자리
  static const gap = 12.0; // 카드 사이
  static const card = 16.0; // 카드 안쪽
}

class AppRadius {
  static const control = 8.0; // 버튼·입력칸·칩
  static const card = 12.0; // 카드·패널
  static const tag = 6.0; // 작은 표시
}

/// 숫자는 고정폭으로 맞춰 열이 흔들리지 않게 한다.
const tabularFigures = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  final control = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control));
  const buttonText = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  final base = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    fontFamily: 'Pretendard',
    visualDensity: VisualDensity.compact,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: NoSplash.splashFactory,
    colorScheme: const ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.brand,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.control,
      outlineVariant: AppColors.border,
      surfaceTint: Colors.transparent,
    ),
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
    borderSide: BorderSide(color: color, width: width),
  );
  TextStyle? tabular(TextStyle? s) => s?.copyWith(fontFeatures: tabularFigures, letterSpacing: 0);
  final text = base.textTheme.apply(
    fontFamily: 'Pretendard',
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );
  return base.copyWith(
    textTheme: text.copyWith(
      bodyLarge: tabular(text.bodyLarge),
      bodyMedium: tabular(text.bodyMedium?.copyWith(fontSize: 13, height: 1.45)),
      bodySmall: tabular(text.bodySmall?.copyWith(color: AppColors.textTertiary)),
      titleMedium: tabular(text.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
      titleSmall: tabular(text.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
      labelLarge: tabular(text.labelLarge),
    ),
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: AppColors.textTertiary, size: 18),
    dataTableTheme: DataTableThemeData(
      headingRowColor: const WidgetStatePropertyAll(AppColors.strip),
      headingRowHeight: 36,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 48,
      horizontalMargin: 12,
      dividerThickness: 1,
      headingTextStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFeatures: tabularFigures,
      ),
      dataTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFeatures: tabularFigures),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      prefixIconColor: AppColors.textTertiary,
      border: inputBorder(AppColors.control),
      enabledBorder: inputBorder(AppColors.control),
      disabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.brand, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        disabledBackgroundColor: AppColors.strip,
        disabledForegroundColor: AppColors.textTertiary,
        shape: control,
        textStyle: buttonText,
        padding: buttonPadding,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        shape: control,
        textStyle: buttonText,
        padding: buttonPadding,
        side: const BorderSide(color: AppColors.control),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.brand, shape: control, textStyle: buttonText),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary, shape: control),
    ),
    // 선택은 칠하지 않고 옅은 강조 바탕과 강조색 글자로 보인다.
    chipTheme: ChipThemeData(
      shape: control,
      showCheckmark: false,
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected) ? AppColors.brand.withValues(alpha: 0.35) : AppColors.control,
        ),
      ),
      color: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.brandSoft : AppColors.surface,
      ),
      labelStyle: TextStyle(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.brand : AppColors.textSecondary,
        ),
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontFeatures: tabularFigures,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: AppColors.control, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.brand : AppColors.control,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(AppRadius.tag)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      width: 480,
      shape: control,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Pretendard'),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      backgroundColor: AppColors.surface,
      titleTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        fontFamily: 'Pretendard',
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.brand, linearTrackColor: AppColors.strip),
  );
}

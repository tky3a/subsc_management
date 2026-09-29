import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// デザイン（ダークモード）のカラートークン。
abstract final class AppColors {
  static const background = Color(0xFF101214);
  static const surface = Color(0xFF181B1F);
  static const raised = Color(0xFF23272C);
  static const navBar = Color(0xFF14171A);
  static const line = Color(0xFF2A2F36);
  static const divider = Color(0xFF22262C);
  static const badgeLine = Color(0xFF3A4048);

  static const text = Color(0xFFECEEF1);
  static const textSub = Color(0xFF9DA4AE);
  static const textLabel = Color(0xFFC9CED5);
  static const icon = Color(0xFF7C838D);

  static const accent = Color(0xFF7FD8C4);
  static const onAccent = Color(0xFF0B1F1B);
  static const accentSoft = Color(0xFF1C2E2A);
  static const warn = Color(0xFFF0A958);
  static const danger = Color(0xFFF2999B);
  static const dangerLine = Color(0xFF5A3336);

  /// サービスのモノグラム用（背景, 文字）。サービス ID から決める。
  static const tiles = [
    (Color(0xFF3A2326), Color(0xFFF2A0A4)),
    (Color(0xFF1F3327), Color(0xFF8FDDA8)),
    (Color(0xFF1F2A3D), Color(0xFF9DBBF2)),
    (Color(0xFF2A2D33), Color(0xFFD5D9DF)),
    (Color(0xFF3A3020), Color(0xFFF0C987)),
    (Color(0xFF2E2440), Color(0xFFC4A8F0)),
  ];

  static (Color, Color) tileFor(int serviceId) => tiles[(serviceId - 1) % tiles.length];
}

/// 金額用の等幅数字フォント。
TextStyle mono(double size, {FontWeight weight = FontWeight.w400, Color color = AppColors.text}) =>
    GoogleFonts.dmMono(fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.2);

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.accent,
    onSecondary: AppColors.onAccent,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.raised,
    onSurfaceVariant: AppColors.textSub,
    outline: AppColors.line,
    outlineVariant: AppColors.divider,
    error: AppColors.danger,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final textTheme = GoogleFonts.ibmPlexSansJpTextTheme(base.textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.icon),
      labelStyle: const TextStyle(color: AppColors.textSub),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.accent, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        disabledBackgroundColor: AppColors.raised,
        disabledForegroundColor: AppColors.icon,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.ibmPlexSansJp(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(44, 52),
        side: const BorderSide(color: AppColors.badgeLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.ibmPlexSansJp(fontSize: 15),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.navBar,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accentSoft,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.textSub,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.ibmPlexSansJp(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? AppColors.accent : AppColors.textSub,
        );
      }),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.raised,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1, thickness: 1),
  );
}

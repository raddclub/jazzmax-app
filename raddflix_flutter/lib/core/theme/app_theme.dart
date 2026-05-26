import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import 'theme_provider.dart';

class JazzThemeData {
  static ThemeData build(JazzTheme mode) {
    final isDark = mode != JazzTheme.light;
    final bg     = _bg(mode);
    final surface = _surface(mode);
    final text   = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final muted  = isDark ? AppColors.textMuted   : AppColors.lightTextMuted;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    return base.copyWith(
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryLight,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
        background: bg,
        onBackground: text,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.inter(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surface : AppColors.lightSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surface : AppColors.lightCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.glassBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        labelStyle: TextStyle(color: muted, fontSize: 14),
        hintStyle: TextStyle(color: muted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.disabled)) {
              return AppColors.primary.withOpacity(0.4);
            }
            return AppColors.primary;
          }),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          overlayColor: MaterialStateProperty.all(Colors.white10),
          minimumSize: MaterialStateProperty.all(const Size(double.infinity, 52)),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          elevation: MaterialStateProperty.all(0),
          textStyle: MaterialStateProperty.all(
            GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(text),
          side: MaterialStateProperty.all(
            BorderSide(color: isDark ? AppColors.glassBorder : AppColors.lightBorder),
          ),
          minimumSize: MaterialStateProperty.all(const Size(double.infinity, 52)),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          textStyle: MaterialStateProperty.all(
            GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      cardTheme: CardTheme(
        color: isDark ? AppColors.card : AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: isDark ? AppColors.cardBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.divider : AppColors.dividerLight,
        thickness: 0.5,
        space: 0,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: isDark ? AppColors.surface : AppColors.lightSurface,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.surface : AppColors.lightSurface,
        modalBackgroundColor: isDark ? AppColors.surface : AppColors.lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceHigh : Colors.grey[850],
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? AppColors.primary : Colors.white),
        trackColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected)
                ? AppColors.primary.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? AppColors.primary : Colors.transparent),
        side: BorderSide(color: muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  static Color _bg(JazzTheme mode) {
    switch (mode) {
      case JazzTheme.amoled: return AppColors.amoled;
      case JazzTheme.light:  return AppColors.lightBg;
      default:               return AppColors.background;
    }
  }

  static Color _surface(JazzTheme mode) {
    switch (mode) {
      case JazzTheme.amoled: return AppColors.amoledSurface;
      case JazzTheme.light:  return AppColors.lightSurface;
      default:               return AppColors.surface;
    }
  }
}

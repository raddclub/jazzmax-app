import 'package:flutter/material.dart';
import '../constants.dart';

extension JazzColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get jazzBg =>
      isDark ? AppColors.background : AppColors.lightBg;

  Color get jazzText =>
      isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

  Color get jazzTextSecondary =>
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

  Color get jazzTextMuted =>
      isDark ? AppColors.textMuted : AppColors.lightTextMuted;

  Color get jazzSurface =>
      isDark ? AppColors.surface : AppColors.lightSurface;

  Color get jazzCard =>
      isDark ? AppColors.card : AppColors.lightCard;

  Color get jazzBorder =>
      isDark ? AppColors.glassBorder : AppColors.lightBorder;

  LinearGradient get jazzHeroGradient => LinearGradient(
    colors: [Colors.transparent, isDark ? AppColors.background : AppColors.lightBg],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.3, 1.0],
  );
}

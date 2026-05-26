import 'package:flutter/material.dart';
import '../constants.dart';

extension RaddColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get raddBg =>
      isDark ? AppColors.background : AppColors.lightBg;

  Color get jazzText =>
      isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

  Color get raddTextSecondary =>
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

  Color get raddTextMuted =>
      isDark ? AppColors.textMuted : AppColors.lightTextMuted;

  Color get raddSurface =>
      isDark ? AppColors.surface : AppColors.lightSurface;

  Color get raddCard =>
      isDark ? AppColors.card : AppColors.lightCard;

  Color get raddBorder =>
      isDark ? AppColors.glassBorder : AppColors.lightBorder;

  LinearGradient get raddHeroGradient => LinearGradient(
    colors: [Colors.transparent, isDark ? AppColors.background : AppColors.lightBg],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.3, 1.0],
  );
}

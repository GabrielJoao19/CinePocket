import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF121214);
  static const surface = Color(0xFF1C1C20);
  static const surfaceLight = Color(0xFF26262B);
  static const border = Color(0xFF2E2E34);
  static const yellow = Color(0xFFF5C518);
  static const textSecondary = Color(0xFF9A9AA3);
  static const heart = Color(0xFFFF8A9B);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.yellow,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.yellow : AppColors.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.yellow : AppColors.textSecondary,
        );
      }),
    ),
  );
}

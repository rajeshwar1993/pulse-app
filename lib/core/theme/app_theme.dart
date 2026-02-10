import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.teal,
        secondary: AppColors.rose,
        surface: AppColors.offWhite,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.offWhite,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.offWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.slate900),
      ),
    );
  }
}

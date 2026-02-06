import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFFF4D4D);
  static const Color secondaryColor = Color(0xFFEA5700);
  static const Color backgroundColor = Color(0xFFF8F9FD);
  static const Color surfaceColor = Colors.white;
  
  static const Gradient defaultGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF4D4D),
      Color(0xFFFF8E53),
    ],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }
}

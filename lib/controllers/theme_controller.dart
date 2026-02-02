import 'package:flutter/material.dart';

class ThemeController {
  // Singleton instance
  static final ThemeController instance = ThemeController._internal();

  factory ThemeController() {
    return instance;
  }

  ThemeController._internal();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  void toggleTheme() {
    themeMode.value = themeMode.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  bool get isDarkMode => themeMode.value == ThemeMode.dark;
}

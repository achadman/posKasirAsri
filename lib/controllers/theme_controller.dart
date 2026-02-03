import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  // Singleton instance
  static final ThemeController instance = ThemeController._internal();

  factory ThemeController() {
    return instance;
  }

  ThemeController._internal() {
    _loadTheme();
  }

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  static const String _themeKey = 'theme_mode';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? false;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    themeMode.value = themeMode.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, themeMode.value == ThemeMode.dark);
  }

  bool get isDarkMode => themeMode.value == ThemeMode.dark;
}

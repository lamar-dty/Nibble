import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeStore extends ChangeNotifier {
  ThemeStore._();
  static final instance = ThemeStore._();

  static const _key = 'isDarkMode';
  bool isDark = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    isDark = !isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
}
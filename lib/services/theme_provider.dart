import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  
  // Minimalistic Dark-First Design System defaults to true.
  bool _isDarkMode = true;
  bool _isLoaded = false;

  ThemeProvider() {
    _loadTheme();
  }

  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _isLoaded;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  ThemeData get themeData => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_themeKey)) {
        _isDarkMode = prefs.getBool(_themeKey) ?? true;
      } else {
        // Defaulting to dark-first aesthetic if no preference exists
        _isDarkMode = true;
      }
    } catch (_) {
      // Fallback gracefully if shared_preferences fails
      _isDarkMode = true;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> toggleTheme(bool isOn) async {
    if (_isDarkMode == isOn) return;
    _isDarkMode = isOn;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isOn);
    } catch (_) {
      // Non-blocking persistent store update
    }
  }
}

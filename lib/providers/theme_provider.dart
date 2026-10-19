import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class ThemeProvider extends ChangeNotifier {
  final PreferencesService _prefs;
  late bool _isDarkMode;

  ThemeProvider(this._prefs) {
    _isDarkMode = _prefs.isDarkMode;
  }

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  void setDarkMode(bool isDark) async {
    if (_isDarkMode == isDark) return;
    _isDarkMode = isDark;
    await _prefs.setDarkMode(_isDarkMode);
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'isDarkMode';
  late Box _box;
  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  // Call this once at startup
  Future<void> init() async {
    _box = await Hive.openBox('theme_prefs');
    _isDark = _box.get(_key, defaultValue: false);
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDark = value;
    await _box.put(_key, value);
    notifyListeners();
  }
}
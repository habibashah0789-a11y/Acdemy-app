import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_palette.dart';
import '../theme/app_theme_registry.dart';

/// Dynamic Theme Provider managing active theme palette, user-scoped persistence,
/// and immediate reactive UI updates across Quaid Academy.
class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'theme_prefs';
  static const String _activeThemeKey = 'app_active_theme_id';
  static const String _legacyModeKey = 'app_theme_mode_v2';
  static const String _legacyDarkKey = 'isDarkMode';

  Box? _box;
  final Map<String, dynamic> _memoryFallback = {};
  String _currentThemeId = AppThemeRegistry.defaultTheme.id;
  AppThemePalette _currentPalette = AppThemeRegistry.defaultTheme;

  String get currentThemeId => _currentThemeId;
  AppThemePalette get currentPalette => _currentPalette;

  /// Current ThemeData configured with Material 3, ColorScheme, and AppThemeTokens extension.
  ThemeData get currentThemeData => _currentPalette.toThemeData();

  /// ThemeMode for MaterialApp binding.
  ThemeMode get themeMode => _currentPalette.isDark ? ThemeMode.dark : ThemeMode.light;

  bool get isDark => _currentPalette.isDark;
  bool get isAuroraGlass =>
      _currentThemeId == 'aurora_glass' || _currentThemeId == 'auroraGlass';

  /// Backwards-compatible enum representation.
  AppThemeMode get currentTheme {
    if (isAuroraGlass) return AppThemeMode.auroraGlass;
    if (isDark) return AppThemeMode.dark;
    return AppThemeMode.light;
  }

  /// Alias for currentTheme.
  AppThemeMode get currentThemeMode => currentTheme;

  /// Resolves the current user key for user-scoped theme preferences.
  String _getEffectiveUserKey([String? explicitUserId]) {
    if (explicitUserId != null && explicitUserId.trim().isNotEmpty) {
      return explicitUserId.trim();
    }
    // 1. Firebase Auth user (Admin, Teacher)
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.uid.isNotEmpty) {
        return 'user_${authUser.uid}';
      }
    } catch (_) {}

    // 2. Student Session from Hive
    try {
      if (Hive.isBoxOpen('student_session')) {
        final sessionBox = Hive.box('student_session');
        final session = sessionBox.get('session');
        if (session is Map && session['studentId'] != null) {
          final sId = session['studentId'].toString();
          if (sId.isNotEmpty) return 'student_$sId';
        }
      }
    } catch (_) {}

    return 'global';
  }

  /// Initializes the provider and loads saved theme preference.
  Future<void> init() async {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        _box = Hive.box(_boxName);
      } else {
        _box = await Hive.openBox(_boxName);
      }
    } catch (e) {
      // Safe fallback if Hive is not initialized in some test environments
    }

    final userKey = _getEffectiveUserKey();
    final userSpecificTheme = _box?.isOpen == true ? _box!.get('user_theme_$userKey') : _memoryFallback['user_theme_$userKey'];
    final activeTheme = _box?.isOpen == true ? _box!.get(_activeThemeKey) : _memoryFallback[_activeThemeKey];
    final legacyMode = _box?.isOpen == true ? _box!.get(_legacyModeKey) : null;
    final legacyDark = _box?.isOpen == true ? _box!.get(_legacyDarkKey) : null;

    String resolvedId = AppThemeRegistry.defaultTheme.id;

    if (userSpecificTheme != null && userSpecificTheme.toString().isNotEmpty) {
      resolvedId = userSpecificTheme.toString();
    } else if (activeTheme != null && activeTheme.toString().isNotEmpty) {
      resolvedId = activeTheme.toString();
    } else if (legacyMode != null) {
      if (legacyMode == 'auroraGlass' || legacyMode == 'aurora_glass') {
        resolvedId = 'aurora_glass';
      } else if (legacyMode == 'dark') {
        resolvedId = 'classic_dark';
      } else {
        resolvedId = 'classic_light';
      }
    } else if (legacyDark != null) {
      resolvedId = (legacyDark == true) ? 'classic_dark' : 'classic_light';
    }

    _currentThemeId = resolvedId;
    _currentPalette = AppThemeRegistry.getTheme(resolvedId);
    notifyListeners();
  }

  /// Sets the active theme dynamically and persists with user scoping.
  Future<void> setTheme(String themeId, {String? userId}) async {
    _currentThemeId = themeId;
    _currentPalette = AppThemeRegistry.getTheme(themeId);

    final userKey = _getEffectiveUserKey(userId);
    _memoryFallback['user_theme_$userKey'] = themeId;
    _memoryFallback[_activeThemeKey] = themeId;

    try {
      if (_box != null && _box!.isOpen) {
        await _box!.put('user_theme_$userKey', themeId);
        await _box!.put(_activeThemeKey, themeId);
        await _box!.put(_legacyModeKey, themeId);
        await _box!.put(_legacyDarkKey, _currentPalette.isDark);
      }
    } catch (_) {}

    notifyListeners();
  }

  /// Loads user-specific theme on login or role switch.
  Future<void> loadUserTheme([String? userId]) async {
    final userKey = _getEffectiveUserKey(userId);
    String? savedUserTheme;

    try {
      if (_box != null && _box!.isOpen) {
        savedUserTheme = _box!.get('user_theme_$userKey')?.toString();
      } else if (Hive.isBoxOpen(_boxName)) {
        _box = Hive.box(_boxName);
        savedUserTheme = _box!.get('user_theme_$userKey')?.toString();
      }
    } catch (_) {}

    savedUserTheme ??= _memoryFallback['user_theme_$userKey']?.toString();

    if (savedUserTheme != null && savedUserTheme.isNotEmpty) {
      await setTheme(savedUserTheme, userId: userId);
    }
  }

  /// Preserved for backward compatibility with existing callers.
  Future<void> setThemeMode(AppThemeMode mode) async {
    switch (mode) {
      case AppThemeMode.light:
        await setTheme('classic_light');
        break;
      case AppThemeMode.dark:
        await setTheme('classic_dark');
        break;
      case AppThemeMode.auroraGlass:
        await setTheme('aurora_glass');
        break;
    }
  }

  /// Preserved for backward compatibility with toggle callers.
  Future<void> toggleTheme([bool? value]) async {
    final nextDark = value ?? !_currentPalette.isDark;
    await setTheme(nextDark ? 'classic_dark' : 'classic_light');
  }
}
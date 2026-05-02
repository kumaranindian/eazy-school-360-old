import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode provider for managing light/dark mode state
class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';

  ThemeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  /// Load saved theme mode from shared preferences
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    
    if (savedTheme != null) {
      state = savedTheme == 'light' 
          ? ThemeMode.light 
          : savedTheme == 'dark' 
              ? ThemeMode.dark 
              : ThemeMode.system;
    }
  }

  /// Toggle between light and dark mode
  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveThemeMode();
  }

  /// Set specific theme mode
  void setThemeMode(ThemeMode mode) {
    state = mode;
    _saveThemeMode();
  }

  /// Save theme mode to shared preferences
  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, state.toString().split('.').last);
  }
}

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

/// Current theme mode provider (returns actual ThemeMode value)
final currentThemeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeModeProvider);
});

/// Is dark mode provider
final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  
  if (themeMode == ThemeMode.dark) {
    return true;
  } else if (themeMode == ThemeMode.light) {
    return false;
  }
  
  // System mode - check platform brightness
  return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
});

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı tercihleri (cihazda saklanır).
class SettingsState extends ChangeNotifier {
  // Yeni anahtar: önceki sürümde kaydedilmiş elle seçim, otomatik seçimi ezmesin
  static const _modelKey = 'manual_model';
  static const _themeKey = 'theme_mode';

  /// Elle seçilen Ollama modeli; null ise sunucu soruya göre OTOMATİK seçer.
  String? model;

  /// Sistem / açık / koyu tema.
  ThemeMode themeMode = ThemeMode.system;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      model = prefs.getString(_modelKey);
      themeMode = switch (prefs.getString(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (_) {
      // Tercih okunamazsa varsayılanlar kullanılır
    }
  }

  Future<void> setModel(String? value) async {
    model = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_modelKey);
      } else {
        await prefs.setString(_modelKey, value);
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, value.name);
    } catch (_) {}
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı tercihleri (cihazda saklanır).
class SettingsState extends ChangeNotifier {
  static const _modelKey = 'selected_model';

  /// Seçilen Ollama modeli; null ise sunucunun varsayılanı (.env içindeki LLM_MODEL).
  String? model;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      model = prefs.getString(_modelKey);
      notifyListeners();
    } catch (_) {
      // Tercih okunamazsa varsayılan kullanılır
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
}

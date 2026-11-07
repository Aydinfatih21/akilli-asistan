import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/asistan_api.dart';
import '../api/models.dart';

/// Oturum durumu. Token cihazın güvenli deposunda (Android Keystore) saklanır.
class AuthState extends ChangeNotifier {
  AuthState(this.api) {
    api.client.onUnauthorized = () => _clear(expired: true);
  }

  final AsistanApi api;
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  User? user;
  bool restoring = true;

  /// Oturum sunucu tarafından düşürüldüğünde (401) çağrılır; açık ekranları kapatmak için.
  void Function()? onSessionExpired;

  bool get isLoggedIn => user != null;

  /// Uygulama açılışında kayıtlı oturumu geri yükler.
  Future<void> restore() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final userJson = await _storage.read(key: _userKey);
      if (token != null && userJson != null) {
        api.client.token = token;
        user = User.fromJson(Map<String, dynamic>.from(jsonDecode(userJson) as Map));
      }
    } catch (_) {
      // Depo okunamazsa (ör. ilk kurulum) giriş ekranı gösterilir
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async => _save(await api.login(email, password));

  Future<void> register(String name, String email, String password) async =>
      _save(await api.register(name, email, password));

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {
      // Sunucuya ulaşılamasa da yerel oturum kapatılır
    }
    await _clear();
  }

  Future<void> _save(AuthResult r) async {
    api.client.token = r.token;
    user = r.user;
    await _storage.write(key: _tokenKey, value: r.token);
    await _storage.write(key: _userKey, value: jsonEncode(r.user.toJson()));
    notifyListeners();
  }

  Future<void> _clear({bool expired = false}) async {
    if (user == null && api.client.token == null) return;
    api.client.token = null;
    user = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (_) {}
    notifyListeners();
    if (expired) onSessionExpired?.call();
  }
}

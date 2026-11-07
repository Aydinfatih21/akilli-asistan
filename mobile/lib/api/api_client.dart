import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Sunucunun döndürdüğü hata ({ok:false, error:{code, message}}) veya ağ hatası.
/// [message] her zaman kullanıcıya gösterilebilecek Türkçe bir cümledir.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, {this.detail});

  final int status; // 0: ağ / zaman aşımı
  final String code;
  final String message;
  final String? detail; // teknik ayrıntı (yalnızca hata ayıklama için)

  /// Oturum geçersiz (yanlış şifre hariç) → kullanıcı giriş ekranına döner.
  bool get isUnauthorized => status == 401 && code == 'UNAUTHORIZED';

  @override
  String toString() => message;
}

/// n8n webhook'larıyla konuşan düşük seviyeli HTTP istemcisi.
/// Tüm istekler POST + JSON; yanıt zarfı docs/API.md'de tanımlıdır.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Giriş yapıldıysa Bearer anahtarı.
  String? token;

  /// Sunucu 401 UNAUTHORIZED döndürdüğünde çağrılır (oturumu kapatmak için).
  void Function()? onUnauthorized;

  static const Duration normalTimeout = Duration(seconds: 20);

  /// Yapay zekâ kullanan uç noktalar için (model yükleme + 3 deneme).
  static const Duration aiTimeout = Duration(seconds: 180);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = normalTimeout,
  }) async {
    final uri = Uri.parse('$baseUrl/$path');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final http.Response res;
    try {
      res = await _http
          .post(uri, headers: headers, body: jsonEncode(body ?? const <String, dynamic>{}))
          .timeout(timeout);
    } on TimeoutException {
      throw ApiException(0, 'TIMEOUT', 'Sunucu zamanında yanıt vermedi. Lütfen tekrar deneyin.');
    } on SocketException {
      throw ApiException(0, 'NETWORK',
          'Sunucuya bağlanılamadı. Bilgisayardaki servislerin açık olduğunu ve sunucu adresini kontrol edin.');
    } on http.ClientException {
      throw ApiException(0, 'NETWORK',
          'Sunucuya bağlanılamadı. Bilgisayardaki servislerin açık olduğunu ve sunucu adresini kontrol edin.');
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      json = null;
    }

    if (json == null) {
      throw ApiException(res.statusCode, 'BAD_RESPONSE', 'Sunucudan beklenmeyen bir yanıt geldi (${res.statusCode}).');
    }

    if (json['ok'] == true && res.statusCode >= 200 && res.statusCode < 300) {
      final data = json['data'];
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    }

    // n8n'in kendi hataları (ör. yayınlanmamış workflow) zarf dışında gelir
    final err = json['error'] is Map ? Map<String, dynamic>.from(json['error'] as Map) : <String, dynamic>{};
    final e = ApiException(
      res.statusCode,
      (err['code'] ?? (res.statusCode == 404 ? 'ENDPOINT_NOT_FOUND' : 'UNKNOWN')).toString(),
      (err['message'] ??
              (res.statusCode == 404
                  ? 'Bu özellik sunucuda etkin değil (workflow yayınlanmamış olabilir).'
                  : 'Beklenmeyen bir hata oluştu.'))
          .toString(),
      detail: (err['detail'] ?? json['message'])?.toString(),
    );
    if (e.isUnauthorized) onUnauthorized?.call();
    throw e;
  }
}

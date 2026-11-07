/// Uygulama ayarları.
///
/// Sunucu adresi derleme sırasında değiştirilebilir:
///   flutter run --dart-define=API_BASE=http://192.168.1.20:5678/webhook
/// Varsayılan değer Android emülatörü içindir (10.0.2.2 = bilgisayarın localhost'u).
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:5678/webhook',
  );

  /// Ayarlar ekranında seçilebilecek modeller (ilk eleman = sunucu varsayılanı).
  static const List<String> models = ['gemma3:4b', 'qwen2.5:7b'];
}

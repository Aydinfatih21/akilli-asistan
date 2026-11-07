import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'api/asistan_api.dart';
import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'state/auth_state.dart';
import 'state/settings_state.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final api = AsistanApi(ApiClient(baseUrl: AppConfig.apiBase));
  final auth = AuthState(api)
    ..onSessionExpired = () {
      // Açık ekranları kapat, giriş ekranına dön ve kullanıcıyı bilgilendir
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Oturumunuzun süresi doldu. Lütfen tekrar giriş yapın.')),
      );
    };
  auth.restore();
  final settings = SettingsState()..load();

  runApp(
    MultiProvider(
      providers: [
        Provider<AsistanApi>.value(value: api),
        ChangeNotifierProvider<AuthState>.value(value: auth),
        ChangeNotifierProvider<SettingsState>.value(value: settings),
      ],
      child: const AsistanApp(),
    ),
  );
}

class AsistanApp extends StatelessWidget {
  const AsistanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akıllı Ders Asistanı',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _Root(),
    );
  }
}

/// Oturum durumuna göre giriş ekranı veya ana sayfa.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (auth.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}

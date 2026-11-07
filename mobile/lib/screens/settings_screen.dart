import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/auth_state.dart';
import '../state/settings_state.dart';

/// Ayarlar: yapay zekâ modeli seçimi, sunucu bilgisi, hesap.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _descriptions = {
    'gemma3:4b': 'Türkçesi doğal ve hızlı',
    'qwen2.5:7b': 'Daha büyük model, yapılandırılmış çıktıda güçlü',
  };

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış yap'),
        content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkış yap')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final auth = context.read<AuthState>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final settings = context.watch<SettingsState>();
    final user = context.watch<AuthState>().user;

    Widget option(String? value, String title, String subtitle) {
      final selected = settings.model == value;
      return ListTile(
        leading: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () => settings.setModel(value),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Yapay zekâ modeli', style: tt.titleSmall?.copyWith(color: cs.primary)),
          ),
          option(null, 'Sunucu varsayılanı', 'Sunucudaki .env ayarında tanımlı model'),
          for (final m in AppConfig.models) option(m, m, _descriptions[m] ?? 'Ollama modeli'),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Sunucu', style: tt.titleSmall?.copyWith(color: cs.primary)),
          ),
          const ListTile(
            leading: Icon(Icons.dns_outlined),
            title: Text('n8n adresi'),
            subtitle: Text(AppConfig.apiBase),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Hesap', style: tt.titleSmall?.copyWith(color: cs.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user?.name ?? ''),
            subtitle: Text(user?.email ?? ''),
          ),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: cs.error),
            title: Text('Çıkış yap', style: TextStyle(color: cs.error)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

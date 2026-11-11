import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/auth_state.dart';
import '../state/settings_state.dart';

/// Ayarlar: tema, yapay zekâ modeli (otomatik / gelişmiş), sunucu bilgisi, hesap.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _descriptions = {
    'gemma3:4b': 'Türkçesi doğal ve hızlı',
    'qwen2.5:7b': 'Matematik, kod ve yapılandırılmış çıktıda güçlü',
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

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(text, style: tt.titleSmall?.copyWith(color: cs.primary)),
        );

    Widget modelOption(String m) {
      final selected = settings.model == m;
      return ListTile(
        contentPadding: const EdgeInsets.only(left: 32, right: 16),
        leading: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(m),
        subtitle: Text(_descriptions[m] ?? 'Ollama modeli'),
        onTap: () => settings.setModel(m),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          header('Görünüm'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Sistem')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Açık')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Koyu')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (v) => settings.setThemeMode(v.first),
            ),
          ),
          header('Yapay zekâ modeli'),
          ListTile(
            leading: Icon(
              settings.model == null ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: settings.model == null ? cs.primary : cs.onSurfaceVariant,
            ),
            title: const Text('Otomatik (önerilen)'),
            subtitle: const Text(
                'Sorunun türüne göre seçilir: Türkçe anlatım, özet ve önerilerde gemma3:4b; matematik, kod ve sayısal '
                'sorularda qwen2.5:7b. Her yanıtın altında hangi modelin neden seçildiği yazar.'),
            isThreeLine: true,
            onTap: () => settings.setModel(null),
          ),
          Theme(
            // ExpansionTile'ın üst/alt çizgilerini gizle
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Gelişmiş: modeli elle seç'),
              subtitle: Text(settings.model == null ? 'Kapalı' : 'Seçili: ${settings.model}'),
              initiallyExpanded: settings.model != null,
              children: [for (final m in AppConfig.models) modelOption(m)],
            ),
          ),
          const Divider(height: 24),
          header('Sunucu'),
          const ListTile(
            leading: Icon(Icons.dns_outlined),
            title: Text('n8n adresi'),
            subtitle: Text(AppConfig.apiBase),
          ),
          const Divider(height: 24),
          header('Hesap'),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import '../state/auth_state.dart';
import '../utils/format.dart';
import '../widgets/state_views.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';
import 'course_screen.dart';
import 'settings_screen.dart';

/// Ana sayfa: karşılama + genel istatistik, ders listesi, ders ekleme.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Course>? _courses;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // initState içinde setState çağrılamaz; ilk kare çizildikten sonra yükle
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = context.read<AsistanApi>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courses = await api.courses();
      if (mounted) setState(() => _courses = courses);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCourse() async {
    final created = await showDialog<Course>(context: context, builder: (_) => const _AddCourseDialog());
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${created.name}" dersi eklendi.')));
    _load();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load(); // geri dönünce istatistikleri tazele
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Derslerim'),
        actions: [
          IconButton(tooltip: 'Yenile', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            tooltip: 'Sohbetler',
            onPressed: () => _push(const ConversationsScreen()),
            icon: const Icon(Icons.forum_outlined),
          ),
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: () => _push(const SettingsScreen()),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCourse,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ders ekle'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final courses = _courses;
    if (courses == null) {
      if (_error != null) return ErrorView(message: _error!, onRetry: _load);
      return const LoadingView(message: 'Dersler yükleniyor…');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _SummaryCard(courses: courses),
          if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
          const SizedBox(height: 12),
          _AskCard(onTap: () => _push(const ChatScreen())),
          const SizedBox(height: 20),
          if (courses.isEmpty)
            EmptyView(
              icon: Icons.menu_book_rounded,
              title: 'Henüz dersin yok',
              subtitle: 'İlk dersini ekle; ardından not yükleyip özet alabilir ve kendini test edebilirsin.',
              action: FilledButton.icon(
                onPressed: _addCourse,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ders ekle'),
              ),
            )
          else ...[
            Text('Dersler', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final c in courses) _CourseCard(course: c, onTap: () => _push(CourseScreen(course: c))),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ özet kartı
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = context.select<AuthState, String>((a) => a.user?.name ?? '');
    final firstName = name.split(' ').first;

    final notes = courses.fold<int>(0, (s, c) => s + c.noteCount);
    final tests = courses.fold<int>(0, (s, c) => s + c.attemptCount);
    // Genel başarı: test sayısıyla ağırlıklı ortalama
    final weighted = courses.where((c) => c.avgPercent != null).fold<int>(0, (s, c) => s + c.avgPercent! * c.attemptCount);
    final avg = tests > 0 ? (weighted / tests).round() : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [cs.primary, cs.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Merhaba, $firstName', style: tt.titleLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Bugün ne çalışmak istersin?', style: tt.bodyMedium?.copyWith(color: cs.onPrimary)),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(value: '${courses.length}', label: 'Ders'),
              _Stat(value: '$notes', label: 'Not'),
              _Stat(value: '$tests', label: 'Test'),
              _Stat(value: avg == null ? '—' : '%$avg', label: 'Başarı'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: tt.headlineSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700)),
          Text(label, style: tt.labelMedium?.copyWith(color: cs.onPrimary)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ asistan kartı
class _AskCard extends StatelessWidget {
  const _AskCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(Icons.auto_awesome_rounded, color: cs.onSecondaryContainer),
        title: Text('Yapay zekâ asistanına sor',
            style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text('Ders konularıyla ilgili her şeyi sorabilirsin.', style: TextStyle(color: cs.onSecondaryContainer)),
        trailing: Icon(Icons.chevron_right_rounded, color: cs.onSecondaryContainer),
        onTap: onTap,
      ),
    );
  }
}

// ------------------------------------------------------------------ ders kartı
class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initial = course.name.isNotEmpty ? course.name.characters.first.toUpperCase() : '?';
    final details = [
      '${course.noteCount} not',
      '${course.attemptCount} test',
      if (course.lastActivity != null) relativeTime(course.lastActivity),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primaryContainer,
                child: Text(initial, style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleMedium),
                    const SizedBox(height: 2),
                    Text(details, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PercentBadge(percent: course.avgPercent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Başarı yüzdesi rozeti: ≥80 yeşil, ≥50 turuncu, altı kırmızı, test yoksa gri.
class PercentBadge extends StatelessWidget {
  const PercentBadge({super.key, required this.percent});

  final int? percent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = percent;
    final MaterialColor? base = p == null ? null : (p >= 80 ? Colors.green : (p >= 50 ? Colors.orange : Colors.red));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: base?.shade100 ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        p == null ? '—' : '%$p',
        style: TextStyle(fontWeight: FontWeight.w700, color: base?.shade900 ?? cs.onSurfaceVariant),
      ),
    );
  }
}

// ------------------------------------------------------------------ ders ekleme
class _AddCourseDialog extends StatefulWidget {
  const _AddCourseDialog();

  @override
  State<_AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends State<_AddCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final api = context.read<AsistanApi>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final course = await api.createCourse(_name.text.trim());
      if (mounted) Navigator.pop(context, course);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni ders'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Ders adı', hintText: 'ör. Mobil Programlama'),
              onFieldSubmitted: (_) => _saving ? null : _save(),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Ders adını girin.';
                if (s.length > 100) return 'En fazla 100 karakter olabilir.';
                return null;
              },
            ),
            if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ekle'),
        ),
      ],
    );
  }
}

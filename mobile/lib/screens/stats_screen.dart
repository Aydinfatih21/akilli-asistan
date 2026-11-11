import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import '../utils/format.dart';
import '../widgets/state_views.dart';

/// İstatistikler: genel başarı, tekrarlayan zayıflıklar, ders ve konu bazlı başarı, son testler.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsOverview? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = context.read<AsistanApi>();
    setState(() => _error = null);
    try {
      final s = await api.stats();
      if (mounted) setState(() => _stats = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İstatistikler')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final s = _stats;
    if (s == null) {
      if (_error != null) return ErrorView(message: _error!, onRetry: _load);
      return const LoadingView(message: 'İstatistikler hesaplanıyor…');
    }
    if (s.attemptCount == 0) {
      return const Center(
        child: EmptyView(
          icon: Icons.insights_rounded,
          title: 'Henüz test çözmedin',
          subtitle: 'Bir nottan test oluşturup çözdüğünde başarı grafiğin ve zayıf konuların burada görünecek.',
        ),
      );
    }
    final tt = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Overall(stats: s),
          if (s.recurring.isNotEmpty) ...[
            const SizedBox(height: 20),
            _RecurringCard(topics: s.recurring),
          ],
          const SizedBox(height: 24),
          Text('Son testler', style: tt.titleMedium),
          const SizedBox(height: 10),
          _RecentChart(items: s.recent),
          const SizedBox(height: 24),
          Text('Ders bazlı başarı', style: tt.titleMedium),
          const SizedBox(height: 8),
          for (final c in s.courses.where((c) => c.attemptCount > 0)) _CourseRow(course: c),
          const SizedBox(height: 24),
          Text('Konu bazlı başarı', style: tt.titleMedium),
          const SizedBox(height: 2),
          Text('En zayıf konular üstte', style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (final t in s.topics.take(12)) _TopicRow(topic: t),
        ],
      ),
    );
  }
}

/// Yüzdeye göre renk: ≥80 yeşil, ≥50 turuncu, altı kırmızı.
Color _tone(int p) => p >= 80 ? Colors.green.shade600 : (p >= 50 ? Colors.orange.shade700 : Colors.red.shade600);

class _Overall extends StatelessWidget {
  const _Overall({required this.stats});

  final StatsOverview stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget tile(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: tt.headlineSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700)),
              Text(label, style: tt.labelMedium?.copyWith(color: cs.onPrimary)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [cs.primary, cs.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          tile('${stats.attemptCount}', 'Test'),
          tile('${stats.questionCount}', 'Soru'),
          tile('${stats.correctCount}', 'Doğru'),
          tile(stats.avgPercent == null ? '—' : '%${stats.avgPercent}', 'Ortalama'),
        ],
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({required this.topics});

  final List<TopicStat> topics;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: cs.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.repeat_rounded, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Tekrarlayan zayıflıklar',
                    style: tt.titleMedium?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Bu konularda birden fazla testte hata yaptın; öncelik bunlarda.',
                style: tt.bodySmall?.copyWith(color: cs.onErrorContainer)),
            const SizedBox(height: 10),
            for (final t in topics.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.courseName == null ? t.topic : '${t.topic} · ${t.courseName}',
                        style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text('${t.wrongAttempts} testte hata · %${t.accuracy}',
                        style: tt.labelMedium?.copyWith(color: cs.onErrorContainer)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Son testlerin başarı yüzdeleri: sade çubuk grafik (ek paket gerektirmez).
class _RecentChart extends StatelessWidget {
  const _RecentChart({required this.items});

  final List<RecentAttempt> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const maxH = 120.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final a in items)
            Expanded(
              child: Tooltip(
                message: '${a.courseName ?? ''} · ${a.score}/${a.total} · ${relativeTime(a.createdAt)}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('%${a.percent}', style: tt.labelSmall),
                    const SizedBox(height: 4),
                    Container(
                      height: 6 + (maxH - 6) * a.percent / 100,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: _tone(a.percent), borderRadius: BorderRadius.circular(6)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course});

  final CourseStat course;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final avg = course.avgPercent ?? 0;
    final first = course.firstPercent, last = course.lastPercent;
    final trend = (first != null && last != null && course.attemptCount > 1) ? last - first : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(course.name, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
              if (trend != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(trend >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 18, color: trend >= 0 ? Colors.green.shade600 : Colors.red.shade600),
                    Text(' ${trend >= 0 ? '+' : ''}$trend', style: tt.labelMedium),
                  ]),
                ),
              Text('%$avg · ${course.attemptCount} test', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: avg / 100,
              minHeight: 10,
              color: _tone(avg),
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final TopicStat topic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.topic, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodyMedium),
                if (topic.courseName != null)
                  Text(topic.courseName!, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: topic.accuracy / 100,
                minHeight: 8,
                color: _tone(topic.accuracy),
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text('${topic.correct}/${topic.total}', textAlign: TextAlign.end, style: tt.labelMedium),
          ),
        ],
      ),
    );
  }
}

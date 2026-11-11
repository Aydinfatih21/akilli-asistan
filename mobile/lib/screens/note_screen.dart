import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import '../state/settings_state.dart';
import '../widgets/state_views.dart';
import 'quiz_screen.dart';

/// Not ekranı: yapay zekâ özeti ve test oluşturma.
class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key, required this.course, required this.note});

  final Course course;
  final NoteItem note;

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  SummaryResult? _summary;
  bool _summarizing = false;
  String? _summaryError;

  int _count = 5;
  String _difficulty = 'medium';
  bool _generating = false;
  String? _quizError;

  @override
  void initState() {
    super.initState();
    // Kayıtlı özet varsa hemen getir (model çağrılmaz, anında döner)
    if (widget.note.hasSummary) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _summarize());
    }
  }

  Future<void> _summarize({bool force = false}) async {
    final api = context.read<AsistanApi>();
    final model = context.read<SettingsState>().model;
    setState(() {
      _summarizing = true;
      _summaryError = null;
    });
    try {
      final r = await api.summarize(widget.note.id, force: force, model: model);
      if (mounted) setState(() => _summary = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _summaryError = e.message);
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  Future<void> _generateQuiz() async {
    final api = context.read<AsistanApi>();
    final model = context.read<SettingsState>().model;
    setState(() {
      _generating = true;
      _quizError = null;
    });
    try {
      final quiz = await api.generateQuiz(widget.note.id, count: _count, difficulty: _difficulty, model: model);
      if (!mounted) return;
      setState(() => _generating = false);
      await Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(quiz: quiz)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _quizError = e.message);
    } finally {
      if (mounted && _generating) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.note.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(widget.course.name, style: tt.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          _section(
            icon: Icons.summarize_rounded,
            title: 'Yapay zekâ özeti',
            child: _buildSummary(),
          ),
          if (_summary != null && !_summarizing) ...[
            const SizedBox(height: 16),
            _section(
              icon: Icons.style_rounded,
              title: 'Hap bilgiler',
              child: _buildFlashcards(_summary!.summary.flashcards),
            ),
          ],
          const SizedBox(height: 16),
          _section(
            icon: Icons.quiz_rounded,
            title: 'Kendini test et',
            child: _buildQuizOptions(),
          ),
        ],
      ),
    );
  }

  Widget _section({required IconData icon, required String title, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_summarizing) {
      return const _AiProgress(message: 'Yapay zekâ notu özetliyor… Bu işlem 10-30 saniye sürebilir.');
    }
    final s = _summary;
    if (s == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Notun kısa özetini, ana noktalarını ve anahtar kavramlarını çıkar.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          if (_summaryError != null) ...[const SizedBox(height: 12), ErrorBanner(_summaryError!)],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _summarize(),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(_summaryError == null ? 'Özet çıkar' : 'Tekrar dene'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.summary.short, style: tt.bodyLarge?.copyWith(height: 1.4)),
        const SizedBox(height: 14),
        Text('Ana noktalar', style: tt.titleSmall),
        const SizedBox(height: 6),
        for (final p in s.summary.keyPoints)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(Icons.check_circle_rounded, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(p, style: tt.bodyMedium?.copyWith(height: 1.35))),
            ]),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final k in s.summary.keywords) Chip(label: Text(k), visualDensity: VisualDensity.compact)],
        ),
        if (_summaryError != null) ...[const SizedBox(height: 12), ErrorBanner(_summaryError!)],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                [if (s.model != null) s.model!, if (s.cached) 'kayıtlı özet'].join(' · '),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            TextButton.icon(
              onPressed: () => _summarize(force: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yeniden özetle'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlashcards(List<Flashcard> cards) {
    final cs = Theme.of(context).colorScheme;
    if (cards.isEmpty) {
      // Bu özellikten önce oluşturulmuş özetlerde kart yok
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bu özet, hap bilgi kartları eklenmeden önce oluşturulmuş.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => _summarize(force: true),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Hap bilgileri oluştur'),
          ),
        ],
      );
    }
    return FlashcardDeck(cards: cards);
  }

  Widget _buildQuizOptions() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (_generating) {
      return _AiProgress(message: '$_count soruluk test hazırlanıyor… Bu işlem 20-60 saniye sürebilir.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Bu nottan çoktan seçmeli bir test oluştur.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 14),
        Text('Soru sayısı', style: tt.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 5, label: Text('5')),
            ButtonSegment(value: 7, label: Text('7')),
            ButtonSegment(value: 10, label: Text('10')),
          ],
          selected: {_count},
          onSelectionChanged: (v) => setState(() => _count = v.first),
        ),
        const SizedBox(height: 14),
        Text('Zorluk', style: tt.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'easy', label: Text('Kolay')),
            ButtonSegment(value: 'medium', label: Text('Orta')),
            ButtonSegment(value: 'hard', label: Text('Zor')),
          ],
          selected: {_difficulty},
          onSelectionChanged: (v) => setState(() => _difficulty = v.first),
        ),
        if (_quizError != null) ...[const SizedBox(height: 12), ErrorBanner(_quizError!)],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _generateQuiz,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Testi oluştur'),
        ),
      ],
    );
  }
}

class _AiProgress extends StatelessWidget {
  const _AiProgress({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// Kaydırılabilir hap bilgi kartları; karta dokununca çevrilir.
class FlashcardDeck extends StatefulWidget {
  const FlashcardDeck({super.key, required this.cards});

  final List<Flashcard> cards;

  @override
  State<FlashcardDeck> createState() => _FlashcardDeckState();
}

class _FlashcardDeckState extends State<FlashcardDeck> {
  final _controller = PageController(viewportFraction: 0.9);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.cards.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _FlashcardView(card: widget.cards[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.cards.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _index ? cs.primary : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Kart ${_index + 1} / ${widget.cards.length} · çevirmek için dokun',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _FlashcardView extends StatefulWidget {
  const _FlashcardView({required this.card});

  final Flashcard card;

  @override
  State<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<_FlashcardView> {
  bool _back = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = _back ? cs.tertiaryContainer : cs.primaryContainer;
    final fg = _back ? cs.onTertiaryContainer : cs.onPrimaryContainer;
    return GestureDetector(
      onTap: () => setState(() => _back = !_back),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(anim), child: child),
        ),
        child: Container(
          key: ValueKey(_back),
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_back ? 'BİLGİ' : 'KAVRAM', style: tt.labelSmall?.copyWith(color: fg, letterSpacing: 1.2)),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    _back ? widget.card.back : widget.card.front,
                    textAlign: TextAlign.center,
                    style: (_back ? tt.titleMedium : tt.titleLarge)
                        ?.copyWith(color: fg, fontWeight: _back ? FontWeight.w500 : FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

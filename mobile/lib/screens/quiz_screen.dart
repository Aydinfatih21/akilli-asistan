import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import '../state/settings_state.dart';
import '../widgets/state_views.dart';
import 'result_screen.dart';

/// Test çözme: soru soru ilerleme, cevapları sunucuya gönderme.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.quiz});

  final Quiz quiz;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  final Map<String, int?> _answers = {};
  bool _submitting = false;
  String? _error;

  List<QuizQuestion> get _questions => widget.quiz.questions;
  int get _answered => _answers.values.where((v) => v != null).length;

  Future<bool> _confirmLeave() async {
    if (_answered == 0) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Testten çık'),
        content: const Text('Cevapların kaydedilmeyecek. Çıkmak istediğine emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Devam et')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çık')),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _submit() async {
    final empty = _questions.length - _answered;
    if (empty > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Boş sorular var'),
          content: Text('$empty soru boş. Boş sorular yanlış sayılır. Testi yine de bitirmek istiyor musun?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Geri dön')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bitir')),
          ],
        ),
      );
      if (go != true) return;
    }
    if (!mounted) return;
    final api = context.read<AsistanApi>();
    final model = context.read<SettingsState>().model;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await api.submitQuiz(
        widget.quiz.id,
        {for (final q in _questions) q.id: _answers[q.id]},
        model: model,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(quiz: widget.quiz, result: result)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_submitting && _answered == 0,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _submitting) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: _submitting
            ? const LoadingView(message: 'Cevapların değerlendiriliyor ve sana özel çalışma önerisi hazırlanıyor…')
            : _buildQuestion(),
        bottomNavigationBar: _submitting ? null : _buildNav(),
      ),
    );
  }

  Widget _buildQuestion() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final q = _questions[_index];
    final selected = _answers[q.id];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Text('Soru ${_index + 1} / ${_questions.length}', style: tt.labelLarge),
            const Spacer(),
            Text('$_answered cevaplandı', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: (_index + 1) / _questions.length, minHeight: 6),
        ),
        const SizedBox(height: 12),
        // Soru gezgini: cevaplananlar dolu, mevcut soru çerçeveli
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _questions.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _index = i),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: _answers[_questions[i].id] != null ? cs.primary : cs.surfaceContainerHighest,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == _index ? FontWeight.w800 : FontWeight.w500,
                      color: _answers[_questions[i].id] != null ? cs.onPrimary : cs.onSurfaceVariant,
                      decoration: i == _index ? TextDecoration.underline : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (q.topic.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(q.topic, style: tt.labelMedium?.copyWith(color: cs.onSecondaryContainer)),
            ),
          ),
        const SizedBox(height: 10),
        Text(q.question, style: tt.titleLarge?.copyWith(height: 1.3)),
        const SizedBox(height: 18),
        for (var i = 0; i < q.options.length; i++)
          _OptionTile(
            letter: String.fromCharCode(65 + i),
            text: q.options[i],
            selected: selected == i,
            onTap: () => setState(() => _answers[q.id] = selected == i ? null : i),
          ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
      ],
    );
  }

  Widget _buildNav() {
    final last = _index == _questions.length - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _index == 0 ? null : () => setState(() => _index--),
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Önceki'),
            ),
            const Spacer(),
            last
                ? FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('Testi bitir'),
                  )
                : FilledButton.icon(
                    onPressed: () => setState(() => _index++),
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('Sonraki'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.letter, required this.text, required this.selected, required this.onTap});

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: selected ? cs.primary : cs.surfaceContainerHighest,
                  child: Text(letter,
                      style: TextStyle(fontWeight: FontWeight.w700, color: selected ? cs.onPrimary : cs.onSurfaceVariant)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../api/models.dart';

/// Test sonucu: puan, zayıf konular, kişisel öneri ve soru soru inceleme.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.quiz, required this.result});

  final Quiz quiz;
  final QuizResult result;

  String get _headline {
    final p = result.percent;
    if (p == 100) return 'Mükemmel! Hepsi doğru.';
    if (p >= 80) return 'Çok iyi gidiyorsun!';
    if (p >= 50) return 'Fena değil, biraz daha tekrar.';
    return 'Bu konuyu birlikte tekrar edelim.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = result.percent;
    final MaterialColor tone = p >= 80 ? Colors.green : (p >= 50 ? Colors.orange : Colors.red);
    final byId = {for (final r in result.results) r.questionId: r};

    return Scaffold(
      appBar: AppBar(title: const Text('Test sonucu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---------------------------------------------------------- puan
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: p / 100,
                    strokeWidth: 12,
                    color: tone.shade600,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('%$p', style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text('${result.score} / ${result.total} doğru', style: tt.labelLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(_headline, textAlign: TextAlign.center, style: tt.titleLarge),
          const SizedBox(height: 20),

          // ---------------------------------------------------------- zayıf konular
          if (result.weakTopics.isNotEmpty) ...[
            Text('Tekrar etmen gereken konular', style: tt.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in result.weakTopics)
                  Chip(
                    avatar: Icon(Icons.flag_rounded, size: 18, color: cs.onErrorContainer),
                    label: Text(t, style: TextStyle(color: cs.onErrorContainer)),
                    backgroundColor: cs.errorContainer,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // ---------------------------------------------------------- geçmişe dönük analiz
          if (result.recurringTopics.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.error, width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.repeat_rounded, color: cs.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tekrarlayan hata', style: tt.titleSmall?.copyWith(color: cs.error)),
                        const SizedBox(height: 4),
                        for (final r in result.recurringTopics)
                          Text('• ${r.topic}: önceki ${r.previous} testte de yanlış yaptın', style: tt.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---------------------------------------------------------- öneri
          Card(
            elevation: 0,
            color: cs.primaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.auto_awesome_rounded, color: cs.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Sana özel çalışma önerisi',
                          style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(result.recommendation,
                      style: tt.bodyLarge?.copyWith(color: cs.onPrimaryContainer, height: 1.45)),
                  if (result.recommendationSource == 'fallback') ...[
                    const SizedBox(height: 8),
                    Text('Yapay zekâ önerisi kullanılamadığı için konulara göre otomatik öneri gösteriliyor.',
                        style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ---------------------------------------------------------- soru soru
          Text('Soru soru inceleme', style: tt.titleMedium),
          const SizedBox(height: 8),
          for (final q in quiz.questions)
            if (byId[q.id] != null) _ReviewCard(question: q, result: byId[q.id]!),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Nota dön'),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.question, required this.result});

  final QuizQuestion question;
  final QuestionResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ok = result.isCorrect;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: ok ? Colors.green.shade600 : Colors.red.shade600),
                const SizedBox(width: 8),
                Text('Soru ${question.position}', style: tt.titleSmall),
                const Spacer(),
                if (question.topic.isNotEmpty)
                  Flexible(
                    child: Text(question.topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(question.question, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (var i = 0; i < question.options.length; i++) _option(context, i),
            if (result.selectedIndex == null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text('Bu soruyu boş bıraktın.', style: tt.labelMedium?.copyWith(color: Colors.red.shade700)),
              ),
            if (result.explanation.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Text('Açıklama: ${result.explanation}', style: tt.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, int i) {
    final isCorrect = i == result.correctIndex;
    final isWrongPick = i == result.selectedIndex && !result.isCorrect;
    final Color? bg = isCorrect ? Colors.green.shade100 : (isWrongPick ? Colors.red.shade100 : null);
    final Color? fg = isCorrect ? Colors.green.shade900 : (isWrongPick ? Colors.red.shade900 : null);
    final icon = isCorrect ? Icons.check_rounded : (isWrongPick ? Icons.close_rounded : null);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text('${String.fromCharCode(65 + i)})  ', style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
          Expanded(child: Text(question.options[i], style: TextStyle(color: fg))),
          if (icon != null) Icon(icon, size: 18, color: fg),
        ],
      ),
    );
  }
}

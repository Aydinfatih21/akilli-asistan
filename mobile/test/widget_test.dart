import 'package:flutter_test/flutter_test.dart';

import 'package:akilli_asistan/api/models.dart';
import 'package:akilli_asistan/utils/format.dart';

/// Sunucu JSON'larının (docs/API.md) modellere doğru çevrildiğini doğrular.
void main() {
  test('Ders: istatistik alanları ve boş ortalama', () {
    final c = Course.fromJson({
      'id': 'c1', 'name': 'Mobil Programlama', 'note_count': 3,
      'attempt_count': 0, 'avg_percent': null, 'last_activity': '2026-11-06T20:00:00.000Z',
    });
    expect(c.name, 'Mobil Programlama');
    expect(c.noteCount, 3);
    expect(c.avgPercent, isNull);
    expect(c.lastActivity, isNotNull);
  });

  test('Test: sorular sıraya dizilir, doğru cevap alanı yoktur', () {
    final q = Quiz.fromJson({
      'quiz_id': 'q1', 'title': 'Flutter — Test',
      'questions': [
        {'id': 'b', 'position': 2, 'question': 'İkinci?', 'options': ['a', 'b', 'c', 'd'], 'topic': 'T'},
        {'id': 'a', 'position': 1, 'question': 'Birinci?', 'options': ['a', 'b', 'c', 'd'], 'topic': 'T'},
      ],
    });
    expect(q.questions.map((e) => e.id), ['a', 'b']);
    expect(q.questions.first.options, hasLength(4));
  });

  test('Sonuç: boş bırakılan soru null, öneri kaynağı', () {
    final r = QuizResult.fromJson({
      'attempt_id': 'x', 'score': 3, 'total': 5, 'percent': 60,
      'results': [
        {'question_id': 'a', 'selected_index': null, 'correct_index': 2, 'is_correct': false, 'explanation': 'e'},
      ],
      'weak_topics': ['Widget'], 'recommendation': 'Öneri', 'recommendation_source': 'fallback',
    });
    expect(r.percent, 60);
    expect(r.results.single.selectedIndex, isNull);
    expect(r.recommendationSource, 'fallback');
  });

  test('Göreli zaman', () {
    expect(relativeTime(DateTime.now()), 'az önce');
    expect(relativeTime(DateTime.now().subtract(const Duration(hours: 3))), '3 saat önce');
    expect(relativeTime(null), '');
  });
}

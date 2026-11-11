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

  test('Özet: hap bilgi kartları; eski özetlerde boş liste', () {
    final withCards = NoteSummary.fromJson({
      'short': 'Ö', 'key_points': ['a'], 'keywords': ['k'],
      'flashcards': [{'front': 'Zincir kuralı', 'back': "f(g(x))' = f'(g(x))·g'(x)"}],
    });
    expect(withCards.flashcards.single.front, 'Zincir kuralı');
    expect(NoteSummary.fromJson({'short': 'Ö', 'key_points': [], 'keywords': []}).flashcards, isEmpty);
  });

  test('Sonuç: tekrarlayan konular; sohbet: model seçim nedeni', () {
    final r = QuizResult.fromJson({
      'score': 1, 'total': 5, 'percent': 20, 'results': [], 'weak_topics': ['Zincir kuralı'],
      'recommendation': 'x', 'recurring_topics': [{'topic': 'Zincir kuralı', 'previous': 2}],
    });
    expect(r.recurringTopics.single.previous, 2);
    final m = ChatMessage.fromJson({'id': '1', 'role': 'assistant', 'content': 'c', 'model': 'qwen2.5:7b', 'model_reason': 'matematiksel ifade'});
    expect(m.modelReason, 'matematiksel ifade');
  });

  test('İstatistik özeti', () {
    final s = StatsOverview.fromJson({
      'overall': {'attempt_count': 3, 'question_count': 15, 'correct_count': 9, 'avg_percent': 60},
      'courses': [{'name': 'Matematik', 'attempt_count': 3, 'avg_percent': 60, 'first_percent': 40, 'last_percent': 80}],
      'topics': [{'topic': 'Zincir kuralı', 'course_name': 'Matematik', 'total': 3, 'correct': 0, 'accuracy': 0, 'wrong_attempts': 3}],
      'recurring': [{'topic': 'Zincir kuralı', 'wrong_attempts': 3, 'accuracy': 0, 'total': 3, 'correct': 0}],
      'recent': [{'percent': 80, 'score': 4, 'total': 5}],
    });
    expect(s.avgPercent, 60);
    expect(s.recurring.single.wrongAttempts, 3);
    expect(s.courses.single.lastPercent, 80);
  });

  test('PDF metni: sayfa sayısı yoksa null', () {
    final p = PdfText.fromJson({'text': 'Türev anlık değişim hızıdır.', 'title': 'Türev', 'pages': 3, 'characters': 28});
    expect(p.pages, 3);
    expect(PdfText.fromJson({'text': 'x', 'title': 't', 'pages': null}).pages, isNull);
  });

  test('Türkçe büyük harf', () {
    expect(capitalizeTr('fatih'), 'Fatih');
    expect(capitalizeTr('ilker'), 'İlker');
    expect(capitalizeTr(''), '');
  });

  test('Göreli zaman', () {
    expect(relativeTime(DateTime.now()), 'az önce');
    expect(relativeTime(DateTime.now().subtract(const Duration(hours: 3))), '3 saat önce');
    expect(relativeTime(null), '');
  });
}

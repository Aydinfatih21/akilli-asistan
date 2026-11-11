// Puanlama KODLA yapılır (model değil). Sonra öneri için Ollama isteği hazırlanır.
const crypto = require('crypto');
const quiz = $('Teslim: test').first().json;
const req = $('Teslim: istek').first().json;

const given = new Map();
for (const a of req.answers) {
  if (a && a.question_id !== null && a.question_id !== undefined) given.set(String(a.question_id), a.selected_index);
}
const questions = [...quiz.questions].sort((a, b) => (a.position || 0) - (b.position || 0));
const graded = questions.map((q) => {
  let sel = given.get(q.id);
  sel = sel === null || sel === undefined || sel === '' ? null : Number(sel);
  if (!(Number.isInteger(sel) && sel >= 0 && sel <= 3)) sel = null; // boş / geçersiz → yanlış
  return { q, sel, ok: sel === q.correct_index };
});
const score = graded.filter((g) => g.ok).length;
const total = graded.length;
const percent = Math.round((100 * score) / total);

// Zayıf konular: yanlış sayısına göre sıralı
const counts = {};
for (const g of graded) if (!g.ok) counts[g.q.topic] = (counts[g.q.topic] || 0) + 1;
const weak_topics = Object.entries(counts).sort((a, b) => b[1] - a[1]).map(([t]) => t);

// ---- Geçmişe dönük analiz: aynı dersin önceki testlerinde bu konularda hata yapıldı mı?
// Model konu adlarını her testte biraz farklı yazabilir ("Zincir kuralı" / "Zincir Kuralı uygulaması");
// bu yüzden küçük harfe çevrilip noktalama atılarak karşılaştırılır ve biri diğerini içeriyorsa aynı sayılır.
const norm = (t) => String(t || '').toLocaleLowerCase('tr').replace(/[^\p{L}\p{N}\s]/gu, ' ').replace(/\s+/g, ' ').trim();
const sameTopic = (a, b) => { const x = norm(a); const y = norm(b); return !!x && !!y && (x === y || x.includes(y) || y.includes(x)); };
const pastQuizzes = new Map($('Teslim: geçmiş testler').all().map((i) => i.json).filter((d) => d && d.id).map((q) => [q.id, q]));
const pastWrongTopics = $('Teslim: geçmiş denemeler').all().map((i) => i.json).filter((d) => d && d.quiz_id)
  .map((a) => {
    const q = pastQuizzes.get(a.quiz_id);
    if (!q || !Array.isArray(q.questions)) return [];
    const topicOf = new Map(q.questions.map((x) => [x.id, x.topic]));
    return [...new Set((a.answers || []).filter((x) => !x.is_correct).map((x) => topicOf.get(x.question_id)).filter(Boolean))];
  });
const recurring_topics = weak_topics
  .map((t) => ({ topic: t, previous: pastWrongTopics.filter((list) => list.some((p) => sameTopic(p, t))).length }))
  .filter((x) => x.previous > 0)
  .sort((a, b) => b.previous - a.previous);

const wrong = graded.filter((g) => !g.ok);
const detail = wrong.length
  ? wrong.map((g, i) => [
      `${i + 1}. [${g.q.topic}] ${g.q.question}`,
      `   Öğrencinin cevabı: ${g.sel === null ? '(boş bırakıldı)' : g.q.options[g.sel]}`,
      `   Doğru cevap: ${g.q.options[g.q.correct_index]}`,
      `   Açıklama: ${g.q.explanation}`,
    ].join('\n')).join('\n')
  : 'Öğrenci tüm soruları doğru yanıtladı.';

const topicList = weak_topics.join(', ');
const system = [
  'Sen öğrencilere test sonuçlarına göre kişisel çalışma önerisi veren bir öğretim asistanısın.',
  'KURALLAR:',
  '1. YALNIZCA Türkçe yaz. Çince, Japonca, Korece veya Kiril alfabesinden tek bir karakter bile kullanma.',
  '2. Selamlama ("Merhaba" vb.) ve kapanış cümlesi yazma; doğrudan öneriyle başla.',
  '3. Öğrenciye "sen" diye hitap et; destekleyici ama net ol.',
  weak_topics.length
    ? `4. Yanlış yapılan HER konuyu adıyla an (${topicList}) ve her biri için tek bir somut çalışma adımı öner.`
    : '4. Tüm sorular doğru: kısaca takdir et ve bir sonraki adım için tek bir öneri ver.',
  '5. Tek paragraf yaz, en fazla 5 cümle; başlık veya madde işareti kullanma.',
  ...(recurring_topics.length
    ? ['7. Öğrenci bazı konularda önceki testlerde de hata yapmış: bunu açıkça belirt ve bu konular için farklı bir çalışma yöntemi öner (ör. konu özetini kendi cümlelerinle yazmak, örnek çözmek).']
    : []),
  percent >= 80
    ? '6. Başarı yüksek; kısa bir takdirle başlayabilirsin.'
    : '6. Puan düşük: "Tebrikler" gibi kutlama ifadeleri KULLANMA.',
].join('\n');

return [{
  json: {
    attempt: {
      id: crypto.randomUUID(), quiz_id: quiz.id, user_id: req.user_id, course_id: quiz.course_id,
      score, total, percent,
      answers: graded.map((g) => ({ question_id: g.q.id, selected_index: g.sel, is_correct: g.ok })),
      created_at: new Date().toISOString(),
    },
    results: graded.map((g) => ({
      question_id: g.q.id, selected_index: g.sel, correct_index: g.q.correct_index,
      is_correct: g.ok, explanation: g.q.explanation,
    })),
    weak_topics,
    recurring_topics,
    route: 'text',
    body: {
      model: req.model,
      stream: false,
      options: { temperature: 0.4, num_ctx: 4096 },
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: `Test: ${quiz.title}\nPuan: ${score}/${total} (%${percent})\n\nYanlış yanıtlanan sorular:\n${detail}` +
          (recurring_topics.length
            ? `\n\nGeçmiş: Öğrenci şu konularda önceki testlerde de hata yapmıştı: ${recurring_topics.map((r) => `${r.topic} (önceki ${r.previous} testte)`).join(', ')}.`
            : '') },
      ],
    },
  },
}];

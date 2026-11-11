// Test belgesini (doğru cevaplarla) ve istemci yanıtını (doğru cevap ve açıklama OLMADAN) hazırlar.
const crypto = require('crypto');
const n = $('Test: not').first().json;
const req = $('Test: istek').first().json;
const v = $input.first().json;
const quiz = {
  id: crypto.randomUUID(),
  user_id: req.user_id,
  note_id: n.id,
  course_id: n.course_id,
  title: `${n.title} — Test`,
  model: v.model || 'bilinmiyor',
  difficulty: req.difficulty,
  questions: v.questions.map((q, i) => ({ id: crypto.randomUUID(), position: i + 1, ...q })),
  created_at: new Date().toISOString(),
};
const response = {
  ok: true,
  data: {
    quiz_id: quiz.id, title: quiz.title, model: quiz.model, difficulty: quiz.difficulty,
    questions: quiz.questions.map((q) => ({
      id: q.id, position: q.position, question: q.question, options: q.options, topic: q.topic,
    })),
  },
};
return [{ json: { ...quiz, response } }];

// Test oluşturma isteğini doğrular.
const b = $('POST /quizzes/generate').first().json.body || {};
const s = (v) => (v === null || v === undefined ? '' : String(v).trim());
const count = s(b.question_count) === '' ? 5 : Number(b.question_count);
const difficulty = s(b.difficulty) || 'medium';
const fail = (message) => [{ json: { valid: false, response: { ok: false, error: { code: 'VALIDATION_ERROR', message } } } }];
if (!Number.isInteger(count) || count < 5 || count > 10) return fail('Soru sayısı 5-10 arasında olmalıdır.');
if (!['easy', 'medium', 'hard'].includes(difficulty)) return fail("Zorluk 'easy', 'medium' veya 'hard' olmalıdır.");
return [{
  json: {
    valid: true,
    user_id: $('Test: oturum').first().json.user_id,
    note_id: s(b.note_id) || '-',
    count,
    difficulty,
    model: s(b.model) || null,
  },
}];

// Test teslim isteğini doğrular.
const b = $('POST /quizzes/submit').first().json.body || {};
const s = (v) => (v === null || v === undefined ? '' : String(v).trim());
if (!Array.isArray(b.answers)) {
  return [{ json: { valid: false, response: { ok: false, error: { code: 'VALIDATION_ERROR', message: '"answers" bir dizi olmalıdır.' } } } }];
}
return [{
  json: {
    valid: true,
    user_id: $('Teslim: oturum').first().json.user_id,
    quiz_id: s(b.quiz_id) || '-',
    answers: b.answers,
    model: s(b.model) || null,
  },
}];

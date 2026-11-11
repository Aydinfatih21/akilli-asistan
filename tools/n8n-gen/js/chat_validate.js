// Soru isteğini doğrular.
const b = $('POST /chat/send').first().json.body || {};
const user_id = $('Soru: oturum').first().json.user_id;
const s = (v) => (v === null || v === undefined ? '' : String(v).trim());
const message = s(b.message);
if (!message || message.length > 4000) {
  return [{ json: { valid: false, response: { ok: false, error: { code: 'VALIDATION_ERROR', message: 'Mesaj 1-4000 karakter arasında olmalıdır.' } } } }];
}
return [{
  json: {
    valid: true,
    user_id,
    message,
    conversation_id: s(b.conversation_id) || null,
    course_id: s(b.course_id) || null,
    model: s(b.model) || null,
  },
}];

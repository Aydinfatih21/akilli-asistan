// Ders adını doğrular ve ders belgesini hazırlar.
const crypto = require('crypto');
const b = $('POST /courses/create').first().json.body || {};
const user_id = $('Ekleme: oturum').first().json.user_id;
const name = String(b.name ?? '').trim().replace(/\s+/g, ' ');
if (!name || name.length > 100) {
  return [{ json: { valid: false, response: { ok: false, error: { code: 'VALIDATION_ERROR', message: 'Ders adı 1-100 karakter arasında olmalıdır.' } } } }];
}
const course = { id: crypto.randomUUID(), user_id, name, created_at: new Date().toISOString() };
return [{
  json: {
    valid: true,
    course,
    response: { ok: true, data: { course: { id: course.id, name: course.name, created_at: course.created_at } } },
  },
}];

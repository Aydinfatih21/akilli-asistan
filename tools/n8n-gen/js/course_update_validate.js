// Ders adı değiştirme isteğini doğrular.
const b = $('POST /courses/update').first().json.body || {};
const user_id = $('Düzenle: oturum').first().json.user_id;
const s = (v) => (v === null || v === undefined ? '' : String(v).trim());
const course_id = s(b.course_id);
const name = s(b.name).replace(/\s+/g, ' ');
const fail = (message) => [{ json: { valid: false, response: { ok: false, error: { code: 'VALIDATION_ERROR', message } } } }];
if (!course_id) return fail('Ders seçilmelidir.');
if (!name || name.length > 100) return fail('Ders adı 1-100 karakter arasında olmalıdır.');
return [{ json: { valid: true, user_id, course_id, name } }];

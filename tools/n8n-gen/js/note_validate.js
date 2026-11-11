// Not ekleme isteğini doğrular ve not belgesini hazırlar.
const crypto = require('crypto');
const b = $('POST /notes/create').first().json.body || {};
const user_id = $('Not ekle: oturum').first().json.user_id;
const s = (v) => (v === null || v === undefined ? '' : String(v).trim());
const course_id = s(b.course_id);
const title = s(b.title).replace(/\s+/g, ' ');
const content = s(b.content).replace(/\r\n/g, '\n');
const source = s(b.source) || 'text';
const fail = (message) => [{ json: { valid: false, response: { ok: false, error: { code: 'VALIDATION_ERROR', message } } } }];

if (!course_id) return fail('Ders seçilmelidir.');
if (!title || title.length > 200) return fail('Not başlığı 1-200 karakter arasında olmalıdır.');
if (content.length < 20 || content.length > 15000) return fail('Not metni 20-15000 karakter arasında olmalıdır.');
if (!['text', 'txt', 'pdf'].includes(source)) return fail("Kaynak 'text', 'txt' veya 'pdf' olmalıdır.");

const note = { id: crypto.randomUUID(), user_id, course_id, title, content, source, created_at: new Date().toISOString() };
return [{ json: { valid: true, note, response: { ok: true, data: { note: { id: note.id, title, created_at: note.created_at } } } } }];

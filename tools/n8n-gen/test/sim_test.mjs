// test-auth.ps1 ve test-chat.ps1 senaryolarını simülatörde çalıştırır (+ ek uç durumlar).
import { api, ollama, db } from './sim.mjs';
let pass = 0, fail = 0;
const t = (name, r, status, check = () => true, desc = '') => {
  let ok = r.status === status && r.json !== null;
  let why = ok ? '' : `beklenen ${status}, gelen ${r.status}`;
  if (ok) { try { ok = !!check(r.json); } catch (e) { ok = false; why = e.message; } if (!ok && !why) why = desc + ' sağlanmadı'; }
  if (ok) { pass++; console.log('GEÇTİ', name, r.status); }
  else { fail++; console.log('KALDI', name, why, '\n      ', r.text); }
  return r.json;
};
const CJK = /[぀-ヿ㐀-鿿가-힯Ѐ-ӿ]/;
const uuid = () => crypto.randomUUID();

console.log('--- test-auth senaryoları');
const email = `test${Date.now()}@ornek.com`;
t('Kayıt (yeni)', api('auth/register', { name: 'Test Öğrenci', email: `  ${email.toUpperCase()} `, password: 'gizli,123' }), 201, (j) => j.data.token.length === 64 && j.data.user.email === email);
t('Kayıt (aynı e-posta)', api('auth/register', { name: 'Test', email, password: 'gizli123' }), 409, (j) => j.error.code === 'EMAIL_TAKEN');
t('Kayıt (geçersiz e-posta)', api('auth/register', { name: 'Test', email: 'yanlis', password: 'gizli123' }), 400);
t('Kayıt (kısa şifre)', api('auth/register', { name: 'Test', email: 'x' + email, password: '123' }), 400);
t('Kayıt (boş gövde)', api('auth/register', undefined), 400);
const login = t('Giriş (doğru, virgüllü)', api('auth/login', { email, password: 'gizli,123' }), 200, (j) => j.data.token && j.data.user.name === 'Test Öğrenci');
t('Giriş (yanlış şifre)', api('auth/login', { email, password: 'yanlis' }), 401, (j) => j.error.code === 'INVALID_CREDENTIALS');
t('Giriş (eksik alan)', api('auth/login', { email }), 401);
t('Giriş (olmayan kullanıcı)', api('auth/login', { email: 'yok@ornek.com', password: 'gizli123' }), 401);
const tok0 = login.data.token;
t('Çıkış', api('auth/logout', {}, tok0), 200);
t('Çıkıştan sonra token geçersiz', api('courses/list', {}, tok0), 401);
console.log('  DB: şifre düz metin değil:', !JSON.stringify(db.users).includes('gizli,123'),
  '| token düz metin değil:', !JSON.stringify(db.sessions).includes(tok0));

console.log('--- test-chat senaryoları');
const tok = api('auth/register', { name: 'Ö', email: 'b' + email, password: 'gizli123' }).json.data.token;
const tok2 = api('auth/register', { name: 'Başka', email: 'c' + email, password: 'gizli123' }).json.data.token;
t('Ders listesi (token yok)', api('courses/list', {}), 401, (j) => j.error.code === 'UNAUTHORIZED');
const c = t('Ders ekle', api('courses/create', { name: '  Mobil   Programlama ' }, tok), 201, (j) => j.data.course.name === 'Mobil Programlama');
const courseId = c.data.course.id;
t('Ders ekle (aynı ad)', api('courses/create', { name: 'Mobil Programlama' }, tok), 409);
t('Ders ekle (boş ad)', api('courses/create', { name: '  ' }, tok), 400);
t('Başka kullanıcı aynı adla ekleyebilir', api('courses/create', { name: 'Mobil Programlama' }, tok2), 201);
t('Ders listesi', api('courses/list', {}, tok), 200, (j) => j.data.courses.length === 1 && j.data.courses[0].note_count === 0 && j.data.courses[0].avg_percent === null);
t('Boş ders listesi', api('courses/list', {}, api('auth/register', { name: 'Y', email: 'y' + email, password: 'gizli123' }).json.data.token), 200, (j) => j.data.courses.length === 0);

t('Soru (token yok)', api('chat/send', { message: 'Merhaba' }), 401);
t('Soru (boş mesaj)', api('chat/send', { message: '  ' }, tok), 400);
t('Soru (olmayan sohbet)', api('chat/send', { message: 'Merhaba', conversation_id: uuid() }, tok), 404);
t('Soru (olmayan ders)', api('chat/send', { message: 'Merhaba', course_id: uuid() }, tok), 404);
t('Soru (başkasının dersi)', api('chat/send', { message: 'Merhaba', course_id: courseId }, tok2), 404);

ollama.requests.length = 0;
const a = t('Genel soru', api('chat/send', { message: 'Flutter nedir? İki cümleyle açıkla.' }, tok), 200, (j) => j.data.reply.content && !CJK.test(j.data.reply.content));
const convId = a.data.conversation_id;
const req1 = ollama.requests[0].body;
console.log('  Ollama isteği: model', req1.model, '| mesaj sayısı', req1.messages.length, '| num_ctx', req1.options.num_ctx);

ollama.requests.length = 0;
ollama.replies.push('Flutter bir UI köprü kitlesi框架', 'İşte örnek: Text("Merhaba")');  // 1. deneme Çince → yeniden dene
const b = t('Devam sorusu (1 tekrar denemeli)', api('chat/send', { message: 'Örnek ver', conversation_id: convId }, tok), 200, (j) => j.data.conversation_id === convId && j.data.reply.content.startsWith('İşte'));
console.log('  Ollama çağrı sayısı:', ollama.requests.length, '| geçmiş dahil mesaj sayısı:', ollama.requests[0].body.messages.length);

// Derse not ekle (02-notes henüz yok; doğrudan veritabanına) → bağlam prompta girmeli
const uidA = db.sessions.find(() => true) && db.users.find((u) => u.email === 'b' + email).id;
db.notes = [{ id: uuid(), user_id: uidA, course_id: courseId, title: 'Widgetlar', content: 'Stateful widget durum tutar.', created_at: new Date() }];
ollama.requests.length = 0;
const m = t('Derse bağlı soru (gemma3:4b)', api('chat/send', { message: 'Stateful nedir?', course_id: courseId, model: 'gemma3:4b' }, tok), 200, (j) => j.data.reply.model === 'gemma3:4b');
console.log('  Prompt ders notlarını içeriyor:', ollama.requests[0].body.messages[0].content.includes('Stateful widget durum tutar.'));

ollama.replies.push('框架', '框架', '框架');
const before = db.messages.length;
t('3 denemede de Çince → 502', api('chat/send', { message: 'x', conversation_id: convId }, tok), 502, (j) => j.error.code === 'AI_BAD_OUTPUT');
console.log('  başarısız denemede mesaj kaydedilmedi:', db.messages.length === before);
ollama.down = true;
t('Ollama kapalı → 503', api('chat/send', { message: 'x' }, tok), 503, (j) => j.error.code === 'AI_UNAVAILABLE' && j.error.detail);
ollama.down = false;

t('Sohbet listesi', api('chat/conversations', {}, tok), 200, (j) => j.data.conversations.length === 2 && j.data.conversations[0].course_name === 'Mobil Programlama');
t('Sohbet listesi (ders filtresi)', api('chat/conversations', { course_id: courseId }, tok), 200, (j) => j.data.conversations.length === 1);
t('Sohbet listesi (başka kullanıcı)', api('chat/conversations', {}, tok2), 200, (j) => j.data.conversations.length === 0);
t('Sohbet geçmişi', api('chat/history', { conversation_id: convId }, tok), 200, (j) => j.data.messages.length === 4 && j.data.messages.map((x) => x.role).join() === 'user,assistant,user,assistant');
t('Sohbet geçmişi (olmayan)', api('chat/history', { conversation_id: uuid() }, tok), 404);
t('Sohbet geçmişi (başkasının)', api('chat/history', { conversation_id: convId }, tok2), 404);
t('Sohbet geçmişi (id yok)', api('chat/history', {}, tok), 404);

console.log(`\nSONUÇ: ${pass} geçti, ${fail} kaldı`);
process.exit(fail ? 1 : 0);

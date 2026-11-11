// Canlı demo senaryosu: not → özet → test → (en az bir yanlış) → öneri, + hata durumları.
import { api, ollama, db } from './sim.mjs';
let pass = 0, fail = 0;
const t = (name, r, status, check = () => true, desc = '') => {
  let ok = r.status === status && r.json !== null; let why = ok ? '' : `beklenen ${status}, gelen ${r.status}`;
  if (ok) { try { ok = !!check(r.json); } catch (e) { ok = false; why = e.message; } if (!ok && !why) why = desc + ' sağlanmadı'; }
  if (ok) { pass++; console.log('GEÇTİ', name, r.status); } else { fail++; console.log('KALDI', name, why, '\n      ', r.text); }
  return r.json;
};
const uuid = () => crypto.randomUUID();
const email = `n${Date.now()}@ornek.com`;
const tok = api('auth/register', { name: 'Not Test', email, password: 'gizli123' }).json.data.token;
const tok2 = api('auth/register', { name: 'Başka', email: 'z' + email, password: 'gizli123' }).json.data.token;
const courseId = api('courses/create', { name: 'Mobil Programlama' }, tok).json.data.course.id;
const NOTE = 'Flutter, Google tarafından geliştirilen açık kaynaklı bir arayüz araç setidir. Dart dilini kullanır. ' +
  'Stateless widget durumu olmayan, stateful widget ise durumu değişebilen widgettir. setState çağrısı arayüzü yeniden çizer.';

console.log('--- notlar');
t('Not ekle (token yok)', api('notes/create', { course_id: courseId, title: 'x', content: NOTE }), 401);
t('Not ekle (kısa metin)', api('notes/create', { course_id: courseId, title: 'x', content: 'kısa' }, tok), 400);
t('Not ekle (ders yok)', api('notes/create', { title: 'x', content: NOTE }, tok), 400);
t('Not ekle (olmayan ders)', api('notes/create', { course_id: uuid(), title: 'x', content: NOTE }, tok), 404);
t('Not ekle (başkasının dersi)', api('notes/create', { course_id: courseId, title: 'x', content: NOTE }, tok2), 404);
const n = t('Not ekle', api('notes/create', { course_id: courseId, title: 'Flutter Giriş', content: NOTE, source: 'txt' }, tok), 201, (j) => j.data.note.id);
const noteId = n.data.note.id;
t('Not listesi', api('notes/list', { course_id: courseId }, tok), 200, (j) => j.data.notes.length === 1 && !j.data.notes[0].has_summary && j.data.notes[0].preview.startsWith('Flutter'));
t('Not listesi (başkasının dersi)', api('notes/list', { course_id: courseId }, tok2), 404);

console.log('--- özet');
ollama.requests.length = 0;
ollama.replies.push('{bozuk json', JSON.stringify({ short: '框架', key_points: ['a', 'b', 'c'], keywords: ['x', 'y', 'z'] }));
t('Özet (2 hatalı denemeden sonra)', api('notes/summarize', { note_id: noteId }, tok), 200, (j) => !j.data.cached && j.data.summary.key_points.length === 3);
console.log('  Ollama çağrısı:', ollama.requests.length, '| format şeması:', !!ollama.requests[0].body.format, '| model:', ollama.requests[0].body.model);
console.log('  not metni prompta girdi:', ollama.requests[0].body.messages[1].content.includes('setState'));
ollama.requests.length = 0;
t('Özet (kayıtlı)', api('notes/summarize', { note_id: noteId }, tok), 200, (j) => j.data.cached === true && j.data.summary.short);
console.log('  kayıtlı özette model çağrılmadı:', ollama.requests.length === 0);
t('Özet (force, gemma3:4b)', api('notes/summarize', { note_id: noteId, force: true, model: 'gemma3:4b' }, tok), 200, (j) => !j.data.cached && j.data.model === 'gemma3:4b');
t('Not listesi (özet var)', api('notes/list', { course_id: courseId }, tok), 200, (j) => j.data.notes[0].has_summary);
t('Özet (olmayan not)', api('notes/summarize', { note_id: uuid() }, tok), 404);
ollama.replies.push('x', 'y', 'z');
t('Özet (3 hatalı deneme → 502)', api('notes/summarize', { note_id: noteId, force: true }, tok), 502, (j) => j.error.code === 'AI_BAD_OUTPUT');
ollama.down = true;
t('Özet (Ollama kapalı → 503)', api('notes/summarize', { note_id: noteId, force: true }, tok), 503);
ollama.down = false;

console.log('--- test oluşturma');
t('Test (az soru)', api('quizzes/generate', { note_id: noteId, question_count: 3 }, tok), 400);
t('Test (yanlış zorluk)', api('quizzes/generate', { note_id: noteId, difficulty: 'süper' }, tok), 400);
t('Test (başkasının notu)', api('quizzes/generate', { note_id: noteId }, tok2), 404);
const bad = (mut) => { const q = Array.from({ length: 5 }, (_, i) => ({ question: `S${i}?`, options: ['A1', 'B1', 'C1', 'D1'], correct_answer: 'B1', explanation: 'e', topic: 'k' })); mut(q); return JSON.stringify({ questions: q }); };
ollama.requests.length = 0;
ollama.replies.push(
  bad((q) => { q[2].correct_answer = 'yok'; }),            // doğru cevap şıklarda yok
  bad((q) => { q[1].options = ['A', 'A', 'B', 'C']; }),    // tekrar eden şık
);
const quiz = t('Test oluştur (2 hatalı denemeden sonra)', api('quizzes/generate', { note_id: noteId }, tok), 200,
  (j) => j.data.questions.length === 5 && j.data.questions.every((q) => q.options.length === 4 && q.topic));
console.log('  Ollama çağrısı:', ollama.requests.length, '| istenen soru sayısı şemada:', ollama.requests[0].body.format.properties.questions.minItems);
const leak = JSON.stringify(quiz.data);
console.log('  istemciye doğru cevap SIZMADI:', !/correct|explanation/.test(leak));
const stored = db.quizzes.find((q) => q.id === quiz.data.quiz_id);
const dist = stored.questions.map((q) => q.correct_index);
console.log('  doğru cevaplar veritabanında:', dist.every((i) => i >= 0 && i <= 3), '| şık sırası karıştı (doğru indeksler):', dist.join(','));
const prefixed = JSON.stringify({ questions: Array.from({ length: 5 }, (_, i) => ({ question: `Harfli ${i}?`, options: ['A) Java', 'B) Dart', 'C) Go', 'D) C#'], correct_answer: 'B) Dart', explanation: 'e', topic: 'k' })) });
ollama.replies.push(prefixed);
t('Test (şıklarda "A)" harfleri temizlenir)', api('quizzes/generate', { note_id: noteId }, tok), 200, (j) => j.data.questions[0].options.includes('Dart'));

console.log('--- değerlendirme (canlı demo: en az bir yanlış)');
const qs = stored.questions;
const answers = qs.map((q, i) => ({ question_id: q.id, selected_index: i === 0 ? (q.correct_index + 1) % 4 : q.correct_index }));
answers[4].selected_index = null; // boş bırakılan
ollama.requests.length = 0;
const res = t('Teslim et', api('quizzes/submit', { quiz_id: quiz.data.quiz_id, answers }, tok), 200,
  (j) => j.data.score === 3 && j.data.total === 5 && j.data.percent === 60 && j.data.results.length === 5 &&
    j.data.recommendation_source === 'ai' && j.data.weak_topics.length >= 1);
console.log('  zayıf konular:', res.data.weak_topics.join(', '), '| öneri promptunda yanlış soru var:',
  ollama.requests[0].body.messages[1].content.includes('Öğrencinin cevabı'));
t('Teslim et (tekrar → 409)', api('quizzes/submit', { quiz_id: quiz.data.quiz_id, answers }, tok), 409, (j) => j.error.code === 'ALREADY_SUBMITTED');
t('Teslim (başkasının testi)', api('quizzes/submit', { quiz_id: quiz.data.quiz_id, answers }, tok2), 404);
t('Teslim (answers dizi değil)', api('quizzes/submit', { quiz_id: quiz.data.quiz_id, answers: 'x' }, tok), 400);

const q2 = api('quizzes/generate', { note_id: noteId }, tok).json.data;
ollama.down = true;
t('Teslim (Ollama kapalı → yedek öneri)', api('quizzes/submit', { quiz_id: q2.quiz_id, answers: [] }, tok), 200,
  (j) => j.data.recommendation_source === 'fallback' && j.data.score === 0 && j.data.recommendation.includes('eksiğin'));
ollama.down = false;
const q3 = api('quizzes/generate', { note_id: noteId }, tok).json.data;
const allRight = db.quizzes.find((q) => q.id === q3.quiz_id).questions.map((q) => ({ question_id: q.id, selected_index: q.correct_index }));
ollama.replies.push('框架', 'kısa', '框架');
t('Teslim (tam puan, 3 hatalı öneri → yedek)', api('quizzes/submit', { quiz_id: q3.quiz_id, answers: allRight }, tok), 200,
  (j) => j.data.percent === 100 && j.data.recommendation_source === 'fallback' && j.data.recommendation.startsWith('Tebrikler'));

console.log('--- ders istatistiği');
t('Ders listesi (not + ortalama)', api('courses/list', {}, tok), 200, (j) => {
  const c = j.data.courses[0]; console.log('  ', JSON.stringify(c)); return c.note_count === 1 && c.attempt_count === 3 && c.avg_percent === Math.round((60 + 0 + 100) / 3);
});
t('Derse bağlı sohbet özeti kullanır', api('chat/send', { message: 'Stateful nedir?', course_id: courseId }, tok), 200);
console.log('  sohbet promptunda özet maddeleri:', ollama.requests.at(-1).body.messages[0].content.includes('- '));

console.log(`\nSONUÇ: ${pass} geçti, ${fail} kaldı`);
process.exit(fail ? 1 : 0);

// Yeni özellikler: ders düzenleme/silme, otomatik model, geçmişe dönük analiz, istatistik, hap bilgi.
import { api, ollama, db } from './sim.mjs';
let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log('GEÇTİ', m); } else { fail++; console.log('KALDI', m); } };
const st = (r, code, m, extra = () => true) => { let good = r.status === code; try { good = good && !!extra(r.json); } catch { good = false; } ok(good, `${m} (${r.status})`); if (!good) console.log('      ', r.text); return r.json; };
const uniq = Date.now();
const reg = (p) => api('auth/register', { name: p, email: `${p}${uniq}@ornek.com`, password: 'gizli123' }).json.data.token;
const A = reg('a'), B = reg('b');
const course = (t, n) => api('courses/create', { name: n }, t).json.data.course.id;
const lastBody = () => ollama.requests.at(-1).body;

console.log('--- ders adı değiştirme');
const c1 = course(A, 'Matematk'), c2 = course(A, 'Fizik');
st(api('courses/update', { course_id: c1, name: '  Matematik  ' }, A), 200, 'ad düzeltildi', (j) => j.data.course.name === 'Matematik');
ok(db.courses.find((c) => c.id === c1).name === 'Matematik', 'veritabanında güncellendi');
st(api('courses/update', { course_id: c1, name: 'Fizik' }, A), 409, 'başka dersin adı → 409');
st(api('courses/update', { course_id: c1, name: 'Matematik' }, A), 200, 'kendi adını tekrar kaydetmek serbest');
st(api('courses/update', { course_id: c1, name: '  ' }, A), 400, 'boş ad → 400');
st(api('courses/update', { course_id: c1, name: 'Hack' }, B), 404, 'başkasının dersi → 404');
st(api('courses/update', { course_id: c1, name: 'x' }), 401, 'token yok → 401');

console.log('--- otomatik model seçimi');
const send = (body, t = A) => api('chat/send', body, t).json.data.reply;
let r = send({ message: 'Flutter nedir?' });
ok(r.model === 'gemma3:4b' && r.model_reason === 'Türkçe anlatım', `genel soru → ${r.model} (${r.model_reason})`);
r = send({ message: '2x + 3 = 7 denklemini çöz' });
ok(r.model === 'qwen2.5:7b' && r.model_reason === 'matematiksel ifade', `denklem → ${r.model} (${r.model_reason})`);
r = send({ message: 'Zincir kuralı nedir?', course_id: c1 });
ok(r.model === 'qwen2.5:7b', `"Matematik" dersinde soru → ${r.model} (${r.model_reason})`);
ok(ollama.requests.at(-1).body.messages[0].content.includes('akademik anlamıyla'), 'sohbet promptunda akademik yorum kuralı var');
r = send({ message: 'Python ile döngü nasıl yazılır?' });
ok(r.model === 'qwen2.5:7b', `kod sorusu → ${r.model} (${r.model_reason})`);
r = send({ message: '2x + 3 = 7', model: 'gemma3:4b' });
ok(r.model === 'gemma3:4b' && r.model_reason === 'elle seçildi', 'elle seçilen model her zaman öncelikli');

const MATH = 'Türev anlık değişim hızıdır. f(x) = x^3 ise f\'(x) = 3x^2 olur. (f + g)\' = f\' + g\'. Zincir kuralı: f(g(x))\' = f\'(g(x))*g\'(x). Fonksiyon türevi sıfır olan noktalar kritik noktadır.';
const FLUT = 'Flutter Google tarafından geliştirilen arayüz araç setidir. Dart dilini kullanır. Stateful widget durum tutar, stateless widget tutmaz.';
const note = (cid, title, content) => api('notes/create', { course_id: cid, title, content }, A).json.data.note.id;
const nm = note(c1, 'Türev', MATH), nf = note(c2, 'Flutter', FLUT);
api('notes/summarize', { note_id: nm }, A);
ok(lastBody().model === 'gemma3:4b', `özet her zaman Türkçe anlatım modeli → ${lastBody().model}`);
api('quizzes/generate', { note_id: nm }, A);
ok(lastBody().model === 'qwen2.5:7b', `formül yoğun nottan test → ${lastBody().model}`);
api('quizzes/generate', { note_id: nf }, A);
ok(lastBody().model === 'gemma3:4b', `sözel nottan test → ${lastBody().model}`);

console.log('--- hap bilgi kartları');
const sm = api('notes/summarize', { note_id: nm }, A).json.data;
ok(sm.summary.flashcards?.length >= 4, `özetle birlikte ${sm.summary.flashcards?.length} hap bilgi kartı (kayıtlı özetten de dönüyor)`);
ollama.replies.push(JSON.stringify({ short: 'Özet', key_points: ['a.', 'b.', 'c.'], keywords: ['x', 'y', 'z'] }));
ollama.requests.length = 0;
api('notes/summarize', { note_id: nf, force: true }, A);
ok(ollama.requests.length === 2, 'kartsız özet reddedildi ve yeniden denendi');

console.log('--- geçmişe dönük hata analizi');
const quizOf = (nid) => api('quizzes/generate', { note_id: nid }, A).json.data;
const wrongAll = (q) => db.quizzes.find((x) => x.id === q.quiz_id).questions.map((x) => ({ question_id: x.id, selected_index: (x.correct_index + 1) % 4 }));
const submit = (q, ans) => { ollama.requests.length = 0; const d = api('quizzes/submit', { quiz_id: q.quiz_id, answers: ans }, A).json.data; return d; };
const q1 = quizOf(nf); let d1 = submit(q1, wrongAll(q1));
ok(d1.recurring_topics.length === 0, 'ilk testte tekrarlayan hata yok');
const q2 = quizOf(nf); let d2 = submit(q2, wrongAll(q2));
ok(d2.recurring_topics.length >= 1 && d2.recurring_topics.every((x) => x.previous === 1), `ikinci testte tekrarlayan: ${JSON.stringify(d2.recurring_topics)}`);
const reco = ollama.requests.find((q) => q.body.messages[0].content.includes('kişisel çalışma önerisi'));
ok(reco && reco.body.messages[1].content.includes('Geçmiş:') && reco.body.messages[0].content.includes('farklı bir çalışma yöntemi'),
  'öneri promptu geçmişi ve ek kuralı içeriyor');
const q3 = quizOf(nf); const d3 = submit(q3, wrongAll(q3));
ok(d3.recurring_topics[0].previous === 2, 'üçüncü testte "önceki 2 testte" sayılıyor');
// Başka dersteki hatalar karışmamalı
const qm = quizOf(nm); const dm = submit(qm, wrongAll(qm));
ok(dm.recurring_topics.length === 0, 'başka dersin geçmişi karışmıyor');
ollama.down = true;
const q4 = quizOf ? null : null; ollama.down = false;
const q5 = quizOf(nf); ollama.down = true; const d5 = submit(q5, wrongAll(q5)); ollama.down = false;
ok(d5.recommendation_source === 'fallback' && d5.recommendation.includes('önceki testlerde de hata yaptın'), 'yedek öneri de geçmişi anıyor');

console.log('--- istatistik');
const s = st(api('stats/overview', {}, A), 200, 'istatistik özeti').data;
ok(s.overall.attempt_count === 5 && s.overall.avg_percent === 0, `genel: ${JSON.stringify(s.overall)}`);
ok(s.recurring.length >= 1 && s.recurring[0].wrong_attempts === 4, `tekrarlayan zayıflık: ${s.recurring.map((t) => `${t.topic}×${t.wrong_attempts}`).join(', ')}`);
ok(s.courses.find((c) => c.name === 'Fizik').attempt_count === 4, 'ders bazlı deneme sayısı');
ok(s.recent.length === 5 && s.topics.every((t) => t.course_name), 'son testler ve konu-ders eşleşmesi');
st(api('stats/overview', {}, B), 200, 'başka kullanıcı boş istatistik', (j) => j.data.overall.attempt_count === 0 && j.data.recurring.length === 0);
st(api('stats/overview', {}), 401, 'token yok → 401');

console.log('--- ders silme');
const before = { notes: db.notes.length, quizzes: db.quizzes.length };
const convC2 = db.conversations.filter((c) => c.course_id === c2).length;
send({ message: 'Widget nedir?', course_id: c2 });
st(api('courses/delete', { course_id: c2 }, B), 404, 'başkası silemez');
st(api('courses/delete', { course_id: c2 }, A), 200, 'ders silindi', (j) => j.data.deleted);
ok(!db.courses.some((c) => c.id === c2), 'ders yok');
ok(!db.notes.some((n) => n.course_id === c2) && !db.quizzes.some((q) => q.course_id === c2) && !db.quiz_attempts.some((a) => a.course_id === c2), 'notları, testleri, denemeleri silindi');
const convIds = new Set(db.conversations.map((c) => c.id));
ok(!db.conversations.some((c) => c.course_id === c2) && db.messages.every((m) => convIds.has(m.conversation_id)), 'sohbetleri ve mesajları silindi');
ok(db.courses.some((c) => c.id === c1) && db.notes.some((n) => n.course_id === c1) && db.quiz_attempts.some((a) => a.course_id === c1), 'diğer dersin verileri duruyor');
ok(db.messages.some((m) => !db.conversations.find((c) => c.id === m.conversation_id)?.course_id), 'genel sohbet mesajları duruyor');
st(api('courses/delete', { course_id: c2 }, A), 404, 'ikinci silme → 404');
st(api('courses/list', {}, A), 200, 'ders listesi tutarlı', (j) => j.data.courses.length === 1);

console.log('--- sohbette yedek model ve yabancı karakter temizliği');
ollama.requests.length = 0;
ollama.replies.push('', '');  // gemma iki kez boş yanıt verir
r = send({ message: 'Etkili ders çalışma yöntemleri nelerdir?' });
const used = ollama.requests.map((q) => q.body.model);
ok(used.join(',') === 'gemma3:4b,gemma3:4b,qwen2.5:7b', `1-2. deneme birincil, 3. deneme yedek model (${used})`);
ok(r.model === 'qwen2.5:7b' && r.model_reason === 'yedek model', `yanıtta yedek model nedeni (${r.model_reason})`);
ollama.requests.length = 0;
ollama.replies.push('Flutter, Google tarafından geliştirilen bir arayüz 框架 araç setidir ve Dart dilini kullanır; tek kodla birçok platform hedeflenir.');
r = send({ message: 'Flutter nedir?' });
ok(ollama.requests.length === 1 && !/[一-鿿]/.test(r.content) && r.content.includes('arayüz araç setidir'), 'uzun yanıtta tek yabancı kelime silindi, yeniden deneme yok');
ok(r.model_reason === 'Türkçe anlatım', 'birincil model nedeni korunur');

ollama.requests.length = 0;
ollama.replies.push('框架框架框架框架框架框架框架框架');  // birincil model Çinceye kaydı
r = send({ message: 'Flutter nedir?' });
const fm = ollama.requests.map((q) => q.body.model);
ok(fm.join(',') === 'gemma3:4b,qwen2.5:7b' && r.model_reason === 'yedek model', `Türkçe dışı yanıttan sonra 2. deneme hemen yedek modelle (${fm})`);

console.log('--- sohbette LaTeX düz metne çevrilir, dil hatırlatması');
ollama.requests.length = 0;
ollama.replies.push(String.raw`Türevin limit tanımı şöyledir: \[ f'(x) = \lim_{h \to 0} \frac{f(x+h) - f(x)}{h} \] Zincir kuralı: \frac{d}{dx} [f(g(x))] = f'(g(x)) \cdot g'(x) ve \text{bu} kuraldır.`);
r = send({ message: 'Türevin limit tanımı nedir?' });
ok(!/\\/.test(r.content) && r.content.includes("lim (h → 0) (f(x+h) - f(x))/(h)") && r.content.includes("f'(g(x)) · g'(x)"), `LaTeX düz metne çevrildi: ${r.content.slice(0, 90)}…`);
const um = ollama.requests.at(-1).body.messages.at(-1).content;
ok(um.startsWith('Türevin limit tanımı nedir?') && um.includes('yalnızca Türkçe'), 'son kullanıcı mesajına dil hatırlatması eklendi');
ok(db.messages.some((m) => m.role === 'user' && m.content === 'Türevin limit tanımı nedir?'), 'veritabanına kullanıcının metni olduğu gibi kaydedildi');

console.log('--- test üretimi: soru bazında eleme ve yedek model');
const TARIH = 'İstanbul 1453 yılında Fatih Sultan Mehmet tarafından fethedildi. Bu olayla Orta Çağ sona erdi ve Yeni Çağ başladı. Osmanlı Devleti 1299 yılında kuruldu. Malazgirt Savaşı 1071 yılında yapıldı.';
const nt = note(course(A, 'Tarih'), 'Tarih notlar', TARIH);
const good = (k) => ({ question: `Tarih sorusu ${k}: hangi yıl doğrudur?`, options: ['1071', '1299', '1453', '1923'],
  correct_answer: '1453', explanation: 'Notta belirtilmiştir.', topic: 'Fetih' });
const bad1 = { question: 'İstanbul 1453 yılında kim tarafından fethedildi, Fatih Sultan Mehmet mi?',
  options: ['Fatih Sultan Mehmet', 'Yavuz Sultan Selim', 'Orhan Gazi', 'Osman Bey'], correct_answer: 'Fatih Sultan Mehmet',
  explanation: 'Notta yazar.', topic: 'Fetih' };  // cevap soru metninde
const bad2 = { ...good(9), correct_answer: '1500' };  // doğru cevap seçeneklerde yok
ollama.requests.length = 0;
ollama.replies.push(JSON.stringify({ questions: [good(1), bad1, good(2), bad2, good(3), good(4), good(5)] }));
let qz = api('quizzes/generate', { note_id: nt, question_count: 5 }, A);
ok(qz.status === 201 || qz.status === 200, `7 sorudan 2'si kurala uymasa da test oluştu (${qz.status})`);
ok(qz.json?.data?.questions?.length === 5 && ollama.requests.length === 1, 'kalan 5 geçerli soru alındı, yeniden deneme yok');
ok(lastBody().format.properties.questions.minItems === 7, 'modelden 2 yedek soru istendi (5+2)');
ollama.requests.length = 0;
ollama.replies.push(JSON.stringify({ questions: [bad1] }), JSON.stringify({ questions: [bad1] }));
qz = api('quizzes/generate', { note_id: nt, question_count: 5 }, A);
const qmods = ollama.requests.map((q) => q.body.model);
ok(qz.json?.ok && qmods.join(",") === "gemma3:4b,gemma3:4b,qwen2.5:7b", `3. deneme yedek modelle (${qmods})`);
ollama.replies.push('x', 'x', 'x');
qz = api('quizzes/generate', { note_id: nt, question_count: 5 }, A);
ok(qz.status === 502 && /geçerli soru|JSON/.test(qz.json.error.detail), `3 deneme de bozuk → 502, nedeni detail'de (${qz.json?.error?.detail})`);

console.log(`\nSONUÇ: ${pass} geçti, ${fail} kaldı`);
process.exit(fail ? 1 : 0);

// PDF yükleme: /notes/extract-pdf (çok parçalı form → Extract From File → metin temizleme)
import { api, db } from './sim.mjs';
let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log('GEÇTİ', m); } else { fail++; console.log('KALDI', m); } };
const st = (r, code, m, extra = () => true) => { let good = r.status === code; try { good = good && !!extra(r.json); } catch { good = false; } ok(good, `${m} (${r.status})`); if (!good) console.log('      ', r.text); return r.json; };
const uniq = Date.now();
const A = api('auth/register', { name: 'p', email: `p${uniq}@ornek.com`, password: 'gizli123' }).json.data.token;
const file = (content, fileName = 'Türev Notları.pdf', mimeType = 'application/pdf') =>
  ({ file: { data: Buffer.from(content, 'utf8').toString('base64'), fileName, mimeType } });
const PDF = '%PDF %%PAGES=3\nTürev, bir fonksiyonun anlık değişim hızını gös-\nterir.   Zincir   kuralı\n\n\n\nbileşke fonksiyonlar içindir.\r\n';

let j = st(api('notes/extract-pdf', {}, A, file(PDF)), 200, 'geçerli PDF → metin');
ok(j?.data?.text === 'Türev, bir fonksiyonun anlık değişim hızını gösterir. Zincir kuralı\n\nbileşke fonksiyonlar içindir.', 'satır sonu tiresi birleşti, boşluklar temizlendi');
ok(j?.data?.pages === 3 && j?.data?.title === 'Türev Notları', 'sayfa sayısı ve dosya adından başlık');
ok(j?.data?.characters === j?.data?.text.length, 'karakter sayısı');
j = api('notes/extract-pdf', {}, A, file('%PDF %%PAGES=1\nGeometrik olarak türev,\nteğet doğrunun eğimidir.\nf(x) gösterimi kullanılır.')).json;
ok(j?.data?.text === 'Geometrik olarak türev, teğet doğrunun eğimidir.\nf(x) gösterimi kullanılır.', 'paragraf içi satır kırılımları birleşti, cümle sonu korundu');
// n8n, alan adını sürüme göre farklı adlandırabilir: ilk dosya alınır
j = st(api('notes/extract-pdf', {}, A, { data0: file(PDF).file }), 200, 'farklı alan adı da kabul');
st(api('notes/extract-pdf', {}, A), 400, 'dosya yok → 400', (x) => x.error.code === 'VALIDATION_ERROR');
st(api('notes/extract-pdf', {}, A, file('düz metin', 'not.txt', 'text/plain')), 400, 'PDF olmayan dosya → 400');
st(api('notes/extract-pdf', {}, A, file('bozuk içerik', 'bozuk.pdf')), 422, 'bozuk PDF → 422 PDF_UNREADABLE', (x) => x.error.code === 'PDF_UNREADABLE');
st(api('notes/extract-pdf', {}, A, file('%PDF %%PAGES=2\n  \n ')), 422, 'taranmış (metinsiz) PDF → 422 PDF_NO_TEXT', (x) => x.error.code === 'PDF_NO_TEXT');
st(api('notes/extract-pdf', {}, undefined, file(PDF)), 401, 'token yok → 401');
st(api('notes/extract-pdf', {}, 'sahte', file(PDF)), 401, 'geçersiz token → 401');

console.log('--- not silme (ders kalır)');
const B = api('auth/register', { name: 'b', email: `b${uniq}@ornek.com`, password: 'gizli123' }).json.data.token;
const cid = api('courses/create', { name: 'Tarih' }, A).json.data.course.id;
const TXT = 'Osmanlı Devleti 1299 yılında kuruldu. İstanbul 1453 yılında fethedildi ve Yeni Çağ başladı.';
const n1 = api('notes/create', { course_id: cid, title: 'Not 1', content: TXT }, A).json.data.note.id;
const n2 = api('notes/create', { course_id: cid, title: 'Not 2', content: TXT }, A).json.data.note.id;
const quiz = (n) => api('quizzes/generate', { note_id: n }, A).json.data;
const solve = (q) => { const st = db.quizzes.find((x) => x.id === q.quiz_id);
  api('quizzes/submit', { quiz_id: q.quiz_id, answers: st.questions.map((x) => ({ question_id: x.id, selected_index: x.correct_index })) }, A); };
const q1 = quiz(n1), q1b = quiz(n1), q2 = quiz(n2);
solve(q1); solve(q2);
st(api('notes/delete', { note_id: n1 }, B), 404, 'başkasının notu → 404');
st(api('notes/delete', { note_id: n1 }), 401, 'token yok → 401');
st(api('notes/delete', { note_id: 'yok' }, A), 404, 'olmayan not → 404');
st(api('notes/delete', { note_id: n1 }, A), 200, 'not silindi', (x) => x.data.deleted && x.data.deleted_quizzes === 2);
ok(!db.notes.some((n) => n.id === n1) && db.notes.some((n) => n.id === n2), 'yalnızca o not silindi');
ok(!db.quizzes.some((q) => q.note_id === n1) && db.quizzes.some((q) => q.id === q2.quiz_id), 'notun testleri silindi, diğer notunki kaldı');
ok(!db.quiz_attempts.some((a) => a.quiz_id === q1.quiz_id) && db.quiz_attempts.some((a) => a.quiz_id === q2.quiz_id), 'notun test sonuçları silindi, diğerininki kaldı');
ok(db.courses.some((c) => c.id === cid), 'ders duruyor');
const list = api('notes/list', { course_id: cid }, A).json.data.notes;
ok(list.length === 1 && list[0].id === n2, 'not listesi güncel');
st(api('notes/delete', { note_id: n1 }, A), 404, 'ikinci silme → 404');

console.log(`\nSONUÇ: ${pass} geçti, ${fail} kaldı`);
process.exit(fail ? 1 : 0);

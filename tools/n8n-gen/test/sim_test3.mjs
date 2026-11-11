// Cila turu senaryoları: öneri kuralları, cevabı içinde veren soru, dengeli doğru cevap dağılımı.
import { api, ollama, db } from './sim.mjs';
let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log('GEÇTİ', m); } else { fail++; console.log('KALDI', m); } };
const tok = api('auth/register', { name: 'C', email: `c${Date.now()}@ornek.com`, password: 'gizli123' }).json.data.token;
const cid = api('courses/create', { name: 'Ders' }, tok).json.data.course.id;
const nid = api('notes/create', { course_id: cid, title: 'Not', content: 'Flutter Dart dilini kullanır. Stateful widget durum tutar.' }, tok).json.data.note.id;
const quiz = () => api('quizzes/generate', { note_id: nid }, tok).json.data;
const stored = (q) => db.quizzes.find((x) => x.id === q.quiz_id);
const wrongAll = (q) => stored(q).questions.map((x) => ({ question_id: x.id, selected_index: (x.correct_index + 1) % 4 }));

// 1) Dengeli dağılım: 20 test x 5 soru
const counts = [0, 0, 0, 0];
for (let i = 0; i < 20; i++) {
  const s = stored(quiz());
  const per = [0, 0, 0, 0]; s.questions.forEach((q) => { counts[q.correct_index]++; per[q.correct_index]++; });
  if (Math.max(...per) > 2) { ok(false, `test içinde dengesiz konum: ${per}`); }
}
console.log('  doğru cevap konumları (100 soru):', counts.join(' / '));
ok(counts.every((c) => c >= 20 && c <= 30), 'toplam dağılım dengeli (her konum 20-30), test içinde hiçbir konum 2\'den fazla değil');
const sq = stored(quiz()).questions[0];
ok(sq.options[sq.correct_index] === 'Dart', 'doğru cevap metni kaybolmadı');

// 2) Cevabı içinde veren soru reddedilir
const bad = JSON.stringify({ questions: Array.from({ length: 5 }, (_, i) => ({ question: i === 0 ? 'Widget nedir, Widget mı?' : `Soru ${i}?`, options: ['Widget', 'B1', 'C1', 'D1'], correct_answer: 'Widget', explanation: 'e', topic: 'k' })) });
ollama.requests.length = 0; ollama.replies.push(bad);
quiz();
ok(ollama.requests.length === 2, 'cevabı içinde veren soru → yeniden deneme');

// 3) Öneri kuralları
const runReco = (replies, answers) => { const q = quiz(); ollama.replies.push(...replies); return api('quizzes/submit', { quiz_id: q.quiz_id, answers: answers(q) }, tok).json.data; };
let r = runReco(['Merhaba! Widget türleri konusunu çalış, notlarını oku ve açıklamaları incele.'], wrongAll);
ok(r.recommendation_source === 'ai' && !r.recommendation.startsWith('Merhaba'), 'selamlamalı öneri reddedildi, ikinci deneme kullanıldı');
r = runReco(['Tebrikler! Widget türleri ve Dart dili konularını çalış, notlarını tekrar oku.'], wrongAll);
ok(!/tebrik/i.test(r.recommendation), 'düşük puanda "Tebrikler" reddedildi');
r = runReco(['Sadece genel olarak biraz daha çalışman gerekiyor, notlarını tekrar okumalısın.', 'x', 'y'], wrongAll);
ok(r.recommendation_source === 'fallback' && r.recommendation.includes('Widget türleri'), 'konu anmayan öneri 3 kez reddedildi → yedek öneri konuları anıyor');
ok(/anılmadı|kısa/.test(r.recommendation_issue || ''), 'yedek önerinin nedeni yanıtta: ' + r.recommendation_issue);
ollama.requests.length = 0;
r = runReco(['Widget türleri konusunu tekrar et ve notlarındaki örnekleri yeniden incele.'], wrongAll);
ok(ollama.requests.filter((q) => q.body.messages[0].content.includes('kişisel çalışma önerisi')).length === 2, '2 zayıf konu varken yalnızca 1\'ini anan öneri reddedildi (ikisi de gerekli)');
const long = Array.from({ length: 10 }, () => 'Widget türleri ve Dart dili konusunu çalış.').join(' ');
r = runReco([long], wrongAll);
ok(r.recommendation !== long, '10 cümlelik öneri reddedildi');
r = runReco(["Widget'ların türlerini ve Dart'ın temellerini tekrar etmelisin; her biri için birer örnek yaz."], wrongAll);
ok(r.recommendation_source === 'ai', 'ekli kelimeler ("Widget\'ların", "Dart\'ın") konu anılmış sayılır');
const allRight = (q) => stored(q).questions.map((x) => ({ question_id: x.id, selected_index: x.correct_index }));
r = runReco(['Tebrikler, tüm soruları doğru yanıtladın! Bir sonraki adımda zor seviyede test dene.'], allRight);
ok(r.percent === 100 && r.recommendation_source === 'ai', 'tam puanda tebrik serbest');

console.log(`\nSONUÇ: ${pass} geçti, ${fail} kaldı`);
process.exit(fail ? 1 : 0);

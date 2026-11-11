// Model çıktısını case dokümanındaki şemaya göre doğrular, correct_answer'ı correct_index'e çevirir
// ve şıkları karıştırır (modeller doğru cevabı hep aynı sıraya koyma eğilimindedir).
const crypto = require('crypto');
const r = $input.first().json;
const req = $('Test: istek').first().json;
const raw = (r.message && typeof r.message.content === 'string') ? r.message.content : '';
const FOREIGN = /[぀-ヿ㐀-䶿一-鿿豈-﫿가-힯Ѐ-ӿ]/;
const clean = (v) => String(v ?? '').trim();
const noLetter = (v) => clean(v).replace(/^[A-Da-d][).:-]\s+/, '');
const tr = (v) => v.toLocaleLowerCase('tr');

const check = () => {
  let j;
  try { j = JSON.parse(raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '')); }
  catch (e) { return { problem: 'geçersiz JSON' }; }
  const qs = j && Array.isArray(j.questions) ? j.questions : null;
  if (!qs) return { problem: '"questions" dizisi yok' };
  // Her soru tek tek denetlenir; kurala uymayan soru elenir (model yedek sorular üretir).
  // İstenen sayıda geçerli soru kalırsa test kabul edilir.
  const out = [];
  const rejected = [];
  const seen = new Set();
  for (const [i, q] of qs.entries()) {
    if (out.length >= req.count) break;
    const no = i + 1;
    const question = clean(q && q.question);
    const options = Array.isArray(q && q.options) ? q.options.map(noLetter) : [];
    const answer = noLetter(q && q.correct_answer);
    const explanation = clean(q && q.explanation);
    const topic = clean(q && q.topic).slice(0, 100);
    const why = (() => {
      if (!question) return 'boş soru';
      if (options.length !== 4 || options.some((o) => !o)) return '4 dolu seçenek yok';
      if (new Set(options.map(tr)).size !== 4) return 'tekrar eden seçenek';
      if (!explanation) return 'açıklama yok';
      if (!topic) return 'konu yok';
      if (seen.has(tr(question))) return 'tekrar eden soru';
      if (FOREIGN.test(question + options.join('') + explanation + topic)) return 'Türkçe dışı karakter';
      return null;
    })();
    let ci = options.indexOf(answer);
    if (ci < 0) ci = options.map(tr).indexOf(tr(answer));
    const problem = why || (ci < 0 ? 'doğru cevap seçeneklerde yok'
      : (options[ci].length >= 4 && tr(question).includes(tr(options[ci])) ? 'cevap soru metninde' : null));
    if (problem) { rejected.push(`${no}. soru: ${problem}`); continue; }
    seen.add(tr(question));
    out.push({ question, options, correct_index: ci, explanation, topic });
  }
  if (out.length < req.count) {
    return { problem: `${out.length} geçerli soru (${req.count} gerekli); elenen: ${rejected.join('; ') || 'yok'}` };
  }

  // Doğru cevap konumlarını DENGELİ dağıt: her 4 soruda A/B/C/D birer kez (sırası rastgele).
  // Böylece "doğru cevap hep A" gibi bir örüntü oluşamaz; yanlış şıklar da karıştırılır.
  const shuffle = (a) => { for (let k = a.length - 1; k > 0; k--) { const m = crypto.randomInt(k + 1); [a[k], a[m]] = [a[m], a[k]]; } return a; };
  let slots = [];
  while (slots.length < out.length) slots.push(...shuffle([0, 1, 2, 3]));
  slots = shuffle(slots.slice(0, out.length));
  out.forEach((q, i) => {
    const correct = q.options[q.correct_index];
    const others = shuffle(q.options.filter((_, k) => k !== q.correct_index));
    others.splice(slots[i], 0, correct);
    q.options = others;
    q.correct_index = slots[i];
  });
  return { questions: out };
};

const res = check();
return [{
  json: {
    valid: !res.problem, problem: res.problem || null, attempt: $runIndex + 1,
    questions: res.questions || null, model: r.model || null,
  },
}];

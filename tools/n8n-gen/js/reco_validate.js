// Öneri metnini doğrular ($runIndex: deneme sırası). 3 denemede geçemezse yedek öneri kullanılır.
const r = $input.first().json;
const s = $('Teslim: puanla').first().json;
const content = (r.message && typeof r.message.content === 'string') ? r.message.content.trim() : '';
const FOREIGN = /[぀-ヿ㐀-䶿一-鿿豈-﫿가-힯Ѐ-ӿ]/;
const tr = (v) => String(v).toLocaleLowerCase('tr');
const text = tr(content);
const sentences = content.split(/(?<=[.!?])\s+/).filter((x) => x.trim()).length;

// Konu anıldı mı? Model ekleri değiştirebilir ("widget'ların"), bu yüzden kelime köklerine bakılır.
const mentioned = (topic) => {
  const words = tr(topic).replace(/['’]\S*/g, '').split(/\s+/).filter((w) => w.length >= 4);
  return !words.length || words.some((w) => text.includes(w.slice(0, Math.max(4, w.length - 2))));
};
// En az 2 zayıf konu (azsa hepsi) adıyla anılmalı
const topics = s.weak_topics.slice(0, 3);
const missing = topics.filter((t) => !mentioned(t));
const needed = Math.min(2, topics.length);

let problem = null;
if (content.length < 40) problem = 'öneri çok kısa';
else if (FOREIGN.test(content)) problem = 'Türkçe dışı karakter';
else if (/^(merhaba|selam|sevgili)/i.test(content)) problem = 'selamlamayla başlıyor';
else if (s.attempt.percent < 80 && /tebrik/i.test(content)) problem = 'düşük puanda tebrik';
else if (content.length > 1200 || sentences > 8) problem = `öneri çok uzun (${sentences} cümle, ${content.length} karakter)`;
else if (topics.length - missing.length < needed) problem = `zayıf konular anılmadı: ${missing.join(', ')}`;

return [{ json: { valid: problem === null, problem, attempt: $runIndex + 1, content, model: r.model || null } }];

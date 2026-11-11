// Model özetini doğrular. Kurallardan biri bozulursa yeniden denenir ($runIndex: deneme sırası).
const r = $input.first().json;
const raw = (r.message && typeof r.message.content === 'string') ? r.message.content : '';
const FOREIGN = /[぀-ヿ㐀-䶿一-鿿豈-﫿가-힯Ѐ-ӿ]/;
const clean = (v) => String(v ?? '').trim();
const list = (a, max) => (Array.isArray(a) ? [...new Set(a.map(clean).filter(Boolean))].slice(0, max) : []);

let problem = null;
let summary = null;
try {
  const j = JSON.parse(raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, ''));
  // Hap bilgi kartları: boş veya aşırı uzun kartlar atılır, en fazla 8 kart
  const cards = Array.isArray(j.flashcards)
    ? j.flashcards.map((c) => ({ front: clean(c && c.front), back: clean(c && c.back) }))
        .filter((c) => c.front && c.back && c.front.length <= 120 && c.back.length <= 300).slice(0, 8)
    : [];
  summary = { short: clean(j.short), key_points: list(j.key_points, 7), keywords: list(j.keywords, 8), flashcards: cards };
  if (!summary.short) problem = 'özet boş';
  else if (summary.key_points.length < 3) problem = 'en az 3 ana madde gerekli';
  else if (summary.keywords.length < 3) problem = 'en az 3 anahtar kavram gerekli';
  else if (summary.flashcards.length < 4) problem = 'en az 4 hap bilgi kartı gerekli';
  else if (FOREIGN.test(JSON.stringify(summary))) problem = 'Türkçe dışı karakter';
} catch (e) {
  problem = 'geçersiz JSON';
}
return [{ json: { valid: problem === null, problem, attempt: $runIndex + 1, summary, model: r.model || null } }];

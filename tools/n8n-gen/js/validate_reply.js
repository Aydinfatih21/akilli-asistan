// Ollama yanıtını doğrular. $runIndex: bu düğümün bu çalıştırmadaki kaçıncı turu (0'dan başlar).
const r = $input.first().json;
let content = (r.message && typeof r.message.content === 'string') ? r.message.content.trim() : '';
// Çince/Japonca/Korece ve Kiril karakterleri
const foreign = /[぀-ヿ㐀-䶿一-鿿豈-﫿가-힯Ѐ-ӿ]/;
const foreignAll = /[぀-ヿ㐀-䶿一-鿿豈-﫿가-힯Ѐ-ӿ]/g;
// Uzun bir yanıtta yalnızca birkaç yabancı karakter kaçmışsa (ör. tek bir Çince kelime) yanıt
// çöpe atılmaz; o karakterler silinir. Yoğunsa yanıt reddedilir ve yeniden üretilir.
let cleaned = 0;
const n = (content.match(foreignAll) || []).length;
if (n > 0 && n <= 6 && content.length >= 80) {
  content = content.replace(foreignAll, '').replace(/[ \t]{2,}/g, ' ').trim();
  cleaned = n;
}

let problem = null;
if (!content) problem = 'boş yanıt';
else if (foreign.test(content)) problem = 'Türkçe dışı karakter';

return [{
  json: { valid: problem === null, problem, attempt: $runIndex + 1, content, model: r.model || null, cleaned },
}];

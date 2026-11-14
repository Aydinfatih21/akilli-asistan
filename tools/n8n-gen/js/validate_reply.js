// Ollama yanıtını doğrular. $runIndex: bu düğümün bu çalıştırmadaki kaçıncı turu (0'dan başlar).
const r = $input.first().json;
let content = (r.message && typeof r.message.content === 'string') ? r.message.content.trim() : '';
// Çince/Japonca/Korece ve Kiril karakterleri
const foreign = /[぀-ヿ㐀-䶿一-鿿豈-﫿가-힯Ѐ-ӿ]/;
const foreignAll = /[぀-ヿ㐀-䶿一-鿿豈-﫿가-힯Ѐ-ӿ]/g;
// Uzun bir yanıtta yalnızca birkaç yabancı karakter kaçmışsa (ör. tek bir Çince kelime) yanıt
// çöpe atılmaz; o karakterler silinir. Yoğunsa yanıt reddedilir ve yeniden üretilir.
// Modeller bazen LaTeX yazar; uygulama LaTeX göstermediği için düz metne çevrilir.
const unlatex = (t) => {
  let s = t.replace(/\\\[|\\\]|\\\(|\\\)/g, '');
  for (let k = 0; k < 3; k++) s = s.replace(/\\frac\{([^{}]*)\}\{([^{}]*)\}/g, '($1)/($2)');
  return s
    .replace(/\\sqrt\{([^{}]*)\}/g, '√($1)')
    .replace(/\\lim_\{([^{}]*)\}/g, 'lim ($1)')
    .replace(/\\text\{([^{}]*)\}/g, '$1')
    .replace(/\\(left|right)\b/g, '')
    .replace(/\\(cdot|times)\b/g, (m, c) => (c === 'cdot' ? '·' : '×'))
    .replace(/\\to\b/g, '→').replace(/\\infty\b/g, '∞').replace(/\\pi\b/g, 'π')
    .replace(/\\(leq|le)\b/g, '≤').replace(/\\(geq|ge)\b/g, '≥').replace(/\\neq\b/g, '≠')
    .replace(/\\(quad|qquad|,|;|!)/g, ' ')
    .replace(/\\(sin|cos|tan|ln|log)\b/g, '$1')
    .replace(/[ \t]{2,}/g, ' ');
};
if (/\\[a-zA-Z\[\(]/.test(content)) content = unlatex(content);
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

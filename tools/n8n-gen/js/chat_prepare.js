// Sohbeti çözer (var olan / yeni), modele gidecek mesajları ve kaydedilecek belgeleri hazırlar.
const crypto = require('crypto');
const v = $('Soru: doğrula').first().json;
const conv = $('Soru: sohbet bul').first().json || {};
const course = $('Soru: ders bul').first().json || {};
const notes = $('Soru: notlar').all().map((i) => i.json).filter((d) => d && d.id);
const history = $('Soru: geçmiş').all().map((i) => i.json).filter((d) => d && d.id)
  .sort((a, b) => a.seq - b.seq);

const notFound = (message) => [{ json: { valid: false, response: { ok: false, error: { code: 'NOT_FOUND', message } } } }];
if (v.conversation_id && !conv.id) return notFound('Sohbet bulunamadı.');
if (!v.conversation_id && v.course_id && !course.id) return notFound('Ders bulunamadı.');

const isNew = !conv.id;
const courseId = isNew ? (course.id || null) : (conv.course_id || null);
const courseName = courseId && course.id === courseId ? course.name : null;

// Ders notları bağlamı: özet varsa özet, yoksa not metni; en fazla 6000 karakter
const noteText = (n) => (n.summary && n.summary.short)
  ? [n.summary.short, ...(n.summary.key_points || []).map((p) => '- ' + p)].join('\n')
  : n.content;
const notesContext = notes.map((n) => `### ${n.title}\n${noteText(n)}`).join('\n\n').slice(0, 6000);

let system = [
  'Sen üniversite öğrencilerine ders çalışmada yardım eden bir yapay zekâ asistanısın.',
  'KURALLAR:',
  '1. Yanıtını YALNIZCA Türkçe yaz. Çince, Japonca, Korece veya Kiril alfabesinden tek bir karakter bile kullanma.',
  '2. Açık, doğru ve öğretici ol; gerekiyorsa kısa bir örnek ver.',
  '3. Emin olmadığın bilgiyi uydurma; bilmiyorsan bunu açıkça söyle.',
  '4. Yanıtın en fazla 250 kelime olsun.',
  '5. Terimleri ders ve akademik anlamıyla yorumla (ör. "zincir kuralı" türevde bir kuraldır); soru belirsizse en olası akademik anlamı seç.',
  '6. Matematiksel ifadeleri LaTeX kullanmadan düz metinle yaz (ör. f\'(x) = 3x^2, lim (h→0), (a + b)/c). \\frac, \\[ gibi komutlar kullanma.',
].join('\n');
if (notesContext) {
  system += `\n\nAşağıda öğrencinin "${courseName}" dersine ait notları var. ` +
    'Soruyu öncelikle bu notlara dayanarak yanıtla. Notlarda olmayan bir bilgi verirsen bunun ' +
    `genel bilgi olduğunu belirt.\n\n<notlar>\n${notesContext}\n</notlar>`;
}

// Otomatik model seçimi (kullanıcı elle seçmediyse):
// matematik / kod / sayısal sorular → akıl yürütmesi güçlü model (qwen2.5:7b),
// Türkçe anlatım → Türkçesi doğal model (gemma3:4b). Model adları .env'den gelir.
const REASONING_WORDS = ['türev', 'integral', 'limit', 'denklem', 'hesapla', 'matris', 'olasılık', 'fonksiyon',
  'ispat', 'formül', 'matematik', 'geometri', 'fizik', 'kimya', 'istatistik', 'algoritma', 'python', 'java',
  'dart', 'sql', 'kod', 'program'];
const haystack = `${v.message} ${courseName || ''}`.toLocaleLowerCase('tr');
const mathLike = /\d\s*[-+*/^=×÷]\s*[\d(a-z]|[a-z]\s*\^\s*\d|f\(x\)|√|∫|```/i.test(v.message);
const hit = REASONING_WORDS.find((w) => haystack.includes(w));
const route = mathLike || hit ? 'reasoning' : 'text';
const route_reason = v.model
  ? 'elle seçildi'
  : route === 'reasoning' ? (mathLike ? 'matematiksel ifade' : `${hit} konusu`) : 'Türkçe anlatım';

const textModel = $env.LLM_MODEL || 'gemma3:4b';
const reasoningModel = $env.LLM_MODEL_REASONING || textModel;
const primary = v.model || (route === 'reasoning' ? reasoningModel : textModel);

const now = Date.now();
const nowIso = new Date(now).toISOString();
const conversation = isNew
  ? { id: crypto.randomUUID(), user_id: v.user_id, course_id: courseId,
      title: v.message.replace(/\s+/g, ' ').slice(0, 60), created_at: nowIso, updated_at: nowIso }
  : { id: conv.id, updated_at: nowIso };

return [{
  json: {
    valid: true,
    is_new: isNew,
    conversation,
    user_message: { id: crypto.randomUUID(), conversation_id: conversation.id, user_id: v.user_id,
      role: 'user', content: v.message, model: null, seq: now, created_at: nowIso },
    model: v.model, // null ise otomatik: route'a göre LLM_MODEL veya LLM_MODEL_REASONING
    route,
    route_reason,
    // 1. ve 2. deneme birincil modelle; 3. deneme diğer modelle (yedek) yapılır
    primary_model: primary,
    fallback_model: primary === textModel ? reasoningModel : textModel,
    messages: [
      { role: 'system', content: system },
      ...history.map((m) => ({ role: m.role, content: m.content })),
      // Dil hatırlatması son mesaja eklenir (küçük modeller sistem mesajındaki dil kuralını uzun yanıtta unutabiliyor).
      // Veritabanına kullanıcının yazdığı metin olduğu gibi kaydedilir.
      { role: 'user', content: `${v.message}\n\n(Yanıtını yalnızca Türkçe yaz; Çince veya başka bir alfabe kullanma.)` },
    ],
  },
}];

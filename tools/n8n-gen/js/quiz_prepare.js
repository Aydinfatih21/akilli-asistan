// Test üretimi için Ollama isteğini hazırlar. Şema, case dokümanındaki yapı + "topic".
const n = $('Test: not').first().json;
const r = $('Test: istek').first().json;
const level = {
  easy: 'kolay (temel tanımlar ve kavramlar)',
  medium: 'orta (kavramları anlama ve karşılaştırma)',
  hard: 'zor (uygulama, analiz ve çıkarım)',
}[r.difficulty];
// Model birkaç fazla (yedek) soru üretir; kurallara uymayan sorular kodda elenir.
const ask = r.count + 2;
const schema = {
  type: 'object',
  properties: {
    questions: {
      type: 'array', minItems: ask, maxItems: ask,
      items: {
        type: 'object',
        properties: {
          question: { type: 'string' },
          options: { type: 'array', items: { type: 'string' }, minItems: 4, maxItems: 4 },
          correct_answer: { type: 'string' },
          explanation: { type: 'string' },
          topic: { type: 'string' },
        },
        required: ['question', 'options', 'correct_answer', 'explanation', 'topic'],
      },
    },
  },
  required: ['questions'],
};
const system = [
  'Sen üniversite öğrencileri için ders notlarından çoktan seçmeli test hazırlayan bir öğretim asistanısın.',
  'KURALLAR:',
  '1. YALNIZCA Türkçe yaz. Çince, Japonca, Korece veya Kiril alfabesinden tek bir karakter bile kullanma.',
  `2. Tam olarak ${ask} soru üret. Zorluk düzeyi: ${level}.`,
  '3. Sorular YALNIZCA verilen ders notundaki bilgilere dayansın.',
  '4. Her sorunun tam 4 farklı seçeneği olsun ve yalnızca biri doğru olsun. Seçeneklerin başına "A)" gibi harf koyma.',
  '5. "correct_answer", doğru seçeneğin metniyle BİREBİR aynı olsun.',
  '6. "explanation", doğru cevabın neden doğru olduğunu 1-2 cümleyle açıklasın.',
  '7. "topic", sorunun ölçtüğü konuyu 1-4 kelimeyle belirtsin (ör. "Widget türleri").',
  '8. Aynı soruyu tekrarlama; "Hepsi" veya "Hiçbiri" seçeneğini kullanma.',
  '9. Doğru cevabı soru metninin içinde verme; yanlış seçenekler de akla yatkın olsun.',
  '10. Soruları dil bilgisi açısından düzgün, açık ve tek anlamlı yaz.',
].join('\n');
// Otomatik model seçimi: formül yoğun / sayısal notlar → akıl yürütme modeli, diğerleri → Türkçe anlatım modeli
const low = n.content.toLocaleLowerCase('tr');
const symbolRatio = (n.content.match(/[=^+*/×÷√∫<>]/g) || []).length / Math.max(n.content.length, 1);
const hits = ['türev', 'integral', 'limit', 'denklem', 'matris', 'olasılık', 'fonksiyon', 'formül', 'algoritma', 'kod']
  .filter((w) => low.includes(w)).length;
const route = symbolRatio > 0.01 || hits >= 2 ? 'reasoning' : 'text';

return [{
  json: {
    route,
    body: {
      model: r.model,
      stream: false,
      format: schema,
      options: { temperature: 0.4, num_ctx: 8192 },
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: `Ders notu başlığı: ${n.title}\n\nDers notu:\n${n.content}` },
      ],
    },
  },
}];

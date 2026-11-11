// Özet için Ollama isteğini hazırlar. "format" ile JSON şeması zorlanır.
const n = $('Özet: not').first().json;
const r = $('Özet: istek').first().json;
const schema = {
  type: 'object',
  properties: {
    short: { type: 'string' },
    key_points: { type: 'array', items: { type: 'string' }, minItems: 3, maxItems: 7 },
    keywords: { type: 'array', items: { type: 'string' }, minItems: 3, maxItems: 8 },
    flashcards: {
      type: 'array', minItems: 4, maxItems: 8,
      items: {
        type: 'object',
        properties: { front: { type: 'string' }, back: { type: 'string' } },
        required: ['front', 'back'],
      },
    },
  },
  required: ['short', 'key_points', 'keywords', 'flashcards'],
};
const system = [
  'Sen üniversite öğrencileri için ders notlarını özetleyen bir asistansın.',
  'KURALLAR:',
  '1. YALNIZCA Türkçe yaz. Çince, Japonca, Korece veya Kiril alfabesinden tek bir karakter bile kullanma.',
  '2. Yalnızca nottaki bilgileri kullan; notta olmayan bilgi ekleme.',
  '3. "short": notun 2-3 cümlelik özeti.',
  '4. "key_points": notun en önemli 3-7 maddesi; her madde kısa tek bir cümle.',
  '5. "keywords": notun 3-8 anahtar kavramı (tek kelime veya kısa ifade).',
  '6. "flashcards": sınav öncesi hızlı tekrar için 4-8 hap bilgi kartı. "front" kısa bir kavram veya soru '
    + '(en fazla 8 kelime), "back" ezberlenecek bilgi (tek cümle; formül varsa formülü yaz).',
  '7. Yanıtın yalnızca istenen JSON nesnesi olsun.',
].join('\n');
return [{
  json: {
    route: 'text',
    body: {
      model: r.model, // null ise .env içindeki LLM_MODEL
      stream: false,
      format: schema,
      options: { temperature: 0.2, num_ctx: 8192 },
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: `Ders notu başlığı: ${n.title}\n\nDers notu:\n${n.content}` },
      ],
    },
  },
}];

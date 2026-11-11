// Sonucu birleştirir. Model geçerli öneri üretemediyse (ya da Ollama kapalıysa)
// yanlış konulardan kural tabanlı yedek öneri yazılır; puan her durumda döner.
const s = $('Teslim: puanla').first().json;
const r = $input.first().json || {};
const useAi = r.valid === true && !!r.content;

let text;
if (useAi) {
  text = r.content;
} else if (s.weak_topics.length) {
  const rec = (s.recurring_topics || []).map((r) => r.topic);
  text = `Şu konularda eksiğin görünüyor: ${s.weak_topics.join(', ')}. ` +
    (rec.length ? `Özellikle ${rec.join(', ')} konusunda önceki testlerde de hata yaptın; bu konuya ekstra zaman ayır ve birkaç örneği kendin çöz. ` : '') +
    'Bu konulara ait ders notlarını yeniden oku ve yanlış yaptığın soruların açıklamalarını dikkatle incele. ' +
    'Ardından aynı nottan yeni bir test oluşturarak kendini tekrar dene.';
} else {
  text = 'Tebrikler, tüm soruları doğru yanıtladın! Bilgini pekiştirmek için daha zor seviyede yeni bir test ' +
    'oluşturabilir ya da bir sonraki konuya geçebilirsin.';
}
// Yedek öneri neden kullanıldı? (teşhis için yanıtta döner)
const issue = useAi ? null : (r.problem || (r.error ? 'yapay zekâya ulaşılamadı' : 'bilinmiyor'));
const attempt = { ...s.attempt, recommendation: text, recommendation_source: useAi ? 'ai' : 'fallback' };
return [{
  json: {
    ...attempt,
    response: {
      ok: true,
      data: {
        attempt_id: attempt.id, score: attempt.score, total: attempt.total, percent: attempt.percent,
        results: s.results, weak_topics: s.weak_topics, recurring_topics: s.recurring_topics || [],
        recommendation: text, recommendation_source: attempt.recommendation_source,
        recommendation_issue: issue,
      },
    },
  },
}];

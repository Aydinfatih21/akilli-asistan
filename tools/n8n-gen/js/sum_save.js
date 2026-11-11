// Özeti nota kaydetmek için güncelleme belgesini ve istemci yanıtını hazırlar.
const n = $('Özet: not').first().json;
const v = $input.first().json;
const now = new Date().toISOString();
return [{
  json: {
    id: n.id,
    summary: v.summary,
    summary_model: v.model,
    summarized_at: now,
    response: { ok: true, data: { note_id: n.id, summary: v.summary, model: v.model, cached: false } },
  },
}];

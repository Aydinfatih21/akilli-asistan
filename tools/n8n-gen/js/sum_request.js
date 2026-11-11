// Özet isteğini okur.
const b = $('POST /notes/summarize').first().json.body || {};
const s = (v) => (v === null || v === undefined ? '' : String(v).trim());
return [{
  json: {
    user_id: $('Özet: oturum').first().json.user_id,
    note_id: s(b.note_id) || '-',
    force: b.force === true || b.force === 'true',
    model: s(b.model) || null,
  },
}];

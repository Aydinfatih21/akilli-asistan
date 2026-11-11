// Bir sohbetin mesajlarını eskiden yeniye döndürür.
const iso = (v) => (v ? new Date(v).toISOString() : null);
const c = $('Geçmiş: sohbet').first().json;
const messages = $input.all().map((i) => i.json).filter((d) => d && d.id)
  .sort((a, b) => a.seq - b.seq)
  .map((m) => ({ id: m.id, role: m.role, content: m.content, model: m.model ?? null, created_at: iso(m.created_at) }));
return [{
  json: {
    response: {
      ok: true,
      data: { conversation: { id: c.id, title: c.title, course_id: c.course_id ?? null }, messages },
    },
  },
}];

// Sohbetleri ders adı, mesaj sayısı ve son mesajla birleştirir.
const iso = (v) => (v ? new Date(v).toISOString() : null);
const rows = (node) => $(node).all().map((i) => i.json).filter((d) => d && d.id);
const courses = Object.fromEntries(rows('Sohbetler: dersler').map((c) => [c.id, c.name]));
const msgs = rows('Sohbetler: mesajlar');

const conversations = rows('Sohbetler: sohbetler').map((c) => {
  const m = msgs.filter((x) => x.conversation_id === c.id).sort((a, b) => b.seq - a.seq);
  return {
    id: c.id,
    title: c.title,
    course_id: c.course_id ?? null,
    course_name: c.course_id ? (courses[c.course_id] ?? null) : null,
    message_count: m.length,
    last_message: m.length ? String(m[0].content).slice(0, 120) : null,
    updated_at: iso(c.updated_at),
  };
}).sort((a, b) => String(b.updated_at).localeCompare(String(a.updated_at)));

return [{ json: { response: { ok: true, data: { conversations } } } }];

// Ders listesini not ve test istatistikleriyle birleştirir.
const iso = (v) => (v ? new Date(v).toISOString() : null);
const rows = (node) => $(node).all().map((i) => i.json).filter((d) => d && d.id);
const courses = rows('Liste: dersler');
const notes = rows('Liste: notlar');
const attempts = rows('Liste: denemeler');
const latest = (vals) => vals.filter(Boolean).map(iso).sort().pop() || null;

const out = courses.map((c) => {
  const n = notes.filter((x) => x.course_id === c.id);
  const a = attempts.filter((x) => x.course_id === c.id);
  return {
    id: c.id,
    name: c.name,
    note_count: n.length,
    attempt_count: a.length,
    avg_percent: a.length ? Math.round(a.reduce((s, x) => s + Number(x.percent || 0), 0) / a.length) : null,
    last_activity: latest([c.created_at, ...n.map((x) => x.created_at), ...a.map((x) => x.created_at)]),
  };
}).sort((x, y) => x.name.localeCompare(y.name, 'tr'));

return [{ json: { response: { ok: true, data: { courses: out } } } }];

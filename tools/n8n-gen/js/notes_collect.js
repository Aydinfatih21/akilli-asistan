// Dersin notlarını önizleme ve özet durumu ile döndürür (en yeni önce).
const iso = (v) => (v ? new Date(v).toISOString() : null);
const notes = $input.all().map((i) => i.json).filter((d) => d && d.id)
  .map((n) => ({
    id: n.id,
    title: n.title,
    preview: String(n.content || '').replace(/\s+/g, ' ').slice(0, 160),
    has_summary: !!(n.summary && n.summary.short),
    source: n.source || 'text',
    created_at: iso(n.created_at),
  }))
  .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
return [{ json: { response: { ok: true, data: { notes } } } }];

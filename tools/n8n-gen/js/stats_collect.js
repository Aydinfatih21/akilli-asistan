// Kullanıcının tüm test geçmişinden ders ve konu bazlı istatistik çıkarır.
// Tekrarlayan zayıflık: aynı konuda en az 2 ayrı testte hata yapılmışsa.
const iso = (v) => (v ? new Date(v).toISOString() : null);
const rows = (node) => $(node).all().map((i) => i.json).filter((d) => d && d.id);
const norm = (t) => String(t || '').toLocaleLowerCase('tr').replace(/[^\p{L}\p{N}\s]/gu, ' ').replace(/\s+/g, ' ').trim();

const courses = new Map(rows('İstatistik: dersler').map((c) => [c.id, c.name]));
const quizzes = new Map(rows('İstatistik: testler').map((q) => [q.id, q]));
const attempts = rows('İstatistik: denemeler').sort((a, b) => String(iso(a.created_at)).localeCompare(String(iso(b.created_at))));

const topicStats = new Map(); // ders|konu → istatistik
for (const a of attempts) {
  const q = quizzes.get(a.quiz_id);
  if (!q || !Array.isArray(q.questions)) continue;
  const topicOf = new Map(q.questions.map((x) => [x.id, x.topic]));
  for (const ans of a.answers || []) {
    const topic = topicOf.get(ans.question_id);
    if (!topic) continue;
    // Benzer adlı konuları birleştir (ör. "Zincir kuralı" ve "Zincir Kuralı")
    let key = `${a.course_id}|${norm(topic)}`;
    for (const k of topicStats.keys()) {
      const [cid, t] = k.split('|');
      if (cid === a.course_id && (t.includes(norm(topic)) || norm(topic).includes(t))) { key = k; break; }
    }
    const s = topicStats.get(key) || { course_id: a.course_id, topic, total: 0, correct: 0, wrong_attempts: new Set(), last_wrong_at: null };
    s.total += 1;
    if (ans.is_correct) s.correct += 1;
    else { s.wrong_attempts.add(a.id); s.last_wrong_at = iso(a.created_at); }
    topicStats.set(key, s);
  }
}

const topics = [...topicStats.values()].map((s) => ({
  course_id: s.course_id,
  course_name: courses.get(s.course_id) ?? null,
  topic: s.topic,
  total: s.total,
  correct: s.correct,
  accuracy: Math.round((100 * s.correct) / s.total),
  wrong_attempts: s.wrong_attempts.size,
  last_wrong_at: s.last_wrong_at,
})).sort((a, b) => a.accuracy - b.accuracy || b.total - a.total);

const recurring = topics.filter((t) => t.wrong_attempts >= 2).sort((a, b) => b.wrong_attempts - a.wrong_attempts);

const courseSummaries = [...courses.entries()].map(([id, name]) => {
  const list = attempts.filter((a) => a.course_id === id);
  const p = list.map((a) => Number(a.percent || 0));
  return {
    course_id: id,
    name,
    attempt_count: list.length,
    avg_percent: p.length ? Math.round(p.reduce((x, y) => x + y, 0) / p.length) : null,
    best_percent: p.length ? Math.max(...p) : null,
    last_percent: p.length ? p[p.length - 1] : null,
    first_percent: p.length ? p[0] : null,
  };
}).sort((a, b) => (b.attempt_count - a.attempt_count) || a.name.localeCompare(b.name, 'tr'));

const allP = attempts.map((a) => Number(a.percent || 0));
const recent = attempts.slice(-10).map((a) => ({
  attempt_id: a.id, created_at: iso(a.created_at), course_name: courses.get(a.course_id) ?? null,
  score: a.score, total: a.total, percent: a.percent,
}));

return [{
  json: {
    response: {
      ok: true,
      data: {
        overall: {
          attempt_count: attempts.length,
          question_count: attempts.reduce((x, a) => x + Number(a.total || 0), 0),
          correct_count: attempts.reduce((x, a) => x + Number(a.score || 0), 0),
          avg_percent: allP.length ? Math.round(allP.reduce((x, y) => x + y, 0) / allP.length) : null,
        },
        courses: courseSummaries,
        topics,
        recurring,
        recent,
      },
    },
  },
}];

// Sohbet listesi sorgusu (isteğe bağlı ders filtresi)
const b = $('POST /chat/conversations').first().json.body || {};
const user_id = $('Sohbetler: oturum').first().json.user_id;
const course_id = b.course_id ? String(b.course_id).trim() : '';
return [{ json: { user_id, query: course_id ? { user_id, course_id } : { user_id } } }];

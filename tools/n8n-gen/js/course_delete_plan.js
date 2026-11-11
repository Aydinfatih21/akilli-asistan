// Silinecek dersin sohbet kimliklerini toplar (mesajlar sohbet üzerinden silinir).
const course = $('Sil: ders').first().json;
const conversation_ids = $('Sil: sohbetler').all().map((i) => i.json.id).filter(Boolean);
return [{ json: { course_id: course.id, user_id: course.user_id, name: course.name, conversation_ids } }];

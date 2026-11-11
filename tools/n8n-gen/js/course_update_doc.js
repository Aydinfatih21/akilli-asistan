// Güncellenecek alanlar ve istemci yanıtı
const v = $('Düzenle: doğrula').first().json;
return [{ json: { id: v.course_id, name: v.name, response: { ok: true, data: { course: { id: v.course_id, name: v.name } } } } }];

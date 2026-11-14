// Silinecek notun testlerini toplar (test sonuçları test kimliği üzerinden silinir).
const note = $('Not sil: not').first().json;
const quiz_ids = $('Not sil: testler').all().map((i) => i.json.id).filter(Boolean);
return [{ json: { note_id: note.id, user_id: note.user_id, title: note.title, quiz_ids } }];

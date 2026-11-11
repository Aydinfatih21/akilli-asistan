# API Sözleşmesi (Flutter ⇄ n8n)

Flutter uygulaması yalnızca n8n webhook'larıyla konuşur. n8n; MongoDB ve Ollama'ya kendisi erişir.

```
Flutter ──HTTP/JSON──▶ n8n (webhook) ──▶ MongoDB (asistan)
                                     └──▶ Ollama /api/chat
```

## 1. Genel kurallar

| Konu | Kural |
|---|---|
| Temel adres | Android emülatör: `http://10.0.2.2:5678/webhook` · Gerçek telefon: `http://<PC-IP>:5678/webhook` |
| Yöntem | Tüm uç noktalar `POST` + JSON gövde (yalnızca `/health` ve `/models` `GET`) |
| Başlıklar | `Content-Type: application/json` · Giriş gerektirenlerde `Authorization: Bearer <token>` |
| Zaman aşımı | Normal istekler 15 sn · Yapay zekâ kullananlar (🤖) **120 sn** |
| Kimlikler | Tüm `id` alanları UUID metni |
| Tarihler | ISO 8601 (`2026-11-05T19:30:00+03:00`) |

### Yanıt zarfı

Her yanıt aynı yapıdadır; Flutter tek bir yerde çözümler.

```json
{ "ok": true, "data": { } }
```

```json
{ "ok": false, "error": { "code": "VALIDATION_ERROR", "message": "Not metni en az 20 karakter olmalıdır." } }
```

`message` her zaman kullanıcıya gösterilebilecek Türkçe bir cümledir. Sunucu ve yapay zekâ hatalarında (500/502/503) hata ayıklama için ek olarak teknik bir `detail` alanı bulunur; kullanıcıya gösterilmez.

### Hata kodları

| HTTP | `code` | Ne zaman |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Eksik/hatalı alan |
| 401 | `UNAUTHORIZED` | Token yok, geçersiz veya süresi dolmuş → Flutter giriş ekranına döner |
| 401 | `INVALID_CREDENTIALS` | E-posta veya şifre hatalı |
| 404 | `NOT_FOUND` | Kayıt yok **veya başka kullanıcıya ait** (ikisi ayırt edilmez) |
| 409 | `EMAIL_TAKEN` | Kayıtta e-posta kullanımda |
| 409 | `COURSE_EXISTS` | Aynı adla ders zaten var |
| 409 | `ALREADY_SUBMITTED` | Test daha önce teslim edilmiş |
| 502 | `AI_BAD_OUTPUT` | Model 3 denemede de geçerli çıktı üretemedi |
| 503 | `AI_UNAVAILABLE` | Ollama'ya ulaşılamadı / zaman aşımı |
| 500 | `INTERNAL_ERROR` | Beklenmeyen hata |

## 2. Uç noktalar

🤖 = Ollama çağırır · 🔒 = `Authorization` gerekir

| # | Yol | Açıklama | Workflow | Durum |
|---|---|---|---|---|
| 3 | `POST /auth/register` | Kayıt | 00-auth | Bonus |
| 4 | `POST /auth/login` | Giriş | 00-auth | Çekirdek |
| 5 | `POST /auth/logout` 🔒 | Çıkış | 00-auth | Bonus |
| 6 | `POST /courses/list` 🔒 | Dersler + kısa istatistik | 10-courses | Çekirdek |
| 7 | `POST /courses/create` 🔒 | Ders ekle | 10-courses | Çekirdek |
| 7a | `POST /courses/update` 🔒 | Ders adını değiştir | 10-courses | Bonus |
| 7b | `POST /courses/delete` 🔒 | Dersi notları, sohbetleri ve testleriyle sil | 10-courses | Bonus |
| 8 | `POST /chat/send` 🔒🤖 | **Soru-cevap** | 01-chat | **Zorunlu 1** |
| 9 | `POST /chat/conversations` 🔒 | Sohbet listesi | 01-chat | Bonus |
| 10 | `POST /chat/history` 🔒 | Bir sohbetin mesajları | 01-chat | Bonus |
| 11 | `POST /notes/create` 🔒 | Not kaydet (metin/TXT/PDF) | 02-notes | Çekirdek |
| 11a | `POST /notes/extract-pdf` 🔒 | PDF'ten metin çıkar (multipart) | 02-notes | Bonus |
| 12 | `POST /notes/list` 🔒 | Dersin notları | 02-notes | Çekirdek |
| 13 | `POST /notes/summarize` 🔒🤖 | **Not özetleme** | 02-notes | **Zorunlu 2** |
| 14 | `POST /quizzes/generate` 🔒🤖 | **Test oluşturma** | 03-quiz-generate | **Zorunlu 3** |
| 15 | `POST /quizzes/submit` 🔒🤖 | **Performans değerlendirme** | 04-quiz-evaluate | **Zorunlu 4** |
| 16 | `POST /stats/overview` 🔒 | Ders/konu istatistikleri, tekrarlayan zayıflıklar | 05-stats | Bonus |

🤖 uç noktalarında model **otomatik** seçilir (`model` gönderilmezse):

| İş | Model | Neden |
|---|---|---|
| Özet, öneri, genel sohbet | `LLM_MODEL` (gemma3:4b) | Türkçesi doğal ve hızlı |
| Sohbette matematik / kod / sayısal soru (ifade veya anahtar kelime: türev, denklem, python…) | `LLM_MODEL_2` (qwen2.5:7b) | Akıl yürütme ve yapılandırılmış çıktıda güçlü |
| Formül yoğun nottan test | `LLM_MODEL_2` | Sayısal sorularda daha isabetli |

İsteğe bağlı `"model"` alanı gönderilirse (Ayarlar → Gelişmiş) o model kullanılır. Sohbet yanıtındaki `reply.model_reason` seçimin nedenini söyler (`"Türkçe anlatım"`, `"matematiksel ifade"`, `"elle seçildi"`…).

---

### 3–5. Kimlik doğrulama

`POST /auth/register`
```json
{ "name": "Fatih", "email": "fatih@ornek.com", "password": "gizli123" }
```
`POST /auth/login`
```json
{ "email": "fatih@ornek.com", "password": "gizli123" }
```
İkisinin de başarılı yanıtı (register için HTTP 201):
```json
{ "ok": true, "data": {
  "token": "9f2c…64 karakter…",
  "user": { "id": "…", "name": "Fatih", "email": "fatih@ornek.com" } } }
```
Kurallar: e-posta biçimi geçerli, şifre 6–72 karakter, ad 1–100 karakter. Token 30 gün geçerlidir; Flutter `flutter_secure_storage` ile saklar.

`POST /auth/logout` → `{ "ok": true, "data": {} }`

### 6–7. Dersler

`POST /courses/list` → gövde `{}`
```json
{ "ok": true, "data": { "courses": [
  { "id": "…", "name": "Mobil Programlama", "note_count": 3,
    "attempt_count": 2, "avg_percent": 70, "last_activity": "2026-11-05T19:30:00+03:00" } ] } }
```
`avg_percent` hiç test çözülmediyse `null`.

`POST /courses/create`
```json
{ "name": "Mobil Programlama" }
```
→ `{ "ok": true, "data": { "course": { "id": "…", "name": "Mobil Programlama" } } }`

`POST /courses/update` → `{ "course_id": "…", "name": "Matematik" }` → `{ "ok": true, "data": { "course": { "id": "…", "name": "Matematik" } } }` (aynı ad başka derste varsa `409 COURSE_EXISTS`)

`POST /courses/delete` → `{ "course_id": "…" }` → `{ "ok": true, "data": { "deleted": true, "course_id": "…" } }`
Dersin notları, testleri, test sonuçları, sohbetleri ve mesajları da silinir; geri alınamaz.

### 8. `POST /chat/send` 🤖 — Zorunlu 1: Soru-cevap

```json
{ "message": "Stateless ve stateful widget farkı nedir?",
  "conversation_id": null,
  "course_id": "…",
  "model": "qwen2.5:7b" }
```
- `conversation_id: null` → yeni sohbet açılır, başlığı ilk mesajdan üretilir.
- `course_id` verilirse o dersin notları modele bağlam olarak eklenir.
- Modele son 10 mesaj geçmiş olarak gönderilir.

```json
{ "ok": true, "data": {
  "conversation_id": "…",
  "reply": { "id": "…", "role": "assistant", "content": "Stateless widget…",
             "model": "qwen2.5:7b", "model_reason": "matematiksel ifade", "created_at": "…" } } }
```

### 9–10. Sohbet geçmişi

`POST /chat/conversations` → `{ "course_id": null }` (isteğe bağlı filtre; size ait olmayan ders için boş liste döner)
```json
{ "ok": true, "data": { "conversations": [
  { "id": "…", "title": "Widget türleri", "course_id": "…", "updated_at": "…" } ] } }
```
`POST /chat/history` → `{ "conversation_id": "…" }`
```json
{ "ok": true, "data": { "messages": [
  { "id": "…", "role": "user", "content": "…", "created_at": "…" },
  { "id": "…", "role": "assistant", "content": "…", "model": "qwen2.5:7b", "created_at": "…" } ] } }
```

### 11–12. Notlar

`POST /notes/create`
```json
{ "course_id": "…", "title": "Flutter Giriş", "content": "Flutter, Google tarafından…", "source": "text" }
```
- `content`: 20–15000 karakter. TXT dosyası Flutter'da okunur, metni bu alanla gönderilir (`"source": "txt"`).
  PDF'in metni önce `/notes/extract-pdf` ile çıkarılır; kullanıcı düzenleyip kaydeder (`"source": "pdf"`).

→ `{ "ok": true, "data": { "note": { "id": "…", "title": "Flutter Giriş", "created_at": "…" } } }`

`POST /notes/extract-pdf` — **multipart/form-data**, dosya `file` alanında (en fazla 10 MB, uygulamada denetlenir)
```
curl -H "Authorization: Bearer <token>" -F "file=@turev.pdf" http://localhost:5678/webhook/notes/extract-pdf
```
n8n'in **Extract From File** düğümü PDF'teki seçilebilir metni okur; kod satır sonunda bölünmüş kelimeleri
birleştirir, fazla boşluk ve boş satırları temizler. Not kaydedilmez; metin uygulamada düzenlenip `/notes/create` ile gönderilir.
```json
{ "ok": true, "data": { "text": "Türev, bir fonksiyonun…", "characters": 2140, "pages": 3,
  "file_name": "Türev Notları.pdf", "title": "Türev Notları" } }
```
| Durum | Kod | Ne zaman |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Dosya yok veya PDF değil |
| 422 | `PDF_UNREADABLE` | Bozuk veya şifreli PDF |
| 422 | `PDF_NO_TEXT` | Seçilebilir metin yok (taranmış belge) |

`POST /notes/list` → `{ "course_id": "…" }`
```json
{ "ok": true, "data": { "notes": [
  { "id": "…", "title": "Flutter Giriş", "preview": "Flutter, Google tarafından…",
    "has_summary": true, "created_at": "…" } ] } }
```

### 13. `POST /notes/summarize` 🤖 — Zorunlu 2: Not özetleme

```json
{ "note_id": "…", "force": false, "model": "qwen2.5:7b" }
```
Özet notla birlikte saklanır; `force: false` iken kayıtlı özet varsa model çağrılmadan döner (`"cached": true`).

```json
{ "ok": true, "data": {
  "note_id": "…",
  "summary": {
    "short": "Flutter, tek kod tabanıyla çok platformlu uygulama geliştirmeyi sağlayan…",
    "key_points": ["Dart dilini kullanır", "Android, iOS, web ve masaüstü desteği", "Arayüz widget'lardan oluşur"],
    "keywords": ["Flutter", "Dart", "Widget"],
    "flashcards": [ { "front": "Flutter hangi dili kullanır?", "back": "Dart" } ] },
  "model": "qwen2.5:7b", "cached": false } }
```

### 14. `POST /quizzes/generate` 🤖 — Zorunlu 3: Test oluşturma

```json
{ "note_id": "…", "question_count": 5, "difficulty": "medium", "model": "qwen2.5:7b" }
```
- `question_count`: 5–10 (varsayılan 5) · `difficulty`: `easy` | `medium` | `hard`
- Modelden `question_count + 2` soru istenir; kurala uymayan sorular (cevabı soru metninde, doğru cevap şıklarda yok, tekrar, Türkçe dışı karakter…) elenir. Yeterli geçerli soru yoksa yeniden denenir; 3. deneme diğer modelle yapılır. 3 denemede de olmazsa `502 AI_BAD_OUTPUT`, elenme nedenleri `error.detail` alanında.

**Yanıtta doğru cevap ve açıklama YOKTUR** (sunucuda saklanır, teslimden sonra döner):
```json
{ "ok": true, "data": {
  "quiz_id": "…", "title": "Flutter Giriş — Test", "model": "qwen2.5:7b",
  "questions": [
    { "id": "…", "position": 1, "question": "Flutter hangi programlama dilini kullanır?",
      "options": ["Java", "Dart", "Python", "C#"], "topic": "Flutter temelleri" } ] } }
```

### 15. `POST /quizzes/submit` 🤖 — Zorunlu 4: Performans değerlendirme

```json
{ "quiz_id": "…", "answers": [
  { "question_id": "…", "selected_index": 1 },
  { "question_id": "…", "selected_index": null } ] }
```
- `selected_index`: 0–3, boş bırakılan soru için `null` (yanlış sayılır).
- Puanlama **n8n'de kodla** yapılır; model yalnızca öneri metnini yazar.
- Model hata verirse puan yine döner, öneri yanlış konulardan kural tabanlı üretilir (`recommendation_source: "fallback"`).

```json
{ "ok": true, "data": {
  "attempt_id": "…", "score": 4, "total": 5, "percent": 80,
  "results": [
    { "question_id": "…", "selected_index": 1, "correct_index": 1, "is_correct": true,
      "explanation": "Flutter, Dart dilini kullanır." } ],
  "weak_topics": ["Widget yaşam döngüsü"],
  "recurring_topics": [ { "topic": "Widget yaşam döngüsü", "previous": 2 } ],
  "recommendation": "Widget yaşam döngüsü konusunda eksiğin var. initState ve dispose…",
  "recommendation_source": "ai", "recommendation_issue": null } }
```
- `recurring_topics`: bu testte yanlış yapılan ve aynı dersin **önceki testlerinde de** hata yapılan konular (`previous`: kaç önceki testte). Öneri bu konuları ayrıca vurgular.
- `recommendation_issue`: yedek öneri kullanıldıysa nedeni (teşhis için).

### 16. `POST /stats/overview` → gövde `{}`

```json
{ "ok": true, "data": {
  "overall": { "attempt_count": 5, "question_count": 25, "correct_count": 14, "avg_percent": 56 },
  "courses": [ { "course_id": "…", "name": "Matematik", "attempt_count": 3, "avg_percent": 60,
                 "best_percent": 80, "first_percent": 40, "last_percent": 80 } ],
  "topics":  [ { "course_name": "Matematik", "topic": "Zincir kuralı", "total": 4, "correct": 1,
                 "accuracy": 25, "wrong_attempts": 3, "last_wrong_at": "…" } ],
  "recurring": [ { "topic": "Zincir kuralı", "course_name": "Matematik", "wrong_attempts": 3, "accuracy": 25 } ],
  "recent":  [ { "created_at": "…", "course_name": "Matematik", "score": 4, "total": 5, "percent": 80 } ] } }
```
- `recurring`: **tekrarlayan zayıflıklar**, aynı konuda en az 2 ayrı testte hata yapılmış konular. Benzer adlar ("Zincir kuralı" / "Zincir Kuralı uygulaması") tek konu sayılır.

## 3. Yapay zekâ çıktılarının doğrulanması (n8n içi)

Modelden gelen test JSON'u (case dokümanındaki şema + `topic`):

```json
{ "questions": [
  { "question": "Flutter hangi programlama dilini kullanır?",
    "options": ["Java", "Dart", "Python", "C#"],
    "correct_answer": "Dart",
    "explanation": "Flutter, Dart dilini kullanır.",
    "topic": "Flutter temelleri" } ] }
```

Kurallar (n8n Code düğümünde):
1. Ollama'ya `format` ile JSON şeması verilir, `temperature: 0.2`, `num_ctx: 8192`.
2. Geçerli JSON, `questions` dizisi, istenen sayıda soru.
3. Her soruda boş olmayan `question`, `explanation`, `topic`; tam 4 farklı ve boş olmayan seçenek.
4. `correct_answer` seçeneklerden biriyle birebir eşleşmeli → `correct_index`'e çevrilir.
5. Hiçbir metinde Çince/Japonca/Korece karakter olmamalı (`/[぀-ヿ㐀-鿿가-힯]/`).
6. Kurallardan biri bozulursa en fazla **3 deneme**; sonra `502 AI_BAD_OUTPUT`.

Özet ve sohbet yanıtlarında da 1. ve 5. kurallar uygulanır.

## 4. Flutter notları

- Android'de düz HTTP için `android/app/src/main/AndroidManifest.xml` içinde `<application android:usesCleartextTraffic="true" …>` gerekir.
- Gerçek telefonda test için Windows Güvenlik Duvarı'nda 5678 numaralı TCP portuna gelen bağlantıya izin verilmelidir.
- n8n'de webhook'ların `/webhook/...` adresinden çalışması için workflow'un **Publish** edilmiş olması gerekir; `/webhook-test/...` adresi yalnızca editörde "dinleme" açıkken çalışır.

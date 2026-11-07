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
| 1 | `GET /health` | Servis durumu | 90-system | Çekirdek |
| 2 | `GET /models` | Kurulu Ollama modelleri | 90-system | Bonus |
| 3 | `POST /auth/register` | Kayıt | 00-auth | Bonus |
| 4 | `POST /auth/login` | Giriş | 00-auth | Çekirdek |
| 5 | `POST /auth/logout` 🔒 | Çıkış | 00-auth | Bonus |
| 6 | `POST /courses/list` 🔒 | Dersler + kısa istatistik | 10-courses | Çekirdek |
| 7 | `POST /courses/create` 🔒 | Ders ekle | 10-courses | Çekirdek |
| 8 | `POST /chat/send` 🔒🤖 | **Soru-cevap** | 01-chat | **Zorunlu 1** |
| 9 | `POST /chat/conversations` 🔒 | Sohbet listesi | 01-chat | Bonus |
| 10 | `POST /chat/history` 🔒 | Bir sohbetin mesajları | 01-chat | Bonus |
| 11 | `POST /notes/create` 🔒 | Not kaydet (metin/TXT) | 02-notes | Çekirdek |
| 12 | `POST /notes/list` 🔒 | Dersin notları | 02-notes | Çekirdek |
| 13 | `POST /notes/summarize` 🔒🤖 | **Not özetleme** | 02-notes | **Zorunlu 2** |
| 14 | `POST /quizzes/generate` 🔒🤖 | **Test oluşturma** | 03-quiz-generate | **Zorunlu 3** |
| 15 | `POST /quizzes/submit` 🔒🤖 | **Performans değerlendirme** | 04-quiz-evaluate | **Zorunlu 4** |
| 16 | `POST /stats/overview` 🔒 | Ders/konu başarı istatistikleri | 10-courses | Bonus |
| 17 | `POST /plans/weekly` 🔒🤖 | Haftalık çalışma programı | 05-plan | Bonus |

🤖 uç noktalarının hepsi isteğe bağlı `"model"` alanı alır (ör. `"gemma3:4b"`). Gönderilmezse `.env` içindeki `LLM_MODEL` kullanılır.

---

### 1. `GET /health`

```json
{ "ok": true, "data": { "db": "up", "ollama": "up", "default_model": "qwen2.5:7b" } }
```

### 2. `GET /models`

```json
{ "ok": true, "data": { "default": "qwen2.5:7b", "models": [
  { "name": "qwen2.5:7b", "size_gb": 4.7 }, { "name": "gemma3:4b", "size_gb": 3.3 } ] } }
```

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
             "model": "qwen2.5:7b", "created_at": "…" } } }
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

→ `{ "ok": true, "data": { "note": { "id": "…", "title": "Flutter Giriş", "created_at": "…" } } }`

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
    "keywords": ["Flutter", "Dart", "Widget"] },
  "model": "qwen2.5:7b", "cached": false } }
```

### 14. `POST /quizzes/generate` 🤖 — Zorunlu 3: Test oluşturma

```json
{ "note_id": "…", "question_count": 5, "difficulty": "medium", "model": "qwen2.5:7b" }
```
- `question_count`: 5–10 (varsayılan 5) · `difficulty`: `easy` | `medium` | `hard`

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
  "recommendation": "Widget yaşam döngüsü konusunda eksiğin var. initState ve dispose…",
  "recommendation_source": "ai" } }
```

### 16. `POST /stats/overview` → gövde `{}`

```json
{ "ok": true, "data": {
  "courses": [ { "course_id": "…", "name": "Mobil Programlama", "attempt_count": 2, "avg_percent": 70 } ],
  "topics":  [ { "course_name": "Mobil Programlama", "topic": "State yönetimi", "correct": 1, "total": 4, "accuracy": 25 } ],
  "recent":  [ { "created_at": "…", "course_name": "Mobil Programlama", "score": 4, "total": 5, "percent": 80 } ] } }
```

### 17. `POST /plans/weekly` 🤖

```json
{ "days_per_week": 5, "minutes_per_day": 60 }
```
```json
{ "ok": true, "data": { "plan_id": "…", "days": [
  { "day": "Pazartesi", "tasks": [ { "course_name": "Mobil Programlama", "topic": "State yönetimi", "minutes": 40, "activity": "Notu tekrar oku, 5 soruluk test çöz" } ] } ] } }
```

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

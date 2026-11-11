"""MongoDB tabanlı 02-notes, 03-quiz-generate, 04-quiz-evaluate workflow'larını üretir.
Kullanım: python3 gen_mongo2.py <çıktı_klasörü>"""
import json
import os
import sys
from n8nlib import Workflow, err_body, RESPONSE_BODY

OUT = sys.argv[1]
JS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "js")


def js(name):
    with open(os.path.join(JS, name + ".js"), encoding="utf-8") as f:
        return f.read()


E500 = err_body("INTERNAL_ERROR", "Sunucu hatası, lütfen tekrar deneyin.")
E503 = err_body("AI_UNAVAILABLE", "Yapay zekâ servisine ulaşılamadı veya model bulunamadı. Lütfen biraz sonra tekrar deneyin.")


def static(obj):
    return json.dumps(obj, ensure_ascii=False)


def node_ref(node, path="response"):
    return "={{ JSON.stringify($('%s').first().json.%s) }}" % (node, path)


def not_found(msg):
    return static({"ok": False, "error": {"code": "NOT_FOUND", "message": msg}})


def ai_loop(wf, prefix, prep, validate_js, x, y, on_valid, fail_target=None, fail_msg=None):
    """prep düğümünün json.body'sini Ollama'ya gönderir; validate_js geçersiz derse en fazla 3 deneme.
    Ollama hatası ve 3 başarısız deneme: fail_target düğümüne ya da 503/502 yanıtlarına gider."""
    P = "$('%s').first().json" % prep
    # 1. ve 2. deneme birincil model; 3. deneme diğer model (yedek)
    T, R = "$env.LLM_MODEL", "($env.LLM_MODEL_REASONING || $env.LLM_MODEL)"
    primary = "(%s.body.model || (%s.route === 'reasoning' ? %s : %s))" % (P, P, R, T)
    body = ("={{ JSON.stringify(Object.assign({}, %s.body, { model: $runIndex >= 2 "
            "? (%s === %s ? %s : %s) : %s })) }}" % (P, primary, T, R, T, primary))
    h = wf.http_json(f"{prefix}: Ollama", "={{ $env.OLLAMA_URL }}/api/chat", body, [x, y])
    wf.link(prep, h)
    v = wf.code(f"{prefix}: yanıtı doğrula", validate_js, [x + 220, y], on_error=True)
    wf.link(h, v, 0)
    ok = wf.if_true(f"{prefix}: yanıt geçerli mi?", "$json.valid", [x + 440, y])
    wf.link(v, ok)
    wf.link(ok, on_valid, 0)
    retry = wf.if_lt(f"{prefix}: tekrar denensin mi?", "$json.attempt", 3, [x + 660, y + 160])
    wf.link(ok, retry, 1)
    wf.link(retry, h, 0)  # döngü
    if fail_target:
        wf.link(h, fail_target, 1)
        wf.link(v, fail_target, 1)
        wf.link(retry, fail_target, 1)
    else:
        r503 = wf.respond(f"{prefix}: 503", 503, [x + 220, y + 200], body=E503)
        wf.link(h, r503, 1)
        wf.link(v, r503, 1)
        wf.link(retry, wf.respond(f"{prefix}: 502", 502, [x + 880, y + 240], body=(
            "={{ JSON.stringify({ ok: false, error: { code: 'AI_BAD_OUTPUT', "
            "message: %s, detail: $json.problem } }) }}" % json.dumps(fail_msg, ensure_ascii=False))), 1)


# =====================================================================
# 02-notes
# =====================================================================
wf = Workflow("02-notes")
wf.note("Açıklama",
        "## 02-notes — Ders notları ve özet (Zorunlu 2)\n"
        "`/notes/create` not kaydı (metin veya TXT içeriği), `/notes/list` dersin notları,\n"
        "`/notes/summarize` Ollama ile JSON şemalı özet (`format`), doğrulama + en fazla 3 deneme.\n"
        "Özet nota kaydedilir; tekrar istenirse model çağrılmadan döner (`force: true` yeniden üretir).",
        [-60, -320], w=900, h=200)
r500 = wf.respond("500 Sunucu hatası", 500, [2600, 1500], body=E500)

# ---- /notes/create
w = wf.webhook("POST /notes/create", "notes/create", [0, 0])
s, ok = wf.auth("Not ekle", w, 220, 0, r500)
v = wf.code("Not ekle: doğrula", js("note_validate"), [880, -60], on_error=True)
wf.link(ok, v, 0); wf.link(v, r500, 1)
iv = wf.if_true("Not ekle: alanlar geçerli mi?", "$json.valid", [1100, -60])
wf.link(v, iv)
wf.link(iv, wf.respond("400 Geçersiz not", 400, [1320, 100], body=RESPONSE_BODY), 1)
f = wf.mongo_find("Not ekle: ders", "courses", "{ id: $json.note.course_id, user_id: $json.note.user_id }",
                  [1320, -140], limit=1, projection={"id": 1})
wf.link(iv, f, 0); wf.link(f, r500, 1)
ex = wf.if_true("Not ekle: ders var mı?", "!!$json.id", [1540, -140])
wf.link(f, ex)
wf.link(ex, wf.respond("404 Ders yok", 404, [1760, 0], body=not_found("Ders bulunamadı.")), 1)
d = wf.code("Not ekle: belge", js("note_doc"), [1760, -220])
wf.link(ex, d, 0)
ins = wf.mongo_insert("Not ekle: kaydet", "notes",
                      ["id", "user_id", "course_id", "title", "content", "source", "created_at"], [1980, -220])
wf.link(d, ins); wf.link(ins, r500, 1)
wf.link(ins, wf.respond("201 Not eklendi", 201, [2200, -220], body=node_ref("Not ekle: doğrula")), 0)

# ---- /notes/list
w = wf.webhook("POST /notes/list", "notes/list", [0, 480])
s, ok = wf.auth("Notlar", w, 220, 480, r500)
U = "$('Notlar: oturum').first().json.user_id"
f = wf.mongo_find("Notlar: ders", "courses",
                  "{ id: String($('POST /notes/list').first().json.body.course_id ?? '-') || '-', user_id: %s }" % U,
                  [880, 420], limit=1, projection={"id": 1})
wf.link(ok, f, 0); wf.link(f, r500, 1)
ex = wf.if_true("Notlar: ders var mı?", "!!$json.id", [1100, 420])
wf.link(f, ex)
wf.link(ex, wf.respond("404 Notlar: ders yok", 404, [1320, 560], body=not_found("Ders bulunamadı.")), 1)
n = wf.mongo_find("Notlar: notlar", "notes", "{ course_id: $json.id, user_id: %s }" % U, [1320, 360],
                  limit=200, sort={"created_at": -1},
                  projection={"id": 1, "title": 1, "content": 1, "summary": 1, "source": 1, "created_at": 1})
wf.link(ex, n, 0); wf.link(n, r500, 1)
col = wf.code("Notlar: birleştir", js("notes_collect"), [1540, 360], on_error=True)
wf.link(n, col); wf.link(col, r500, 1)
wf.link(col, wf.respond("200 Not listesi", 200, [1760, 360], body=RESPONSE_BODY), 0)

# ---- /notes/summarize
w = wf.webhook("POST /notes/summarize", "notes/summarize", [0, 960])
s, ok = wf.auth("Özet", w, 220, 960, r500)
rq = wf.code("Özet: istek", js("sum_request"), [880, 900])
wf.link(ok, rq, 0)
f = wf.mongo_find("Özet: not", "notes", "{ id: $json.note_id, user_id: $json.user_id }", [1100, 900], limit=1)
wf.link(rq, f); wf.link(f, r500, 1)
ex = wf.if_true("Özet: not var mı?", "!!$json.id", [1320, 900])
wf.link(f, ex)
wf.link(ex, wf.respond("404 Not yok", 404, [1540, 1060], body=not_found("Not bulunamadı.")), 1)
cached = wf.if_true("Özet: kayıtlı özet kullanılsın mı?",
                    "!$('Özet: istek').first().json.force && !!($json.summary && $json.summary.short)",
                    [1540, 860])
wf.link(ex, cached, 0)
wf.link(cached, wf.respond("200 Kayıtlı özet", 200, [1760, 760], body=(
    "={{ JSON.stringify({ ok: true, data: { note_id: $json.id, summary: $json.summary, "
    "model: $json.summary_model || null, cached: true } }) }}")), 0)
p = wf.code("Özet: prompt hazırla", js("sum_prepare"), [1760, 940])
wf.link(cached, p, 1)
sv = wf.code("Özet: kayıt belgesi", js("sum_save"), [2880, 860])
ai_loop(wf, "Özet", p, js("sum_validate"), 1980, 940, sv,
        fail_msg="Yapay zekâ 3 denemede de geçerli bir özet üretemedi. Lütfen tekrar deneyin.")
up = wf.mongo_update("Özet: nota kaydet", "notes", "id", ["id", "summary", "summary_model", "summarized_at"],
                     [3100, 860], date_fields=("summarized_at",))
wf.link(sv, up); wf.link(up, r500, 1)
wf.link(up, wf.respond("200 Özet", 200, [3320, 860], body=node_ref("Özet: kayıt belgesi")), 0)

# ---- /notes/extract-pdf (bonus: PDF yükleme) — çok parçalı form, alan adı "file"
w = wf.webhook("POST /notes/extract-pdf", "notes/extract-pdf", [0, 1440])
s_, ok = wf.auth("PDF", w, 220, 1440, r500)
pk = wf.code("PDF: dosya", js("pdf_pick"), [880, 1380], on_error=True)
wf.link(ok, pk, 0); wf.link(pk, r500, 1)
iv = wf.if_true("PDF: dosya geçerli mi?", "$json.valid", [1100, 1380])
wf.link(pk, iv)
wf.link(iv, wf.respond("400 PDF: geçersiz dosya", 400, [1320, 1540], body=RESPONSE_BODY), 1)
ex = wf.extract_pdf("PDF: metni çıkar", "pdf", [1320, 1340])
wf.link(iv, ex, 0)
wf.link(ex, wf.respond("422 PDF okunamadı", 422, [1540, 1520], body=static(
    {"ok": False, "error": {"code": "PDF_UNREADABLE",
                            "message": "PDF okunamadı. Dosya bozuk veya şifreli olabilir."}})), 1)
cl = wf.code("PDF: metni temizle", js("pdf_clean"), [1540, 1340], on_error=True)
wf.link(ex, cl, 0); wf.link(cl, r500, 1)
okt = wf.if_true("PDF: metin var mı?", "$json.valid", [1760, 1340])
wf.link(cl, okt)
wf.link(okt, wf.respond("200 PDF metni", 200, [1980, 1280], body=RESPONSE_BODY), 0)
wf.link(okt, wf.respond("422 PDF: metin yok", 422, [1980, 1440], body=RESPONSE_BODY), 1)

wf.save(f"{OUT}/02-notes.json")
print("02-notes:", len(wf.nodes), "düğüm")

# =====================================================================
# 03-quiz-generate
# =====================================================================
wf = Workflow("03-quiz-generate")
wf.note("Açıklama",
        "## 03-quiz-generate — Otomatik test oluşturma (Zorunlu 3)\n"
        "Ders notundan 5-10 çoktan seçmeli soru. Ollama `format` ile JSON şeması zorlanır; çıktı case "
        "dokümanındaki şemaya göre doğrulanır (4 farklı şık, correct_answer şıklardan biri, açıklama, konu, "
        "Türkçe), şıklar karıştırılır, en fazla 3 deneme.\n"
        "**Doğru cevap ve açıklama istemciye gönderilmez**; testle birlikte veritabanında saklanır.",
        [-60, -340], w=1000, h=220)
r500 = wf.respond("500 Sunucu hatası", 500, [2600, 700], body=E500)
w = wf.webhook("POST /quizzes/generate", "quizzes/generate", [0, 0])
s, ok = wf.auth("Test", w, 220, 0, r500)
rq = wf.code("Test: istek", js("quiz_request"), [880, -60], on_error=True)
wf.link(ok, rq, 0); wf.link(rq, r500, 1)
iv = wf.if_true("Test: istek geçerli mi?", "$json.valid", [1100, -60])
wf.link(rq, iv)
wf.link(iv, wf.respond("400 Geçersiz istek", 400, [1320, 100], body=RESPONSE_BODY), 1)
f = wf.mongo_find("Test: not", "notes", "{ id: $json.note_id, user_id: $json.user_id }", [1320, -140],
                  limit=1, projection={"id": 1, "course_id": 1, "title": 1, "content": 1})
wf.link(iv, f, 0); wf.link(f, r500, 1)
ex = wf.if_true("Test: not var mı?", "!!$json.id", [1540, -140])
wf.link(f, ex)
wf.link(ex, wf.respond("404 Not yok", 404, [1760, 20], body=not_found("Not bulunamadı.")), 1)
p = wf.code("Test: prompt hazırla", js("quiz_prepare"), [1760, -220])
wf.link(ex, p, 0)
doc = wf.code("Test: belge", js("quiz_doc"), [2880, -300], on_error=True)
ai_loop(wf, "Test", p, js("quiz_validate"), 1980, -220, doc,
        fail_msg="Yapay zekâ 3 denemede de geçerli bir test üretemedi. Lütfen tekrar deneyin veya daha uzun bir not kullanın.")
wf.link(doc, r500, 1)
ins = wf.mongo_insert("Test: kaydet", "quizzes",
                      ["id", "user_id", "note_id", "course_id", "title", "model", "difficulty", "questions",
                       "created_at"], [3100, -300])
wf.link(doc, ins, 0); wf.link(ins, r500, 1)
wf.link(ins, wf.respond("200 Test", 200, [3320, -300], body=node_ref("Test: belge")), 0)
wf.save(f"{OUT}/03-quiz-generate.json")
print("03-quiz-generate:", len(wf.nodes), "düğüm")

# =====================================================================
# 04-quiz-evaluate
# =====================================================================
wf = Workflow("04-quiz-evaluate")
wf.note("Açıklama",
        "## 04-quiz-evaluate — Performans değerlendirme (Zorunlu 4)\n"
        "Puanlama **kodla** yapılır (doğru/yanlış, yüzde, zayıf konular). Ollama yalnızca yanlış "
        "yapılan sorulara göre kişisel çalışma önerisi yazar. Model hata verirse kural tabanlı yedek "
        "öneri kullanılır; puan her durumda döner. Bir test yalnızca bir kez teslim edilebilir.",
        [-60, -340], w=1000, h=200)
r500 = wf.respond("500 Sunucu hatası", 500, [2600, 700], body=E500)
w = wf.webhook("POST /quizzes/submit", "quizzes/submit", [0, 0])
s, ok = wf.auth("Teslim", w, 220, 0, r500)
rq = wf.code("Teslim: istek", js("submit_request"), [880, -60], on_error=True)
wf.link(ok, rq, 0); wf.link(rq, r500, 1)
iv = wf.if_true("Teslim: istek geçerli mi?", "$json.valid", [1100, -60])
wf.link(rq, iv)
wf.link(iv, wf.respond("400 Geçersiz cevaplar", 400, [1320, 100], body=RESPONSE_BODY), 1)
f = wf.mongo_find("Teslim: test", "quizzes", "{ id: $json.quiz_id, user_id: $json.user_id }", [1320, -140],
                  limit=1)
wf.link(iv, f, 0); wf.link(f, r500, 1)
ex = wf.if_true("Teslim: test var mı?", "!!$json.id", [1540, -140])
wf.link(f, ex)
wf.link(ex, wf.respond("404 Test yok", 404, [1760, 20], body=not_found("Test bulunamadı.")), 1)
a = wf.mongo_find("Teslim: önceki teslim", "quiz_attempts", "{ quiz_id: $json.id }", [1760, -220],
                  limit=1, projection={"id": 1})
wf.link(ex, a, 0); wf.link(a, r500, 1)
done = wf.if_true("Teslim: daha önce teslim edildi mi?", "!!$json.id", [1980, -220])
wf.link(a, done)
wf.link(done, wf.respond("409 Zaten teslim edildi", 409, [2200, -60], body=static(
    {"ok": False, "error": {"code": "ALREADY_SUBMITTED", "message": "Bu test daha önce teslim edildi. Yeni bir test oluşturabilirsiniz."}})), 0)
sc = wf.code("Teslim: puanla", js("submit_score"), [2640, -300], on_error=True)
# Geçmişe dönük analiz için aynı dersin önceki denemeleri ve testleri
T = "$('Teslim: test').first().json"
pa = wf.mongo_find("Teslim: geçmiş denemeler", "quiz_attempts",
                   "{ user_id: %s.user_id, course_id: %s.course_id }" % (T, T), [2200, -480],
                   limit=50, sort={"created_at": -1}, projection={"quiz_id": 1, "answers": 1, "created_at": 1})
wf.link(done, pa, 1); wf.link(pa, r500, 1)
pq = wf.mongo_find("Teslim: geçmiş testler", "quizzes",
                   "{ user_id: %s.user_id, course_id: %s.course_id }" % (T, T), [2420, -480],
                   limit=60, projection={"id": 1, "questions": 1})
wf.link(pa, pq); wf.link(pq, r500, 1)
wf.link(pq, sc); wf.link(sc, r500, 1)
fin = wf.code("Teslim: sonuç", js("reco_final"), [3760, -380], on_error=True)
ai_loop(wf, "Öneri", sc, js("reco_validate"), 2860, -300, fin, fail_target=fin)
wf.link(fin, r500, 1)
ins = wf.mongo_insert("Teslim: kaydet", "quiz_attempts",
                      ["id", "quiz_id", "user_id", "course_id", "score", "total", "percent", "answers",
                       "recommendation", "recommendation_source", "created_at"], [3540, -380])
wf.link(fin, ins, 0)
wf.link(ins, wf.respond("409 Eşzamanlı teslim", 409, [3760, -220], body=static(
    {"ok": False, "error": {"code": "ALREADY_SUBMITTED", "message": "Bu test daha önce teslim edildi."}})), 1)
wf.link(ins, wf.respond("200 Sonuç", 200, [3760, -380], body=node_ref("Teslim: sonuç")), 0)
wf.save(f"{OUT}/04-quiz-evaluate.json")
print("04-quiz-evaluate:", len(wf.nodes), "düğüm")


# =====================================================================
# 05-stats
# =====================================================================
wf = Workflow("05-stats")
wf.note("Açıklama",
        "## 05-stats — İstatistik ve geçmişe dönük analiz (bonus)\n"
        "Tüm test geçmişinden ders bazlı başarı, konu bazlı doğruluk, **tekrarlayan zayıflıklar** "
        "(aynı konuda en az 2 ayrı testte hata) ve son 10 test.",
        [-60, -300], w=900, h=160)
r500 = wf.respond("500 Sunucu hatası", 500, [1900, 300], body=E500)
w = wf.webhook("POST /stats/overview", "stats/overview", [0, 0])
s_, ok = wf.auth("İstatistik", w, 220, 0, r500)
U = "$('İstatistik: oturum').first().json.user_id"
a = wf.mongo_find("İstatistik: dersler", "courses", "{ user_id: %s }" % U, [880, -60], projection={"id": 1, "name": 1})
wf.link(ok, a, 0); wf.link(a, r500, 1)
b = wf.mongo_find("İstatistik: testler", "quizzes", "{ user_id: %s }" % U, [1100, -60],
                  limit=500, projection={"id": 1, "course_id": 1, "questions": 1})
wf.link(a, b); wf.link(b, r500, 1)
c = wf.mongo_find("İstatistik: denemeler", "quiz_attempts", "{ user_id: %s }" % U, [1320, -60],
                  limit=500, sort={"created_at": 1},
                  projection={"id": 1, "quiz_id": 1, "course_id": 1, "score": 1, "total": 1, "percent": 1,
                              "answers": 1, "created_at": 1})
wf.link(b, c); wf.link(c, r500, 1)
col = wf.code("İstatistik: hesapla", js("stats_collect"), [1540, -60], on_error=True)
wf.link(c, col); wf.link(col, r500, 1)
wf.link(col, wf.respond("200 İstatistik", 200, [1760, -60], body=RESPONSE_BODY), 0)
wf.save(f"{OUT}/05-stats.json")
print("05-stats:", len(wf.nodes), "düğüm")

"""MongoDB tabanlı 00-auth, 10-courses, 01-chat workflow'larını üretir.
Kullanım: python3 gen_mongo.py <çıktı_klasörü>"""
import json
import os
import sys
from n8nlib import Workflow, err_body, RESPONSE_BODY, AUTH_TOKEN_JS

OUT = sys.argv[1]
JS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "js")


def js(name):
    with open(os.path.join(JS, name + ".js"), encoding="utf-8") as f:
        return f.read()


E500 = err_body("INTERNAL_ERROR", "Sunucu hatası, lütfen tekrar deneyin.")


def static(obj):
    return json.dumps(obj, ensure_ascii=False)


def node_ref(node, path="response"):
    return "={{ JSON.stringify($('%s').first().json.%s) }}" % (node, path)


# =====================================================================
# 00-auth
# =====================================================================
wf = Workflow("00-auth")
wf.note("Açıklama",
        "## 00-auth — Kimlik doğrulama (MongoDB)\n"
        "Şifreler scrypt ile özetlenir (`scrypt$tuz$özet`). Oturum anahtarının yalnızca SHA-256 özeti "
        "`sessions` koleksiyonunda saklanır; TTL indeksi süresi dolanları siler.\n"
        "Yanıt: `{ok:true,data}` veya `{ok:false,error:{code,message}}`", [-60, -300], w=900, h=180)
r500 = wf.respond("500 Sunucu hatası", 500, [1900, 1000], body=E500)

# ---- kayıt
w = wf.webhook("POST /auth/register", "auth/register", [0, 0])
v = wf.code("Kayıt: doğrula", js("register_validate"), [220, 0], on_error=True)
wf.link(w, v); wf.link(v, r500, 1)
iv = wf.if_true("Kayıt: alanlar geçerli mi?", "$json.valid", [440, 0])
wf.link(v, iv)
wf.link(iv, wf.respond("400 Geçersiz alan", 400, [660, 160], body=RESPONSE_BODY), 1)
f = wf.mongo_find("Kayıt: e-posta ara", "users", "{ email: $json.user.email }", [660, -40],
                  limit=1, projection={"id": 1})
wf.link(iv, f, 0); wf.link(f, r500, 1)
ex = wf.if_true("Kayıt: e-posta kayıtlı mı?", "!!$json.id", [880, -40])
wf.link(f, ex)
wf.link(ex, wf.respond("409 E-posta kayıtlı", 409, [1100, 100], body=static(
    {"ok": False, "error": {"code": "EMAIL_TAKEN", "message": "Bu e-posta adresi zaten kayıtlı."}})), 0)
d = wf.code("Kayıt: belge", js("register_doc"), [1100, -120])
wf.link(ex, d, 1)
ins = wf.mongo_insert("Kayıt: kullanıcı ekle", "users",
                      ["id", "name", "email", "password_hash", "created_at"], [1320, -120])
wf.link(d, ins); wf.link(ins, r500, 1)
ses = wf.code("Kayıt: oturum", js("register_session"), [1540, -120], on_error=True)
wf.link(ins, ses); wf.link(ses, r500, 1)
si = wf.mongo_insert("Kayıt: oturum ekle", "sessions",
                     ["token_hash", "user_id", "created_at", "expires_at", "expires_ms"], [1760, -120],
                     date_fields=("created_at", "expires_at"))
wf.link(ses, si); wf.link(si, r500, 1)
wf.link(si, wf.respond("201 Kayıt OK", 201, [1980, -120], body=node_ref("Kayıt: oturum")), 0)

# ---- giriş
w = wf.webhook("POST /auth/login", "auth/login", [0, 480])
f = wf.mongo_find("Giriş: kullanıcı ara", "users",
                  "{ email: String($json.body.email ?? '').trim().toLowerCase() }", [220, 480], limit=1)
wf.link(w, f); wf.link(f, r500, 1)
c = wf.code("Giriş: şifre kontrol", js("login_check"), [440, 480], on_error=True)
wf.link(f, c); wf.link(c, r500, 1)
iv = wf.if_true("Giriş: şifre doğru mu?", "$json.valid", [660, 480])
wf.link(c, iv)
wf.link(iv, wf.respond("401 Hatalı bilgi", 401, [880, 620], body=RESPONSE_BODY), 1)
si = wf.mongo_insert("Giriş: oturum ekle", "sessions",
                     ["token_hash", "user_id", "created_at", "expires_at", "expires_ms"], [880, 420],
                     date_fields=("created_at", "expires_at"))
wf.link(iv, si, 0); wf.link(si, r500, 1)
wf.link(si, wf.respond("200 Giriş OK", 200, [1100, 420], body=node_ref("Giriş: şifre kontrol")), 0)

# ---- çıkış
w = wf.webhook("POST /auth/logout", "auth/logout", [0, 840])
h = wf.code("Çıkış: token özeti", AUTH_TOKEN_JS.replace("__WEBHOOK__", "POST /auth/logout"),
            [220, 840], on_error=True)
wf.link(w, h); wf.link(h, r500, 1)
dl = wf.mongo_delete("Çıkış: oturumu sil", "sessions", "{ token_hash: $json.token_hash }", [440, 840])
wf.link(h, dl); wf.link(dl, r500, 1)
wf.link(dl, wf.respond("200 Çıkış OK", 200, [660, 840], body=static({"ok": True, "data": {}})), 0)
wf.save(f"{OUT}/00-auth.json")
print("00-auth:", len(wf.nodes), "düğüm")

# =====================================================================
# 10-courses
# =====================================================================
wf = Workflow("10-courses")
wf.note("Açıklama",
        "## 10-courses — Dersler (MongoDB)\n"
        "`/courses/list`: dersler + not sayısı + test ortalaması, `/courses/create`: ders ekleme.\n"
        "Tüm istekler `Authorization: Bearer <token>` ister.", [-60, -300], w=800, h=160)
r500 = wf.respond("500 Sunucu hatası", 500, [2000, 900], body=E500)

# ---- liste
w = wf.webhook("POST /courses/list", "courses/list", [0, 0])
s, ok = wf.auth("Liste", w, 220, 0, r500)
uid = "$('Liste: oturum').first().json.user_id"
a = wf.mongo_find("Liste: dersler", "courses", "{ user_id: %s }" % uid, [880, -60],
                  sort={"name": 1}, projection={"id": 1, "name": 1, "created_at": 1})
wf.link(ok, a, 0); wf.link(a, r500, 1)
b = wf.mongo_find("Liste: notlar", "notes", "{ user_id: %s }" % uid, [1100, -60],
                  projection={"id": 1, "course_id": 1, "created_at": 1})
wf.link(a, b); wf.link(b, r500, 1)
c = wf.mongo_find("Liste: denemeler", "quiz_attempts", "{ user_id: %s }" % uid, [1320, -60],
                  projection={"id": 1, "course_id": 1, "percent": 1, "created_at": 1})
wf.link(b, c); wf.link(c, r500, 1)
col = wf.code("Liste: birleştir", js("courses_list"), [1540, -60], on_error=True)
wf.link(c, col); wf.link(col, r500, 1)
wf.link(col, wf.respond("200 Ders listesi", 200, [1760, -60], body=RESPONSE_BODY), 0)

# ---- ekleme
w = wf.webhook("POST /courses/create", "courses/create", [0, 480])
s, ok = wf.auth("Ekleme", w, 220, 480, r500)
v = wf.code("Ekleme: doğrula", js("course_validate"), [880, 420], on_error=True)
wf.link(ok, v, 0); wf.link(v, r500, 1)
iv = wf.if_true("Ekleme: ad geçerli mi?", "$json.valid", [1100, 420])
wf.link(v, iv)
wf.link(iv, wf.respond("400 Geçersiz ders adı", 400, [1320, 580], body=RESPONSE_BODY), 1)
f = wf.mongo_find("Ekleme: aynı ad var mı", "courses",
                  "{ user_id: $json.course.user_id, name: $json.course.name }", [1320, 380],
                  limit=1, projection={"id": 1})
wf.link(iv, f, 0); wf.link(f, r500, 1)
ex = wf.if_true("Ekleme: ders zaten var mı?", "!!$json.id", [1540, 380])
wf.link(f, ex)
wf.link(ex, wf.respond("409 Ders zaten var", 409, [1760, 520], body=static(
    {"ok": False, "error": {"code": "COURSE_EXISTS", "message": "Bu isimde bir dersiniz zaten var."}})), 0)
d = wf.code("Ekleme: belge", js("course_doc"), [1760, 300])
wf.link(ex, d, 1)
ins = wf.mongo_insert("Ekleme: ders ekle", "courses", ["id", "user_id", "name", "created_at"], [1980, 300])
wf.link(d, ins); wf.link(ins, r500, 1)
wf.link(ins, wf.respond("201 Ders eklendi", 201, [2200, 300], body=node_ref("Ekleme: doğrula")), 0)

# ---- ders adı değiştirme
w = wf.webhook("POST /courses/update", "courses/update", [0, 960])
s_, ok = wf.auth("Düzenle", w, 220, 960, r500)
v = wf.code("Düzenle: doğrula", js("course_update_validate"), [880, 900], on_error=True)
wf.link(ok, v, 0); wf.link(v, r500, 1)
iv = wf.if_true("Düzenle: alanlar geçerli mi?", "$json.valid", [1100, 900])
wf.link(v, iv)
wf.link(iv, wf.respond("400 Düzenle: geçersiz", 400, [1320, 1060], body=RESPONSE_BODY), 1)
f = wf.mongo_find("Düzenle: ders", "courses", "{ id: $json.course_id, user_id: $json.user_id }", [1320, 860],
                  limit=1, projection={"id": 1})
wf.link(iv, f, 0); wf.link(f, r500, 1)
ex = wf.if_true("Düzenle: ders var mı?", "!!$json.id", [1540, 860])
wf.link(f, ex)
wf.link(ex, wf.respond("404 Düzenle: ders yok", 404, [1760, 1000], body=static(
    {"ok": False, "error": {"code": "NOT_FOUND", "message": "Ders bulunamadı."}})), 1)
V = "$('Düzenle: doğrula').first().json"
dup = wf.mongo_find("Düzenle: aynı ad var mı", "courses",
                    "{ user_id: %s.user_id, name: %s.name, id: { $ne: %s.course_id } }" % (V, V, V),
                    [1760, 820], limit=1, projection={"id": 1})
wf.link(ex, dup, 0); wf.link(dup, r500, 1)
dx = wf.if_true("Düzenle: ad başka derste mi?", "!!$json.id", [1980, 820])
wf.link(dup, dx)
wf.link(dx, wf.respond("409 Düzenle: ad kullanımda", 409, [2200, 960], body=static(
    {"ok": False, "error": {"code": "COURSE_EXISTS", "message": "Bu isimde bir dersiniz zaten var."}})), 0)
d = wf.code("Düzenle: belge", js("course_update_doc"), [2200, 760])
wf.link(dx, d, 1)
up = wf.mongo_update("Düzenle: kaydet", "courses", "id", ["id", "name"], [2420, 760])
wf.link(d, up); wf.link(up, r500, 1)
wf.link(up, wf.respond("200 Ders güncellendi", 200, [2640, 760], body=node_ref("Düzenle: belge")), 0)

# ---- ders silme (bağlı tüm verilerle)
w = wf.webhook("POST /courses/delete", "courses/delete", [0, 1440])
s_, ok = wf.auth("Sil", w, 220, 1440, r500)
U = "$('Sil: oturum').first().json.user_id"
f = wf.mongo_find("Sil: ders", "courses",
                  "{ id: String($('POST /courses/delete').first().json.body.course_id ?? '-') || '-', user_id: %s }" % U,
                  [880, 1380], limit=1)
wf.link(ok, f, 0); wf.link(f, r500, 1)
ex = wf.if_true("Sil: ders var mı?", "!!$json.id", [1100, 1380])
wf.link(f, ex)
wf.link(ex, wf.respond("404 Sil: ders yok", 404, [1320, 1520], body=static(
    {"ok": False, "error": {"code": "NOT_FOUND", "message": "Ders bulunamadı."}})), 1)
cv = wf.mongo_find("Sil: sohbetler", "conversations", "{ course_id: $json.id, user_id: $json.user_id }",
                   [1320, 1340], projection={"id": 1})
wf.link(ex, cv, 0); wf.link(cv, r500, 1)
plan = wf.code("Sil: plan", js("course_delete_plan"), [1540, 1340])
wf.link(cv, plan)
P = "$('Sil: plan').first().json"
prev = plan
x = 1760
for coll, q in [("messages", "{ conversation_id: { $in: %s.conversation_ids }, user_id: %s.user_id }" % (P, P)),
                ("conversations", "{ course_id: %s.course_id, user_id: %s.user_id }" % (P, P)),
                ("quiz_attempts", "{ course_id: %s.course_id, user_id: %s.user_id }" % (P, P)),
                ("quizzes", "{ course_id: %s.course_id, user_id: %s.user_id }" % (P, P)),
                ("notes", "{ course_id: %s.course_id, user_id: %s.user_id }" % (P, P)),
                ("courses", "{ id: %s.course_id, user_id: %s.user_id }" % (P, P))]:
    dl = wf.mongo_delete(f"Sil: {coll}", coll, q, [x, 1340])
    wf.link(prev, dl); wf.link(dl, r500, 1)
    prev, x = dl, x + 220
wf.link(prev, wf.respond("200 Ders silindi", 200, [x, 1340], body=(
    "={{ JSON.stringify({ ok: true, data: { deleted: true, course_id: $('Sil: plan').first().json.course_id } }) }}")), 0)

wf.save(f"{OUT}/10-courses.json")
print("10-courses:", len(wf.nodes), "düğüm")

# =====================================================================
# 01-chat
# =====================================================================
OLLAMA_BODY = ("={{ JSON.stringify({ "
               "model: ($runIndex >= 2 || ($runIndex === 1 && $('Yanıtı doğrula').last().json.problem === 'Türkçe dışı karakter')) "
               "? $('Soru: hazırla').first().json.fallback_model : $('Soru: hazırla').first().json.primary_model, "
               "messages: $('Soru: hazırla').first().json.messages, "
               "stream: false, "
               "options: { temperature: 0.3, num_ctx: 8192 } }) }}")

wf = Workflow("01-chat")
wf.note("Açıklama",
        "## 01-chat — Soru-cevap (Zorunlu 1, MongoDB)\n"
        "1) Oturum → 2) sohbet / ders / ders notları / son 9 mesaj → 3) prompt\n"
        "4) Ollama `/api/chat` (Türkçe kuralı, temperature 0.3, num_ctx 8192)\n"
        "5) Yanıt doğrulama: boş veya Türkçe dışı karakter → en fazla 3 deneme\n"
        "6) Sohbet + 2 mesaj kaydı (yalnızca başarılı yanıtta)", [-60, -340], w=900, h=220)
r500 = wf.respond("500 Sunucu hatası", 500, [3400, 1400], body=E500)

# ---- /chat/send
w = wf.webhook("POST /chat/send", "chat/send", [0, 0])
s, ok = wf.auth("Soru", w, 220, 0, r500)
v = wf.code("Soru: doğrula", js("chat_validate"), [880, -60], on_error=True)
wf.link(ok, v, 0); wf.link(v, r500, 1)
iv = wf.if_true("Soru: mesaj geçerli mi?", "$json.valid", [1100, -60])
wf.link(v, iv)
wf.link(iv, wf.respond("400 Geçersiz mesaj", 400, [1320, 100], body=RESPONSE_BODY), 1)
V = "$('Soru: doğrula').first().json"
f1 = wf.mongo_find("Soru: sohbet bul", "conversations",
                   "{ id: $json.conversation_id || '-', user_id: $json.user_id }", [1320, -140], limit=1)
wf.link(iv, f1, 0); wf.link(f1, r500, 1)
f2 = wf.mongo_find("Soru: ders bul", "courses",
                   "{ id: ($json.id ? ($json.course_id || '-') : (%s.course_id || '-')), user_id: %s.user_id }" % (V, V),
                   [1540, -140], limit=1, projection={"id": 1, "name": 1})
wf.link(f1, f2); wf.link(f2, r500, 1)
f3 = wf.mongo_find("Soru: notlar", "notes", "{ course_id: $json.id || '-', user_id: %s.user_id }" % V,
                   [1760, -140], limit=10, sort={"created_at": -1},
                   projection={"id": 1, "title": 1, "content": 1, "summary": 1})
wf.link(f2, f3); wf.link(f3, r500, 1)
f4 = wf.mongo_find("Soru: geçmiş", "messages",
                   "{ conversation_id: $('Soru: sohbet bul').first().json.id || '-', user_id: %s.user_id }" % V,
                   [1980, -140], limit=9, sort={"seq": -1},
                   projection={"id": 1, "role": 1, "content": 1, "seq": 1})
wf.link(f3, f4); wf.link(f4, r500, 1)
p = wf.code("Soru: hazırla", js("chat_prepare"), [2200, -140], on_error=True)
wf.link(f4, p); wf.link(p, r500, 1)
ip = wf.if_true("Soru: sohbet/ders bulundu mu?", "$json.valid", [2420, -140])
wf.link(p, ip)
wf.link(ip, wf.respond("404 Sohbet/ders yok", 404, [2640, 20], body=RESPONSE_BODY), 1)

h = wf.http_json("Ollama /api/chat", "={{ $env.OLLAMA_URL }}/api/chat", OLLAMA_BODY, [2640, -220])
wf.link(ip, h, 0)
wf.link(h, wf.respond("503 Yapay zekâ erişilemez", 503, [2860, -20], body=err_body(
    "AI_UNAVAILABLE", "Yapay zekâ servisine ulaşılamadı veya model bulunamadı. Lütfen biraz sonra tekrar deneyin.")), 1)
rv = wf.code("Yanıtı doğrula", js("validate_reply"), [2860, -220])
wf.link(h, rv, 0)
okr = wf.if_true("Yanıt geçerli mi?", "$json.valid", [3080, -220])
wf.link(rv, okr)
retry = wf.if_lt("Tekrar denensin mi?", "$json.attempt", 3, [3300, -60])
wf.link(okr, retry, 1)
wf.link(retry, h, 0)  # döngü: modeli yeniden çağır
wf.link(retry, wf.respond("502 Geçersiz model yanıtı", 502, [3520, 20], body=(
    "={{ JSON.stringify({ ok: false, error: { code: 'AI_BAD_OUTPUT', "
    "message: 'Yapay zekâ 3 denemede de geçerli bir yanıt üretemedi. Lütfen sorunuzu farklı ifade edip tekrar deneyin.', "
    "detail: $json.problem } }) }}")), 1)

cd = wf.code("Soru: sohbet belgesi", js("chat_conv_doc"), [3300, -320])
wf.link(okr, cd, 0)
isn = wf.if_true("Soru: yeni sohbet mi?", "$('Soru: hazırla').first().json.is_new", [3520, -320])
wf.link(cd, isn)
ci = wf.mongo_insert("Soru: sohbet ekle", "conversations",
                     ["id", "user_id", "course_id", "title", "created_at", "updated_at"], [3740, -420],
                     date_fields=("created_at", "updated_at"))
cu = wf.mongo_update("Soru: sohbet güncelle", "conversations", "id", ["id", "updated_at"], [3740, -240],
                     date_fields=("updated_at",))
wf.link(isn, ci, 0); wf.link(isn, cu, 1)
wf.link(ci, r500, 1); wf.link(cu, r500, 1)
mm = wf.code("Soru: mesaj belgeleri", js("chat_messages"), [3960, -320], on_error=True)
wf.link(ci, mm, 0); wf.link(cu, mm, 0); wf.link(mm, r500, 1)
mi = wf.mongo_insert("Soru: mesajları ekle", "messages",
                     ["id", "conversation_id", "user_id", "role", "content", "model", "seq", "created_at"],
                     [4180, -320])
wf.link(mm, mi); wf.link(mi, r500, 1)
wf.link(mi, wf.respond("200 Yanıt", 200, [4400, -320], body=node_ref("Soru: mesaj belgeleri")), 0)

# ---- /chat/conversations
w = wf.webhook("POST /chat/conversations", "chat/conversations", [0, 700])
s, ok = wf.auth("Sohbetler", w, 220, 700, r500)
fl = wf.code("Sohbetler: filtre", js("convs_filter"), [880, 640])
wf.link(ok, fl, 0)
U = "$('Sohbetler: oturum').first().json.user_id"
a = wf.mongo_find("Sohbetler: sohbetler", "conversations", "$json.query", [1100, 640],
                  limit=100, sort={"updated_at": -1})
wf.link(fl, a); wf.link(a, r500, 1)
b = wf.mongo_find("Sohbetler: dersler", "courses", "{ user_id: %s }" % U, [1320, 640],
                  projection={"id": 1, "name": 1})
wf.link(a, b); wf.link(b, r500, 1)
c = wf.mongo_find("Sohbetler: mesajlar", "messages", "{ user_id: %s }" % U, [1540, 640],
                  limit=5000, sort={"seq": -1},
                  projection={"id": 1, "conversation_id": 1, "content": 1, "seq": 1})
wf.link(b, c); wf.link(c, r500, 1)
col = wf.code("Sohbetler: birleştir", js("convs_collect"), [1760, 640], on_error=True)
wf.link(c, col); wf.link(col, r500, 1)
wf.link(col, wf.respond("200 Sohbet listesi", 200, [1980, 640], body=RESPONSE_BODY), 0)

# ---- /chat/history
w = wf.webhook("POST /chat/history", "chat/history", [0, 1100])
s, ok = wf.auth("Geçmiş", w, 220, 1100, r500)
f = wf.mongo_find("Geçmiş: sohbet", "conversations",
                  "{ id: String($('POST /chat/history').first().json.body.conversation_id ?? '-') || '-', "
                  "user_id: $('Geçmiş: oturum').first().json.user_id }", [880, 1040], limit=1)
wf.link(ok, f, 0); wf.link(f, r500, 1)
ex = wf.if_true("Geçmiş: sohbet var mı?", "!!$json.id", [1100, 1040])
wf.link(f, ex)
wf.link(ex, wf.respond("404 Sohbet yok", 404, [1320, 1180], body=static(
    {"ok": False, "error": {"code": "NOT_FOUND", "message": "Sohbet bulunamadı."}})), 1)
m = wf.mongo_find("Geçmiş: mesajlar", "messages", "{ conversation_id: $json.id }", [1320, 980],
                  limit=200, sort={"seq": 1},
                  projection={"id": 1, "role": 1, "content": 1, "model": 1, "seq": 1, "created_at": 1})
wf.link(ex, m, 0); wf.link(m, r500, 1)
col = wf.code("Geçmiş: birleştir", js("history_collect"), [1540, 980], on_error=True)
wf.link(m, col); wf.link(col, r500, 1)
wf.link(col, wf.respond("200 Sohbet geçmişi", 200, [1760, 980], body=RESPONSE_BODY), 0)

wf.save(f"{OUT}/01-chat.json")
print("01-chat:", len(wf.nodes), "düğüm")

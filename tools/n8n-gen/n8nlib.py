"""n8n workflow JSON üretici yardımcıları.

Kurallar (gerçek n8n'de öğrenilenler):
  * Durum kodları ifadeyle değil, IF düğümü + sabit kodlu yanıt düğümleriyle verilir.
  * Yanıtlar Text + Content-Type: application/json olarak döner (n8n gövdeyi ayrıştırmaz).
"""
import json
import uuid

TOKEN = r"($json.headers.authorization ?? '').replace(/^Bearer\s+/i, '')"
CRED_MONGO = {"mongoDb": {"id": "asistanMongoCredential", "name": "Asistan Mongo"}}
RESPONSE_BODY = "={{ JSON.stringify($json.response) }}"

AUTH_TOKEN_JS = r"""// Authorization: Bearer <token> başlığındaki anahtarın SHA-256 özetini çıkarır.
// Veritabanında yalnızca özet saklanır; ham anahtar sadece istemcide bulunur.
const crypto = require('crypto');
const headers = $('__WEBHOOK__').first().json.headers || {};
const raw = String(headers.authorization || '').replace(/^Bearer\s+/i, '').trim();
return [{
  json: {
    token_hash: raw ? crypto.createHash('sha256').update(raw).digest('hex') : '-',
    now_ms: Date.now(),
  },
}];
"""

UNAUTH_BODY = ("={{ JSON.stringify({ ok: false, error: { code: 'UNAUTHORIZED', "
               "message: 'Oturumunuz geçersiz veya süresi dolmuş. Lütfen tekrar giriş yapın.' } }) }}")
JSON_HEADER = {"entries": [{"name": "Content-Type", "value": "application/json; charset=utf-8"}]}
RESULT_BODY = "={{ JSON.stringify($json.result) }}"


def nid():
    return str(uuid.uuid4())


def err_body(code, message, with_detail=True):
    """Hata yanıt gövdesi. detail: n8n'in yakaladığı teknik hata (hata ayıklama için)."""
    msg = json.dumps(message, ensure_ascii=False)
    detail = "($json.error && ($json.error.message || $json.error.description)) || null" if with_detail else "null"
    return ("={{ JSON.stringify({ ok: false, error: { code: '%s', message: %s, detail: %s } }) }}"
            % (code, msg, detail))


class Workflow:
    def __init__(self, name):
        self.name = name
        self.nodes = []
        self.connections = {}

    # ------------------------------------------------------------ temel
    def add(self, node):
        assert node["name"] not in {n["name"] for n in self.nodes}, node["name"]
        node.setdefault("id", nid())
        self.nodes.append(node)
        return node["name"]

    def link(self, src, dst, out=0):
        outs = self.connections.setdefault(src, {"main": []})["main"]
        while len(outs) <= out:
            outs.append([])
        outs[out].append({"node": dst, "type": "main", "index": 0})

    # ------------------------------------------------------------ düğümler
    def note(self, name, text, pos, w=700, h=180):
        return self.add({"name": name, "type": "n8n-nodes-base.stickyNote", "typeVersion": 1,
                         "position": pos, "parameters": {"content": text, "width": w, "height": h}})

    def webhook(self, name, path, pos):
        return self.add({"name": name, "type": "n8n-nodes-base.webhook", "typeVersion": 2,
                         "position": pos, "webhookId": nid(),
                         "parameters": {"httpMethod": "POST", "path": path,
                                        "responseMode": "responseNode", "options": {}}})

    def _if(self, name, left, op, right, pos):
        return self.add({"name": name, "type": "n8n-nodes-base.if", "typeVersion": 2, "position": pos,
                         "parameters": {"conditions": {
                             "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "loose"},
                             "conditions": [{"id": nid(), "leftValue": left, "rightValue": right,
                                             "operator": op}],
                             "combinator": "and"}, "options": {}}})

    def if_true(self, name, expr, pos):
        return self._if(name, "={{ " + expr + " }}",
                        {"type": "boolean", "operation": "true", "singleValue": True}, "", pos)

    def if_equals(self, name, expr, value, pos):
        return self._if(name, "={{ " + expr + " }}", {"type": "string", "operation": "equals"}, value, pos)

    def if_lt(self, name, expr, value, pos):
        return self._if(name, "={{ " + expr + " }}", {"type": "number", "operation": "lt"}, value, pos)

    def respond(self, name, status, pos, body=RESULT_BODY):
        return self.add({"name": name, "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1.1,
                         "position": pos,
                         "parameters": {"respondWith": "text", "responseBody": body,
                                        "options": {"responseCode": status,
                                                    "responseHeaders": JSON_HEADER}}})

    def code(self, name, js, pos, on_error=False):
        node = {"name": name, "type": "n8n-nodes-base.code", "typeVersion": 2,
                "position": pos, "parameters": {"jsCode": js}}
        if on_error:
            node["onError"] = "continueErrorOutput"
        return self.add(node)

    # ------------------------------------------------------------ MongoDB
    # Kurallar: yalnızca basit işlemler; mantık Code düğümlerinde.
    #  * find: alwaysOutputData → sonuç yoksa boş öğe {} çıkar (akış durmaz)
    #  * find/update/delete: executeOnce → önceki düğüm kaç öğe verirse versin tek kez çalışır
    #  * insert: gelen HER öğeyi ekler (çoklu mesaj kaydı için)
    def _mongo(self, name, params, pos, always=False, once=True):
        node = {"name": name, "type": "n8n-nodes-base.mongoDb", "typeVersion": 1.2,
                "position": pos, "onError": "continueErrorOutput", "credentials": CRED_MONGO,
                "parameters": params}
        if always:
            node["alwaysOutputData"] = True
        if once:
            node["executeOnce"] = True
        return self.add(node)

    def mongo_find(self, name, coll, query_js, pos, limit=None, sort=None, projection=None):
        opts = {}
        if limit:
            opts["limit"] = limit
        if sort:
            opts["sort"] = json.dumps(sort)
        if projection:
            opts["projection"] = json.dumps(projection)
        return self._mongo(name, {"operation": "find", "collection": coll,
                                  "query": "={{ JSON.stringify(" + query_js + ") }}",
                                  "options": opts}, pos, always=True)

    def mongo_insert(self, name, coll, fields, pos, date_fields=("created_at",)):
        return self._mongo(name, {"operation": "insert", "collection": coll,
                                  "fields": ",".join(fields),
                                  "options": {"dateFields": ",".join(date_fields)}}, pos, once=False)

    def mongo_update(self, name, coll, key, fields, pos, date_fields=()):
        return self._mongo(name, {"operation": "update", "collection": coll, "updateKey": key,
                                  "fields": ",".join(fields),
                                  "options": {"dateFields": ",".join(date_fields)}}, pos)

    def mongo_delete(self, name, coll, query_js, pos):
        return self._mongo(name, {"operation": "delete", "collection": coll,
                                  "query": "={{ JSON.stringify(" + query_js + ") }}"}, pos,
                           always=True)

    def auth(self, prefix, webhook, x, y, r500):
        """Bearer anahtarını doğrular. Dönüş: (oturum düğümü adı, 'geçerli' IF adı).
        IF'in 0. çıkışını endpoint mantığına bağlayın. Kullanıcı:
        $('<oturum düğümü>').first().json.user_id"""
        h = self.code(f"{prefix}: token özeti", AUTH_TOKEN_JS.replace("__WEBHOOK__", webhook),
                      [x, y], on_error=True)
        self.link(webhook, h); self.link(h, r500, 1)
        s = self.mongo_find(f"{prefix}: oturum", "sessions",
                            "{ token_hash: $json.token_hash, expires_ms: { $gt: $json.now_ms } }",
                            [x + 220, y], limit=1)
        self.link(h, s); self.link(s, r500, 1)
        c = self.if_true(f"{prefix}: oturum geçerli mi?", "!!$json.user_id", [x + 440, y])
        self.link(s, c)
        self.link(c, self.respond(f"{prefix}: 401", 401, [x + 660, y + 140], body=UNAUTH_BODY), 1)
        return s, c

    def extract_pdf(self, name, binary_prop, pos):
        """n8n Extract From File (PDF) — çıktı: json.text, json.numpages"""
        return self.add({"name": name, "type": "n8n-nodes-base.extractFromFile", "typeVersion": 1,
                         "position": pos, "onError": "continueErrorOutput",
                         "parameters": {"operation": "pdf", "binaryPropertyName": binary_prop, "options": {}}})

    def http_json(self, name, url, body_expr, pos, timeout_ms=120000):
        return self.add({"name": name, "type": "n8n-nodes-base.httpRequest", "typeVersion": 4.2,
                         "position": pos, "onError": "continueErrorOutput",
                         "parameters": {"method": "POST", "url": url, "sendBody": True,
                                        "specifyBody": "json", "jsonBody": body_expr,
                                        "options": {"timeout": timeout_ms}}})

    # ------------------------------------------------------------ desenler
    def route_result(self, prefix, src, ok, errors, fallback, x, y):
        """src çıktısındaki $json.result'a göre yönlendirir.
        ok: (durum, ad) → yanıt düğümü oluşturur, ya da hazır düğüm adı (str).
        errors: [(hata_kodu, durum, ad), ...] sırayla IF zinciri.
        fallback: (durum, ad) — hiçbir koda uymayan hata."""
        cond = self.if_true(f"{prefix} başarılı mı?", "$json.result.ok", [x, y])
        self.link(src, cond, 0)
        if isinstance(ok, str):
            self.link(cond, ok, 0)
        else:
            self.link(cond, self.respond(ok[1], ok[0], [x + 280, y - 80]), 0)
        prev, out, cx, cy = cond, 1, x + 280, y + 80
        for code, status, rname in errors:
            c = self.if_equals(f"{prefix}: {code}?", "$json.result.error.code", code, [cx, cy])
            self.link(prev, c, out)
            self.link(c, self.respond(rname, status, [cx + 280, cy - 60]), 0)
            prev, out, cx, cy = c, 1, cx + 280, cy + 80
        self.link(prev, self.respond(fallback[1], fallback[0], [cx, cy]), out)

    def to_json(self):
        return {"name": self.name, "nodes": self.nodes, "connections": self.connections,
                "settings": {"executionOrder": "v1"}, "pinData": {}}

    def save(self, path):
        self.validate()
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.to_json(), f, ensure_ascii=False, indent=2)

    # ------------------------------------------------------------ doğrulama
    def validate(self):
        names = {n["name"]: n for n in self.nodes}
        for src, c in self.connections.items():
            assert src in names, f"bilinmeyen kaynak: {src}"
            for outs in c["main"]:
                for e in outs:
                    assert e["node"] in names, f"bilinmeyen hedef: {e['node']}"
        # Webhook'tan erişilen her uç bir yanıt düğümü olmalı (döngüler dahil)
        def walk(name, seen):
            if name in seen:
                return
            seen = seen | {name}
            nxt = [e["node"] for o in self.connections.get(name, {"main": []})["main"] for e in o]
            if not nxt:
                assert names[name]["type"].endswith("respondToWebhook"), f"yanıtsız uç: {name}"
            for n in nxt:
                walk(n, seen)
        for n in self.nodes:
            if n["type"].endswith(".webhook"):
                walk(n["name"], set())
        # Hata çıkışı olan her düğümün 2. çıkışı bağlı olmalı
        for n in self.nodes:
            if n.get("onError") == "continueErrorOutput":
                outs = self.connections.get(n["name"], {"main": []})["main"]
                assert len(outs) >= 2 and outs[1], f"hata çıkışı bağlı değil: {n['name']}"

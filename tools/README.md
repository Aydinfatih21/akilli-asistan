# Geliştirici araçları

## `n8n-gen/` — n8n iş akışı üreticisi ve simülatörü

`n8n/workflows/*.json` dosyaları elle düzenlenmez; buradaki kaynaktan üretilir.

| Dosya | Görev |
|---|---|
| `n8nlib.py` | Düğüm oluşturucular (webhook, MongoDB, IF, Code, HTTP, yanıt), oturum doğrulama deseni ve yapı kontrolleri (her yol bir yanıtla bitiyor mu, her hata çıkışı bağlı mı) |
| `gen_mongo.py` | `00-auth`, `10-courses`, `01-chat` |
| `gen_mongo2.py` | `02-notes`, `03-quiz-generate`, `04-quiz-evaluate`, `05-stats`; Ollama çağrısı + doğrulama + 3 deneme döngüsü |
| `js/*.js` | Code düğümlerinin JavaScript'i (doğrulama, prompt, puanlama, öneri, istatistik) |
| `test/sim.mjs` | Mini n8n simülatörü: workflow JSON'larını gerçek Code düğümü kodu ve ifadelerle, bellek-içi MongoDB ve sahte Ollama üzerinde çalıştırır |
| `test/sim_test*.mjs` | 135 senaryo |

```bash
python tools/n8n-gen/build.py          # n8n/workflows/*.json dosyalarını üretir
node tools/n8n-gen/test/run-all.mjs    # 135 senaryoyu çalıştırır
```

Gereksinimler: Python 3.10+, Node.js 18+ (ek paket gerekmez).

Üretilen dosyalarda MongoDB credential kimliği yer tutucudur. n8n'e içe aktarmadan önce:
`powershell -ExecutionPolicy Bypass -File scripts\set-credential-id.ps1 -Id <KIMLIK>`

### Gerçek n8n'de öğrenilen kurallar

- Durum kodları ifadeyle değil, **IF düğümü + sabit kodlu yanıt düğümleriyle** verilir
  (ifadeyle verilen kod, başında boşluk kalırsa metin sayılıp reddediliyor).
- Yanıtlar `Text` + `Content-Type: application/json` olarak döner; n8n gövdeyi yeniden ayrıştırmaya çalışmaz.
- MongoDB `find` düğümlerinde **Always Output Data** açıktır: sonuç yoksa akış durmaz, boş öğe gelir.
- Önceki düğüm birden fazla öğe üretse de MongoDB okuma düğümleri **Execute Once** ile bir kez çalışır.
- Uygulama kimliği `id` alanıdır (UUID); n8n'in `_id` → ObjectId dönüşümüne takılmamak için `_id` kullanılmaz.

## `assets/`

- `make_icon.py` — uygulama ikonunu çizer (`mobile/assets/icon/`)
- `make_architecture.py` — mimari diyagramı çizer (`docs/architecture.png`)
- `make_sample_pdf.py` — demo ve PDF testi için örnek not PDF'i üretir (`docs/ornek-notlar/turev.pdf`, reportlab gerekir)

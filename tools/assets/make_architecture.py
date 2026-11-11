"""Sistem mimarisi diyagramı (docs/architecture.png)."""
from PIL import Image, ImageDraw, ImageFont

W, H = 1900, 1120
img = Image.new("RGB", (W, H), "white")
d = ImageDraw.Draw(img)
F = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
f_title = ImageFont.truetype(FB, 34)
f_head = ImageFont.truetype(FB, 24)
f_box = ImageFont.truetype(FB, 20)
f_txt = ImageFont.truetype(F, 17)
f_small = ImageFont.truetype(F, 15)

INK, MUTED = (33, 37, 41), (90, 96, 110)
INDIGO, INDIGO_BG = (59, 91, 219), (234, 238, 255)
GREEN, GREEN_BG = (24, 128, 72), (230, 246, 237)
ORANGE, ORANGE_BG = (199, 102, 18), (255, 242, 228)
STAR_BG = (255, 248, 214)

def box(x, y, w, h, fill, outline, r=16, width=2):
    d.rounded_rectangle([x, y, x + w, y + h], radius=r, fill=fill, outline=outline, width=width)

def text(x, y, s, font, fill=INK, anchor="la"):
    d.text((x, y), s, font=font, fill=fill, anchor=anchor)

def arrow(x1, y1, x2, y2, color=INK, label=None, label_dy=-22, both=False):
    d.line([x1, y1, x2, y2], fill=color, width=3)
    def head(xa, ya, xb, yb):
        import math
        a = math.atan2(yb - ya, xb - xa)
        L = 14
        p1 = (xb - L * math.cos(a - 0.4), yb - L * math.sin(a - 0.4))
        p2 = (xb - L * math.cos(a + 0.4), yb - L * math.sin(a + 0.4))
        d.polygon([(xb, yb), p1, p2], fill=color)
    head(x1, y1, x2, y2)
    if both:
        head(x2, y2, x1, y1)
    if label:
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2 + label_dy
        for i, line in enumerate(label.split("\n")):
            text(mx, my + i * 20, line, f_small, MUTED, anchor="mm")

text(W / 2, 40, "Akıllı Ders ve Soru Asistanı — Sistem Mimarisi", f_title, anchor="mm")

# ---------------------------------------------------------------- Flutter
fx, fy, fw, fh = 40, 110, 420, 900
box(fx, fy, fw, fh, INDIGO_BG, INDIGO, r=22)
text(fx + fw / 2, fy + 32, "Android uygulaması", f_head, INDIGO, anchor="mm")
text(fx + fw / 2, fy + 62, "Flutter · Provider", f_txt, MUTED, anchor="mm")
screens = ["Giriş / kayıt", "Dersler (ekle · düzenle · sil)", "Notlar · TXT / PDF yükleme",
           "Özet · hap bilgi kartları", "Test çözme · sonuç · öneri", "Sohbet (Markdown)",
           "İstatistik · tekrarlayan hata", "Ayarlar (tema · model)"]
for i, s in enumerate(screens):
    y = fy + 100 + i * 62
    box(fx + 30, y, fw - 60, 48, "white", INDIGO, r=12, width=1)
    text(fx + 50, y + 24, s, f_txt, INK, anchor="lm")
y = fy + 100 + len(screens) * 62 + 14
box(fx + 30, y, fw - 60, 120, (220, 227, 255), INDIGO, r=12, width=2)
text(fx + 50, y + 22, "ApiClient", f_box, INDIGO, anchor="lm")
for i, s in enumerate(["JSON zarfı {ok, data | error}", "Türkçe hata mesajları", "Bearer token → güvenli depo"]):
    text(fx + 50, y + 54 + i * 22, "• " + s, f_small, INK, anchor="lm")

# ---------------------------------------------------------------- n8n
nx, ny, nw, nh = 640, 110, 560, 900
box(nx, ny, nw, nh, ORANGE_BG, ORANGE, r=22)
text(nx + nw / 2, ny + 32, "n8n  :5678", f_head, ORANGE, anchor="mm")
text(nx + nw / 2, ny + 62, "webhook + iş akışları · 7 workflow", f_txt, MUTED, anchor="mm")
wfs = [("00-auth", "kayıt · giriş · çıkış (scrypt, SHA-256 token)", False),
       ("10-courses", "ders listesi · ekle · düzenle · sil", False),
       ("01-chat", "soru-cevap · ders notu bağlamı · geçmiş", True),
       ("02-notes", "not kaydı · PDF metni · özet · hap bilgi", True),
       ("03-quiz-generate", "JSON şemalı test · dengeli şıklar", True),
       ("04-quiz-evaluate", "kodla puanlama · geçmiş analizi · öneri", True),
       ("05-stats", "ders/konu başarısı · tekrarlayan hata", False)]
for i, (name, desc, star) in enumerate(wfs):
    y = ny + 100 + i * 96
    box(nx + 30, y, nw - 60, 80, STAR_BG if star else "white", ORANGE, r=12, width=2 if star else 1)
    text(nx + 50, y + 26, ("★ " if star else "") + name, f_box, INK, anchor="lm")
    text(nx + 50, y + 56, desc, f_small, MUTED, anchor="lm")
text(nx + nw / 2, ny + nh - 34, "★ PDF'teki 4 zorunlu iş akışı", f_small, ORANGE, anchor="mm")

# ---------------------------------------------------------------- MongoDB
mx, my, mw, mh = 1380, 110, 480, 400
box(mx, my, mw, mh, GREEN_BG, GREEN, r=22)
text(mx + mw / 2, my + 32, "MongoDB  :27017", f_head, GREEN, anchor="mm")
text(mx + mw / 2, my + 62, "uygulama verisi", f_txt, MUTED, anchor="mm")
for i, s in enumerate(["users · sessions (TTL)", "courses · notes", "conversations · messages",
                       "quizzes (doğru cevaplar burada)", "quiz_attempts · study_plans"]):
    text(mx + 36, my + 110 + i * 34, "▪ " + s, f_txt, INK, anchor="lm")
text(mx + 36, my + 300, "$jsonSchema doğrulaması", f_small, GREEN, anchor="lm")
text(mx + 36, my + 324, "tekil indeksler · user_id ile sahiplik", f_small, GREEN, anchor="lm")
text(mx + 36, my + 348, "bir test bir kez teslim edilir", f_small, GREEN, anchor="lm")

# ---------------------------------------------------------------- Ollama
ox, oy, ow, oh = 1380, 610, 480, 400
box(ox, oy, ow, oh, INDIGO_BG, INDIGO, r=22)
text(ox + ow / 2, oy + 32, "Ollama  :11434 (GPU)", f_head, INDIGO, anchor="mm")
text(ox + ow / 2, oy + 62, "yerel dil modelleri", f_txt, MUTED, anchor="mm")
box(ox + 30, oy + 95, ow - 60, 70, "white", INDIGO, r=12, width=1)
text(ox + 50, oy + 118, "gemma3:4b", f_box, INK, anchor="lm")
text(ox + 50, oy + 146, "Türkçe anlatım: özet · öneri · genel sohbet", f_small, MUTED, anchor="lm")
box(ox + 30, oy + 180, ow - 60, 70, "white", INDIGO, r=12, width=1)
text(ox + 50, oy + 203, "qwen2.5:7b", f_box, INK, anchor="lm")
text(ox + 50, oy + 231, "matematik · kod · formül yoğun notlar", f_small, MUTED, anchor="lm")
for i, s in enumerate(["Otomatik model seçimi (soruya göre)", "JSON şeması (format) · num_ctx 8192",
                       "Doğrulama: şema · Türkçe · kurallar → 3 deneme"]):
    text(ox + 36, oy + 290 + i * 28, "• " + s, f_small, INK, anchor="lm")

# ---------------------------------------------------------------- oklar
arrow(fx + fw, 560, nx, 560, label="HTTP POST\n/webhook/… + token", label_dy=-34, both=True)
arrow(nx + nw, 310, mx, 310, label="find · insert\nupdate · delete", label_dy=-34, both=True)
arrow(nx + nw, 810, ox, 810, label="/api/chat\n(stream: false)", label_dy=-34, both=True)

text(W / 2, H - 40, "Docker Compose: mongo · ollama · ollama-init (model indirme) · n8n — tek komut: docker compose up -d",
     f_txt, MUTED, anchor="mm")
import os
img.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "architecture.png"), optimize=True)
print("diyagram yazıldı")

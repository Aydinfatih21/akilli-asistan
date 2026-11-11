"""Özgün uygulama ikonu: indigo→mor degrade yuvarlak kare, açık kitap ve yapay zekâ yıldızı."""
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # 4x çizip küçült (kenar yumuşatma)

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def gradient(size):
    top, bottom = (59, 91, 219), (112, 72, 232)  # #3B5BDB → #7048E8
    g = Image.new("RGB", (size, size))
    px = g.load()
    for y in range(size):
        for x in range(size):
            t = (x * 0.35 + y * 0.65) / size
            px[x, y] = lerp(top, bottom, min(1, t))
    return g

def book_and_spark(d, cx, cy, w, color):
    """Açık kitap (iki sayfa) + sağ üstte dört köşeli yıldız."""
    h = w * 0.62
    spine_top, spine_bot = (cx, cy - h * 0.38), (cx, cy + h * 0.50)
    # sol sayfa
    d.polygon([spine_top, (cx - w * 0.50, cy - h * 0.50), (cx - w * 0.50, cy + h * 0.38), spine_bot], fill=color)
    # sağ sayfa
    d.polygon([spine_top, (cx + w * 0.50, cy - h * 0.50), (cx + w * 0.50, cy + h * 0.38), spine_bot], fill=color)
    # sırt çizgisi (arka plan rengiyle ince boşluk)
    gap = w * 0.022
    d.polygon([(cx - gap, spine_top[1]), (cx + gap, spine_top[1]), (cx + gap, spine_bot[1]), (cx - gap, spine_bot[1])],
              fill=(86, 80, 226))
    # yıldız
    sx, sy, r = cx + w * 0.40, cy - h * 0.98, w * 0.17
    k = r * 0.22
    d.polygon([(sx, sy - r), (sx + k, sy - k), (sx + r, sy), (sx + k, sy + k),
               (sx, sy + r), (sx - k, sy + k), (sx - r, sy), (sx - k, sy - k)], fill=color)
    sx2, sy2, r2 = sx - w * 0.30, sy - r * 0.35, r * 0.45
    k2 = r2 * 0.25
    d.polygon([(sx2, sy2 - r2), (sx2 + k2, sy2 - k2), (sx2 + r2, sy2), (sx2 + k2, sy2 + k2),
               (sx2, sy2 + r2), (sx2 - k2, sy2 + k2), (sx2 - r2, sy2), (sx2 - k2, sy2 - k2)], fill=color)

def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m

import os
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "mobile", "assets", "icon")

# 1) Tam ikon (eski Android, uygulama içi logo)
bg = gradient(S // 4).resize((S, S), Image.BICUBIC)
icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
icon.paste(bg, (0, 0), rounded_mask(S, int(S * 0.23)))
d = ImageDraw.Draw(icon)
book_and_spark(d, S * 0.5, S * 0.58, S * 0.58, (255, 255, 255, 255))
icon.resize((1024, 1024), Image.LANCZOS).save(f"{out}/app_icon.png")

# 2) Uyarlanabilir ikon ön planı (şeffaf, güvenli alan için küçük)
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(fg)
book_and_spark(d, S * 0.5, S * 0.56, S * 0.40, (255, 255, 255, 255))
fg.resize((1024, 1024), Image.LANCZOS).save(f"{out}/app_icon_foreground.png")

print("ikonlar yazıldı")

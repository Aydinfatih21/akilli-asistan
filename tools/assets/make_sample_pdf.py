"""Demo ve PDF yükleme testi için örnek not PDF'i üretir: python tools/assets/make_sample_pdf.py
Metin docs/demo-senaryosu.md'deki örnek nottan alınır."""
import os
import re

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer

root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
md = open(os.path.join(root, "docs", "demo-senaryosu.md"), encoding="utf-8").read()
title = re.search(r"\*\*Başlık:\*\* (.+)", md).group(1).strip()
body = re.search(r"## Örnek not.*?```\n(.*?)```", md, re.S).group(1).strip()
paras = [p.strip() for p in body.split("\n\n") if p.strip()]

for name, file in (("DejaVu", "DejaVuSans.ttf"), ("DejaVu-Bold", "DejaVuSans-Bold.ttf")):
    pdfmetrics.registerFont(TTFont(name, f"/usr/share/fonts/truetype/dejavu/{file}"))
h = ParagraphStyle("h", fontName="DejaVu-Bold", fontSize=18, leading=24, spaceAfter=14)
p = ParagraphStyle("p", fontName="DejaVu", fontSize=11.5, leading=17, spaceAfter=10)

story = [Paragraph(title, h)]
for i, t in enumerate(paras):
    if i == len(paras) // 2:
        story.append(PageBreak())  # iki sayfalı olsun
    story.append(Paragraph(t, p))
story.append(Spacer(1, 12))

out = os.path.join(root, "docs", "ornek-notlar", "turev.pdf")
SimpleDocTemplate(out, pagesize=A4, title=title, author="Akıllı Ders Asistanı",
                  leftMargin=60, rightMargin=60, topMargin=60, bottomMargin=60).build(story)
print("yazıldı:", out)

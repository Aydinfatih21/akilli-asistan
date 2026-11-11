// PDF'ten çıkan metni temizler: satır sonu tireleri, fazla boşluk ve boş satırlar.
const r = $input.first().json;
const name = $('PDF: dosya').first().json.file_name;
let text = String(r.text || '')
  .replace(/\r\n?/g, '\n')
  .replace(/(\p{L})-\n(\p{L})/gu, '$1$2')   // satır sonunda bölünmüş kelimeler: "geliş-\ntirilen"
  .replace(/[ \t]+/g, ' ')
  .replace(/ *\n */g, '\n')
  .replace(/\n{3,}/g, '\n\n')
  .replace(/([^.!?:;\n])\n(?!\n)/g, '$1 ')  // paragraf içindeki satır kırılımları: PDF satırları birleşir
  .trim();
if (text.length < 20) {
  return [{ json: { valid: false, response: { ok: false, error: { code: 'PDF_NO_TEXT',
    message: 'PDF\'te seçilebilir metin bulunamadı. Taranmış (resim) bir belge olabilir; metni elle yapıştırmayı deneyin.' } } } }];
}
return [{
  json: {
    valid: true,
    response: {
      ok: true,
      data: {
        text,
        characters: text.length,
        pages: Number(r.numpages || r.numPages || 0) || null,
        file_name: name,
        title: name.replace(/\.pdf$/i, ''),
      },
    },
  },
}];

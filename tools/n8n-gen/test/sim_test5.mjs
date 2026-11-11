// PDF yükleme: /notes/extract-pdf (çok parçalı form → Extract From File → metin temizleme)
import { api } from './sim.mjs';
let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log('GEÇTİ', m); } else { fail++; console.log('KALDI', m); } };
const st = (r, code, m, extra = () => true) => { let good = r.status === code; try { good = good && !!extra(r.json); } catch { good = false; } ok(good, `${m} (${r.status})`); if (!good) console.log('      ', r.text); return r.json; };
const uniq = Date.now();
const A = api('auth/register', { name: 'p', email: `p${uniq}@ornek.com`, password: 'gizli123' }).json.data.token;
const file = (content, fileName = 'Türev Notları.pdf', mimeType = 'application/pdf') =>
  ({ file: { data: Buffer.from(content, 'utf8').toString('base64'), fileName, mimeType } });
const PDF = '%PDF %%PAGES=3\nTürev, bir fonksiyonun anlık değişim hızını gös-\nterir.   Zincir   kuralı\n\n\n\nbileşke fonksiyonlar içindir.\r\n';

let j = st(api('notes/extract-pdf', {}, A, file(PDF)), 200, 'geçerli PDF → metin');
ok(j?.data?.text === 'Türev, bir fonksiyonun anlık değişim hızını gösterir. Zincir kuralı\n\nbileşke fonksiyonlar içindir.', 'satır sonu tiresi birleşti, boşluklar temizlendi');
ok(j?.data?.pages === 3 && j?.data?.title === 'Türev Notları', 'sayfa sayısı ve dosya adından başlık');
ok(j?.data?.characters === j?.data?.text.length, 'karakter sayısı');
j = api('notes/extract-pdf', {}, A, file('%PDF %%PAGES=1\nGeometrik olarak türev,\nteğet doğrunun eğimidir.\nf(x) gösterimi kullanılır.')).json;
ok(j?.data?.text === 'Geometrik olarak türev, teğet doğrunun eğimidir.\nf(x) gösterimi kullanılır.', 'paragraf içi satır kırılımları birleşti, cümle sonu korundu');
// n8n, alan adını sürüme göre farklı adlandırabilir: ilk dosya alınır
j = st(api('notes/extract-pdf', {}, A, { data0: file(PDF).file }), 200, 'farklı alan adı da kabul');
st(api('notes/extract-pdf', {}, A), 400, 'dosya yok → 400', (x) => x.error.code === 'VALIDATION_ERROR');
st(api('notes/extract-pdf', {}, A, file('düz metin', 'not.txt', 'text/plain')), 400, 'PDF olmayan dosya → 400');
st(api('notes/extract-pdf', {}, A, file('bozuk içerik', 'bozuk.pdf')), 422, 'bozuk PDF → 422 PDF_UNREADABLE', (x) => x.error.code === 'PDF_UNREADABLE');
st(api('notes/extract-pdf', {}, A, file('%PDF %%PAGES=2\n  \n ')), 422, 'taranmış (metinsiz) PDF → 422 PDF_NO_TEXT', (x) => x.error.code === 'PDF_NO_TEXT');
st(api('notes/extract-pdf', {}, undefined, file(PDF)), 401, 'token yok → 401');
st(api('notes/extract-pdf', {}, 'sahte', file(PDF)), 401, 'geçersiz token → 401');

console.log(`\nSONUÇ: ${pass} geçti, ${fail} kaldı`);
process.exit(fail ? 1 : 0);

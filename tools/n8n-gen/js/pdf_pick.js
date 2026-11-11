// Yüklenen dosyayı bulur ve "pdf" adlı ikili alana taşır (n8n çok parçalı formda alan adını
// sürüme göre farklı adlandırabildiği için ilk dosya alınır).
const req = $('POST /notes/extract-pdf').first();
const files = req.binary || {};
const key = Object.keys(files)[0];
const fail = (message) => [{ json: { valid: false, response: { ok: false, error: { code: 'VALIDATION_ERROR', message } } } }];
if (!key) return fail('PDF dosyası gönderilmedi.');
const file = files[key];
const name = String(file.fileName || '');
const isPdf = /\.pdf$/i.test(name) || String(file.mimeType || '').includes('pdf');
if (!isPdf) return fail('Yalnızca PDF dosyası yüklenebilir.');
return [{ json: { valid: true, file_name: name }, binary: { pdf: file } }];

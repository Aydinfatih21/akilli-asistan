// Yeni kullanıcı için oturum anahtarı üretir. Veritabanına yalnızca SHA-256 özeti yazılır.
const crypto = require('crypto');
const u = $('Kayıt: doğrula').first().json.user;
const token = crypto.randomBytes(32).toString('hex');
const now = Date.now();
const expires = now + 30 * 24 * 3600 * 1000; // 30 gün
return [{
  json: {
    token_hash: crypto.createHash('sha256').update(token).digest('hex'),
    user_id: u.id,
    created_at: new Date(now).toISOString(),
    expires_at: new Date(expires).toISOString(),
    expires_ms: expires,
    response: { ok: true, data: { token, user: { id: u.id, name: u.name, email: u.email } } },
  },
}];

// Şifreyi kayıtlı scrypt özetiyle karşılaştırır; doğruysa oturum anahtarı üretir.
const crypto = require('crypto');
const b = $('POST /auth/login').first().json.body || {};
const u = $input.first().json || {};
const password = String(b.password ?? '');

let ok = false;
if (u.id && typeof u.password_hash === 'string') {
  const [alg, salt, hash] = u.password_hash.split('$');
  if (alg === 'scrypt' && salt && hash) {
    const calc = crypto.scryptSync(password, salt, 64);
    const expected = Buffer.from(hash, 'hex');
    ok = expected.length === calc.length && crypto.timingSafeEqual(calc, expected);
  }
}
if (!ok) {
  return [{ json: { valid: false, response: { ok: false, error: { code: 'INVALID_CREDENTIALS', message: 'E-posta veya şifre hatalı.' } } } }];
}

const token = crypto.randomBytes(32).toString('hex');
const now = Date.now();
const expires = now + 30 * 24 * 3600 * 1000; // 30 gün
return [{
  json: {
    valid: true,
    token_hash: crypto.createHash('sha256').update(token).digest('hex'),
    user_id: u.id,
    created_at: new Date(now).toISOString(),
    expires_at: new Date(expires).toISOString(),
    expires_ms: expires,
    response: { ok: true, data: { token, user: { id: u.id, name: u.name, email: u.email } } },
  },
}];

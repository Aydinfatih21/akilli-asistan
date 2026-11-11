// Kayıt isteğini doğrular ve kullanıcı belgesini hazırlar (şifre scrypt ile özetlenir).
const crypto = require('crypto');
const b = $('POST /auth/register').first().json.body || {};
const name = String(b.name ?? '').trim().replace(/\s+/g, ' ');
const email = String(b.email ?? '').trim().toLowerCase();
const password = String(b.password ?? '');
const fail = (message) => [{ json: { valid: false, response: { ok: false, error: { code: 'VALIDATION_ERROR', message } } } }];

if (!name || name.length > 100) return fail('Ad 1-100 karakter arasında olmalıdır.');
if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return fail('Geçerli bir e-posta adresi girin.');
if (password.length < 6 || password.length > 72) return fail('Şifre en az 6, en fazla 72 karakter olmalıdır.');

const salt = crypto.randomBytes(16).toString('hex');
const hash = crypto.scryptSync(password, salt, 64).toString('hex');
return [{
  json: {
    valid: true,
    user: {
      id: crypto.randomUUID(),
      name,
      email,
      password_hash: `scrypt$${salt}$${hash}`,
      created_at: new Date().toISOString(),
    },
  },
}];

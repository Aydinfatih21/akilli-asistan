// =====================================================================
// MongoDB başlangıç betiği (mongosh) — veritabanı: asistan
// Yalnızca mongo_data volume'ü İLK oluşturulduğunda otomatik çalışır.
// Tekrar çalıştırılabilir: koleksiyon varsa şema doğrulamasını günceller,
// indeksler zaten varsa dokunmaz. Elle çalıştırma:
//   docker compose exec mongo sh -c 'mongosh -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase admin asistan --quiet /docker-entrypoint-initdb.d/01-init.js'
//
// Tasarım:
//   * Her belgenin uygulama kimliği "id" alanıdır (UUID metni, tekil indeks).
//     MongoDB'nin kendi _id'si iç kullanım içindir, API'de görünmez.
//   * Tüm sorgular user_id ile filtrelenir: kullanıcı başkasının verisini göremez.
//   * Şema doğrulaması ($jsonSchema) hatalı belgeyi veritabanı seviyesinde reddeder.
//   * sessions.expires_at TTL indeksi: süresi dolan oturumlar kendiliğinden silinir.
//   * Test soruları quizzes belgesine gömülüdür (doğru cevap sunucuda kalır).
//   * Bir test bir kez teslim edilir: quiz_attempts.quiz_id tekil.
// =====================================================================

db = db.getSiblingDB('asistan');

const str = { bsonType: 'string' };
const nonEmpty = (max) => ({ bsonType: 'string', minLength: 1, maxLength: max });
const date = { bsonType: ['date', 'string'] };          // n8n tarih alanını Date'e çevirir
const strOrNull = { bsonType: ['string', 'null'] };
const num = { bsonType: 'number' };

function collection(name, required, properties, indexes) {
  const validator = { $jsonSchema: { bsonType: 'object', required, properties } };
  if (db.getCollectionNames().includes(name)) {
    db.runCommand({ collMod: name, validator, validationLevel: 'strict', validationAction: 'error' });
  } else {
    db.createCollection(name, { validator, validationLevel: 'strict', validationAction: 'error' });
  }
  for (const [keys, opts] of indexes) db[name].createIndex(keys, opts || {});
  print(`  ${name}: hazır`);
}

print('asistan veritabanı hazırlanıyor...');

collection('users',
  ['id', 'name', 'email', 'password_hash', 'created_at'],
  {
    id: str,
    name: nonEmpty(100),
    email: { bsonType: 'string', pattern: '^[^@A-Z\\s]+@[^@A-Z\\s]+\\.[^@A-Z\\s]+$' },  // küçük harf
    password_hash: { bsonType: 'string', pattern: '^scrypt\\$' },
    created_at: date,
  },
  [[{ id: 1 }, { unique: true }], [{ email: 1 }, { unique: true }]]);

collection('sessions',
  ['token_hash', 'user_id', 'expires_at', 'expires_ms'],
  { token_hash: str, user_id: str, created_at: date, expires_at: date, expires_ms: num },
  [[{ token_hash: 1 }, { unique: true }], [{ user_id: 1 }], [{ expires_at: 1 }, { expireAfterSeconds: 0 }]]);

collection('courses',
  ['id', 'user_id', 'name', 'created_at'],
  { id: str, user_id: str, name: nonEmpty(100), created_at: date },
  [[{ id: 1 }, { unique: true }], [{ user_id: 1, name: 1 }, { unique: true }]]);

collection('notes',
  ['id', 'user_id', 'course_id', 'title', 'content', 'source', 'created_at'],
  {
    id: str, user_id: str, course_id: str,
    title: nonEmpty(200),
    content: { bsonType: 'string', minLength: 20, maxLength: 50000 },
    source: { enum: ['text', 'txt', 'pdf'] },
    summary: { bsonType: ['object', 'null'] },
    created_at: date,
  },
  [[{ id: 1 }, { unique: true }], [{ user_id: 1, course_id: 1, created_at: -1 }]]);

collection('conversations',
  ['id', 'user_id', 'title', 'created_at', 'updated_at'],
  { id: str, user_id: str, course_id: strOrNull, title: nonEmpty(100), created_at: date, updated_at: date },
  [[{ id: 1 }, { unique: true }], [{ user_id: 1, updated_at: -1 }]]);

collection('messages',
  ['id', 'conversation_id', 'user_id', 'role', 'content', 'seq', 'created_at'],
  {
    id: str, conversation_id: str, user_id: str,
    role: { enum: ['user', 'assistant'] },
    content: { bsonType: 'string', minLength: 1 },
    model: strOrNull, seq: num, created_at: date,
  },
  [[{ id: 1 }, { unique: true }], [{ conversation_id: 1, seq: 1 }], [{ user_id: 1 }]]);

collection('quizzes',
  ['id', 'user_id', 'note_id', 'course_id', 'title', 'model', 'difficulty', 'questions', 'created_at'],
  {
    id: str, user_id: str, note_id: str, course_id: str, title: str, model: str,
    difficulty: { enum: ['easy', 'medium', 'hard'] },
    questions: {
      bsonType: 'array', minItems: 1,
      items: {
        bsonType: 'object',
        required: ['id', 'question', 'options', 'correct_index', 'explanation', 'topic'],
        properties: {
          id: str, question: nonEmpty(1000), explanation: str, topic: nonEmpty(100),
          options: { bsonType: 'array', minItems: 4, maxItems: 4, items: nonEmpty(300) },
          correct_index: { bsonType: 'number', minimum: 0, maximum: 3 },
        },
      },
    },
    created_at: date,
  },
  [[{ id: 1 }, { unique: true }], [{ user_id: 1, note_id: 1, created_at: -1 }]]);

collection('quiz_attempts',
  ['id', 'quiz_id', 'user_id', 'course_id', 'score', 'total', 'percent', 'answers', 'created_at'],
  {
    id: str, quiz_id: str, user_id: str, course_id: str,
    score: { bsonType: 'number', minimum: 0 }, total: { bsonType: 'number', minimum: 1 },
    percent: { bsonType: 'number', minimum: 0, maximum: 100 },
    answers: { bsonType: 'array' },
    recommendation: strOrNull,
    recommendation_source: { enum: ['ai', 'fallback', null] },
    created_at: date,
  },
  [[{ id: 1 }, { unique: true }], [{ quiz_id: 1 }, { unique: true }], [{ user_id: 1, created_at: -1 }]]);

collection('study_plans',
  ['id', 'user_id', 'content', 'model', 'created_at'],
  { id: str, user_id: str, content: { bsonType: 'object' }, model: str, created_at: date },
  [[{ id: 1 }, { unique: true }], [{ user_id: 1, created_at: -1 }]]);

print('Tamamlandı. Koleksiyonlar: ' + db.getCollectionNames().sort().join(', '));

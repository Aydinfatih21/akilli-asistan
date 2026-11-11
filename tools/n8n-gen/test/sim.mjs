// Mini n8n simülatörü: workflow JSON'larını gerçek Code/ifade koduyla, bellek-içi MongoDB
// ve sahte Ollama ile çalıştırır. Kullanım: node sim.mjs <workflow_klasörü>
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
const dir = process.env.WF_DIR || process.argv[2] || fileURLToPath(new URL('../../../n8n/workflows', import.meta.url));

// ------------------------------------------------------------------ bellek-içi MongoDB
const UNIQUE = { users: [['id'], ['email']], sessions: [['token_hash']], courses: [['id'], ['user_id', 'name']],
  conversations: [['id']], messages: [['id']] };
const db = {};
const coll = (n) => (db[n] ??= []);
const match = (doc, q) => Object.entries(q).every(([k, v]) => {
  if (v && typeof v === 'object' && !Array.isArray(v)) {
    if ('$gt' in v) return doc[k] > v.$gt;
    if ('$ne' in v) return doc[k] !== v.$ne;
    if ('$in' in v) return v.$in.includes(doc[k]);
    throw new Error('desteklenmeyen operatör: ' + JSON.stringify(v));
  }
  return doc[k] === v;
});
const mongo = {
  find(c, q, o = {}) {
    let r = coll(c).filter((d) => match(d, q));
    if (o.sort) { const s = JSON.parse(o.sort); const [[k, dir]] = Object.entries(s);
      r = [...r].sort((a, b) => (a[k] > b[k] ? 1 : a[k] < b[k] ? -1 : 0) * dir); }
    if (o.limit) r = r.slice(0, o.limit);
    if (o.projection) { const p = Object.keys(JSON.parse(o.projection));
      r = r.map((d) => Object.fromEntries(p.filter((k) => k in d).map((k) => [k, d[k]]))); }
    return r.map((d) => JSON.parse(JSON.stringify(d))); // n8n öğeleri JSON'a çevrilir (Date → ISO)
  },
  insert(c, doc) {
    for (const keys of UNIQUE[c] || []) {
      if (coll(c).some((d) => keys.every((k) => d[k] === doc[k]))) throw new Error(`E11000 duplicate key ${c} ${keys}`);
    }
    coll(c).push(doc);
  },
};

// ------------------------------------------------------------------ sahte Ollama
export const ollama = { replies: [], requests: [], down: false };

// ------------------------------------------------------------------ yürütücü
const workflows = fs.readdirSync(dir).filter((f) => f.endsWith('.json'))
  .map((f) => JSON.parse(fs.readFileSync(`${dir}/${f}`, 'utf8')));
const ENV = { LLM_MODEL: 'gemma3:4b', LLM_MODEL_REASONING: 'qwen2.5:7b', OLLAMA_URL: 'http://ollama:11434' };

function run(wf, webhookItem, webhookName) {
  const byName = Object.fromEntries(wf.nodes.map((n) => [n.name, n]));
  const runs = {}; // ad → [çıktı dizileri]
  let response = null;
  let curRun = 0;
  const accessor = (name) => {
    const r = runs[name]; if (!r) throw new Error(`$('${name}') henüz çalışmadı`);
    const items = r[r.length - 1][0] || [];
    return { first: () => items[0], last: () => items[items.length - 1], all: () => items };
  };
  const evalExpr = (v, json) => {
    if (typeof v !== 'string' || !v.startsWith('=')) return v;
    const f = (code) => new Function('$json', '$', '$env', '$runIndex', `return (${code});`)(json, accessor, ENV, curRun);
    const m = v.match(/^=\{\{([\s\S]*)\}\}$/);
    if (m && !m[1].includes('}}')) return f(m[1]);
    return v.slice(1).replace(/\{\{([\s\S]*?)\}\}/g, (_, code) => String(f(code)));  // karışık şablon
  };
  const exec = (node, input) => {
    const p = node.parameters; const j = input[0]?.json ?? {};
    curRun = (runs[node.name] || []).length;
    switch (node.type.split('.').pop()) {
      case 'code': {
        const $input = { first: () => input[0], all: () => input, last: () => input[input.length - 1] };
        const out = new Function('$input', '$', '$runIndex', 'require', '$env', p.jsCode)(
          $input, accessor, (runs[node.name] || []).length, require, ENV);
        return [JSON.parse(JSON.stringify(out))];
      }
      case 'mongoDb': {
        const items = node.executeOnce ? input.slice(0, 1) : input;
        let out = [];
        for (const it of items) {
          if (p.operation === 'find') out.push(...mongo.find(p.collection, JSON.parse(evalExpr(p.query, it.json)), p.options));
          else if (p.operation === 'insert') {
            const doc = {}; for (const f of p.fields.split(',')) doc[f] = it.json[f] ?? null;
            for (const f of (p.options.dateFields || '').split(',').filter(Boolean)) {
              if (doc[f] == null || isNaN(new Date(doc[f]))) throw new Error(`geçersiz tarih alanı ${f}`);
              doc[f] = new Date(doc[f]);
            }
            mongo.insert(p.collection, doc); out.push(JSON.parse(JSON.stringify(doc)));
          } else if (p.operation === 'update') {
            const d = coll(p.collection).find((x) => x[p.updateKey] === it.json[p.updateKey]);
            if (d) for (const f of p.fields.split(',')) d[f] = (p.options.dateFields || '').split(',').includes(f) ? new Date(it.json[f]) : it.json[f];
            out.push(it.json);
          } else if (p.operation === 'delete') {
            const q = JSON.parse(evalExpr(p.query, it.json)); const before = coll(p.collection).length;
            db[p.collection] = coll(p.collection).filter((d) => !match(d, q));
            out.push({ deletedCount: before - coll(p.collection).length });
          } else throw new Error('bilinmeyen işlem ' + p.operation);
        }
        out = out.map((json) => ({ json }));
        if (!out.length && node.alwaysOutputData) out = [{ json: {} }];
        return [out];
      }
      case 'if': {
        const c = p.conditions.conditions[0]; const left = evalExpr(c.leftValue, j);
        const op = c.operator; let res;
        if (op.type === 'boolean' && op.operation === 'true') {
          if (typeof left !== 'boolean') throw new Error(`IF ${node.name}: boolean değil (${typeof left})`);
          res = left;
        } else if (op.type === 'string' && op.operation === 'equals') res = String(left) === String(c.rightValue);
        else if (op.type === 'number' && op.operation === 'lt') res = Number(left) < Number(c.rightValue);
        else throw new Error('bilinmeyen IF ' + JSON.stringify(op));
        return res ? [input, []] : [[], input];
      }
      case 'httpRequest': {
        if (ollama.down) throw new Error('connect ECONNREFUSED ollama:11434');
        const url = evalExpr(p.url, j); const body = JSON.parse(evalExpr(p.jsonBody, j));
        ollama.requests.push({ url, body });
        let content;
        if (ollama.replies.length) content = ollama.replies.shift();
        else if (body.format?.properties?.questions) {
          const n = body.format.properties.questions.minItems;
          content = JSON.stringify({ questions: Array.from({ length: n }, (_, i) => ({
            question: `Soru ${i + 1}: Flutter uygulamaları hangi dille yazılır? (${i + 1})`,
            options: ['Java', 'Dart', 'Python', 'C#'], correct_answer: 'Dart',
            explanation: 'Flutter, Dart dilini kullanır.', topic: i % 2 ? 'Dart dili' : 'Widget türleri' })) });
        } else if (body.format?.properties?.short) {
          content = JSON.stringify({ short: 'Flutter, Google tarafından geliştirilen bir arayüz aracıdır.',
            key_points: ['Dart dilini kullanır.', 'Çok platformludur.', 'Arayüz widgetlardan oluşur.'],
            keywords: ['Flutter', 'Dart', 'Widget'],
            flashcards: [{ front: 'Flutter dili', back: 'Dart' }, { front: 'Durumsuz widget', back: 'StatelessWidget' },
              { front: 'Durumlu widget', back: 'StatefulWidget' }, { front: 'Arayüzü yenileme', back: 'setState çağrılır.' }] });
        } else if (body.messages[0].content.includes('kişisel çalışma önerisi')) {
          const topics = [...new Set([...body.messages[1].content.matchAll(/\[([^\]]+)\]/g)].map((m) => m[1]))];
          content = topics.length
            ? `${topics.join(' ve ')} konularını yeniden çalışmalısın. Notlarını tekrar oku ve yanlış soruların açıklamalarını incele.`
            : 'Tüm soruları doğru yanıtladın, harika iş çıkardın. Bir sonraki adımda zor seviyede yeni bir test dene.';
        } else content = 'Bu, Türkçe bir örnek yanıttır ve öneri olarak da yeterince uzundur.';
        return [[{ json: { model: body.model, message: { role: 'assistant', content }, done: true } }]];
      }
      case 'extractFromFile': {
        // Sahte PDF okuyucu: "%PDF" ile başlayan içerikte "%%PAGES=n" ve sonrasındaki metin
        const out = input.map((it) => {
          const b = it.binary?.[p.binaryPropertyName];
          if (!b) throw new Error(`binary alan yok: ${p.binaryPropertyName}`);
          const raw = Buffer.from(b.data, 'base64').toString('utf8');
          if (!raw.startsWith('%PDF')) throw new Error('Invalid PDF structure');
          const m = raw.match(/^%PDF\s*%%PAGES=(\d+)\n([\s\S]*)$/);
          return { json: { numpages: m ? Number(m[1]) : 1, text: m ? m[2] : '' } };
        });
        return [out];
      }
      case 'respondToWebhook': {
        if (response) throw new Error('ikinci yanıt!');
        const code = p.options.responseCode;
        if (!Number.isInteger(code)) throw new Error('durum kodu tam sayı değil');
        response = { status: code, text: evalExpr(p.responseBody, j) };
        return [input];
      }
      default: throw new Error('desteklenmeyen düğüm ' + node.type);
    }
  };
  // n8n v1 sırası: derinlik öncelikli yığın
  const stack = [[webhookName, [webhookItem]]];
  let steps = 0;
  while (stack.length) {
    if (++steps > 200) throw new Error('sonsuz döngü?');
    const [name, input] = stack.pop(); const node = byName[name];
    let outputs;
    if (node.type.endsWith('.webhook')) outputs = [input];
    else {
      try { outputs = exec(node, input); }
      catch (e) {
        if (node.onError === 'continueErrorOutput') outputs = [[], [{ json: { error: { message: e.message } } }]];
        else throw new Error(`${name}: ${e.message}`);
      }
    }
    (runs[name] ??= []).push(outputs);
    const conns = wf.connections[name]?.main || [];
    const next = [];
    conns.forEach((targets, i) => { if (outputs[i]?.length) for (const t of targets) next.push([t.node, outputs[i]]); });
    stack.push(...next.reverse());
  }
  if (!response) throw new Error('yanıt dönmedi');
  return response;
}

export function api(path, body, token, binary) {
  for (const wf of workflows) {
    const w = wf.nodes.find((n) => n.type.endsWith('.webhook') && n.parameters.path === path);
    if (w) {
      const headers = token ? { authorization: `Bearer ${token}` } : {};
      const r = run(wf, { json: { headers, body, params: {}, query: {} }, ...(binary ? { binary } : {}) }, w.name);
      let json = null; try { json = JSON.parse(r.text); } catch {}
      return { status: r.status, json, text: r.text };
    }
  }
  throw new Error('webhook yok: ' + path);
}
export { db };

// Tüm simülatör test setlerini sırayla çalıştırır: node tools/n8n-gen/test/run-all.mjs
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const suites = [
  ['sim_test.mjs', 'Kimlik doğrulama, dersler, soru-cevap'],
  ['sim_test2.mjs', 'Not, özet, test, değerlendirme (canlı demo)'],
  ['sim_test3.mjs', 'Öneri kuralları, soru kalitesi, dengeli şıklar'],
  ['sim_test4.mjs', 'Ders düzenle/sil, otomatik model, geçmiş analizi, istatistik, hap bilgi'],
  ['sim_test5.mjs', 'PDF yükleme, not silme'],
];
let failed = 0;
for (const [file, title] of suites) {
  const r = spawnSync(process.execPath, [path.join(here, file)], { encoding: 'utf8' });
  const summary = (r.stdout.trim().split('\n').pop() || '').trim();
  console.log(`${r.status === 0 ? 'GEÇTİ' : 'KALDI'}  ${title.padEnd(72)} ${summary}`);
  if (r.status !== 0) { failed++; console.log(r.stdout.split('\n').filter((l) => l.startsWith('KALDI')).join('\n')); }
}
process.exit(failed ? 1 : 0);

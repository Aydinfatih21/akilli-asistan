# Model Karşılaştırması ve Otomatik Model Seçimi

Donanım: RTX 4060 Laptop (8 GB VRAM), 32 GB RAM. İki model de VRAM'e tam sığar (`ollama ps` → `100% GPU`).

| Model | Boyut | Bağlam (projede) |
|---|---|---|
| `qwen2.5:7b` | ~4,7 GB | `num_ctx: 8192` |
| `gemma3:4b` | ~3,3 GB | `num_ctx: 8192` |

> **Not:** Aşağıdaki gözlemler geliştirme sırasında aynı not ve aynı promptlarla yapılan **az sayıdaki**
> denemeye dayanır; istatistiksel bir ölçüm değildir. Kararlar bu yüzden yalnızca modele güvenmek yerine
> koddaki doğrulama ve yeniden deneme mekanizmasıyla birlikte verilmiştir.

## 1. Türkçe tutarlılığı

İlk kurulum testinde, dil kuralı olmayan basit bir promptla `qwen2.5:7b` cümlenin ortasında Çinceye geçti:

> Flutter, Google tarafından geliştirilen bir UI köprü kitlesi框架,用于创建跨平台的移动和桌面应用。

Prompta *"Sadece Türkçe yanıt ver, başka dilde karakter kullanma"* kuralı eklendiğinde iki model de
temiz Türkçe üretti; `gemma3:4b`'nin cümleleri daha doğaldı.

**Alınan önlem:** Tüm promptlarda Türkçe kuralı + koddan Türkçe dışı karakter denetimi
(Çince, Japonca, Korece, Kiril). Denetimden geçmeyen çıktı yeniden üretilir (en fazla 3 deneme).

## 2. Test üretimi (aynı Flutter notu, 5 soru, orta zorluk)

| | `qwen2.5:7b` | `gemma3:4b` |
|---|---|---|
| Şemaya uygunluk | ✅ | ✅ |
| Soru kalitesi | 1 soru bozuk: *"Widget'ların hangi temel yapı taşıdır?"* — hem Türkçesi düşük hem cevabı kendi içinde veriyor | 5 sorunun 5'i anlamlı; seçenekler daha açıklayıcı |

**Alınan önlemler:** Prompta "doğru cevabı soru metninde verme" ve "dil bilgisi açısından düzgün yaz"
kuralları eklendi; doğru cevap metnini içeren sorular kodda reddedilip yeniden üretiliyor.

## 3. Kişisel öneri (aynı yanlış cevaplar)

| | `qwen2.5:7b` | `gemma3:4b` |
|---|---|---|
| Zayıf konuları anma | 2 konudan yalnızca 1'ini andı | 3 konunun 3'ünü de andı |
| Biçim | Kısa, ifade biraz yapay ("unuttun gibi") | Uzun (5 paragraf), "Merhaba" ile başladı, %40 puanda "Tebrikler" dedi |
| Süre (puanlama + öneri) | ~6,4 sn | ~9,3 sn |

**Alınan önlemler:** Öneri artık koddan denetleniyor: selamlamayla başlayan, puan %80'in altındayken
"Tebrikler" diyen, 8 cümleden uzun olan veya zayıf konuları anmayan öneri reddedilip yeniden üretiliyor.
3 denemede de olmazsa yanlış konulardan **kural tabanlı yedek öneri** kullanılıyor ve nedeni
`recommendation_issue` alanında dönüyor.

## 4. Karar: soruya göre otomatik seçim

Tek bir model her işte en iyisi değildi. Bu yüzden iş akışları modeli işe göre seçer:

| İş | Model | Gerekçe |
|---|---|---|
| Not özeti, hap bilgi kartları | `gemma3:4b` | Türkçe anlatım kalitesi |
| Kişisel öneri | `gemma3:4b` | Tüm zayıf konuları kapsadı; biçim sorunları kodla denetleniyor |
| Genel sohbet | `gemma3:4b` | Doğal Türkçe |
| Sohbette matematik / kod / sayısal soru | `qwen2.5:7b` | Akıl yürütme ve sembolik ifadelerde daha güçlü |
| Formül yoğun nottan test | `qwen2.5:7b` | Sayısal soru ve seçeneklerde daha isabetli |
| Sözel nottan test | `gemma3:4b` | Daha anlamlı soru ve seçenekler |

Sohbette seçim; sorudaki matematiksel ifadelere (`2x + 3 = 7`, `x^2`, `f(x)`, `√`, kod bloğu) ve
anahtar kelimelere (türev, integral, denklem, algoritma, python, …) göre; testte ise nottaki sembol
yoğunluğuna ve anahtar kelime sayısına göre yapılır. Seçimin nedeni yanıtta döner ve uygulamada her
yanıtın altında görünür (ör. `qwen2.5:7b · matematiksel ifade`). Kullanıcı isterse
**Ayarlar → Gelişmiş** bölümünden modeli elle sabitleyebilir; elle seçim her zaman önceliklidir.

Model adları `.env` dosyasından gelir (`LLM_MODEL`, `LLM_MODEL_2`); kod değiştirmeden başka modellerle
denenebilir.

# Demo Videosu Senaryosu (4-5 dakika)

Hedef: case dokümanındaki canlı demo senaryosunu ve projeyi diğerlerinden ayıran yönleri kısa ve akıcı göstermek.

## Hazırlık (çekimden önce)

- [ ] `docker compose ps` → mongo ve ollama `healthy`, n8n `running`
- [ ] Modelleri ısıt (ilk istek yavaş olmasın): uygulamada bir genel soru ve bir matematik sorusu sor
- [ ] Temiz bir kullanıcıyla başla; "Matematik" dersi ve [türev notu](#örnek-not) hazır olsun
- [ ] Aynı nottan **önceden 1 test** çözülmüş olsun (tekrarlayan hata analizi videoda görünsün)
- [ ] Emülatör dikey, ekran kaydı 1080p; bildirimler kapalı

## Akış

| Süre | Ekran | Anlatım |
|---|---|---|
| 0:00 | `docs/architecture.png` | "Flutter uygulaması yalnızca n8n webhook'larıyla konuşuyor; n8n verileri MongoDB'de tutuyor ve yerel Ollama modellerini çağırıyor. Her şey tek `docker compose up` ile ayağa kalkıyor." |
| 0:25 | Terminal: `docker compose ps` + n8n arayüzünde 7 workflow | "4 zorunlu iş akışı yıldızlı; workflow'lar koddan üretiliyor ve 135 senaryoyla test ediliyor." |
| 0:45 | Uygulama: giriş → ana sayfa | Özet kart, dersler, istatistik simgesi |
| 1:00 | Ders → **Not ekle** → **PDF seç** (metin kutuya dolar) → Kaydet | "PDF'in metni n8n'de çıkarılıp temizleniyor. Zorunlu 2: not özetleme." |
| 1:15 | **Özet çıkar** → hap bilgi kartlarını çevir | "Özet JSON şemasıyla üretiliyor; Türkçe dışı karakter veya eksik alan varsa otomatik yeniden deneniyor." |
| 1:45 | **Testi oluştur** (5 soru, orta) | "Zorunlu 3. Doğru cevaplar telefona hiç gelmiyor, sunucuda saklanıyor; şıklar dengeli dağıtılıyor." |
| 2:15 | Testi çöz, **en az 2 yanlış** yap → Testi bitir | "Zorunlu 4: puanlama kodla yapılıyor, model sadece öneriyi yazıyor." |
| 2:35 | Sonuç ekranı: yüzde, zayıf konular, **Tekrarlayan hata** kutusu, öneri, soru soru inceleme | "Aynı konuda önceki testte de hata yaptığım için sistem bunu ayrıca vurguluyor." |
| 3:05 | İstatistikler ekranı | Tekrarlayan zayıflıklar, son testler grafiği, ders ve konu bazlı başarı |
| 3:25 | Ders → **Bu derse soru sor**: "Zincir kuralını bir örnekle açıklar mısın?" | "Zorunlu 1. Yanıt nottaki örneğe dayanıyor; altında `qwen2.5:7b · matematik konusu` yazıyor: matematik sorusu olduğu için model otomatik seçildi." |
| 3:50 | Genel sohbet: "Etkili ders çalışma yöntemleri nelerdir?" | Altında `gemma3:4b · Türkçe anlatım` |
| 4:05 | Ayarlar: koyu mod, Gelişmiş model seçimi | |
| 4:15 | (İsteğe bağlı) `docker compose stop ollama` → testi teslim et | "Yapay zekâ kapalıyken bile puan dönüyor, kural tabanlı yedek öneri gösteriliyor." Sonra `docker compose start ollama` |
| 4:35 | Ders kartına basılı tut → adını değiştir | Kapanış: "Kaynak kodu, workflow'lar, Docker yapılandırması ve belgeler GitHub deposunda." |

## Örnek not

**Başlık:** Türev ve Türev Alma Kuralları

```
Türev, bir fonksiyonun bir noktadaki anlık değişim hızını gösterir. Geometrik olarak türev, fonksiyonun grafiğine o noktada çizilen teğet doğrunun eğimidir. f(x) fonksiyonunun türevi f'(x) veya df/dx şeklinde gösterilir. Türevin limit tanımı şöyledir: f'(x) = lim (h→0) [f(x+h) − f(x)] / h.

Temel türev kurallarından ilki sabit fonksiyon kuralıdır: sabit bir sayının türevi sıfırdır. Kuvvet kuralına göre f(x) = x^n ise f'(x) = n·x^(n−1) olur. Örneğin x^3 fonksiyonunun türevi 3x^2 olur. Bir sabitle çarpılmış fonksiyonun türevi alınırken sabit dışarıda kalır: (5x^2)' = 10x.

Toplam kuralına göre (f + g)' = f' + g'. Çarpım kuralına göre (f·g)' = f'·g + f·g'. Bölüm kuralı ise (f/g)' = (f'·g − f·g') / g^2 şeklindedir.

Zincir kuralı, bileşke fonksiyonların türevini almak için kullanılır: f(g(x)) fonksiyonunun türevi f'(g(x))·g'(x) olur. Örneğin (2x+1)^3 fonksiyonunun türevi 6·(2x+1)^2 olur.

sin x fonksiyonunun türevi cos x, cos x fonksiyonunun türevi −sin x, e^x fonksiyonunun türevi e^x, ln x fonksiyonunun türevi 1/x olur.

Türevin sıfır olduğu noktalara kritik nokta denir. Türev pozitiften negatife geçiyorsa yerel maksimum, negatiften pozitife geçiyorsa yerel minimum vardır.
```

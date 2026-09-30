# Forever Clean Chat — 1.0.0

Forever sohbetinde gold, ücretli boost/carry, hesap ve ilerletme hizmeti
reklamlarını yerel olarak gizleyen bağımsız addon. Forever Mini Reminder
değiştirilmedi; bu addonun ona bağımlılığı yoktur.

Hedef `.toc` değeri **16001** korunmuştur. Bu metadata gerçek API sürümünü
kanıtlamaz. **Canlı Forever istemcisinde doğrulama yapılmadı.**

## Kurulum / güncelleme

1. Oyunu tamamen kapat. Mevcut `ForeverCleanChatDB` SavedVariables dosyanı
   yedeklemek istersen bunu oyun kapalıyken yap; güncelleme için silmek gerekmez.
2. `ForeverCleanChat` klasörünü ilgili istemcinin `Interface\AddOns` klasörüne
   kopyala. Yol `Interface\AddOns\ForeverCleanChat\ForeverCleanChat.toc` olmalı.
3. Addonu etkinleştir; minimap yanındaki kalkan simgesine tıkla veya `/fcc` yaz.
   `/fcc test`, `/fcc status`, `/fcc pack` metin komutları da kullanılabilir.
4. Dahili kural kontrolünde `12/12` beklenir. `events: 5/5` yalnız API kayıt
   denemelerinin tamamlandığını gösterir. `callbacks observed` ayrı bir ölçüdür;
   ikisi de hedef istemciye tam uyumluluk garantisi değildir.

Oyunda Python, JSON okuyucu, ek kütüphane veya harici program gerekmez.
`.toc` yalnız üretilmiş Lua verisini ve addon kodunu yükler.

## Kontrol paneli

Panel dili İngilizcedir. Minimap simgesinde sol tık paneli açar/kapatır;
sağ tık doğrudan Settings bölümünü açar. Simgeyi sürükleyerek minimap etrafında
taşıyabilirsin. Panelin başlığını sürükleyerek pencereyi taşıyabilirsin; iki
konum da kaydedilir. Escape paneli kapatır. Simge gizliyse `/fcc minimap reset`
yeniden gösterir ve konumunu sıfırlar.

- **Overview:** filtre anahtarı, oturum/toplam sayaçları, profil ve paket durumu.
- **Hidden messages:** son 50 gizlenen mesaj, arama, karar ayrıntıları ve oyuncu izin/engel işlemleri.
- **Your lists:** özel alan adları, ifadeler, oyuncular ve alan adı istisnaları.
- **Settings:** profil, alan adı politikası, beş sohbet türü ve minimap ayarları.
- **Local test:** örnek metni yerel sınıflandırma ve 12 dahili kontrol.

Local Test sohbet kanalına mesaj göndermez ve gizleme sayacını artırmaz.
Log temizlemek de sayaçları sıfırlamaz. Oyuncu, profil ve liste tercihleri
önceki sürümden korunur; pencere/minimap tercihleri ayrıca saklanır.

## Profiller ve alan adı politikası

**Yeni kurulum:** açık, `strict`, `hide_all`.

**Güncelleme:** mevcut `enabled`, `balanced`/`strict`, toplam sayaç, özel alan
adları/ifadeler ve oyuncu izin/engel listeleri korunur. Kullanıcının balanced
profili sessizce strict yapılmaz.

- `balanced`: bilinen alan adları ve güçlü ticari/gerçek para ilanları.
  Salt oyun gold'u karşılığında boost/carry genellikle görünür kalır.
- `strict`: ayrıca oyun gold'u karşılığındaki veya fiyatı belirtilmemiş
  boost/carry, gold ve hesap satış teklifleri. Bu bir içerik tercihidir.
- `hide_all`: bilinen alan adının rehberde, soruda veya reklam karşıtı uyarıda
  anılması da gizlenebilir. Varsayılan sert alan adı politikasının takası budur.
- `contextual`: alan adı tek başına yeterli değildir; aynı teklif bölümünde
  olumlu satıcı/sipariş çağrısı ve hizmet/gold/hesap teklifi gerekir.

Bilinen alan adına dayalı istisna bağımsız gerçek para veya satış kurallarını
aklamaz. Örneğin alan adına izin verilse de açık gerçek para gold ilanı
gizlenebilir. Oyuncu izin listesi ise tüm içerik kurallarından önce uygulanır.

## Komutlar

| Komut | İşlev |
|---|---|
| `/fcc` | Kontrol panelini aç/kapat |
| `/fcc settings`, `/fcc close` | Ayarları aç / paneli kapat |
| `/fcc minimap show/hide/reset` | Minimap simgesi görünürlüğü / konum sıfırlama |
| `/fcc status` | Durum, sayaç, kayıt API'si, gözlenen callback, hatalar |
| `/fcc on`, `/fcc off` | Filtreyi aç/kapat |
| `/fcc mode balanced`, `/fcc mode strict` | Profil |
| `/fcc domainpolicy hide_all`, `/fcc domainpolicy contextual` | Alan adı politikası |
| `/fcc pack` | Çevrimdışı veri paketi sürümü ve gösterge sayısı |
| `/fcc why <yerel örnek>` | Karar nedeni, kural/gösterge kimlikleri ve dönüşüm |
| `/fcc test` | 12 yerel smoke kontrolü; mesaj göndermez, sayaç değişmez |
| `/fcc log [1-20]` | Oturumda gizlenen son mesajları ve nedenlerini göster |
| `/fcc list` | Kullanıcı listeleri, yerleşik istisnalar ve inceleme kayıtları |
| `/fcc domain add example.com` | Özel alan adı ekle / yerleşik engeli geri aç |
| `/fcc domain remove example.com` | Özel kaydı kaldır / yerleşik göstergeyi kapat |
| `/fcc domain allow example.com` | Yalnız alan adı kurallarında istisna |
| `/fcc domain unallow example.com` | Alan adı istisnasını kaldır |
| `/fcc word add unwanted phrase` | Açık kullanıcı ifade engeli |
| `/fcc word remove unwanted phrase` | İfade engelini kaldır |
| `/fcc allow Player Name-Realm`, `/fcc unallow Player Name-Realm` | Oyuncu izni |
| `/fcc block Player Name-Realm`, `/fcc unblock Player Name-Realm` | Yerel oyuncu engeli |

`/fclean` aynı komutların takma adıdır. Komut anahtarları büyük/küçük harfe
duyarlı değildir. İsimlerdeki boşluklar korunur; realm'siz oyuncu kaydı aynı
kısa adı farklı realm'lerde de kapsar. Aynı kimlik iki listedeyse izin önceliklidir.
Okunabilir oyuncu GUID'si varken isim eşleşmesi farklı GUID'yi kendi oyuncun
saymaz; GUID yoksa mevcut tam isim/realm fallback'i kullanılır.

## Çevrimdışı veri ve sınıflandırma

Kaynak: `research/forever-clean-chat-research.json`.
Veri sürümü: **2026-09-30.1**; **37 aktif alan adı, 26 sözlük ailesi, 17 kural
(15 etkin, 2 deneysel kapalı)**. Kaynakta 9 karantina alan adı bulunur;
bunlar çalışma zamanı engel paketine dahil edilmez. Ortak Discord/Telegram,
link kısaltıcıları ve YouTube adresleri genel olarak kara listeye alınmaz.

Araştırmada kaynakla desteklenen web adresleri ile kullanıcının reklamda
gördüğü `mythicstore.com` ayrı göstergelerdir. `mythic-store.com` ile aynı
işletmeye ait oldukları varsayılmaz. Satıcı sayfası, gönderen karakterin o
satıcıya ait olduğunu veya güvenlik iddialarının doğru olduğunu kanıtlamaz.

Normalizasyon görünür metni, semantik token/cümlecikleri ve alan adı adaylarını
ayrı işler. Host/userinfo/path/query ayrılır; item bağlantısının gizli payload'ı
taranmaz, görünür etiketi taranır. Gerçek alt alan adları desteklenir. Tireler,
rakamlar, TLD ve iki tarafın sınırları korunur; farklı adresler aynı anahtara
kompaktlanmaz. Sonlu Unicode/dot-word/boşluk dönüşümleri uygulanır. Leet yalnız
bilinen esas etikette, en fazla iki değişiklik ve ilgili ticari bölüm bağlamıyla
denenir; TLD dönüştürülmez. Tam Unicode, IDNA veya keyfi kod çözme desteği yoktur.

Satıcı niyeti hizmet nesnesine bağlanır. Gold Bar, eşya fiyatındaki gold,
alıcı isteği, ücretsiz yardım, ilgisiz FPS/buff konuşması ve yerel olumsuzlama
ayrılır. `free`, `LFM` veya `guide` sözcüğü tüm ilanı otomatik aklamaz.
Yanlış pozitifler ve kaçan yeni ilanlar hâlâ mümkündür; `/fcc why` ve `/fcc log`
ile yerel kararları inceleyebilirsin. Yakın yazım ve tekrar itibarı varsayılan
engelleme nedeni değildir; isimlerden otomatik kara liste üretilmez.

## Ayar taşıma

Yerleşik veri paketi, özel `domains`, `domainDisabled` ve `domainAllow`
katmanlarından ayrıdır. Eski kompakt anahtardan yeni alan adı uydurulmaz;
geçerli eski **value** yapısal alan adı olarak korunur. Geçersiz kayıtlar
`legacyReview` içinde kayıpsız tutulur; `/fcc list` bunların anahtarlarını gösterir.
İlk taşımada eski listeler/ayarlar `migrationBackup` içinde de saklanır.
Eski tek varsayılan `mythicstore.com` kaldırılmışsa bu tercih güncellemede korunur.

Eski sürümde bir alan adı çakışması nedeniyle zaten ezilmiş kayıt geri
oluşturulamaz. Yeni sürüm `a-b.com`, `ab.com` ve `a.b.com` kayıtlarını ayrı tutar.

## Kapsam ve sınırlar

`CHAT_MSG_CHANNEL`, `CHAT_MSG_SAY`, `CHAT_MSG_YELL`, `CHAT_MSG_WHISPER`,
`CHAT_MSG_EMOTE` kapsanır; kanal adı/numarası sabit varsayılmaz.
Guild/party/raid/officer/instance/Battle.net/sistem ve giden whisper kapsam dışıdır.
Kendi oyuncun ve istemcinin doğruladığı GM/DEV mesajları muaf tutulur.

Mesaj sunucudan gelmeye devam eder; yalnız standart chat filtresi tüketen
pencerelerde görünümü gizlenir. Geçmiş, sohbet balonları, mailbox, grup bulucu,
davetler ve özel chat panelleri desteklenmiş sayılmaz. Raporlama, ignore,
otomatik yanıt, tarayıcı açma, mesaj gönderme veya HTTP yoktur.

Hata, erişilemeyen değer, geçersiz UTF-8 veya işlem bütçesi aşımında mesaj
görünür bırakılır. 4096 bayt, 32 alan adı adayı, aday başına 128 görünür karakter
bütçesi vardır. Karar/dedupe tamponları 256, oturum kaydı 50 girişle sınırlıdır.
Oturumda tutulan ham mesajlar SavedVariables'a yazılmaz; `/reload` ile kaybolur.
LineID yoksa 0,25 saniyelik sayaç tekilleştirmesi yaklaşık olabilir.
OnUpdate/polling/zamanlayıcı yoktur. Canlı FPS/bellek ölçümü yapılmadı.

## Üretim, test ve canlı kabul

Geliştirme ortamında:

```text
python tools/build_rule_data.py
python tools/build_rule_data.py --check
python tools/test_build_rule_data.py
python tests/run_all.py
```

Derleyici yalnız Python standard library kullanır. Tam test koşucusu gerçek
`lupa.lua51` ve `lupa.lua53` çalışma zamanlarını ister; eksikse testi geçmiş saymaz.
Yerleşik test dosyaları `.toc` içinde değildir.

Gerçek çalıştırma sonuçları `TEST_REPORT.txt`, `tests/results/latest.md` ve
`tests/results/latest.json` içinde; eski beklenti farkları `tests/README.md`
içinde ayrı belgelenmiştir. JSON'daki `not_executed` notları test sonucu değildir.

Hedef istemcide `/fcc status` ve `/fcc test` kontrolünden sonra, gelen gerçek
bir reklamın chat'te gizlenip `/fcc log` içinde göründüğünü ve normal LFM/WTS
eşya mesajlarının kaldığını kontrol et. Herkese açık kanallara deneme reklamı
gönderme. Kendi mesajın muaf olduğundan kendi gönderdiğin örnek canlı filtre
kontrolü değildir. Gerçek event desteği, vararg indeksleri, secret-value
davranışı ve diğer addonlarla etkileşim bu paketin yerel testleriyle kanıtlanmaz.

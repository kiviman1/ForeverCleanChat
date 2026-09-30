# Changelog

## 1.0.0 — 2026-09-30 — English control panel

- Added a native minimap shield: left-click panel, right-click Settings, drag to move;
  saved visibility/position, round and square minimap support, no library dependency.
- Added Overview, Blocked Messages, Lists, Settings and Local Test tabs;
  searchable bounded logs/lists, rule details, player actions and local samples.
- `/fcc` opens the movable panel; Escape closes it. Existing text commands remain,
  with settings/close/minimap recovery commands added.
- Shared validated settings operations keep panel and slash changes consistent;
  existing modes/lists/counters survive upgrading, and UI positions are saved.
- Individual channel/say/yell/whisper/emote switches; UI errors cannot alter
  filter decisions. Local samples and log clearing do not change block counters.
- Native UI interaction checks run under Lua 5.1 and 5.3 alongside the full
  classifier, callback, migration, compiler and adversarial suites.
- Actual game rendering and live chat integration remain unverified.

## 0.2.0 — 2026-09-30 — çevrimdışı araştırma paketi

- Kaynak JSON projeye aynen alındı; doğrulayan Python derleyicisi deterministik
  Lua verisi ve ayrı test fixture dosyası üretir. Oyunda JSON/ağ/eval yoktur.
- 37 alan adı ve 26 sözlük ailesi; karantina alan adları etkin pakete alınmaz.
  `mythicstore.com` ve `mythic-store.com` ayrı gösterge kimlikleridir.
- Yapısal host ayrıştırma, sonlu Unicode dönüşümleri ve semantik teklif kuralları;
  iki yönlü sınırlar, URL host/path/query/userinfo ve item etiketleri korunur.
- Alan adı çakışmaları, normal eşya satışı, ücretsiz yardım, alıcı niyeti,
  yerel olumsuzlama, fiyat nesnesi ve cümleler arası kanıt sızması düzeltildi.
- Yeni kurulum strict; eski kullanıcının modu/ayarları/sayacı/listeleri korunur.
  Yerleşik paket kullanıcı istisnalarından ayrıdır; bozuk legacy kayıtlar
  inceleme ve özgün ayar yedeğinde kayıpsız saklanır.
- `/fcc why`, `/fcc pack`, `/fcc domainpolicy` ve domain-only izin komutları.
  Sert domain anma politikası rehber/uyarıları da gizleyebilir; contextual seçeneği eklendi.
- Modern kayıt API'si hata/false döndürürse legacy fallback; kayıt sayısı ile
  gözlenen callback ayrı gösterilir. TOC 16001 değiştirilmedi.
- Gerçek Lua 5.1/5.3 regresyon, JSON profil/adaptör, migration, derleyici ve
  adversarial kontrolleri ayrı raporlanır. Canlı Forever kabul testi yapılmadı.

## 0.1.0 — 2026-09-30 — initial test package

- Standalone addon targeting the reported Forever Interface 16001 environment.
- Screenshot-observed domain rule and conservative commercial-message rules.
- Common obfuscation normalization with an end-of-domain boundary check.
- Balanced default; optional strict filtering of boost/carry sales.
- Manual domain/phrase/player lists, player exceptions, diagnostic commands.
- Standard modern/legacy chat filter API detection and deferred registration.
- Bounded session log and cache; no polling, network or report automation.
- Offline rule/runtime regression suite and in-game rule self-test.
- Live Forever acceptance testing remains outstanding.

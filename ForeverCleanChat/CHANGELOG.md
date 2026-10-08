# Changelog

## 1.1.2 — 2026-10-08 — Animated protection padlock

- Replaced the home status light with a native padlock that fades in open over
  0.5 seconds, closes its shackle and briefly flashes green when enabled.
- The closed lock stays visible while enabled; disabling raises the shackle and
  fades out the open lock. Interrupted transitions retain their current pose.
- Initial panel display and hidden setting changes show the current state
  without replaying old transitions. Animation callbacks stop at rest or hide.
- Filtering preferences, counters, panel size and minimap behavior are unchanged.

## 1.1.1 — 2026-10-08 — Compact panel and text fixes

- Reduced home and advanced panels by 28%, with further automatic screen fitting.
- Assigned per-control fonts and fitted button captions to their available width;
  long entries retain their full value for tooltips, search and player actions.
- Fixed conflicting list-row anchors and kept multiline local-test input inside
  a fixed scrollable viewport with caret scrolling.
- Replaced the truncated close caption with a graphical X and removed the footer
  `/fcc` hint. The slash command remains available.
- Added native-font, caption-bounds, multiline-editor and close-geometry regression
  checks; actual game rendering still requires a target-client check.

## 1.1.0 — 2026-10-08 — Gold fantasy interface

- Redesigned the home screen to match the supplied reference: a dark textured
  panel, ornate gold frame, chat-shield emblem and gold serif typography.
- Added a green/red protection indicator and ON/OFF switch, larger
  Balanced/Strict options, the real session count and View messages action.
- Moved detailed controls into Advanced settings; hidden messages, personal
  lists, filtering settings and local tests remain available with Home navigation.
- Included local RGBA TGA artwork for the panel and minimap emblem in releases.
  All settings, lists, counters and filter rules retain their existing behavior.
- Verified native control callbacks and full filter suites in Lua 5.1/5.3.
  Native game rendering still requires checking in the target client.

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

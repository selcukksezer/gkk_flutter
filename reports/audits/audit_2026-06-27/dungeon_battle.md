---
# 📦 DOSYA/SAYFA ANALİZİ: DungeonBattleScreen (`lib/screens/dungeon/dungeon_battle_screen.dart`)

**Rota:** `/dungeon/battle` (query: `dungeon_id`, `dungeon_name`, `zone`, `energy_cost`, `auto`)  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/dungeon_battle.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `lib/components/layout/game_chrome.dart`  
**İlgili widget'lar:** `dungeon_result_widgets.dart`, `dungeon_victory_effects.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Idle kart — generic "Zindan" başlığı
* **Hata Tanımı:** Screenshot query params olmadan açılmış: `_dungeonName` default `'Zindan'` (satır 30, 57); enerji maliyeti, bölge, ödül önizlemesi yok.
* **Kullanıcıya Etkisi:** Hangi zindana saldırıldığı belirsiz; smoke route direkt `/dungeon/battle` açınca kırık UX.
* **Kesin Çözüm ve Öneri:** `dungeon_id` boşsa `context.pop()` veya zindan listesine yönlendir; idle'da enerji/zone badge.

* **Sorunlu Bileşen/Yer:** Viewport — %65 boş alan
* **Hata Tanımı:** Screenshot tek küçük kart + geniş boş gradient; savaş animasyonu/ düşman görseli yok.
* **Kullanıcıya Etkisi:** Epik savaş beklentisi karşılanmaz; "placeholder" hissi.
* **Kesin Çözüm ve Öneri:** Zone-themed arka plan, düşman silüeti, enerji maliyeti chip.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Zindan doğru ama sub-route
* **Hata Tanımı:** `currentRoute: AppRoutes.dungeon` (satır 227); battle alt rotası ana zindan ile aynı highlight — kabul edilebilir ama geri stack belirsiz (`pop` vs hub).
* **Kullanıcıya Etkisi:** Screenshot'ta Zindan tab mavi — OK; ancak battle bitince nereye dönüleceği tutarsız (`pop` / `go`).
* **Kesin Çözüm ve Öneri:** `GameSubScreenScaffold` + explicit Geri.

* **Sorunlu Bileşen/Yer:** Savaş fazı — statik emoji
* **Hata Tanımı:** `_buildFightingPhase` sabit ⚔️ + flavor text (satır 340-365); gerçek hasar/HP yok.
* **Kullanıcıya Etkisi:** Savaş "bekleme ekranı" gibi; RPC süresince boş his.
* **Kesin Çözüm ve Öneri:** HP bar simülasyonu veya en azından zone sprite.

* **Sorunlu Bileşen/Yer:** Hata mesajı — `Hata: $e`
* **Hata Tanımı:** `catch` bloğu ham exception (satır 188).
* **Kullanıcıya Etkisi:** Teknik hata + ani pop.
* **Kesin Çözüm ve Öneri:** `_mapError` pattern genişlet; retry CTA.

* **Sorunlu Bileşen/Yer:** Geri butonu — düşük kontrast
* **Hata Tanımı:** `← Geri Dön` TextButton `white54` (satır 303-306); primary CTA'nın gölgesinde.
* **Kullanıcıya Etkisi:** Kaçış yolu zayıf görünür.
* **Kesin Çözüm ve Öneri:** Outlined secondary veya AppBar back.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Query params — `didChangeDependencies` state
* **Risk/Maliyet:** `_paramsLoaded` flag (satır 50-65); hot reload / deep link değişiminde güncellenmez.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// GoRouter extra veya path param + ref.listen manual
```

* **Hatalı Kod Yapısı:** `Timer` lifecycle
* **Risk/Maliyet:** `_countdownTimer` / `_logTimer` dispose'da cancel OK; `_startBattle` exception'da `_logTimer` cancel var ama `_phase` stuck olabilir.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// finally { setState(() => _phase = 'idle'); }
```

* **Hatalı Kod Yapısı:** `Scaffold` — `GameSubScreenScaffold` değil
* **Risk/Maliyet:** Manuel `GameTopBar` + `GameBottomBar` (satır 224-227); Geri butonu yok, `extendBody: true` FAB overlap riski.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
GameSubScreenScaffold(title: _dungeonName, fallbackRoute: AppRoutes.dungeon, ...)
```

* **Hatalı Kod Yapısı:** RPC sonrası flavor log — geç append
* **Risk/Maliyet:** `_battleLog.add` RPC sonrası (satır 156-168); kullanıcı savaş bitmeden log görür.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Sonuç fazında ayrı sonuç paneli; fighting sadece animasyon
```

* **Hatalı Kod Yapısı:** logout — inventory clear eksik
* **Risk/Maliyet:** Satır 219-222; dungeon loot cache kalır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(inventoryProvider.notifier).clear();
```

* **Hatalı Kod Yapısı:** `_canRetry` — energy check local
* **Risk/Maliyet:** Sunucu enerji düşürmeden retry mümkün görünür; race condition.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Retry öncesi loadProfile + server validate
```

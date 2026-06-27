---
# 📦 DOSYA/SAYFA ANALİZİ: MekanArenaScreen (`lib/screens/mekans/mekan_arena_screen.dart`)

**Rota:** `/mekans/:id/arena` (screenshot: `7bd9915c-5984-43a5-a41f-63df9bce7081/arena`)  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/mekans_7bd9915c_5984_43a5_a41f_63df9bce7081_arena.png`  
**Tema referansları:** `lib/screens/mekans/widgets/mekan_theme.dart`, `mekan_design.dart`  
**İlgili widget'lar:** `lib/providers/mekan_provider.dart`, `pvp_provider.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Rakip listesi — qa_bot flood (Screenshot QA)
* **Hata Tanımı:** Screenshot tüm kartlar `qa_bot_XXXX`; gerçek oyuncu yok. `_FighterCard` avatar tek harf (satır 327-329).
* **Kullanıcıya Etkisi:** Prod'da bot görünümü güveni düşürür; test data leak.
* **Kesin Çözüm ve Öneri:** Prod'da bot filtrele veya `BOT` badge; smoke-only seed.

* **Sorunlu Bileşen/Yer:** Enerji chip — maliyet vs mevcut
* **Hata Tanımı:** Header `⚡ 100` (satır 223-227); `_energyCost = 15` (satır 20). Screenshot'ta 100 enerji — maliyet oranı net değil (15 gerekli yazısı bet sheet'te).
* **Kullanıcıya Etkisi:** Header'da maliyet gösterilmezse yanlış anlama.
* **Kesin Çözüm ve Öneri:** `'$energy / $_energyCost'` veya `-15⚡` etiketi.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** Screenshot Home mavi; arena derin rotası.
* **Kullanıcıya Etkisi:** Nav konumu kaybı.
* **Kesin Çözüm ve Öneri:** Mekan/PvP secondary nav.

* **Sorunlu Bileşen/Yer:** Sıralama tab — empty QA
* **Hata Tanımı:** Screenshot Dövüş tab aktif, bot listesi dolu; Sıralama tab screenshot'ta doğrulanmadı. Kod empty: `'Henuz arena sıralamasi olusmadi.'` (satır 279-283) — ASCII ı.
* **Kullanıcıya Etkisi:** Boş sıralama copy zayıf.
* **Kesin Çözüm ve Öneri:** `'Henüz arena sıralaması oluşmadı.'`

* **Sorunlu Bileşen/Yer:** Bahis sheet — wager UI
* **Hata Tanımı:** Preset 10K–5M (satır 440); düşük level oyuncu çoğu gri disabled — OK. Custom wager yok.
* **Kullanıcıya Etkisi:** Esnek bahis yok; orta stake seçilemez.
* **Kesin Çözüm ve Öneri:** Slider veya custom input.

* **Sorunlu Bileşen/Yer:** Sonuç dialog — hastane CTA yok
* **Hata Tanımı:** `hospital` → `GlowChip` (satır 138-141); hastaneye git linki yok (dungeon battle'daki gibi).
* **Kullanıcıya Etkisi:** Hastane durumunda sonraki adım belirsiz.
* **Kesin Çözüm ve Öneri:** `Hastaneye Git` butonu.

* **Sorunlu Bileşen/Yer:** Rakip yok empty — iyi tasarım
* **Hata Tanımı:** `_opponents.isEmpty` → `MekanEmpty` (satır 240-250); screenshot'ta dolu liste, empty QA yok.
* **Kullanıcıya Etkisi:** N/A — pattern iyi.
* **Kesin Çözüm ve Öneri:** Koru.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_load` — silent catch
* **Risk/Maliyet:** `catch (_) { setState loading false }` (satır 58-60); hata UI yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
_error message + retry
```

* **Hatalı Kod Yapısı:** `_fight` — sheet kapanma race
* **Risk/Maliyet:** `_BetSheet` `onFight` await sonra `Navigator.pop` (satır 508-511); dialog `_showResult` üst üste.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// pop sheet before dialog; await chain
```

* **Hatalı Kod Yapısı:** PvP refresh — üç provider
* **Risk/Maliyet:** `_fight` sonrası player + pvpDashboard + pvpHistory load (satır 87-89); arena-only fight için ağır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// invalidate only affected providers
```

* **Hatalı Kod Yapısı:** `mekanId` — sadece RPC param
* **Risk/Maliyet:** Ekran `widget.mekanId` kullanıyor; mekan kapalı/raid kontrolü yok (detail'de vardı).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// init: fetch mekan, redirect if closed
```

* **Hatalı Kod Yapısı:** `_RankRow` weekly reward format
* **Risk/Maliyet:** Manual K/M (satır 418-420); `formatMekanGold` ile tutarsız.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
formatMekanGold(row.weeklyReward)
```

* **Hatalı Kod Yapısı:** 518 satır tek dosya
* **Risk/Maliyet:** Bet sheet, rank row, fighter card inline.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// widgets/mekan_arena_fighter_card.dart, mekan_bet_sheet.dart
```

---
# 📦 DOSYA/SAYFA ANALİZİ: HorseRaceScreen (`lib/screens/horse_race/horse_race_screen.dart`)

**Rota:** `/horse-race`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/horse_race.png`  
**Tema referansları:** `lib/theme/app_colors.dart`  
**İlgili widget'lar:** `lib/screens/horse_race/horse_race_live_view.dart`, `lib/screens/horse_race/horse_race_provider.dart`, `lib/screens/horse_race/horse_race_track_painter.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Screenshot QA — yakalanan faz yanlış
* **Hata Tanımı:** Audit PNG **canlı yarış overlay** (`HorseRaceLiveView` countdown "2"); bahis grid, currency toggle, preset chip'ler görünmüyor. Smoke capture timing race phase'e denk gelmiş — bahis UX audit edilemedi.
* **Kullanıcıya Etkisi:** QA raporu eksik; regresyon bahis ekranında kaçabilir.
* **Kesin Çözüm ve Öneri:** Screenshot script'te `HorseRacePhase.betting` bekle; ayrı `horse_race_betting.png`.

* **Sorunlu Bileşen/Yer:** Immersive mod — navigasyon tamamen gizli
* **Hata Tanımı:** `_showingLiveRace` → `appBar: null`, `bottomNavigationBar: null` (satır 103-121). Çıkış yolu yok (geri swipe `PopScope` yok live view'da).
* **Kullanıcıya Etkisi:** 9 sn+ yarış sırasında sıkışmış hissi; acil çıkış yok.
* **Kesin Çözüm ve Öneri:** Minimal top bar X veya swipe-down dismiss.

* **Sorunlu Bileşen/Yer:** Türkçe diakritik — tutarsız marka
* **Hata Tanımı:** AppBar `'At Yarisi'` (satır 106); live header `'Canlı Yarış'` (live_view); status `'Kapaniyor'`, `'Bahis acik'` ASCII.
* **Kullanıcıya Etkisi:** At yarışı ekranı "beta" hissi.
* **Kesin Çözüm ve Öneri:** `'At Yarışı'`, `'Bahis açık'`, `'Kapanıyor'`.

* **Sorunlu Bileşen/Yer:** Bahis miktarı — preset only
* **Hata Tanımı:** `_goldPresets` / `_gemPresets` (satır 62-63); custom amount TextField yok. Yüksek roller 1M+ gold dışarıda kalır.
* **Kullanıcıya Etkisi:** Esneklik düşük; whale oyuncu churn.
* **Kesin Çözüm ve Öneri:** Custom input + min/max validation RPC'den.

* **Sorunlu Bileşen/Yer:** At grid — düşük touch target
* **Hata Tanımı:** `childAspectRatio: 2.65` (satır 66) — kart ~40pt yükseklik; emoji 18 + isim 13px + mult.
* **Kullanıcıya Etkisi:** Yanlış at seçimi; bahis hatası.
* **Kesin Çözüm ve Öneri:** aspect 1.8-2.0; min 48dp height.

* **Sorunlu Bileşen/Yer:** Son kazananlar — 30 item sabit grid yüksekliği
* **Hata Tanımı:** `recentWinners.take(30)` + computed grid height (satır 538-577) — ana ListView'e büyük blok ekler; bahis UI aşağı iter.
* **Kullanıcıya Etkisi:** Bahis CTA fold altında; scroll gerekir (screenshot betting'de görülmedi).
* **Kesin Çözüm ve Öneri:** Collapse "Son 5" + "Tümünü gör".

* **Sorunlu Bileşen/Yer:** Sonuç overlay — `won == null`
* **Hata Tanımı:** `_buildResultOverlay` (satır 727-728): bet var ama `won` null → `'...'` sonsuz.
* **Kullanıcıya Etkisi:** Bahis sonucu belirsiz; profil refresh bekleme.
* **Kesin Çözüm ve Öneri:** Loading spinner + timeout retry.

* **Sorunlu Bileşen/Yer:** Live view — finish bar artifact
* **Hata Tanımı:** Screenshot sağda dikey gri/bar pixelated — `horse_race_track_painter` veya progress marker render kalitesi düşük.
* **Kullanıcıya Etkisi:** Görsel kalite düşük; premium mini-game hissi zayıf.
* **Kesin Çözüm ve Öneri:** Anti-alias paint; asset-based finish line.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Phase sync — local flags + provider
* **Risk/Maliyet:** `_showingLiveRace`, `_showingResult`, `_dismissedResultRoundId` (satır 76-80) provider state ile duplicate; rebuild race.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — HorseRaceUiPhase enum in provider
enum HorseRaceUiPhase { betting, live, result }
```

* **Hatalı Kod Yapısı:** `ref.listen` inside `build`
* **Risk/Maliyet:** Satır 94-96 her build'de listen register — Riverpod duplicate listener riski (aslında rebuild'de yeniden? Riverpod listen in build is anti-pattern).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — initState veya ref.listenManual in initState callback
ref.listenManual(horseRaceProvider, _syncPhaseFromState);
```

* **Hatalı Kod Yapısı:** `_gridHeight` — fixed height grid in ListView
* **Risk/Maliyet:** `NeverScrollableScrollPhysics` nested — OK ama orientation change'de recalc?
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — SliverGrid in CustomScrollView tek scroll
```

* **Hatalı Kod Yapısı:** `_parseColor` — invalid hex fallback
* **Risk/Maliyet:** Satır 13-20; server bad color → tüm atlar mavi.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
Color _parseColor(String raw, {required String horseId}) {
  // log + per-horse default palette
}
```

* **Hatalı Kod Yapısı:** Logout — inventory clear yok
* **Risk/Maliyet:** Satır 107-110.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(inventoryProvider.notifier).clear();
```

* **Hatalı Kod Yapısı:** `horse_race_provider.dart` — ayrı dosya iyi; screen hâlâ 747 satır
* **Risk/Maliyet:** UI + overlay logic birleşik.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
lib/screens/horse_race/widgets/horse_bet_panel.dart
lib/screens/horse_race/widgets/horse_result_overlay.dart
```

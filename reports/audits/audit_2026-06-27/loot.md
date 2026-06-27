---
# 📦 DOSYA/SAYFA ANALİZİ: LootHubScreen (`lib/screens/loot/loot_hub_screen.dart`)

**Rota:** `/loot`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/loot.png`  
**Tema referansları:** `lib/screens/loot/loot_chest_theme.dart`, `lib/screens/loot/loot_chest_widgets.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/components/common/item_icon_view.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — **yanlış currentRoute bug**
* **Hata Tanımı:** Satır 456-458: `currentRoute: AppRoutes.shop` — `/loot` ekranında shop route geçiliyor! `_activeIndex` shop'u tanımaz → yine Home; ama menü highlight/ analytics route yanlış.
* **Kullanıcıya Etkisi:** Nav state corruption; gelecekte shop bottom item eklenirse yanlış highlight; telemetri `/shop` sayar.
* **Kesin Çözüm ve Öneri:** `currentRoute: AppRoutes.loot` — copy-paste bug fix.

* **Sorunlu Bileşen/Yer:** Lokalizasyon — EN/TR karışımı
* **Hata Tanımı:** `'Drop Preview'` (satır 610), `'Kasa Acma'` title (satır 448), `'Goster'` (satır 623 — **Göster** olmalı), `'Aciliyor...'`, `'Carpan'` badge screenshot'ta **kesilmiş** (horizontal scroll clip).
* **Kullanıcıya Etkisi:** Premium kasa deneyimi amatör; App Store loot box scrutiny.
* **Kesin Çözüm ve Öneri:** `AppStrings.loot.*`; `'Önizleme'`, `'Göster'`, `'Çarpan'`.

* **Sorunlu Bileşen/Yer:** Stat chip yatay scroll — clipping QA
* **Hata Tanımı:** `LootChestBanner` footer `SingleChildScrollView` horizontal (satır 540-559); screenshot **Cadı Kasası** ve **Uzay Kasası**'nda üçüncü chip `'Carp.'` truncated — `Carpan: x1.00` tam görünmüyor.
* **Kullanıcıya Etkisi:** RTP/çarpan şeffaflığı eksik — gambling regulation riski.
* **Kesin Çözüm ve Öneri:** `Wrap` veya 2 satır chip; min width garanti.

* **Sorunlu Bileşen/Yer:** Drop preview — lazy load friction
* **Hata Tanımı:** Drop listesi varsayılan gizli; `'Goster\'a dokun'` (satır 715). 317 item kasada preview boş — oyuncu odds görmeden açabilir.
* **Kullanıcıya Etkisi:** Bilinçsiz harcama; şikayet/chargeback.
* **Kesin Çözüm ve Öneri:** İlk expand otomatik veya banner altında top-5 drop.

* **Sorunlu Bileşen/Yer:** Kasa açılış — 9 sn spin, kapatma kilitli
* **Hata Tanımı:** `_totalSpinMs = 9000` (satır 789); close button `_finished ? pop : null` (satır 1050-1052). UX uzun; app switch during spin state belirsiz.
* **Kullanıcıya Etkisi:** Sabırsız oyuncu trapped; düşük cihazda jank.
* **Kesin Çözüm ve Öneri:** Skip animasyon (settings); max 4-5 sn.

* **Sorunlu Bileşen/Yer:** Chest art overflow — kasıtlı ama küçük ekran
* **Hata Tanımı:** `LootChestBanner` illustration card sınırını aşıyor (screenshot); iPhone SE'de başlık/fiyat overlap riski.
* **Kullanıcıya Etkisi:** Fiyat badge (42💎) görsel gürültüde kaybolabilir.
* **Kesin Çözüm ve Öneri:** `LayoutBuilder` — dar ekranda art küçült.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight (route bug + menü rotası)
* **Hata Tanımı:** Screenshot Home aktif; `/loot` bottom item değil.
* **Kullanıcıya Etkisi:** Cross-cutting nav.
* **Kesin Çözüm ve Öneri:** Fix route + menü map.

* **Sorunlu Bileşen/Yer:** Hata metinleri — ASCII + raw exception
* **Hata Tanımı:** `'Yukleme hatasi:\n$_error'`, `'Kasa acilirken hata: $e'`, `'Gecersiz yanit'`.
* **Kullanıcıya Etkisi:** Profesyonellik düşük.
* **Kesin Çözüm ve Öneri:** User-friendly errors.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `loot_hub_screen.dart` + fullscreen page — ~1500 satır tek dosya
* **Risk/Maliyet:** Hub + reel animasyon + spin math bir arada.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
lib/screens/loot/loot_box_open_page.dart
lib/screens/loot/loot_reel_controller.dart
```

* **Hatalı Kod Yapısı:** Reel randomization — görsel bait
* **Risk/Maliyet:** `_buildRandomizedReel` komşu slotlara legendary equipment koyar (satır 834-879) — sonuç zaten belli (`targetIndex`); yanıltıcı "near miss" psikolojisi.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — etik reel: gerçek drop pool weighted random
// veya disclaimer "animasyon temsilidir"
```

* **Hatalı Kod Yapısı:** `_rowsFromRpc` — payload shape karmaşık
* **Risk/Maliyet:** Map/list dual parse (satır 101-112) — silent empty.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — typed DTO + unit test fixtures
```

* **Hatalı Kod Yapısı:** Theme index vs box id
* **Risk/Maliyet:** `resolveLootChestTheme(boxIndex, ...)` — DB sırası değişince tema/kasa eşleşmesi kayar.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
resolveLootChestTheme(box.artAsset ?? box.id)
```

* **Hatalı Kod Yapısı:** `GoogleFonts.urbanist` — fullscreen only
* **Risk/Maliyet:** Satır 1027 loot open page; tema `AppTextStyles` bypass.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
style: AppTextStyles.headline.copyWith(fontWeight: FontWeight.w900)
```

* **Hatalı Kod Yapısı:** Logout — doğru pattern (inventory clear var)
* **Risk/Maliyet:** Satır 449-453 iyi örnek; shop/bank ile contrast — diğer ekranlara export et.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// lib/core/session/logout.dart — shared helper
```

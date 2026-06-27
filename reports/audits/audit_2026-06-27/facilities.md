---
# 📦 DOSYA/SAYFA ANALİZİ: FacilitiesScreen (`lib/screens/facilities/facilities_screen.dart`)

**Rota:** `/facilities`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/facilities.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `lib/providers/facilities_provider.dart`  
**İlgili widget'lar:** `lib/models/facility_model.dart`, `lib/components/layout/game_chrome.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home yanlış aktif
* **Hata Tanımı:** `currentRoute: AppRoutes.facilities` nav item değil → Home highlight (screenshot). `_activeIndex` default `0`.
* **Kullanıcıya Etkisi:** Tesis hub'ında olduğu hissi zayıf.
* **Kesin Çözüm ve Öneri:** Drawer rotaları için Menü highlight veya facilities quick-menu eşlemesi.

* **Sorunlu Bileşen/Yer:** Gem gösterimi — ondalık format
* **Hata Tanımı:** `_tinyStat('Gem', '$gems')` profile `gems` `double` (`facilities_screen.dart` 38, 133). Screenshot'ta "Gem: 500.0" — para birimi tamsayı beklenir.
* **Kullanıcıya Etkisi:** Prod veri hatası veya format bug algısı; gem ekonomisi güvenilmez görünür.
* **Kesin Çözüm ve Öneri:** `'${gems.toInt()}'` veya `NumberFormat` tamsayı.

* **Sorunlu Bileşen/Yer:** Şüphe çubuğu — renk uygulanmıyor
* **Hata Tanımı:** `%` label `_suspicionColor(globalSuspicion)` kullanır (satır 169–175) ama `LinearProgressIndicator` `valueColor` yok — varsayılan tema rengi (screenshot'ta nötr/gri bar, %0 yeşil label).
* **Kullanıcıya Etkisi:** Risk seviyesi görsel olarak iletilmez; %80 ile %0 aynı bar.
* **Kesin Çözüm ve Öneri:** `valueColor: AlwaysStoppedAnimation(_suspicionColor(globalSuspicion))`.

* **Sorunlu Bileşen/Yer:** Rüşvet butonu — disabled state belirsiz
* **Hata Tanımı:** `globalSuspicion <= 0` iken `FilledButton` `onPressed: null` (satır 198–200) ama sarı dolu görünüm korunabilir; alt metin "Şüphe 0 iken..." küçük 11px. Screenshot'ta buton aktif görünümlü, metin tek ipucu.
* **Kullanıcıya Etkisi:** Tıklanamaz buton → sessiz no-op veya snack; kafa karışıklığı.
* **Kesin Çözüm ve Öneri:** `FilledButton.styleFrom(disabledBackgroundColor: ...)` + ikon kilit; butonu tamamen gizle suspicion==0.

* **Sorunlu Bileşen/Yer:** Tier etiketleri — İngilizce "Tier"
* **Hata Tanımı:** `'🏚️ Tier 1 — Başlangıç'`, Tier 2/3 (`facilities_screen.dart` 50–52). Oyun Türkçe; "Kademe" veya "Seviye" beklenir.
* **Kullanıcıya Etkisi:** Lokalizasyon tutarsızlığı; casual oyuncu terimi tanımaz.
* **Kesin Çözüm ve Öneri:** `'Kademe 1 — Başlangıç'`; ARB dosyasına taşı.

* **Sorunlu Bileşen/Yer:** Tesis kartları — kilitli grid okunabilirlik
* **Hata Tanımı:** `childAspectRatio: 1.15`, isim `fontSize: 12`, gereksinim `10px` (`facilities_screen.dart` 258–347). Screenshot'ta 4 kart; "Odun..." / "Seramik..." alt satır nav+FAB altında kesilir.
* **Kullanıcıya Etkisi:** 15 tesisin sonları scroll olmadan görünmez; maliyet karşılaştırması zor.
* **Kesin Çözüm ve Öneri:** Bottom `gameBottomBarClearance` padding; kart min height; sticky tier header.

* **Sorunlu Bileşen/Yer:** `Card` widget — tema uyumsuz
* **Hata Tanımı:** Üst kartlar `Card()` default Material — `Operasyon Merkezi` cyan accent (`0xFF67E8F9`) app gold/coral sisteminden kopuk (satır 85–138).
* **Kullanıcıya Etkisi:** Mekan neon / home gold ile facilities cyan üçlü palet kırılması.
* **Kesin Çözüm ve Öneri:** `GkkCard` veya `AppColors` surface token.

* **Sorunlu Bileşen/Yer:** Aktif tesis `0/15` — boş state motivasyonu
* **Hata Tanımı:** Screenshot smoke user 0 aktif tesis; tüm kartlar "Kilitli" ama seviye 6 ile Maden (Lv.1) açılabilir — `canUnlock` görsel fark yok (sadece border rengi `white24` vs `0x8040E0FF`).
* **Kullanıcıya Etkisi:** Açılabilir tesis keşfedilmez; altın 50K yeterli olsa bile kart "kilitli" badge.
* **Kesin Çözüm ve Öneri:** `canUnlock` için yeşil "Açılabilir" badge + pulse; sort unlocked-first.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_handleBribe` — rastgele ilk tesis
* **Risk/Maliyet:** `facilitiesState.facilities.first` (satır 431–434); oyuncu hangi tesise rüşvet verdiğini bilmiyor.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — tesis seçim bottom sheet veya en yüksek şüpheli tesis
final PlayerFacility target = facilitiesState.facilities
    .reduce((a, b) => a.suspicionLevel >= b.suspicionLevel ? a : b);
```

* **Hatalı Kod Yapısı:** Facility metadata duplicate — client-side const lists
* **Risk/Maliyet:** `_basicFacilities` / `_organicFacilities` / `_mysticalFacilities` (satır 518–540) backend `facility_types` ile drift riski.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
final defs = ref.watch(facilityDefinitionsProvider); // single source from API/seed
```

* **Hatalı Kod Yapısı:** `_onFacilityTap` — `canUnlock` false iken sessiz return
* **Risk/Maliyet:** Yetersiz altın/seviye durumunda yalnızca snack (satır 408–415); locked kart tıklanınca feedback gecikmeli.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — kart üzerinde inline reason chip; tap → bottom sheet önizleme
```

* **Hatalı Kod Yapısı:** `ListView` padding — bottom clearance yok
* **Risk/Maliyet:** `padding: EdgeInsets.fromLTRB(12,12,12,28)` (satır 83); `extendBody: true` + FAB + nav ile son tier kesilir.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
padding: EdgeInsets.fromLTRB(12, 12, 12, gameBottomBarClearance(context) + 16),
```

* **Hatalı Kod Yapısı:** `logout` — `facilitiesProvider` clear yok
* **Risk/Maliyet:** Stale facility queue başka hesapta flash.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(facilitiesProvider.notifier).clear();
```

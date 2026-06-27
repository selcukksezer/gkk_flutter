---
# 📦 DOSYA/SAYFA ANALİZİ: FacilityDetailScreen (`lib/screens/facilities/facility_detail_screen.dart`)

**Rota:** `/facilities/:type` (screenshot: `/facilities/farm` → slug `facilities_farm`; kodda type `farming`)  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/facilities_farm.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `lib/providers/facilities_provider.dart`  
**İlgili widget'lar:** `facilities_screen.dart`, `facility_model.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Tesis bulunamadı — smoke route mismatch (Screenshot QA)
* **Hata Tanımı:** Screenshot `Tesis bulunamadı` / `Bu tesis henüz açılmamış`; muhtemel neden: screenshot `/facilities/farm` ama `_facilityMeta` anahtarı `farming` (satır 799-807). `widget.type == 'farm'` → meta null → facility loop boş.
* **Kullanıcıya Etkisi:** Çiftlik rotası kırık; tüm facility detail smoke'ları yanlış slug ile boş.
* **Kesin Çözüm ve Öneri:** Route alias `farm` → `farming`; veya smoke manifest `farming` kullan.

* **Sorunlu Bileşen/Yer:** Empty state — CTA yok
* **Hata Tanımı:** `facility == null` Card yalnızca metin (satır 139-151); "Tesisi aç" / facilities hub linki yok.
* **Kullanıcıya Etkisi:** Oyuncu çıkmaz sokakta.
* **Kesin Çözüm ve Öneri:** `context.go(AppRoutes.facilities)` + unlock şartları.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** `currentRoute: AppRoutes.facilities` (satır 118-120) → `_activeIndex` fallback Home. Screenshot doğruladı.
* **Kullanıcıya Etkisi:** Tesis detayında nav yanlış.
* **Kesin Çözüm ve Öneri:** Facilities alt rotası Menü.

* **Sorunlu Bileşen/Yer:** AppBar — generic başlık
* **Hata Tanımı:** `title: 'Tesis Konsolu'` (satır 110-111); body'de de aynı (satır 169-170). Facility adı (`Çiftlik`) ikincil.
* **Kullanıcıya Etkisi:** Hangi tesis olduğu AppBar'dan anlaşılmaz.
* **Kesin Çözüm ve Öneri:** `meta?.name ?? widget.type` AppBar'da.

* **Sorunlu Bileşen/Yer:** Nadirlik — İngilizce etiketler
* **Hata Tanımı:** `_rarityLabel` → `'⚪ Common'` (satır 935-951); UI Türkçe ama rarity İngilizce.
* **Kullanıcıya Etkisi:** L10n tutarsızlığı (dolu ekranda belirgin).
* **Kesin Çözüm ve Öneri:** `Yaygın`, `Nadir` vb. TR map.

* **Sorunlu Bileşen/Yer:** Nadirlik Simülatörü — 10 seviye scroll duvarı
* **Hata Tanımı:** `List.generate(10, ...)` overview tab'de (satır 360-434); çiftlik açık olsa bile çok uzun sayfa.
* **Kullanıcıya Etkisi:** Üretim CTA aşağıda kaybolur.
* **Kesin Çözüm ve Öneri:** Accordion veya ayrı "Drop tablosu" ekranı.

* **Sorunlu Bileşen/Yer:** Card widget — tema dışı default
* **Hata Tanımı:** `Card()` default Material (satır 140, 154); koyu gradient body üzerinde açık tema flash riski.
* **Kullanıcıya Etkisi:** Screenshot'ta koyu card — theme bağlı tutarsızlık.
* **Kesin Çözüm ve Öneri:** `GkkCard` veya `color: AppColors.bgCard`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** 1100+ satır monolith
* **Risk/Maliyet:** Meta map, rarity math, UI aynı dosyada; bakım maliyeti yüksek.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// facility_meta.dart, facility_production_calculator.dart, widgets/
```

* **Hatalı Kod Yapısı:** `_clockTimer` — her saniye `setState`
* **Risk/Maliyet:** Tüm ekran rebuild (satır 40-45); production countdown için `ValueListenableBuilder` yeterli.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Sadece countdown widget rebuild
```

* **Hatalı Kod Yapısı:** Client-side production simulation
* **Risk/Maliyet:** `_buildLiveProductionSnapshot` (satır 1041-1123); server authoritative değil → collect mismatch.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Server preview endpoint veya poll result only
```

* **Hatalı Kod Yapısı:** `collectResourcesV2` — client seed hash
* **Risk/Maliyet:** `_hashString(productionStartedAt)` (satır 555); manipülasyon yüzeyi.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Server-generated seed only
```

* **Hatalı Kod Yapısı:** logout — facilitiesProvider clear yok
* **Risk/Maliyet:** Satır 112-115; önceki kullanıcı tesis cache.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(facilitiesProvider.notifier).clear();
```

* **Hatalı Kod Yapısı:** Tab state — local string
* **Risk/Maliyet:** `_activeTab = 'overview'|'queue'` (satır 31); deep link tab yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// query ?tab=queue veya TabController
```

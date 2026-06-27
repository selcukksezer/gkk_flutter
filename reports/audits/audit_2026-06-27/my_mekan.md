---
# 📦 DOSYA/SAYFA ANALİZİ: MyMekanScreen (`lib/screens/mekans/my_mekan_screen.dart`)

**Rota:** `/my-mekan`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/my_mekan.png`  
**Tema referansları:** `lib/screens/mekans/widgets/mekan_theme.dart`, `mekan_design.dart`  
**İlgili widget'lar:** `mekan_scaffold.dart`, `lib/providers/mekan_provider.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Empty state — iyi ama nav yanlış (Screenshot QA)
* **Hata Tanımı:** Screenshot `Mekanin yok` + `Mekan Ac` CTA (satır 109-118) — empty state kaliteli; ancak Home bottom bar aktif.
* **Kullanıcıya Etkisi:** CTA doğru route'a gider; nav konumu yine yanıltıcı.
* **Kesin Çözüm ve Öneri:** Mekan rotaları Menü highlight.

* **Sorunlu Bileşen/Yer:** Copy — ASCII Türkçe
* **Hata Tanımı:** `'Mekanin yok'`, `'Han ticareti icin once bir mekan ac.'`, tab `'Istatistik'`, `'Yukseltme'` (satır 111-137).
* **Kullanıcıya Etkisi:** Tüm mekan modülünde tutarlı ama yanlış Türkçe.
* **Kesin Çözüm ve Öneri:** `Mekanın yok`, `İstatistik`, `Yükseltme` + ARB.

* **Sorunlu Bileşen/Yer:** `THE VAULT` — İngilizce başlık
* **Hata Tanımı:** `_vaultHeader` `'THE VAULT'` (satır 172-173); gelir metni Türkçe.
* **Kullanıcıya Etkisi:** Stilistik karar ama genel TR UI ile uyumsuz.
* **Kesin Çözüm ve Öneri:** `KASA` veya `Hazine`.

* **Sorunlu Bileşen/Yer:** Gelir formatı — binlik ayırıcı yok
* **Hata Tanımı:** `'$revenue'` raw int (satır 184-187); `formatMekanGold` kullanılmıyor header'da.
* **Kullanıcıya Etkisi:** Büyük gelirde okunaksız (dolu state QA'da test edilmedi).
* **Kesin Çözüm ve Öneri:** `formatMekanGold(revenue)`.

* **Sorunlu Bileşen/Yer:** Stats tab — null empty
* **Hata Tanımı:** `_stats == null` → `'Istatistik yok'` (satır 431-436); RPC optional catch (satır 64-66).
* **Kullanıcıya Etkisi:** Yeni mekanda tüm istatistik sekmesi boş — kabul edilebilir ama skeleton tercih.
* **Kesin Çözüm ve Öneri:** Partial stats from `Mekan` model fallback.

* **Sorunlu Bileşen/Yer:** PvP Arena butonu — kapalı mekanda disabled
* **Hata Tanımı:** `onPressed: mekan.isOpen ? ... : null` (satır 303); disabled görsel ipucu zayıf.
* **Kullanıcıya Etkisi:** Neden arena kapalı belirsiz.
* **Kesin Çözüm ve Öneri:** Tooltip "Önce mekanı aç".

* **Sorunlu Bileşen/Yer:** Screenshot QA — empty vs dolu
* **Hata Tanımı:** QA hesabında mekan yok; 4 tab, vault, stok yönetimi screenshot'ta doğrulanmadı.
* **Kullanıcıya Etkisi:** Audit kapsamı empty-only.
* **Kesin Çözüm ve Öneri:** Smoke fixture: mekan sahibi hesap + dolu stok screenshot.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** 880 satır monolith
* **Risk/Maliyet:** Tab'ler, stock sheet, upgrade aynı dosya; test zor.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// my_mekan_overview_tab.dart, my_mekan_stock_tab.dart, ...
```

* **Hatalı Kod Yapısı:** Local state — `_mekan`, `_stock`, `_inventory`
* **Risk/Maliyet:** Provider pattern yok (satır 24-27); her tab `_load` duplicate.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.watch(myMekanControllerProvider)
```

* **Hatalı Kod Yapısı:** `_run` busy — global lock
* **Risk/Maliyet:** `_busy` tüm butonları kilitler (satır 84-96); toggle + happy hour aynı anda yapılamaz.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Per-action busy flags
```

* **Hatalı Kod Yapısı:** `HappyHourBanner` — `DateTime.parse` crash risk
* **Risk/Maliyet:** `mekan.happyHourUntil!` (satır 285); invalid ISO → build fail.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
DateTime.tryParse(...) ?? fallback
```

* **Hatalı Kod Yapısı:** `_StockSheet` — `DropdownButtonFormField` initialValue
* **Risk/Maliyet:** Flutter 3.16+ `initialValue` deprecated pattern; state sync risk (satır 779-793).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
value: _itemId, onChanged: ...
```

* **Hatalı Kod Yapısı:** Logout — mekan provider clear yok
* **Risk/Maliyet:** `MekanSubScaffold` logout path; stale mekan cache.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.invalidate(mekanRepositoryProvider);
```

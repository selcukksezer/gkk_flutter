---
# 📦 DOSYA/SAYFA ANALİZİ: MekanDetailScreen (`lib/screens/mekans/mekan_detail_screen.dart`)

**Rota:** `/mekans/:id` (screenshot: `7bd9915c-5984-43a5-a41f-63df9bce7081` — selcuk barı)  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/mekans_7bd9915c_5984_43a5_a41f_63df9bce7081.png`  
**Tema referansları:** `lib/screens/mekans/widgets/mekan_theme.dart`, `mekan_design.dart`  
**İlgili widget'lar:** `LootStockCard`, `lib/providers/mekan_provider.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Vitrin boş — empty state iyi (Screenshot QA)
* **Hata Tanımı:** Screenshot `0 urun satista`, `Vitrin bos` + açıklama (satır 166-175); empty state tasarımı güçlü.
* **Kullanıcıya Etkisi:** Sahip olmayan ziyaretçi durumu net; alışveriş CTA yok (doğru).
* **Kesin Çözüm ve Öneri:** Ziyaretçiye "Başka mekanlara göz at" linki ekle.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home aktif
* **Hata Tanımı:** `MekanSubScaffold` + screenshot Home mavi; derin link mekan detayında.
* **Kullanıcıya Etkisi:** Nav konumu yanlış.
* **Kesin Çözüm ve Öneri:** Mekan hub → Menü.

* **Sorunlu Bileşen/Yer:** Başlık — lowercase tipografi
* **Hata Tanımı:** Screenshot mekan adı `selcuk barı` — kullanıcı girişi; `maxLines: 2` (satır 252-256) OK.
* **Kullanıcıya Etkisi:** Profesyonel vitrin için capitalize opsiyonu düşünülebilir.
* **Kesin Çözüm ve Öneri:** Display name trim + profanity filter (server).

* **Sorunlu Bileşen/Yer:** Owner vs visitor — PvP CTA
* **Hata Tanımı:** Owner → `Mekani Yonet` (satır 304-309); visitor + PvP → Arena. Screenshot owner değil (Arena yok) — stok boş bar vitrin.
* **Kullanıcıya Etkisi:** QA: ziyaretçi vitrin empty; arena butonu bu mekanda görünmedi (bar PvP destekli mi kontrol).
* **Kesin Çözüm ve Öneri:** PvP destekli türlerde visitor'a da arena linki header'da.

* **Sorunlu Bileşen/Yer:** Hata yükleme — silent catch
* **Hata Tanımı:** `_load` `catch (_) {}` (satır 52-58); hata mesajı yok, sadece loading false.
* **Kullanıcıya Etkisi:** Ağ hatası → "Mekan bulunamadı" yanlış pozitif.
* **Kesin Çözüm ve Öneri:** Error state: "Yüklenemedi" + retry.

* **Sorunlu Bileşen/Yer:** `sohret` — ASCII
* **Hata Tanımı:** `'${mekan.fame} sohret'` (satır 273); `şöhret` olmalı.
* **Kullanıcıya Etkisi:** Copy kalitesi.
* **Kesin Çözüm ve Öneri:** l10n düzelt.

* **Sorunlu Bileşen/Yer:** Buy sheet — busy sonrası pop
* **Hata Tanımı:** `_BuySheet` `_busy` set, `onConfirm` await, sonra `Navigator.pop` (satır 412-415); hata olsa da sheet kapanabilir.
* **Kullanıcıya Etkisi:** Satın alma hatası görülmeden sheet kapanır.
* **Kesin Çözüm ve Öneri:** Yalnızca success'te pop.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Local `_mekan` / `_stock` state
* **Risk/Maliyet:** Her ekran instance kendi cache (satır 25-27).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.watch(mekanDetailProvider(mekanId))
```

* **Hatalı Kod Yapısı:** `_buy` — double inventory load
* **Risk/Maliyet:** `loadInventory` satır 90 ve 101; gereksiz RPC.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Tek load, canAddItem cached state
```

* **Hatalı Kod Yapısı:** Contraband hardcoded ids
* **Risk/Maliyet:** `han_item_berserk` / `han_item_shadow_brew` (satır 198); data-driven olmalı.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
s.isContraband from model
```

* **Hatalı Kod Yapısı:** `CustomScrollView` + `SliverFillRemaining` empty
* **Risk/Maliyet:** Empty vitrin scroll bounce OK; owner dolu grid QA eksik.
* **Mevcut Durum vs Olması Gereken (Refaktör):** Mevcut pattern OK.

* **Hatalı Kod Yapısı:** Police raid — sadece snackbar
* **Risk/Maliyet:** `police_raid == true` (satır 103-104); UI banner yok, `_load` sonrası raid banner header'da var.
* **Mevcut Durum vs Olması Gereken (Refaktör):** Tutarlı — OK.

* **Hatalı Kod Yapısı:** Route string hardcoded
* **Risk/Maliyet:** `context.go('/mekans/${mekan.id}/arena')` (satır 316); `AppRoutes` helper yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
context.go(AppRoutes.mekanArena(mekan.id));
```

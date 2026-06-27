---
# 📦 DOSYA/SAYFA ANALİZİ: BankScreen (`lib/screens/bank/bank_screen.dart`)

**Rota:** `/bank`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/bank.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/components/common/item_icon_view.dart`, `lib/providers/inventory_provider.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight (menü rotası)
* **Hata Tanımı:** `currentRoute: AppRoutes.bank` geçiliyor; bottom bar 5 sabit rota dışında `/bank` → `_activeIndex` fallback 0 (Home). Screenshot: Banka ekranı + "Home" aktif.
* **Kullanıcıya Etkisi:** Konum belirsizliği; KO-style banka ekranında navigasyon güveni zayıf.
* **Kesin Çözüm ve Öneri:** Menü kaynaklı rotalar için aktif tab = Menü (index 4) veya indicator gizle.

* **Sorunlu Bileşen/Yer:** Dikey split — Envanter + Banka eşit `Expanded`
* **Hata Tanımı:** `_buildInventoryArea` + `_buildBankArea` aynı `Column` içinde iki `Expanded` (satır 1624-1633). Her biri 5×2 / 5×1 grid + header — screenshot'ta ~%45 viewport envanter, ~%45 banka; tek elle kullanımda slotlar ~40×45dp.
* **Kullanıcıya Etkisi:** Drag-drop hedef alanı dar; slot numarası (#1) 7px okunmaz; yatay scroll yok.
* **Kesin Çözüm ve Öneri:** Tab veya `DraggableScrollableSheet` tek panel odak; KO tarzı "Envanter | Banka" toggle.

* **Sorunlu Bileşen/Yer:** Drag affordance — keşfedilebilirlik sıfır
* **Hata Tanımı:** `LongPressDraggable` delay 120ms (satır 963) — UI'da "sürükle" ipucu yok; yalnızca boş slot `+` ikonu. Batch butonlar disabled (0 seçili) gri.
* **Kullanıcıya Etkisi:** Oyuncu long-press ve tap-select farkını keşfedemez; banka "çalışmıyor" şikayeti.
* **Kesin Çözüm ve Öneri:** İlk ziyaret coach mark; header altına `'Uzun bas: sürükle · Dokun: seç'`.

* **Sorunlu Bileşen/Yer:** Türkçe karakter / yazım — prod metin kalitesi
* **Hata Tanımı:** `'Genislet 50 gem'`, `'Kullanilan'`, `'Iptal'`, `'Tasima basarisiz'`, `'Yatirilacak gecerli item'` — ASCII Türkçe. Dialog `'Iptal'` (satır 345).
* **Kullanıcıya Etkisi:** Profesyonellik düşük; MMO kitlesi detay fark eder (inventory audit ile aynı tema).
* **Kesin Çözüm ve Öneri:** `AppStrings.bank.*` merkezi tablo; `Genişlet`, `Kullanılan`, `İptal`.

* **Sorunlu Bileşen/Yer:** Slot etiket tipografi — WCAG altı
* **Hata Tanımı:** Item adı overlay `fontSize: 8` (satır 859, 1051); slot index `7`; qty badge `9`.
* **Kullanıcıya Etkisi:** "Iron Sword" vs "Steel Axe" ayırt edilemez; yaşlı/küçük ekran.
* **Kesin Çözüm ve Öneri:** Tooltip/long-press detail sheet; grid 4 sütun veya daha büyük hücre.

* **Sorunlu Bileşen/Yer:** Bottom clearance — FAB/nav overlap
* **Hata Tanımı:** `Column` + `SafeArea` — `gameBottomBarClearance(context)` yok. Bank pagination (`1 / 10`) screenshot'ta nav bar üstünde; scroll body yok, alt banka satırı FAB yakını.
* **Kullanıcıya Etkisi:** Son envanter slotları (#16-20 sayfa 2+) thumb zone dışında.
* **Kesin Çözüm ve Öneri:** `Padding(bottom: gameBottomBarClearance(context))` veya `SingleChildScrollView` wrapper.

* **Sorunlu Bileşen/Yer:** `_buildStatsCard` — doluluk %0 ile 100 boş slot
* **Hata Tanımı:** Screenshot: Toplam 100, Kullanılan 0, Boş 100, Doluluk 0% — doğru ama "Genişlet 50 gem" CTA yeni oyuncuda agresif; maliyet `_expandCost` client-side hardcoded.
* **Kullanıcıya Etkisi:** Boş bankada bile gem sink görünür; fiyat tablosu UI'da yok.
* **Kesin Çözüm ve Öneri:** %80+ dolulukta göster; maliyet RPC'den.

* **Sorunlu Bileşen/Yer:** Hata mesajları — ham exception
* **Hata Tanımı:** `'Banka yuklenemedi: $e'` (satır 148), `'Tasima basarisiz: $e'` — Postgrest/RLS metni kullanıcıya.
* **Kullanıcıya Etkisi:** Teknik jargon korkutucu; destek yükü.
* **Kesin Çözüm ve Öneri:** `AppMessenger.showError(context, mapBankError(e))`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `bank_screen.dart` monolit (~1642 satır)
* **Risk/Maliyet:** Slot builder, drag logic, RPC, dialog — tek StatefulWidget; hot reload yavaş.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
lib/screens/bank/widgets/bank_slot_grid.dart
lib/screens/bank/bank_controller.dart  // Riverpod Notifier
```

* **Hatalı Kod Yapısı:** `_buildInventorySlots` — pozisyonsuz item fill cursor
* **Risk/Maliyet:** Satır 189-198: `slotPosition < 0` item'ları sırayla boş slotlara doldurur — sayfa değişince görsel slot kayması.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — backend slot_position zorunlu veya client-side stable sort
items.sort((a, b) => a.slotPosition.compareTo(b.slotPosition));
```

* **Hatalı Kod Yapısı:** `_withdrawSingle` — miktar diyaloğu sonrası tam çekim RPC
* **Risk/Maliyet:** `_askQuantity` ile `qty` seçilir (satır 589-599) ama RPC `withdraw_from_bank` yalnızca `p_bank_item_ids` — kısmi miktar parametresi yok; UI yanıltıcı.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
await client.rpc('withdraw_from_bank', params: {
  'p_bank_item_ids': [id],
  'p_quantities': [qty],
});
```

* **Hatalı Kod Yapısı:** `_stackableCache` — stale per session
* **Risk/Maliyet:** Item `max_stack` DB'de değişirse cache invalidate yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — inventory item model'den isStackable oku
final bool isStackable = item.isStackable;
```

* **Hatalı Kod Yapısı:** `_rarityColor` duplicate
* **Risk/Maliyet:** Satır 755-770 shop/trade ile kopya.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
import '../../theme/item_rarity.dart';
```

* **Hatalı Kod Yapısı:** `_inventoryPage` mutation during build
* **Risk/Maliyet:** Satır 1256-1258 build içinde `_inventoryPage = totalPages` — setState olmadan side effect.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
final int safePage = _inventoryPage.clamp(1, totalPages);
// veya didUpdateWidget'ta düzelt
```

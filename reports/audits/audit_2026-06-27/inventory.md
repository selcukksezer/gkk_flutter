---
# 📦 DOSYA/SAYFA ANALİZİ: InventoryScreen (`lib/screens/inventory/inventory_screen.dart`)

**Rota:** `/inventory`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/inventory.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/components/common/item_icon_view.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameTopBar` — route başlığı İngilizce
* **Hata Tanımı:** `GameTopBar(title: 'Inventory')` satır 37. Bottom nav aktif tab "Envanter" Türkçe; AppBar/route semantiği İngilizce.
* **Kullanıcıya Etkisi:** Dil tutarsızlığı; ekran okuyucu "Inventory" duyurur.
* **Kesin Çözüm ve Öneri:** `title: 'Envanter'` veya `AppStrings.routes.inventory`.

* **Sorunlu Bileşen/Yer:** Bölüm başlığı — yazım hatası ve ASCII Türkçe
* **Hata Tanımı:** `'Kusanilanlar'` (satır 485, 518) — doğrusu **"Kuşanılanlar"**. Ekran görüntüsünde de aynı hatalı yazım görünüyor. Hata mesajları: `'Envanter yuklenemedi.'`, `'Islem basarisiz'`, `'Kusanma basarisiz'`.
* **Kullanıcıya Etkisi:** Profesyonellik algısı düşer; MMO oyuncu kitlesi equip terminolojisine duyarlı.
* **Kesin Çözüm ve Öneri:** Merkezi string tablosu; tüm snack/dialog metinlerinde Türkçe karakter.

* **Sorunlu Bileşen/Yer:** Alt navigasyon / FAB çakışması — bottom clearance eksik
* **Hata Tanımı:** `SingleChildScrollView(padding: EdgeInsets.all(12))` — `gameBottomBarClearance(context)` yok (home'da var: satır 206-263). Ekran görüntüsünde envanter grid'i bottom nav + "Sohbet" FAB'a yakın; son slot satırı (~4×5 grid 20 slot) scroll sonunda nav altında kalabilir.
* **Kullanıcıya Etkisi:** Son envanter slotları thumb zone/nav bar arkasında; drag-drop hedefi zor.
* **Kesin Çözüm ve Öneri:** `padding: EdgeInsets.fromLTRB(12, 12, 12, gameBottomBarClearance(context) + kGameChatFabSize + 12)`.

* **Sorunlu Bileşen/Yer:** Filtre çubuğu — gizlenen item'lar boş numaralı slot bırakıyor
* **Hata Tanımı:** `_matchesFilter` false ise `item = null` render edilir; slot yine numaralı boş hücre (`${slotIndex + 1}`). Filtre "Silah" seçiliyken envanter 0/20 gösterir ama 20 boş kutucuk — kullanıcı "item kayboldu" sanabilir.
* **Kullanıcıya Etkisi:** Filtre UX kafa karıştırıcı; KO/MMO standardında filtre yalnızca dolu slotları listeler veya empty state gösterir.
* **Kesin Çözüm ve Öneri:** Filtre modunda `itemCount: filteredItems.length` ayrı grid; veya filtre aktifken boş slotları gizle + "Bu filtrede eşya yok" mesajı.

* **Sorunlu Bileşen/Yer:** `_SelectedItemPanel` — açık tema dialog koyu envanter üzerinde
* **Hata Tanımı:** Dialog arka plan `#FFFFFF`, sarı KO-style CTA `#F2D74C`; envanter `#090D14` gradient + glass card. Bilinçli KO referansı olsa da ekran görüntüsü dışı deneyim: gece modu oyuncuya anlık flashbang. Label'lar ASCII: `ESYA ADI`, `DEGER`, `COP`, `BOL`, `KULLAN`.
* **Kullanıcıya Etkisi:** Marka tutarsızlığı; OLED'de parlak panel göz yorgunluğu.
* **Kesin Çözüm ve Öneri:** `GkkCard` dark variant ile panel; KO layout korunup `AppColors.bgCard` zemin. Metin: `EŞYA ADI`, `DEĞER`, `ÇÖP`.

* **Sorunlu Bileşen/Yer:** Kuşanılan slot — tek dokunuşla unequip, onay yok
* **Hata Tanımı:** `_EquippedPanel` `onTap: hasItem ? () => onUnequip(slotMeta.$1) : null` — yanlış dokunuşta ekipman anında çıkar. Sağ üst `Icons.close` 9px — affordance zayıf, touch target ~48dp slot içinde küçük ikon.
* **Kullanıcıya Etkisi:** Kazara unequip; PvP/dungeon öncesi kritik build kaybı.
* **Kesin Çözüm ve Öneri:** Long-press unequip veya confirm dialog; close ikon minimum 24dp hit area.

* **Sorunlu Bileşen/Yer:** 5 sütun grid — mobil touch target sınırda
* **Hata Tanımı:** `crossAxisCount: 5`, `crossAxisSpacing: 8`, padding 12 — iPhone 390pt genişlikte slot ~`(390-24-32)/5 ≈ 67dp`. WCAG önerilen 44dp üstünde ama `LongPressDraggable` + komşu slotlar yanlış drop riski yüksek. Slot numarası `fontSize: 10`, `Colors.white12` — kontrast ~1.5:1.
* **Kullanıcıya Etkisi:** Yaşlı/kalın parmak kullanıcıda drag hassasiyeti düşük; boş slot numaraları neredeyse görünmez.
* **Kesin Çözüm ve Öneri:** Mobile'da 4 sütun; `LayoutBuilder` ile breakpoint. Numara rengi `white38` minimum.

* **Sorunlu Bileşen/Yer:** Kapasite göstergesi — `0/20` smoke verisi ile boş envanter
* **Hata Tanımı:** Ekran görüntüsünde tüm slotlar boş, equipped panel boş — QA smoke hesabında starter item yok. Yeni oyuncu "envanter neden boş / oyun mu bozuk" algısı (onboarding gap).
* **Kullanıcıya Etkisi:** İlk envanter ziyareti motivasyon düşük; drag-drop tutorial yok.
* **Kesin Çözüm ve Öneri:** Onboarding'de starter item seed; empty state illustration + "Zindandan loot topla" CTA.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Monolitik 1675 satır — tek dosyada UI + DnD + dialog + API
* **Risk/Maliyet:** Bakım maliyeti; `_InventoryReadyInteractiveState` 600+ satır handler. Test izolasyonu imkansız.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN dosya ayrımı
// inventory_screen.dart — scaffold + provider switch
// widgets/equipped_panel.dart, inventory_grid.dart, item_action_panel.dart
// inventory_drag_controller.dart — drop logic unit test
```

* **Hatalı Kod Yapısı:** `_InventoryReadyView` gereksiz passthrough wrapper
* **Risk/Maliyet:** `_InventoryReadyView` yalnızca `_InventoryReadyInteractive` döndürür — ekstra widget layer, state promotion engellenir.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — satır 74-88
InventoryStatus.ready => _InventoryReadyView(state: inventoryState),

// OLMASI GEREKEN
InventoryStatus.ready => _InventoryReadyInteractive(state: inventoryState),
```

* **Hatalı Kod Yapısı:** Grid `itemBuilder` içinde DnD + filter + selection — O(n) slot lookup her rebuild
* **Risk/Maliyet:** `_getItemBySlot` her index için linear scan; 20 slot × rebuild kabul edilebilir ama filter değişiminde 20× LongPressDraggable yeniden oluşur.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — build öncesi map
final slotMap = { for (final i in state.items) i.slotPosition: i };
// itemBuilder: final rawItem = slotMap[index];
```

* **Hatalı Kod Yapısı:** `onWillAcceptWithDetails` — if without braces, lint risk
* **Risk/Maliyet:** Satır 658-661 tek satır if; future edit'te bug. `onWillAcceptWithDetails: (details) => true` equipped panel'de her payload kabul — invalid drop sonra snack ile reddedilir (geç feedback).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — equipped slot
onWillAcceptWithDetails: (d) {
  final slot = EquipSlot.fromName(slotMeta.$1);
  return d.data.item.equipSlot == slot;
},
```

* **Hatalı Kod Yapısı:** `_QuantityActionDialog` — `_quantity` init her zaman 1, maxQuantity edge case
* **Risk/Maliyet:** `maxQuantity < 1` ise `_quantity = 1` ama slider `max: 1, min: 1` — split dialog stack qty=1 item'da anlamsız açılabilir (guard `_handleSplit`'te var ama dialog yine açılır route'da).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — dialog açmadan önce
if (!item.isStackable || item.quantity <= 1) {
  _showSnack('Bu eşya bölünemez.');
  return;
}
```

* **Hatalı Kod Yapısı:** Duplicate logout — home ile aynı pattern, inventory clear var ama character/settings'te farklı
* **Risk/Maliyet:** `onLogout` AppBar + BottomBar duplicate (satır 38-42, 47-51); character screen inventory clear yapmıyor — cross-screen state tutarsızlığı.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — shared LogoutService
await ref.read(sessionControllerProvider.notifier).logout(); // clears all providers
```

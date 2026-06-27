---
# 📦 DOSYA/SAYFA ANALİZİ: EnhancementScreen (`lib/screens/enhancement/enhancement_screen.dart`)

**Rota:** `/enhancement`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/enhancement.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/models/item_model.dart` (`getRarityColor`)  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/components/common/item_icon_view.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Sohbet FAB — Risk satırı overlap
* **Hata Tanımı:** `GameBottomBar` + `GameChatFab` stack; `_buildInfoPanel` son satır `'Risk'` (satır 1159-1163). Screenshot'ta FAB "Risk" label/value üzerine bindiriyor — `SingleChildScrollView` padding bottom clearance yok.
* **Kullanıcıya Etkisi:** +4/+6 yok olma riski metni okunamaz; enhancement kararı yanlış.
* **Kesin Çözüm ve Öneri:** `padding: EdgeInsets.only(bottom: gameBottomBarClearance(context) + 16)`.

* **Sorunlu Bileşen/Yer:** Üç yuva paneli — yatay sıkışma / overflow
* **Hata Tanımı:** `_buildThreeSlotPanel` tek `Row`: Eşya + Rune + 3×3 Parşömen (flex 2) + Önizleme (satır 617-694). Dar telefonda (390pt) screenshot'ta parşömen grid kayık; label `'Parşömen (9)'` 10px.
* **Kullanıcıya Etkisi:** Drag hedefleri ~24dp; parmak isabeti düşük; KO +9 fantasy kaybı (9 slot gereksiz).
* **Kesin Çözüm ve Öneri:** Dikey stack mobil breakpoint; tek parşömen slotu (server zaten 1 scroll).

* **Sorunlu Bileşen/Yer:** 9 parşömen slotu — UI teatrı
* **Hata Tanımı:** `_maxScrollSlots = 9` (satır 188); `_findCompatibleScroll` yalnızca ilk uyumlu scroll (satır 293-301). 9 slot KO nostalji ama işlevsel değil.
* **Kullanıcıya Etkisi:** Oyuncu 9 slot doldurmaya çalışır; yalnızca biri sayılır — kafa karışıklığı.
* **Kesin Çözüm ve Öneri:** 1 slot + "bonus scroll" feature flag; veya tooltip.

* **Sorunlu Bileşen/Yer:** Maliyet vs bakiye — doğru renk, yanlış erişilebilirlik
* **Hata Tanımı:** Screenshot: Maliyet **100.0K**, Altın **50.0K** kırmızı — `_formatGold` + `hasEnoughGold` doğru. Güçlendir butonu disabled OK. Ancak `'Gerekli Parşömen'` boş (eşya seçilmemiş) — empty state net değil.
* **Kullanıcıya Etkisi:** Yeni oyuncu neden disabled anlamaz; parşömen gereksinimi görünmez.
* **Kesin Çözüm ve Öneri:** Empty state CTA: `'Envanterden eşya sürükleyin'`.

* **Sorunlu Bileşen/Yer:** Client-side maliyet/şans tablosu — sunucu drift
* **Hata Tanımı:** `_kUpgradeChances`, `_kUpgradeCosts` (satır 55-81) hardcoded; UI tablo + info panel bunları gösterir; gerçek `enhance_item` RPC farklı olabilir.
* **Kullanıcıya Etkisi:** UI %100 şans, sunucu fail → güven kaybı.
* **Kesin Çözüm ve Öneri:** `get_enhancement_config` RPC; tek kaynak.

* **Sorunlu Bileşen/Yer:** Post-enhance auto-reset — 3 sn
* **Hata Tanımı:** Satır 277-284: dialog sonrası 3 sn bekleyip seçimi sıfırlar — hızlı ardışık + basma engellenir.
* **Kullanıcıya Etkisi:** Power user friction; başarılı +7 sonrası tekrar sürüklemek zorunda.
* **Kesin Çözüm ve Öneri:** Reset yalnız destroyed'da; success'te item seçili kalsın.

* **Sorunlu Bileşen/Yer:** Türkçe ASCII — panel başlıkları
* **Hata Tanımı:** `'Envanter Izgarası'` (satır 1362), `'Oturum bulunamadi!'` (satır 213) — İ/ı/ş eksik.
* **Kullanıcıya Etkisi:** Inventory/bank ile aynı kalite sorunu.
* **Kesin Çözüm ve Öneri:** Merkezi strings.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — route doğru geçiliyor ama screenshot enhancement'ta Home?
* **Hata Tanımı:** Kod `AppRoutes.enhancement` — `_activeIndex` yine Home fallback. Screenshot bilgi paneli görünür → enhancement route; nav Home.
* **Kullanıcıya Etkisi:** Cross-cutting.
* **Kesin Çözüm ve Öneri:** Menü indicator.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_EnhancementDesignSystem` — tema duplicate
* **Risk/Maliyet:** Satır 19-50 inline colors/spacing; `AppColors`/`AppSpacing` overlap.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — theme extension
Theme.of(context).extension<EnhancementTheme>()!
```

* **Hatalı Kod Yapısı:** `_enhance` — unsafe cast
* **Risk/Maliyet:** `result as Map<String, dynamic>` (satır 246) — wrong type crash.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
if (result is! Map<String, dynamic>) {
  _showSnack('Beklenmeyen yanıt');
  return;
}
```

* **Hatalı Kod Yapısı:** `_buildInventoryGrid` — slotPosition only, 20 slot cap
* **Risk/Maliyet:** Satır 1391-1397: pozisyonsuz item grid'de görünmez; max 20 — büyük envanter kesilir.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — filter enhanceable/scroll/rune + scrollable grid
final items = inventory.items.where((i) => _isEnhanceable(i) || _isScrollItem(i) || _isRuneItem(i));
```

* **Hatalı Kod Yapısı:** `_ItemPickerSheet` — dead code?
* **Risk/Maliyet:** Satır 1627+ tanımlı ama grep'te kullanılmıyor; drag-only UX.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — kullan veya sil; tap-to-pick sheet ekle
```

* **Hatalı Kod Yapısı:** `enhancement_screen_new.dart` — paralel implementasyon
* **Risk/Maliyet:** Repo'da iki enhancement screen; router hangisini kullanıyor belirsizlik riski.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — unused file sil veya router tek kaynak
```

* **Hatalı Kod Yapısı:** Rune seçimi — drag vs dropdown karışık
* **Risk/Maliyet:** `_selectedRune` string enum; `_kRuneTypes` listede UI picker yok — yalnızca drag `rune_*` item.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — rune slot tap → bottom sheet _kRuneLabels
```

---
# 📦 DOSYA/SAYFA ANALİZİ: CraftingScreen (`lib/screens/crafting/crafting_screen.dart`)

**Rota:** `/crafting`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/crafting.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/providers/crafting_provider.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/components/common/item_icon_view.dart`, `lib/models/crafting_model.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Tarif kartları — İngilizce isim / Türkçe UI
* **Hata Tanımı:** Screenshot grid: "Bone Amulet", "Leather Choker", "Copper Pendant" vb.; başlık `'🔨 Üretim Atölyesi'`, uyarı `'⚠ Malzeme yok'`. Backend `recipe.name` localize edilmemiş.
* **Kullanıcıya Etkisi:** TR oyuncu kitlesi için yabancılaşma; KO clone beklentisi Türkçe item adları.
* **Kesin Çözüm ve Öneri:** `items.name_tr` veya `CraftRecipe.localizedName`; fallback EN.

* **Sorunlu Bileşen/Yer:** Elmas gösterimi — ondalık tutarsızlık
* **Hata Tanımı:** Header `'💎 $playerGems'` (satır 381-387) — screenshot **500.0**; `GameTopBar` **500**. Aynı shop/bank teması.
* **Kullanıcıya Etkisi:** Bakiye güveni zayıf.
* **Kesin Çözüm ve Öneri:** Shared `formatGems(profile.gems)`.

* **Sorunlu Bileşen/Yer:** `_RecipeCard` — çıktı ikonu yok
* **Hata Tanımı:** Kart yalnızca 8px rarity dot + metin (satır 985-1030); `ItemIconView` yok. Screenshot'ta tüm kartlar metin ağırlıklı, görsel ayırt zor.
* **Kullanıcıya Etkisi:** 20+ tarif arasında tarama yavaş; MMO crafting grid görsel bekler.
* **Kesin Çözüm ve Öneri:** 48dp output icon merkez; malzeme yok overlay köşede.

* **Sorunlu Bileşen/Yer:** Başarı oranı — çift format riski
* **Hata Tanımı:** `_RecipeCard`: `(recipe.successRate * 100)` (satır 1016); `_PreviewPanel._parseRate`: `value > 1 ? value/100 : value` (satır 513-516). DB `success_rate=80` → kart **8000%**, preview **80%**.
* **Kullanıcıya Etkisi:** Yanlış karar (craft etme/etmeme); ekonomi kaybı.
* **Kesin Çözüm ve Öneri:** `CraftRecipe.normalizedSuccessRate` tek helper; model parse'da normalize.

* **Sorunlu Bileşen/Yer:** Süre formatı — `_formatDuration` kafa karıştırıcı
* **Hata Tanımı:** Satır 51: `'${h}s ${m}d ${s}sn'` — `s` saat, `d` dakika (Türkçe'de `s` saniye sanılır). Preview chip'te kullanılıyor.
* **Kullanıcıya Etkisi:** "1s 30d" = 1 saat 30 dk mi 1 sn 30 gün mü?
* **Kesin Çözüm ve Öneri:** `'${h}sa ${m}dk ${s}sn'` veya `Duration` + `intl`.

* **Sorunlu Bileşen/Yer:** Kuyruk overlay — FAB/nav çakışması
* **Hata Tanımı:** `_QueueSection` `Positioned(bottom: 12)` (satır 454-471); `gameBottomBarClearance` yok. Aktif kuyruk açıkken Sohbet FAB + bottom nav üstüne biner.
* **Kullanıcıya Etkisi:** "Talep Et" butonu thumb zone dışında veya FAB altında.
* **Kesin Çözüm ve Öneri:** `bottom: gameBottomBarClearance(context) + 12`.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** `/crafting` menü rotası; screenshot Home aktif.
* **Kullanıcıya Etkisi:** Cross-cutting nav bug (diğer ekonomi ekranları ile aynı).
* **Kesin Çözüm ve Öneri:** Menü tab map.

* **Sorunlu Bileşen/Yer:** Malzeme yok uyarısı — 9px turuncu
* **Hata Tanımı:** `'⚠ Malzeme yok'` fontSize 9 (satır 1026-1028); screenshot'ta her kartta tekrar — grid gürültülü, hepsi aynı durum (QA envanter boş).
* **Kullanıcıya Etkisi:** Alarm yorgunluğu; gerçek craft-ready tarif kaybolur.
* **Kesin Çözüm ve Öneri:** Filtre "Craft edilebilir"; yoksa soluk kart + tooltip.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Tab sync — `TabController` vs provider
* **Risk/Maliyet:** `_onTabChanged` provider'a yazar; init'te `_tabController.index` ile `craftState.selectedTab` senkron garanti değil — ilk frame yanlış filtre.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — initState sonunda
_tabController.index = _kTabs.indexWhere((t) => t.$1 == craftState.selectedTab).clamp(0, _kTabs.length - 1);
```

* **Hatalı Kod Yapısı:** `_queueTimer` — her saniye full `setState`
* **Risk/Maliyet:** Satır 133-137 tüm ekranı rebuild; büyük recipe grid + dialog açıkken jank.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — yalnızca _QueueSection StatefulWidget timer
// veya ValueNotifier<int> tick for queue tiles only
```

* **Hatalı Kod Yapısı:** `_rarityColor` — Material `Colors.green` vs hex elsewhere
* **Risk/Maliyet:** Satır 31-44 farklı palette (shop hex); görsel tutarsızlık.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
import '../../theme/item_rarity.dart';
```

* **Hatalı Kod Yapısı:** `_PreviewPanel` — `Dialog` + `Consumer` iç içe
* **Risk/Maliyet:** 400+ satır widget aynı dosyada; preview dialog test edilemez.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
lib/screens/crafting/widgets/craft_preview_dialog.dart
```

* **Hatalı Kod Yapısı:** `_autoFinalizeCompletedItems` — fire-and-forget RPC
* **Risk/Maliyet:** `_pendingFinalizations` set; fail durumunda sessiz kalır; duplicate finalize retry yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
finalizeCraftedItem(item.id).catchError((e) {
  _pendingFinalizations.remove(item.id);
  _showSnack(mapError(e));
});
```

* **Hatalı Kod Yapısı:** logout — inventory clear eksik
* **Risk/Maliyet:** Satır 328-331.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(inventoryProvider.notifier).clear();
```

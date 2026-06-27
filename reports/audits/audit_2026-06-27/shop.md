---
# 📦 DOSYA/SAYFA ANALİZİ: ShopScreen (`lib/screens/shop/shop_screen.dart`)

**Rota:** `/shop`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/shop.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/components/common/item_icon_view.dart`, `lib/components/common/app_messenger.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — alt nav aktif sekme yanlış
* **Hata Tanımı:** `GameBottomBar(currentRoute: AppRoutes.shop)` doğru geçiliyor; `_activeIndex` (`game_chrome.dart` satır 724-731) yalnızca Home/Envanter/Zindan/Karakter/Menü rotalarını tanır — `/shop` eşleşmez → fallback index 0 (Home). Screenshot'ta Mağaza içeriği açıkken "Home" mavi highlight.
* **Kullanıcıya Etkisi:** Oyuncu hangi bölümde olduğunu kaybeder; Menü'den açılan tüm ekonomi ekranları aynı hatayı paylaşır.
* **Kesin Çözüm ve Öneri:** Menü-only rotalar için `leadingOverlay` veya nötr indicator; ya da `_activeIndex` son eşleşmeyi "Menü" tab'ına map et.

* **Sorunlu Bileşen/Yer:** Cüzdan şeridi — elmas format tutarsızlığı
* **Hata Tanımı:** Header `GameTopBar` gems `500` (int); mağaza şeridi `'$gems'` → screenshot'ta **500.0** görünür (`profile.gems` num/double). Altın `_fmtGold` → `50K` vs header `50.0k`.
* **Kullanıcıya Etkisi:** Aynı oturumda iki farklı bakiye formatı güven kaybı; elmas ondalık gereksiz.
* **Kesin Çözüm ve Öneri:** Shared `formatGems()` / `formatGold()` — `lib/core/utils/currency_format.dart`; int cast veya `toStringAsFixed(0)`.

* **Sorunlu Bileşen/Yer:** Tab etiketleri — dil karışımı
* **Hata Tanımı:** TabBar: `'💎 Gem'` (İngilizce) yanında `'💰 Altın'`, `'🛍️ Eşya'` (Türkçe). Kart içi `'Elmas'` Türkçe.
* **Kullanıcıya Etkisi:** Lokalizasyon tutarsız; App Store/TR oyuncu kitlesi için amatör izlenim.
* **Kesin Çözüm ve Öneri:** `'💎 Elmas'` veya merkezi `AppStrings.shop.tabs.gems`.

* **Sorunlu Bileşen/Yer:** `_GemPackagesTab` — sahte IAP / prod güvenlik
* **Hata Tanımı:** `_buyGemPackage` (satır 402-450) doğrudan `users.update({gems: currentGems + pkg.gems})` — StoreKit/Play Billing yok, fiyat `$0.99` yalnızca UI. QA smoke hesabında ücretsiz elmas enflasyonu.
* **Kullanıcıya Etkisi:** Prod'da ekonomi çöküşü veya store reddi; test ortamında gerçek satın alma yanılsaması.
* **Kesin Çözüm ve Öneri:** `in_app_purchase` + sunucu receipt doğrulama RPC; dev'de feature flag `mock_iap`.

* **Sorunlu Bileşen/Yer:** `_GoldPackagesTab` — scroll kilitli
* **Hata Tanımı:** `ListView.separated(physics: NeverScrollableScrollPhysics())` (satır 774) — TabBarView içinde 4 paket sığmazsa taşma/kesilme; screenshot Gem sekmesinde grid OK ama Altın sekmesi dar cihazda risk.
* **Kullanıcıya Etkisi:** Son altın paketi görünmez; satın alma dönüşümü düşer.
* **Kesin Çözüm ve Öneri:** `physics: BouncingScrollPhysics()` veya `AlwaysScrollableScrollPhysics`.

* **Sorunlu Bileşen/Yer:** `_ItemsTab` — 4 sütun grid okunabilirlik
* **Hata Tanımı:** `crossAxisCount: 4`, isim `fontSize: 9.5`, fiyat `10` — screenshot benzeri inventory grid pattern. Uzun isimler `ellipsis`; nadir dot 6×6px.
* **Kullanıcıya Etkisi:** Eşya mağazasında isim/fiyat tarama zor; yanlış satın alma riski.
* **Kesin Çözüm ve Öneri:** `crossAxisCount: 3` veya `LayoutBuilder` breakpoint; min label 11px.

* **Sorunlu Bileşen/Yer:** Miktar diyaloğu — TextEditingController anti-pattern
* **Hata Tanımı:** Satır 603: `TextEditingController(text: '$_quantityInput')..selection` her rebuild'de yeni controller — focus kaybı, memory leak riski, cursor sıçraması.
* **Kullanıcıya Etkisi:** Stackable eşyada miktar girerken klavye/input reset.
* **Kesin Çözüm ve Öneri:** Stateful dialog veya `TextFormField` + persistent controller.

* **Sorunlu Bileşen/Yer:** `_BattlePassTab` / `_OffersTab` — yarım özellik
* **Hata Tanımı:** Battle Pass `'Muharebe Geçidi yakında aktif olacak.'`; Teklif sekmesi salt okunur kart — satın alma CTA yok. Screenshot Gem sekmesinde; kullanıcı diğer sekmelere geçince boş/teaser.
* **Kullanıcıya Etkisi:** Bitmemiş prod sinyali; Pass emoji tab (`⚔️ Pass`) İngilizce.
* **Kesin Çözüm ve Öneri:** Feature flag ile sekme gizle veya `ComingSoonBadge`; Pass → `'Savaş Bileti'`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Monolitik `shop_screen.dart` (~1137 satır)
* **Risk/Maliyet:** 5 tab widget + RPC + IAP logic tek dosyada; test ve tema drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — tüm tab'lar shop_screen.dart içinde private class

// OLMASI GEREKEN
lib/screens/shop/widgets/gem_packages_tab.dart
lib/screens/shop/shop_repository.dart  // buy_shop_item, gold exchange RPC
```

* **Hatalı Kod Yapısı:** `_buyGoldPackage` — client-side users.update bypass
* **Risk/Maliyet:** Satır 377-383 doğrudan Supabase update; `buy_shop_item` RPC pattern'i ile tutarsız; race condition iki sekme açıkken.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
await SupabaseService.client.rpc('exchange_gems_for_gold', params: {...});
await ref.read(playerProvider.notifier).loadProfile();
```

* **Hatalı Kod Yapısı:** `_rarityColor` — duplicate renk haritası
* **Risk/Maliyet:** Satır 226-235; bank/trade/loot ile aynı hex map kopyalanmış — drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
import '../../theme/item_rarity.dart';
color: rarityColor(item['rarity']),
```

* **Hatalı Kod Yapısı:** `_doLogout` — inventory clear eksik
* **Risk/Maliyet:** Satır 458-461 yalnızca auth + player; loot ekranı `inventoryProvider.clear()` çağırır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — shared session teardown helper
await ref.read(inventoryProvider.notifier).clear();
```

* **Hatalı Kod Yapısı:** Hardcoded gradient — `GameScreenBackground` kullanılmıyor
* **Risk/Maliyet:** Satır 478-483 inline `LinearGradient`; home/character ile farklı ton.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
body: GameScreenBackground(child: Column(...)),
```

* **Hatalı Kod Yapısı:** `_mapItemsForShop` legacy fallback — tüm items yükleme
* **Risk/Maliyet:** `shop_available` boşsa tüm `items` tablosu mağazaya düşer (satır 173-186) — QA'da yanlış fiyat/availability.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — legacy fallback kaldır veya admin-only flag
if (mappedShopItems.isEmpty) showEmptyState(); // tüm DB'yi satma
```

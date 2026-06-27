---
# 📦 DOSYA/SAYFA ANALİZİ: MarketScreen (`lib/screens/market/market_screen.dart`)

**Rota:** `/market`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/market.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/screens/market/widgets/market_browse_tab.dart`, `lib/screens/market/widgets/market_sell_tab.dart`, `lib/screens/market/widgets/market_my_market_tab.dart`, `lib/screens/market/widgets/market_tab_bar.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Boş pazar — `Sonuc yok`
* **Hata Tanımı:** Screenshot'ta Gözat sekmesi filtreler açık, liste boş; yalnızca gri `Sonuc yok` metni. Neden boş (gerçekten işlem yok / filtre / API) belirtilmiyor.
* **Kullanıcıya Etkisi:** Oyuncu pazarın çalışmadığını sanır; ilk keşif motivasyonu düşer.
* **Kesin Çözüm ve Öneri:** Empty state: `Henüz ilan yok` + `İlk sen sat` → Sat sekmesi.

* **Sorunlu Bileşen/Yer:** ASCII Türkçe — başlık ve filtreler
* **Hata Tanımı:** `Oyuncu Pazari` (82) → `ı` eksik; tab `Gozat`, sıralama `Ucuz`/`Pahali`, `Tum Kategoriler`, `Tum Nadirlik`, `Sonuc yok` — screenshot'ta doğrulandı.
* **Kullanıcıya Etkisi:** Login/register/home pantheon ile aynı i18n borcu.
* **Kesin Çözüm ve Öneri:** `Oyuncu Pazarı`, `Gözat`, `Tüm Kategoriler`, `Sonuç yok`.

* **Sorunlu Bileşen/Yer:** Çift başlık
* **Hata Tanımı:** AppBar `Pazar` (64) + gövde `Oyuncu Pazari` (82).
* **Kullanıcıya Etkisi:** Dikey alan israfı; hangi ismin resmi olduğu belirsiz.
* **Kesin Çözüm ve Öneri:** Tek başlık; alt başlığı kaldır veya `GameTopBar` subtitle.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** Pazar menü rotası; bottom nav Home seçili (screenshot).
* **Kullanıcıya Etkisi:** Navigasyon tutarsızlığı.
* **Kesin Çözüm ve Öneri:** Menü highlight pattern (pvp/guild ile ortak fix).

* **Sorunlu Bileşen/Yer:** Alt padding — FAB + nav overlap
* **Hata Tanımı:** `ListView(padding: EdgeInsets.fromLTRB(12, 8, 12, 12))` (76); `extendBody: true` + Sohbet FAB. `gameBottomBarClearance` kullanılmıyor.
* **Kullanıcıya Etkisi:** Dolu listede son ilanlar kesilir.
* **Kesin Çözüm ve Öneri:** `gameBottomContentPadding(context)` alt inset.

* **Sorunlu Bileşen/Yer:** Nested scroll riski
* **Hata Tanımı:** Shell `ListView` içinde `MarketBrowseTab` kendi scroll'unu yönetebilir; çift scroll veya shrinkWrap performans sorunu.
* **Kullanıcıya Etkisi:** Scroll "takılır" veya bounce garip.
* **Kesin Çözüm ve Öneri:** Shell `Column` + `Expanded(child: tab)`; tab içi tek scroll owner.

* **Sorunlu Bileşen/Yer:** Olumlu — tema uyumu
* **Hata Tanımı:** Shell `AppColors.bgDeep` / `bgBase` gradient kullanıyor (68–73) — bu audit grubunda en tutarlı arka plan.
* **Kullanıcıya Etkisi:** Olumlu.
* **Kesin Çözüm ve Öneri:** Diğer menü ekranlarına aynı pattern yay.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Tab değişiminde her seferinde reload
* **Risk/Maliyet:** `_onTabChanged` browse/myMarket'te her tap `loadTickers`/`loadMyOrders` (42–50).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
void _onTabChanged(MarketTab tab) {
  setState(() => _tab = tab);
  ref.read(marketProvider.notifier).loadTickers();
}

// OLMASI GEREKEN
if (!ref.read(marketProvider).tickersLoaded) {
  ref.read(marketProvider.notifier).loadTickers();
}
```

* **Hatalı Kod Yapısı:** `ListView` shell — tab body için anti-pattern
* **Risk/Maliyet:** Tüm tab içeriği ListView child; unbounded height riski (75–114).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
body: Column(
  children: [
    _MarketHeader(...),
    MarketTabBar(...),
    Expanded(child: switch (_tab) { ... }),
  ],
)
```

* **Hatalı Kod Yapısı:** Refresh yok
* **Risk/Maliyet:** `_loadInitial` yalnızca post-frame (30–39).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
RefreshIndicator(onRefresh: _loadInitial, child: ...)
```

* **Hatalı Kod Yapısı:** Inline `TextStyle` başlık
* **Risk/Maliyet:** `AppTextStyles` bypass (83–86).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
```

* **Hatalı Kod Yapısı:** Logout inventory clear — diğer ekranlarla tutarsız
* **Risk/Maliyet:** Market `_logout` inventory clear yapar (56); pvp yapmaz.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — shared AuthActions.signOut(ref)
await ref.read(authProvider.notifier).logout();
ref.read(playerProvider.notifier).clear();
ref.read(inventoryProvider.notifier).clear();
```

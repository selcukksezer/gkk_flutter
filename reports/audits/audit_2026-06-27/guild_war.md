---
# 📦 DOSYA/SAYFA ANALİZİ: GuildWarHubScreen (`lib/screens/guild_war/guild_war_hub_screen.dart`)

**Rota:** `/guild-war`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/guild_war.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`  
**İlgili widget'lar:** `lib/screens/guild_war/widgets/guild_war_season_header.dart`, `lib/screens/guild_war/widgets/guild_war_tab_bar.dart`, `lib/screens/guild_war/widgets/ranking_podium.dart`, `lib/screens/guild_war/widgets/territory_map_view.dart`, `lib/components/layout/game_chrome.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home yanlış aktif
* **Hata Tanımı:** `currentRoute: AppRoutes.guildWar` (`/guild-war`) bottom bar `_items` listesinde yok; `_activeIndex` eşleşme bulamayınca `0` (Home) döner (`game_chrome.dart` 724–731). Screenshot'ta Lonca Savaşı ekranındayken Home mavi highlight.
* **Kullanıcıya Etkisi:** Oyuncu hangi hub'da olduğunu nav'dan anlayamaz; Menü'den gelinen derin rotalarda konum kaybı.
* **Kesin Çözüm ve Öneri:** `_matches` içinde drawer/quick-menu rotaları için Menü highlight veya `GameBottomBar` dışı rotalarda nötr state; en azından `guildWar` prefix → Menü aktif.

* **Sorunlu Bileşen/Yer:** Lonca üyeliği uyarısı — `Lonca Bul` CTA görsel hiyerarşi
* **Hata Tanımı:** `guildId == null` iken sarı çerçeveli tam genişlik `TextButton('Lonca Bul')` sezon kartı + 4 tab arasında sıkışık (`guild_war_hub_screen.dart` 167–185). Screenshot'ta turnuva/saldırı aksiyonları görünmeden önce tek CTA; uyarı metni yok, sadece buton.
* **Kullanıcıya Etkisi:** Lonca savaşı özelliklerini keşfeden oyuncu neden katılamadığını anlamaz; CTA tıklanmadan tab içerikleri anlamsız (sıralama dışı lonca yok).
* **Kesin Çözüm ve Öneri:** Banner: "Lonca üyeliği gerekli" + ikincil "Lonca Bul"; tab'ler disabled overlay.

* **Sorunlu Bileşen/Yer:** `RankingPodium` — podium tipografi
* **Hata Tanımı:** `_PodiumSlot` guild adı `fontSize: 10`, puan `9` (`ranking_podium.dart` 86–99). Screenshot'ta #1/#2 kartlarında "aaaaaa", "kankaja" okunur ama puan satırı küçük; `#` numarası 24px kartın ~%60'ını kaplar — bilgi/ornament oranı ters.
* **Kullanıcıya Etkisi:** Sıralama taraması yavaş; uzun lonca adları ellipsis ile kaybolur.
* **Kesin Çözüm ve Öneri:** İsim min 11px; dev `#` yerine medal + compact rank badge.

* **Sorunlu Bileşen/Yer:** Tab bar + `Savaş Kayıtları` — dikey alan tüketimi
* **Hata Tanımı:** `GuildWarSeasonHeader` + `GuildWarTabBar` + `OutlinedButton` (Savaş Kayıtları) + `NestedScrollView` header hepsi fold üstünde (`guild_war_hub_screen.dart` 155–206). Screenshot'ta podium altı (#3+) viewport dışında; scroll gerektirir.
* **Kullanıcıya Etkisi:** İlk bakışta yalnızca top-2; geri kalan sıra gizli kalır.
* **Kesin Çözüm ve Öneri:** Kayıtlar butonunu AppBar action veya tab içi FAB; header compact mode.

* **Sorunlu Bileşen/Yer:** `GuildWarTabBar` — 4 emoji tab dar ekran
* **Hata Tanımı:** `isScrollable: tabs.length > 3` → 4 tab scrollable (`guild_war_tab_bar.dart` 28). Label `fontSize: 11` emoji+metin; küçük cihazda "Krallık" kısmen görünür, yatay kaydırma affordance yok.
* **Kullanıcıya Etkisi:** 4. tab keşfedilmez; kingdom election gizli kalır.
* **Kesin Çözüm ve Öneri:** Scroll hint gradient veya 2×2 grid tab; `TabBar` `tabAlignment: TabAlignment.start`.

* **Sorunlu Bileşen/Yer:** Bölge haritası — sabit 420pt yükseklik
* **Hata Tanımı:** `_buildTerritoriesContent` map view `SizedBox(height: 420)` (`guild_war_hub_screen.dart` 294–301). iPhone SE viewport ~667pt; header+tab+420 harita = liste moduna geçmeden scroll zorunlu.
* **Kullanıcıya Etkisi:** Harita modunda diğer bölgeler görünmez; toggle fark edilmez.
* **Kesin Çözüm ve Öneri:** `LayoutBuilder` ile `min(420, constraints.maxHeight * 0.45)`; varsayılan Liste modu mobilde.

* **Sorunlu Bileşen/Yer:** Gradient duplicate — tema dışı
* **Hata Tanımı:** Body `LinearGradient` hardcoded `0xFF090D14` (`guild_war_hub_screen.dart` 145–150); `GameScreenBackground` / `AppColors` ile aynı ton ama ayrı sabit.
* **Kullanıcıya Etkisi:** Mikro renk drift diğer hub ekranlarıyla.
* **Kesin Çözüm ve Öneri:** `GameScreenBackground` veya shared gradient token.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `NestedScrollView` + `TabBarView` + `SliverOverlapInjector`
* **Risk/Maliyet:** `_scrollTab` her tab için ayrı `CustomScrollView` + overlap injector; tab switch'te scroll pozisyonu korunur ama header yüksekliği değişince overlap glitch riski.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — 4× NestedScrollView overhead
body: TabBarView(
  children: [_scrollTab(child: RankingPodium(...)), ...],
)

// OLMASI GEREKEN — PrimaryScrollController veya tek CustomScrollView + TabBarView primary:false
DefaultTabController + CustomScrollView(slivers: [header, TabBar, SliverFillRemaining(child: TabBarView(...))])
```

* **Hatalı Kod Yapısı:** `_myRank` / `_myPoints` — O(n) linear scan
* **Risk/Maliyet:** Her build'de rankings listesi döngü (`guild_war_hub_screen.dart` 57–70); büyük sezonlarda gereksiz.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
final myEntry = warState.rankings.cast<GuildWarRanking?>().firstWhere(
  (r) => r!.guildName == guildName, orElse: () => null);
```

* **Hatalı Kod Yapısı:** `logout()` — provider teardown eksik
* **Risk/Maliyet:** `guildWarProvider`, `inventoryProvider` clear yok; stale war state sonraki login'de flash.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — shared SessionTeardown.logout(ref)
ref.read(guildWarProvider.notifier).clear();
ref.read(inventoryProvider.notifier).clear();
```

* **Hatalı Kod Yapısı:** `_attackTerritory` — `context.push` sonra `_refresh` fire-and-forget
* **Risk/Maliyet:** Battle result dönüşünde `then((_) => _refresh())` mounted check yok (`guild_war_hub_screen.dart` 110).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
await context.push(...);
if (!mounted) return;
await _refresh();
```

* **Hatalı Kod Yapısı:** `initState` — sıralı await guild sonra war
* **Risk/Maliyet:** `loadGuild` bitene kadar `loadAll` bekler; skeleton süresi uzar.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
unawaited(Future.wait([
  ref.read(guildProvider.notifier).loadGuild(),
  ref.read(guildWarProvider.notifier).loadAll(),
]));
```

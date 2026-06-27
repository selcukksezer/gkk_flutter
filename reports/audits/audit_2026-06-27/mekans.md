---
# 📦 DOSYA/SAYFA ANALİZİ: MekansScreen (`lib/screens/mekans/mekans_screen.dart`)

**Rota:** `/mekans`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/mekans.png`  
**Tema referansları:** `lib/screens/mekans/widgets/mekan_theme.dart`, `lib/screens/mekans/widgets/mekan_design.dart`  
**İlgili widget'lar:** `lib/screens/mekans/widgets/mekan_scaffold.dart`, `lib/providers/mekan_provider.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameTopBar` title — ASCII transliterasyon
* **Hata Tanımı:** `MekanHubScaffold(title: 'Han Agi')` (`mekans_screen.dart` 72, `mekan_scaffold.dart` 32). Türkçe "Han Ağı" beklenir; ğ eksik.
* **Kullanıcıya Etkisi:** Prod kalitesi düşük; SEO/marka "Han Agi" olarak kalır.
* **Kesin Çözüm ve Öneri:** `'Han Ağı'`; tüm mekan copy UTF-8 audit.

* **Sorunlu Bileşen/Yer:** Hero panel — viewport domine
* **Hata Tanımı:** `_hero` + `_ctaRow` + leaderboard + filter ≈ 380pt (`mekans_screen.dart` 133–285). Screenshot'ta mekan listesi fold altında; ilk bakışta yalnızca marketing metni.
* **Kullanıcıya Etkisi:** Var olan mekanlara hızlı erişim gecikir; power user scroll yorgunluğu.
* **Kesin Çözüm ve Öneri:** Collapsible hero; leaderboard ayrı tab veya swipe.

* **Sorunlu Bileşen/Yer:** Türkçe diakritik eksikliği — kullanıcı metinleri
* **Hata Tanımı:** `'$openCount acik'`, filter `'Tumu'`, `'Dovus'`, `'Lux'`, `'Yeralti'`, empty `'Yuklenemedi'`, `'acik mekan bulunamadi'` (satır 94–106, 173, 239–245). Screenshot'ta "2 acik", "Tumu" chip görünür.
* **Kullanıcıya Etkisi:** Oyun Türkçe ama mekan modülü ASCII; güven ve immersion kırılır.
* **Kesin Çözüm ve Öneri:** `'açık'`, `'Tümü'`, `'Dövüş'`, `'Lüks'`, `'Yeraltı'`, `'Yüklenemedi'`.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** `MekanHubScaffold` `currentRoute: AppRoutes.mekans` — bottom item değil → Home aktif (screenshot).
* **Kullanıcıya Etkisi:** Han modülünde iken nav yanıltıcı.
* **Kesin Çözüm ve Öneri:** Mekans → Menü aktif veya özel bottom item.

* **Sorunlu Bileşen/Yer:** `NeonButton` "Mekan Ac" — glow + altın
* **Hata Tanımı:** Sağ CTA solid gold + outer glow (`mekans_screen.dart` 199–206); sol "Benim Mekanim" outline. FAB Sohbet sağ alt ile görsel rekabet.
* **Kullanıcıya Etkisi:** İki birincil CTA (Mekan Aç vs Sohbet); tıklama hedefi belirsiz.
* **Kesin Çözüm ve Öneri:** Tek primary CTA; chat FAB mekan temasında küçült.

* **Sorunlu Bileşen/Yer:** Filter bar — yatay scroll affordance
* **Hata Tanımı:** `ListView` horizontal 6 chip, sağ padding `14` (`mekans_screen.dart` 247–283). "Yeraltı" kısmen görünür; scroll ipucu yok.
* **Kullanıcıya Etkisi:** Son kategoriler keşfedilmez.
* **Kesin Çözüm ve Öneri:** Fade edge gradient; veya `TabBar` scrollable.

* **Sorunlu Bileşen/Yer:** Leaderboard — owner adı truncation
* **Hata Tanımı:** `_LeaderRow` subtitle `mekanTypeLabelKey - ownerName` `maxLines: 1` (satır 328–332). Uzun owner + tip ellipsis.
* **Kullanıcıya Etkisi:** Sıralamada kimin mekanı olduğu okunamaz.
* **Kesin Çözüm ve Öneri:** İki satır veya owner `@handle` kısaltma.

* **Sorunlu Bileşen/Yer:** Ayrı tasarım sistemi — app tema kopukluğu
* **Hata Tanımı:** `MekanPalette` (aqua/fuchsia/gold) global `AppColors` gold/coral'dan bağımsız; `GameTopBar` + neon kartlar aynı ekranda clash (screenshot header vs neon hero).
* **Kullanıcıya Etkisi:** Mekan "DLC skin" hissi; ana oyunla görsel süreklilik yok.
* **Kesin Çözüm ve Öneri:** `ThemeExtension<MekanTokens>` app theme'e bağla; accent'leri `AppColors` türevi yap.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Local state — provider bypass
* **Risk/Maliyet:** `_mekans`, `_leaderboard`, `_loading` ekranda (`mekans_screen.dart` 20–24); `mekanRepositoryProvider` doğrudan `ref.read` init'te.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
@riverpod
class MekansHub extends _$MekansHub {
  Future<MekansHubState> build() => ref.watch(mekanRepositoryProvider).fetchHub();
}
```

* **Hatalı Kod Yapısı:** Leaderboard RPC — silent catch
* **Risk/Maliyet:** `fetchFameLeaderboard` catch empty (satır 42–46); RPC yoksa UI fark etmez — screenshot'ta leaderboard var ama prod'da sessiz kaybolur.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — degraded banner veya debug flag
if (lb.isEmpty && kDebugMode) showBanner('Leaderboard RPC unavailable');
```

* **Hatalı Kod Yapısı:** Navigation — raw string path
* **Risk/Maliyet:** `context.go('/mekans/${m.id}')` (satır 123, 228); `AppRoutes` sabiti yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
context.go('${AppRoutes.mekans}/${m.id}');
```

* **Hatalı Kod Yapısı:** `_filter` — client-side only
* **Risk/Maliyet:** Tüm mekanlar fetch → filter local; liste büyüyünce performans.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
repo.fetchMekans(typeKey: _filter == 'all' ? null : _filter);
```

* **Hatalı Kod Yapısı:** `MekanHubScaffold` logout — inventory clear yok
* **Risk/Maliyet:** `mekan_scaffold.dart` 25–27 yalnızca auth+player.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// shared SessionTeardown
```

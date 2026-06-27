---
# 📦 DOSYA/SAYFA ANALİZİ: CharacterScreen (`lib/screens/character/character_screen.dart`)

**Rota:** `/character`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/character.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/components/character/character_combat_stats_panel.dart`, `lib/components/layout/game_screen_background.dart`, `lib/components/layout/game_chrome.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameTopBar` vs kimlik kartı — isim sunumu tutarsız
* **Hata Tanımı:** Top bar `Hi, qa_smoke_primary...` truncated greeting (`game_chrome.dart` displayName logic); kimlik kartında tam `qa_smoke_primary` + `@username` yok. Screenshot'ta üst "Hi, qa_smoke_primary..." alt kart "qa_smoke_primary" — aynı veri, farklı format.
* **Kullanıcıya Etkisi:** Profil sahipliği zayıf; sosyal/guild bağlamında kimlik karmaşası.
* **Kesin Çözüm ve Öneri:** Tek `PlayerIdentityHeader` shared widget; greeting veya raw username — birini seç.

* **Sorunlu Bileşen/Yer:** `_buildQuickResources` — 4 sütun mini kart okunabilirlik
* **Hata Tanımı:** `_miniResource` label `fontSize: 9`, value `13` — dört kart yan yana (`Expanded` × 4). Screenshot'ta "50.0K Altın", "100/100 Enerji" sıkışık; `Tolerans` label 9px `white54` — WCAG küçük metin eşiği altında. Emoji + kısa label (`💰 Altın`) yatay truncation `ellipsis`.
* **Kullanıcıya Etkisi:** Küçük cihazda kaynak tarama zor; yaşlı kullanıcı tolerans/enerji ayırt edemez.
* **Kesin Çözüm ve Öneri:** 2×2 grid breakpoint `<360pt`; label min 11px `AppTextStyles.caption`.

* **Sorunlu Bileşen/Yer:** `CharacterCombatStatsPanel` — dev ikon grid dikey alan tüketimi
* **Hata Tanımı:** `_iconSize = 70`, `crossAxisCount: 4`, `childAspectRatio: 0.78` — 8 stat ≈ 2 satır × ~90pt = 180pt+ başlık. Screenshot'ta istatistik bölümü viewport'un ~%40'ını kaplar; sınıf özellikleri fold altında kalır (partially visible "Sınıf Özellikleri" alt kenarda).
* **Kullanıcıya Etkisi:** Asıl farklılaştırıcı içerik (sınıf pasifleri) scroll gerektirir; oyuncu combat stat'larda takılır.
* **Kesin Çözüm ve Öneri:** İkon 48–56dp; collapsible stats; sınıf kartını yukarı taşı.

* **Sorunlu Bileşen/Yer:** Tipografi — `GoogleFonts.urbanist` vs `AppTextStyles` karışımı
* **Hata Tanımı:** `CharacterCombatStatsPanel` tamamen `GoogleFonts.urbanist`; kimlik kartı raw `TextStyle`. Tema `app_theme.dart` zaten Urbanist bağlar — çift font resolution.
* **Kullanıcıya Etkisi:** Mikro farklılıklar (letter-spacing, weight) fark edilir tutarsızlık yaratır.
* **Kesin Çözüm ve Öneri:** Panel'de `AppTextStyles.bodyBold` / `caption`; GoogleFonts yalnızca tema seviyesinde.

* **Sorunlu Bileşen/Yer:** İtibar tier — home ile farklı eşikler (kod tutarsızlığı)
* **Hata Tanımı:** Character `_getReputationTier`: 1000/5000/20000/50000/100000. Home `_getReputationTier`: 5000/20000/80000/170000/280000/356000 — farklı başlıklar (`👑 Efsane` vs `İmparator`). Character ekranı rep tier badge göstermiyor ama helper dead code.
* **Kullanıcıya Etkisi:** İleride rep gösterilirse home/character çelişir; oyuncu güven kaybı.
* **Kesin Çözüm ve Öneri:** `lib/core/utils/reputation_tier.dart` tek kaynak; home ve character import.

* **Sorunlu Bileşen/Yer:** Yetenekler bölümü — placeholder dead UI
* **Hata Tanımı:** `_buildExtraInfo` ExpansionTile içinde 6 skill chip + `'Yetenek sistemi yakında güncellenecek.'` (`Opacity 0.5`, 10px). Chip'ler tıklanamaz; veri backend'e bağlı değil.
* **Kullanıcıya Etkisi:** "Yakında" metni prod'da bitmemiş özellik sinyali; chip'ler interaktif değil ama öyle görünür.
* **Kesin Çözüm ve Öneri:** Feature flag ile gizle veya `ComingSoonBadge`; chip'leri disabled + tooltip.

* **Sorunlu Bileşen/Yer:** Bottom padding — nav bar / FAB overlap
* **Hata Tanımı:** `ListView` padding `AppSpacing.xxl` (32) alt — `gameBottomBarClearance` yok. Screenshot'ta bottom nav + Sohbet FAB; expansion tile açılınca içerik nav altında kalır.
* **Kullanıcıya Etkisi:** Son satırlar (adli sicil) kesilir; expansion scroll gerektirir.
* **Kesin Çözüm ve Öneri:** Home ile aynı bottom inset formülü.

* **Sorunlu Bileşen/Yer:** Simyacı detox — gizli IconButton affordance
* **Hata Tanımı:** `_buildClassDetails` alchemist için sağ üst `IconButton(Icons.clean_hands_rounded, size: 20)` — tooltip `'Günlük Detox'` var ama görsel olarak sınıf açıklamasından ayrışmıyor. Spinner `_claimingDetox` 16px — düşük kontrast coral arka planda.
* **Kullanıcıya Etkisi:** Simyacı oyuncu günlük freebie'yi keşfedemez; class fantasy kaybı.
* **Kesin Çözüm ve Öneri:** Tam genişlik `FilledButton.tonal('Günlük Detox Al')`; cooldown state API'den.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Hardcoded renk sabitleri — tema duplicate
* **Risk/Maliyet:** `_spaceNavy`, `_liquidGold`, `_coralFlare` vb. (satır 20-26) `AppColors` / `GameScreenBackground.spaceNavy` ile overlap; renk drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
const _liquidGold = Color(0xFFFFB800);

// OLMASI GEREKEN
import '../../theme/app_colors.dart';
// AppColors.gold veya theme extension
```

* **Hatalı Kod Yapısı:** `logout()` local function — inventory provider clear yok
* **Risk/Maliyet:** Satır 102-105 yalnızca `auth` + `player` clear; home/inventory `inventoryProvider.clear()` çağırır. Character'den logout nadir ama stale inventory state riski.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — shared session teardown
Future<void> logout() async {
  await ref.read(authProvider.notifier).logout();
  ref.read(playerProvider.notifier).clear();
  ref.read(inventoryProvider.notifier).clear();
}
```

* **Hatalı Kod Yapısı:** Avatar/frame picker — doğrudan Supabase update, provider bypass pattern
* **Risk/Maliyet:** `_showAvatarPicker` `users.update` sonra `loadProfile()` — hata durumunda raw exception snack (`Profil fotoğrafı güncellenemedi: $e`). RLS/validation mesajı kullanıcıya teknik.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
await ref.read(playerProvider.notifier).updateAvatar(path);
// repository encapsulates Supabase + user-friendly errors
```

* **Hatalı Kod Yapısı:** `_buildExtraInfo` — `Wrap` içinde `_infoRow` without width
* **Risk/Maliyet:** `_infoRow` `Row(spaceBetween)` — `Wrap` child'ları intrinsic width alır; "Şüphe Seviyesi" ve değer yan yana sıkışır, spaceBetween çalışmaz (screenshot geniş ekranda OK, dar ekranda broken).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
SizedBox(
  width: double.infinity,
  child: _infoRow(...),
)
// veya Column + ListTile
```

* **Hatalı Kod Yapısı:** Asset path Unicode — `saldırı.png`
* **Risk/Maliyet:** `character_combat_stats_panel.dart` satır 55 `'${_iconBase}saldırı.png'` — CI/Linux build'de encoding/normalization failure → fallback bolt icon (screenshot'ta gerçek ikonlar yüklü, macOS OK).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — ASCII asset adı
'${_iconBase}saldira_icon.png'
// pubspec + asset rename
```

* **Hatalı Kod Yapısı:** `_claimAlchemistDetox` — `if (mounted)` tek satır without braces
* **Risk/Maliyet:** Satır 81-82, 84-88 lint/deviation; `res` cast `as Map` unsafe — wrong type runtime crash.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
final res = await SupabaseService.client.rpc('claim_alchemist_detox');
if (res is! Map<String, dynamic>) {
  if (mounted) AppMessenger.showError(context, 'Beklenmeyen yanıt');
  return;
}
```

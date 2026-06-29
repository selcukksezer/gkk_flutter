# GKK Flutter — Audit Fix Checklist

**Tarih:** 2026-06-27  
**Kaynak audit:** `reports/audits/audit_2026-06-27/`  
**İlerleme:** 55 / 455  
**Son güncelleme:** 2026-06-29 — alt menü boşluğu bank/market/quests/reputation/settings
**Üretim:** `python3 scripts/generate_audit_todo.py`

---

## Öncelik Özeti

| P0 | P1 | P2 | Cross-App | Sayfa Bazlı | QA Görevleri | Toplam |
|----|----|----|-----------|-------------|--------------|--------|
| 16 | 41 | 386 | 13 | 430 | 12 | 455 |

> Cross-app maddeler tek fix ile birden fazla sayfayı kapatır. Tamamlandığında ilgili sayfa maddelerini de işaretleyin.

---


## A. Cross-App Düzeltmeler (tek fix, çok sayfa)

- [x] **[P0] GameBottomBar yanlış Home highlight**
  - **Sorun:** `currentRoute: AppRoutes.bank` geçiliyor; bottom bar 5 sabit rota dışında `/bank` → `_activeIndex` fallback 0 (Home). Screenshot: Banka ekranı + "Home" aktif. (+35 ek rapor varyasyonu)
  - **Çözüm:** lib/components/layout/game_chrome.dart — _activeIndex prefix map (/pvp, /guild, /trade vb.) veya bilinmeyen route için Menü (index 4) fallback
  - **Hedef dosya:** `lib/components/layout/game_chrome.dart`
  - **Etkilenen raporlar (33):** [bank.md](reports/audits/audit_2026-06-27/bank.md), [chat.md](reports/audits/audit_2026-06-27/chat.md), [crafting.md](reports/audits/audit_2026-06-27/crafting.md), [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md), [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md), [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md), [facilities.md](reports/audits/audit_2026-06-27/facilities.md), [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md), [guild.md](reports/audits/audit_2026-06-27/guild.md), [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md), [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md), [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md), [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md), [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md), [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md), [hospital.md](reports/audits/audit_2026-06-27/hospital.md), [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md), [loot.md](reports/audits/audit_2026-06-27/loot.md), [market.md](reports/audits/audit_2026-06-27/market.md), [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md), [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md), [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md), [mekans.md](reports/audits/audit_2026-06-27/mekans.md), [prison.md](reports/audits/audit_2026-06-27/prison.md), [pvp.md](reports/audits/audit_2026-06-27/pvp.md), [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md), [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md), [quests.md](reports/audits/audit_2026-06-27/quests.md), [reputation.md](reports/audits/audit_2026-06-27/reputation.md), [season.md](reports/audits/audit_2026-06-27/season.md), [settings.md](reports/audits/audit_2026-06-27/settings.md), [shop.md](reports/audits/audit_2026-06-27/shop.md), [trade.md](reports/audits/audit_2026-06-27/trade.md)

- [x] **[P0] Loot currentRoute AppRoutes.shop copy-paste bug**
  - **Sorun:** Loot currentRoute AppRoutes.shop copy-paste bug
  - **Çözüm:** currentRoute: AppRoutes.loot olarak düzelt
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`
  - **Etkilenen raporlar (1):** [loot.md](reports/audits/audit_2026-06-27/loot.md)

- [x] **[P0] Trade karşı teklif realtime senkronu yok**
  - **Sorun:** Trade karşı teklif realtime senkronu yok
  - **Çözüm:** Supabase Realtime veya polling; Onayla disabled + Beta banner
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`
  - **Etkilenen raporlar (1):** [trade.md](reports/audits/audit_2026-06-27/trade.md)

- [x] **[P1] Chat GameChrome dışında — header/nav kopuk**
  - **Sorun:** Chat GameChrome dışında — header/nav kopuk
  - **Çözüm:** GameTopBar + GameBottomBar entegrasyonu veya chat-specific chrome
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`
  - **Etkilenen raporlar (1):** [chat.md](reports/audits/audit_2026-06-27/chat.md)

- [x] **[P1] Facility route slug farm ≠ farming**
  - **Sorun:** Facility route slug farm ≠ farming
  - **Çözüm:** Router alias farm→farming veya smoke manifest düzelt
  - **Hedef dosya:** `lib/routing/app_router.dart`
  - **Etkilenen raporlar (1):** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)

- [x] **[P1] Guild war tournament/territory null → SizedBox.shrink()**
  - **Sorun:** Guild war tournament/territory null → SizedBox.shrink()
  - **Çözüm:** Empty/error widget + geri CTA
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`
  - **Etkilenen raporlar (2):** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md), [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)

- [x] **[P1] Logout sırasında provider clear tutarsız**
  - **Sorun:** Satır 102-105 yalnızca `auth` + `player` clear; home/inventory `inventoryProvider.clear()` çağırır. Character'den logout nadir ama stale inventory state riski. (+22 ek rapor varyasyonu)
  - **Çözüm:** Merkezi logout() helper: player, inventory, guild, facilities, pvp* provider invalidate/clear
  - **Hedef dosya:** `lib/providers/auth_provider.dart`
  - **Etkilenen raporlar (23):** [character.md](reports/audits/audit_2026-06-27/character.md), [crafting.md](reports/audits/audit_2026-06-27/crafting.md), [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md), [facilities.md](reports/audits/audit_2026-06-27/facilities.md), [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md), [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md), [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md), [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md), [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md), [home.md](reports/audits/audit_2026-06-27/home.md), [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md), [inventory.md](reports/audits/audit_2026-06-27/inventory.md), [loot.md](reports/audits/audit_2026-06-27/loot.md), [market.md](reports/audits/audit_2026-06-27/market.md), [mekans.md](reports/audits/audit_2026-06-27/mekans.md), [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md), [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md), [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md), [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md), [quests.md](reports/audits/audit_2026-06-27/quests.md), [season.md](reports/audits/audit_2026-06-27/season.md), [shop.md](reports/audits/audit_2026-06-27/shop.md), [trade.md](reports/audits/audit_2026-06-27/trade.md)

- [x] **[P2] DefensePowerBar current > max (2600/1000)**
  - **Sorun:** DefensePowerBar current > max (2600/1000)
  - **Çözüm:** clamp(current, 0, max) veya max değeri backend'den doğru çek
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`
  - **Etkilenen raporlar (1):** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)

- [x] **[P2] GameTopBar / header İngilizce route adları**
  - **Sorun:** Top bar `Hi, qa_smoke_primary...` truncated greeting (`game_chrome.dart` displayName logic); kimlik kartında tam `qa_smoke_primary` + `@username` yok. Screenshot'ta üst "Hi, qa_smoke_primary..." alt kart "qa_smoke_primary" — aynı veri, farklı format. (+10 ek rapor varyasyonu)
  - **Çözüm:** Flutter gen-l10n (`app_tr.arb` + `app_en.arb`); selamlama kaldırıldı; Semantics label; menü/başlıklar l10n; Ayarlar → dil seçici (`localeProvider`)
  - **Hedef dosya:** `lib/components/layout/game_chrome.dart`, `lib/l10n/`, `lib/providers/locale_provider.dart`
  - **Etkilenen raporlar (9):** [character.md](reports/audits/audit_2026-06-27/character.md), [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md), [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md), [home.md](reports/audits/audit_2026-06-27/home.md), [inventory.md](reports/audits/audit_2026-06-27/inventory.md), [market.md](reports/audits/audit_2026-06-27/market.md), [mekans.md](reports/audits/audit_2026-06-27/mekans.md), [pvp.md](reports/audits/audit_2026-06-27/pvp.md), [season.md](reports/audits/audit_2026-06-27/season.md)

- [x] **[P2] Ham exception/RPC metni UI'da gösteriliyor**
  - **Sorun:** `'Banka yuklenemedi: $e'` (satır 148), `'Tasima basarisiz: $e'` — Postgrest/RLS metni kullanıcıya. (+10 ek rapor varyasyonu)
  - **Çözüm:** User-friendly error string + retry CTA; debug'da only kDebugMode ile detay
  - **Etkilenen raporlar (11):** [bank.md](reports/audits/audit_2026-06-27/bank.md), [character.md](reports/audits/audit_2026-06-27/character.md), [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md), [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md), [loot.md](reports/audits/audit_2026-06-27/loot.md), [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md), [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md), [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md), [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md), [settings.md](reports/audits/audit_2026-06-27/settings.md), [trade.md](reports/audits/audit_2026-06-27/trade.md)

- [x] **[P2] _rarityColor hex map tekrarı**
  - **Sorun:** Satır 755-770 shop/trade ile kopya. (+3 ek rapor varyasyonu)
  - **Çözüm:** Merkezi item_rarity.dart veya AppColors.rarityFor() — shop/bank/trade/loot'taki duplicate map kaldır
  - **Hedef dosya:** `lib/theme/item_rarity.dart`
  - **Etkilenen raporlar (4):** [bank.md](reports/audits/audit_2026-06-27/bank.md), [crafting.md](reports/audits/audit_2026-06-27/crafting.md), [shop.md](reports/audits/audit_2026-06-27/shop.md), [trade.md](reports/audits/audit_2026-06-27/trade.md)

- [x] **[P2] gameBottomBarClearance padding eksik**
  - **Sorun:** `Column` + `SafeArea` — `gameBottomBarClearance(context)` yok. Bank pagination (`1 / 10`) screenshot'ta nav bar üstünde; scroll body yok, alt banka satırı FAB yakını. (+10 ek rapor varyasyonu)
  - **Çözüm:** Scroll body sonuna AppSpacing.gameBottomBarClearance veya GameChrome padding token ekle
  - **Hedef dosya:** `lib/components/layout/game_chrome.dart`
  - **Etkilenen raporlar (10):** [bank.md](reports/audits/audit_2026-06-27/bank.md), [character.md](reports/audits/audit_2026-06-27/character.md), [crafting.md](reports/audits/audit_2026-06-27/crafting.md), [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md), [facilities.md](reports/audits/audit_2026-06-27/facilities.md), [inventory.md](reports/audits/audit_2026-06-27/inventory.md), [market.md](reports/audits/audit_2026-06-27/market.md), [quests.md](reports/audits/audit_2026-06-27/quests.md), [reputation.md](reports/audits/audit_2026-06-27/reputation.md), [settings.md](reports/audits/audit_2026-06-27/settings.md)

- [ ] **[P2] ref.listen build() içinde — navigasyon yan etkisi**
  - **Sorun:** Satır 1256-1258 build içinde `_inventoryPage = totalPages` — setState olmadan side effect. (+10 ek rapor varyasyonu)
  - **Çözüm:** ref.listen → initState/post-frame callback veya ref.listenManual; build saf kalır
  - **Etkilenen raporlar (9):** [bank.md](reports/audits/audit_2026-06-27/bank.md), [home.md](reports/audits/audit_2026-06-27/home.md), [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md), [hospital.md](reports/audits/audit_2026-06-27/hospital.md), [login.md](reports/audits/audit_2026-06-27/login.md), [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md), [register.md](reports/audits/audit_2026-06-27/register.md), [settings.md](reports/audits/audit_2026-06-27/settings.md), [splash.md](reports/audits/audit_2026-06-27/splash.md)

---

## B. Sayfa Bazlı Düzeltmeler

### bank — [bank.md](reports/audits/audit_2026-06-27/bank.md)
**Kaynak kod:** `lib/screens/bank/bank_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** `_stackableCache` — stale per session
  - **Sorun:** Item `max_stack` DB'de değişirse cache invalidate yok.
  - **Çözüm:** final bool isStackable = item.isStackable;
  - **Kaynak rapor:** [bank.md](reports/audits/audit_2026-06-27/bank.md)
  - **Hedef dosya:** `lib/screens/bank/bank_screen.dart`

- [ ] **[P1 · UI/UX]** Slot etiket tipografi — WCAG altı
  - **Sorun:** Item adı overlay `fontSize: 8` (satır 859, 1051); slot index `7`; qty badge `9`.
  - **Çözüm:** Tooltip/long-press detail sheet; grid 4 sütun veya daha büyük hücre.
  - **Kaynak rapor:** [bank.md](reports/audits/audit_2026-06-27/bank.md)
  - **Hedef dosya:** `lib/screens/bank/bank_screen.dart`

- [ ] **[P1 · UI/UX]** Türkçe karakter / yazım — prod metin kalitesi
  - **Sorun:** `'Genislet 50 gem'`, `'Kullanilan'`, `'Iptal'`, `'Tasima basarisiz'`, `'Yatirilacak gecerli item'` — ASCII Türkçe. Dialog `'Iptal'` (satır 345).
  - **Çözüm:** `AppStrings.bank.*` merkezi tablo; `Genişlet`, `Kullanılan`, `İptal`.
  - **Kaynak rapor:** [bank.md](reports/audits/audit_2026-06-27/bank.md)
  - **Hedef dosya:** `lib/screens/bank/bank_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_buildInventorySlots` — pozisyonsuz item fill cursor
  - **Sorun:** Satır 189-198: `slotPosition < 0` item'ları sırayla boş slotlara doldurur — sayfa değişince görsel slot kayması.
  - **Çözüm:** items.sort((a, b) => a.slotPosition.compareTo(b.slotPosition));
  - **Kaynak rapor:** [bank.md](reports/audits/audit_2026-06-27/bank.md)
  - **Hedef dosya:** `lib/screens/bank/bank_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_withdrawSingle` — miktar diyaloğu sonrası tam çekim RPC
  - **Sorun:** `_askQuantity` ile `qty` seçilir (satır 589-599) ama RPC `withdraw_from_bank` yalnızca `p_bank_item_ids` — kısmi miktar parametresi yok; UI yanıltıcı.
  - **Çözüm:** await client.rpc('withdraw_from_bank', params: {
  'p_bank_item_ids': [id],
  'p_quantities': [qty],
});
  - **Kaynak rapor:** [bank.md](reports/audits/audit_2026-06-27/bank.md)
  - **Hedef dosya:** `lib/screens/bank/bank_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `bank_screen.dart` monolit (~1642 satır)
  - **Sorun:** Slot builder, drag logic, RPC, dialog — tek StatefulWidget; hot reload yavaş.
  - **Çözüm:** lib/screens/bank/widgets/bank_slot_grid.dart
lib/screens/bank/bank_controller.dart  // Riverpod Notifier
  - **Kaynak rapor:** [bank.md](reports/audits/audit_2026-06-27/bank.md)
  - **Hedef dosya:** `lib/screens/bank/bank_screen.dart`

- [ ] **[P2 · UI/UX]** Dikey split — Envanter + Banka eşit `Expanded`
  - **Sorun:** `_buildInventoryArea` + `_buildBankArea` aynı `Column` içinde iki `Expanded` (satır 1624-1633). Her biri 5×2 / 5×1 grid + header — screenshot'ta ~%45 viewport envanter, ~%45 banka; tek elle kullanımda slotlar ~40×45dp.
  - **Çözüm:** Tab veya `DraggableScrollableSheet` tek panel odak; KO tarzı "Envanter | Banka" toggle.
  - **Kaynak rapor:** [bank.md](reports/audits/audit_2026-06-27/bank.md)
  - **Hedef dosya:** `lib/screens/bank/bank_screen.dart`

- [ ] **[P2 · UI/UX]** Drag affordance — keşfedilebilirlik sıfır
  - **Sorun:** `LongPressDraggable` delay 120ms (satır 963) — UI'da "sürükle" ipucu yok; yalnızca boş slot `+` ikonu. Batch butonlar disabled (0 seçili) gri.
  - **Çözüm:** İlk ziyaret coach mark; header altına `'Uzun bas: sürükle · Dokun: seç'`.
  - **Kaynak rapor:** [bank.md](reports/audits/audit_2026-06-27/bank.md)
  - **Hedef dosya:** `lib/screens/bank/bank_screen.dart`

- [ ] **[P2 · UI/UX]** `_buildStatsCard` — doluluk %0 ile 100 boş slot
  - **Sorun:** Screenshot: Toplam 100, Kullanılan 0, Boş 100, Doluluk 0% — doğru ama "Genişlet 50 gem" CTA yeni oyuncuda agresif; maliyet `_expandCost` client-side hardcoded.
  - **Çözüm:** %80+ dolulukta göster; maliyet RPC'den.
  - **Kaynak rapor:** [bank.md](reports/audits/audit_2026-06-27/bank.md)
  - **Hedef dosya:** `lib/screens/bank/bank_screen.dart`

### character — [character.md](reports/audits/audit_2026-06-27/character.md)
**Kaynak kod:** `lib/screens/character/character_screen.dart`

- [ ] **[P1 · UI/UX]** `_buildQuickResources` — 4 sütun mini kart okunabilirlik
  - **Sorun:** `_miniResource` label `fontSize: 9`, value `13` — dört kart yan yana (`Expanded` × 4). Screenshot'ta "50.0K Altın", "100/100 Enerji" sıkışık; `Tolerans` label 9px `white54` — WCAG küçük metin eşiği altında. Emoji + kısa label (`💰 Altın`) yatay truncation `ellipsis`.
  - **Çözüm:** 2×2 grid breakpoint `<360pt`; label min 11px `AppTextStyles.caption`.
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Asset path Unicode — `saldırı.png`
  - **Sorun:** `character_combat_stats_panel.dart` satır 55 `'${_iconBase}saldırı.png'` — CI/Linux build'de encoding/normalization failure → fallback bolt icon (screenshot'ta gerçek ikonlar yüklü, macOS OK).
  - **Çözüm:** '${_iconBase}saldira_icon.png'
// pubspec + asset rename
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Hardcoded renk sabitleri — tema duplicate
  - **Sorun:** `_spaceNavy`, `_liquidGold`, `_coralFlare` vb. (satır 20-26) `AppColors` / `GameScreenBackground.spaceNavy` ile overlap; renk drift.
  - **Çözüm:** import '../../theme/app_colors.dart';
// AppColors.gold veya theme extension
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_buildExtraInfo` — `Wrap` içinde `_infoRow` without width
  - **Sorun:** `_infoRow` `Row(spaceBetween)` — `Wrap` child'ları intrinsic width alır; "Şüphe Seviyesi" ve değer yan yana sıkışır, spaceBetween çalışmaz (screenshot geniş ekranda OK, dar ekranda broken).
  - **Çözüm:** SizedBox(
  width: double.infinity,
  child: _infoRow(...),
)
// veya Column + ListTile
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_claimAlchemistDetox` — `if (mounted)` tek satır without braces
  - **Sorun:** Satır 81-82, 84-88 lint/deviation; `res` cast `as Map` unsafe — wrong type runtime crash.
  - **Çözüm:** final res = await SupabaseService.client.rpc('claim_alchemist_detox');
if (res is! Map<String, dynamic>) {
  if (mounted) AppMessenger.showError(context, 'Beklenmeyen yanıt');
  return;
}
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

- [ ] **[P2 · UI/UX]** Simyacı detox — gizli IconButton affordance
  - **Sorun:** `_buildClassDetails` alchemist için sağ üst `IconButton(Icons.clean_hands_rounded, size: 20)` — tooltip `'Günlük Detox'` var ama görsel olarak sınıf açıklamasından ayrışmıyor. Spinner `_claimingDetox` 16px — düşük kontrast coral arka planda.
  - **Çözüm:** Tam genişlik `FilledButton.tonal('Günlük Detox Al')`; cooldown state API'den.
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

- [ ] **[P2 · UI/UX]** Tipografi — `GoogleFonts.urbanist` vs `AppTextStyles` karışımı
  - **Sorun:** `CharacterCombatStatsPanel` tamamen `GoogleFonts.urbanist`; kimlik kartı raw `TextStyle`. Tema `app_theme.dart` zaten Urbanist bağlar — çift font resolution.
  - **Çözüm:** Panel'de `AppTextStyles.bodyBold` / `caption`; GoogleFonts yalnızca tema seviyesinde.
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

- [ ] **[P2 · UI/UX]** Yetenekler bölümü — placeholder dead UI
  - **Sorun:** `_buildExtraInfo` ExpansionTile içinde 6 skill chip + `'Yetenek sistemi yakında güncellenecek.'` (`Opacity 0.5`, 10px). Chip'ler tıklanamaz; veri backend'e bağlı değil.
  - **Çözüm:** Feature flag ile gizle veya `ComingSoonBadge`; chip'leri disabled + tooltip.
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

- [ ] **[P2 · UI/UX]** `CharacterCombatStatsPanel` — dev ikon grid dikey alan tüketimi
  - **Sorun:** `_iconSize = 70`, `crossAxisCount: 4`, `childAspectRatio: 0.78` — 8 stat ≈ 2 satır × ~90pt = 180pt+ başlık. Screenshot'ta istatistik bölümü viewport'un ~%40'ını kaplar; sınıf özellikleri fold altında kalır (partially visible "Sınıf Özellikleri" alt kenarda).
  - **Çözüm:** İkon 48–56dp; collapsible stats; sınıf kartını yukarı taşı.
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

- [ ] **[P2 · UI/UX]** İtibar tier — home ile farklı eşikler (kod tutarsızlığı)
  - **Sorun:** Character `_getReputationTier`: 1000/5000/20000/50000/100000. Home `_getReputationTier`: 5000/20000/80000/170000/280000/356000 — farklı başlıklar (`👑 Efsane` vs `İmparator`). Character ekranı rep tier badge göstermiyor ama helper dead code.
  - **Çözüm:** `lib/core/utils/reputation_tier.dart` tek kaynak; home ve character import.
  - **Kaynak rapor:** [character.md](reports/audits/audit_2026-06-27/character.md)
  - **Hedef dosya:** `lib/screens/character/character_screen.dart`

### chat — [chat.md](reports/audits/audit_2026-06-27/chat.md)
**Kaynak kod:** `lib/screens/chat/chat_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** God file — ~1986 satır tek dosya
  - **Sorun:** Design system, models, moderation, realtime, UI hep `chat_screen.dart`; `.bak` / `_new` duplicate dosyalar repo'da.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [x] **[P1 · UI/UX]** Bottom inset — composer + sistem gesture
  - **Sorun:** `_buildComposer` `SafeArea` kısmi; full-screen chat'te home indicator overlap riski; FAB modal (`asPanel`) vs route farklı padding.
  - **Çözüm:** `MediaQuery.padding.bottom` + `viewInsets` keyboard aware scroll.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [x] **[P1 · UI/UX]** Gradient typo — panel arka plan
  - **Sorun:** `gradientBgPanel` colors `0xfff0141b26`, `0xfff0090d15` (`chat_screen.dart` 61–64) — fazla `f` prefix; alpha/channel şüpheli parse.
  - **Çözüm:** `Color(0xFF141B26)`, `Color(0xFF090D15)`.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [x] **[P1 · UI/UX]** Kanal chip + moderasyon — 5. chip kalabalık
  - **Sorun:** `_buildChannelBar` 4 kanal + `Susturulanlar` aynı satır (`chat_screen.dart` 1281–1344). Screenshot'ta 5 chip; "Susturulanlar" kanal değil — mental model karışır.
  - **Çözüm:** Susturulanlar AppBar action veya composer menü.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [x] **[P1 · UI/UX]** Kullanıcı etiketi — solid mavi tag
  - **Sorun:** Mesaj başlığında username `Container` solid accent background (`chat_screen.dart` 1892–1895). Screenshot'ta mavi blok isimden büyük; mesaj gövdesi ikincil.
  - **Çözüm:** İnce text-only username; renk kanal accent.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [x] **[P1 · UI/UX]** `maxWidth: 380` — dar bubble
  - **Sorun:** `ConstrainedBox(maxWidth: 380)` telefon genişliğinin ~%50'si (`chat_screen.dart` 1869–1870). Screenshot sağda boş alan; kısa mesajlar bile dar sütun.
  - **Çözüm:** `maxWidth: min(520, width * 0.78)`.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** In-memory message store — restart loss
  - **Sorun:** `_messages` map state (satır 395–400); realtime append local; pagination yok.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Realtime channel — lifecycle
  - **Sorun:** `_subscribeRealtime` init'te; kanal değişiminde re-subscribe belirsiz; dispose unsubscribe var ama reconnect yok.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_mutedPlayers` ≡ `_blockedPlayers`
  - **Sorun:** `_syncBlockedUsers` her ikisini aynı key set (satır 615–620); mute vs block ayrımı yok.
  - **Çözüm:** ```
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_showSnack` vs `AppMessenger`
  - **Sorun:** Karışık feedback kanalları; bazı path `AppMessenger`, çoğu local snack.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

- [ ] **[P2 · UI/UX]** Mesaj hizalama — sender ID eşleşmesi
  - **Sorun:** `_isOwnSender` `senderId == gameUserId || authUserId` (satır 431–433); history RPC `sender_user_id` auth vs game id mismatch ise tüm balonlar sola hizalanır. Screenshot'ta tüm mesajlar solda, dar bubble (~%35 genişlik).
  - **Çözüm:** RPC normalize game `users.id`; fallback username match; QA assert own-message right-align.
  - **Kaynak rapor:** [chat.md](reports/audits/audit_2026-06-27/chat.md)
  - **Hedef dosya:** `lib/screens/chat/chat_screen.dart`

### crafting — [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
**Kaynak kod:** `lib/screens/crafting/crafting_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Tab sync — `TabController` vs provider
  - **Sorun:** `_onTabChanged` provider'a yazar; init'te `_tabController.index` ile `craftState.selectedTab` senkron garanti değil — ilk frame yanlış filtre.
  - **Çözüm:** _tabController.index = _kTabs.indexWhere((t) => t.$1 == craftState.selectedTab).clamp(0, _kTabs.length - 1);
  - **Kaynak rapor:** [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
  - **Hedef dosya:** `lib/screens/crafting/crafting_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_PreviewPanel` — `Dialog` + `Consumer` iç içe
  - **Sorun:** 400+ satır widget aynı dosyada; preview dialog test edilemez.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
  - **Hedef dosya:** `lib/screens/crafting/crafting_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_autoFinalizeCompletedItems` — fire-and-forget RPC
  - **Sorun:** `_pendingFinalizations` set; fail durumunda sessiz kalır; duplicate finalize retry yok.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
  - **Hedef dosya:** `lib/screens/crafting/crafting_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_queueTimer` — her saniye full `setState`
  - **Sorun:** Satır 133-137 tüm ekranı rebuild; büyük recipe grid + dialog açıkken jank.
  - **Çözüm:** // veya ValueNotifier<int> tick for queue tiles only
  - **Kaynak rapor:** [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
  - **Hedef dosya:** `lib/screens/crafting/crafting_screen.dart`

- [ ] **[P2 · UI/UX]** Başarı oranı — çift format riski
  - **Sorun:** `_RecipeCard`: `(recipe.successRate * 100)` (satır 1016); `_PreviewPanel._parseRate`: `value > 1 ? value/100 : value` (satır 513-516). DB `success_rate=80` → kart **8000%**, preview **80%**.
  - **Çözüm:** `CraftRecipe.normalizedSuccessRate` tek helper; model parse'da normalize.
  - **Kaynak rapor:** [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
  - **Hedef dosya:** `lib/screens/crafting/crafting_screen.dart`

- [ ] **[P2 · UI/UX]** Malzeme yok uyarısı — 9px turuncu
  - **Sorun:** `'⚠ Malzeme yok'` fontSize 9 (satır 1026-1028); screenshot'ta her kartta tekrar — grid gürültülü, hepsi aynı durum (QA envanter boş).
  - **Çözüm:** Filtre "Craft edilebilir"; yoksa soluk kart + tooltip.
  - **Kaynak rapor:** [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
  - **Hedef dosya:** `lib/screens/crafting/crafting_screen.dart`

- [ ] **[P2 · UI/UX]** Süre formatı — `_formatDuration` kafa karıştırıcı
  - **Sorun:** Satır 51: `'${h}s ${m}d ${s}sn'` — `s` saat, `d` dakika (Türkçe'de `s` saniye sanılır). Preview chip'te kullanılıyor.
  - **Çözüm:** `'${h}sa ${m}dk ${s}sn'` veya `Duration` + `intl`.
  - **Kaynak rapor:** [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
  - **Hedef dosya:** `lib/screens/crafting/crafting_screen.dart`

- [ ] **[P2 · UI/UX]** Tarif kartları — İngilizce isim / Türkçe UI
  - **Sorun:** Screenshot grid: "Bone Amulet", "Leather Choker", "Copper Pendant" vb.; başlık `'🔨 Üretim Atölyesi'`, uyarı `'⚠ Malzeme yok'`. Backend `recipe.name` localize edilmemiş.
  - **Çözüm:** `items.name_tr` veya `CraftRecipe.localizedName`; fallback EN.
  - **Kaynak rapor:** [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
  - **Hedef dosya:** `lib/screens/crafting/crafting_screen.dart`

- [ ] **[P2 · UI/UX]** `_RecipeCard` — çıktı ikonu yok
  - **Sorun:** Kart yalnızca 8px rarity dot + metin (satır 985-1030); `ItemIconView` yok. Screenshot'ta tüm kartlar metin ağırlıklı, görsel ayırt zor.
  - **Çözüm:** 48dp output icon merkez; malzeme yok overlay köşede.
  - **Kaynak rapor:** [crafting.md](reports/audits/audit_2026-06-27/crafting.md)
  - **Hedef dosya:** `lib/screens/crafting/crafting_screen.dart`

### dungeon — [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
**Kaynak kod:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P0 · Kod/Refaktör]** Monolith dosya (~1854 satır, 15+ private widget)
  - **Sorun:** `_DungeonCard`, `_LootDialog`, `_ConfirmEntryDialog`, victory/defeat dialogları tek dosyada; test ve hot-reload yavaş.
  - **Çözüm:** // widgets/dungeon_card.dart, dialogs/dungeon_loot_dialog.dart
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P0 · UI/UX]** Zindan kartı CTA — `Loot` İngilizce
  - **Sorun:** `_LootButton` metni `'Loot'` (satır 1141). Ana CTA `Zindana Gir` Türkçe; yan düğme İngilizce.
  - **Çözüm:** `'Ganimet'` veya `'Ödül Tablosu'`.
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** Tema token bypass — `Color(0xFF080B12)`, `withOpacity` (29 kullanım)
  - **Sorun:** Dark mode / tema değişiminde kırılır; Flutter 3.27 `withOpacity` deprecation.
  - **Çözüm:** color: AppColors.textPrimary.withValues(alpha: 0.08)
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Onay dialog — typo `ptal`
  - **Sorun:** UX bug; muhtemelen kopyala-yapıştır hatası (satır 1399).
  - **Çözüm:** child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `initState` içinde doğrudan `ref.read` async
  - **Sorun:** Post-frame callback pattern pvp/guild ile tutarsız; build sırasında race (satır 103–107).
  - **Çözüm:** @override
void initState() {
  super.initState();
  deferProviderUpdate(() async {
    await ref.read(dungeonProvider.notifier).loadDungeons();
  });
}
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Çift zone state — `_selectedZone` + `TabController`
  - **Sorun:** İki kaynak gerçek; listener senkron hatası riski (satır 87–101, 308).
  - **Çözüm:** int get _selectedZone => _tabController.index == 0 ? 0 : _kZones[_tabController.index - 1].number;
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Ölü kod — kullanılmayan dialog/overlay sınıfları
  - **Sorun:** `_EntryOverlay`, `_ResultDialog`, `_DefeatResultDialog`, `_kVictoryBg*` sabitleri (24–47) hiç referanslanmıyor; binary şişkinliği.
  - **Çözüm:** // grep ile 0 referans → sil
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P2 · UI/UX]** ASCII Türkçe hata/snackbar metinleri
  - **Sorun:** `yuklenemedi` (176, 1265), `giris yapilamaz`, `Baglanti`, `ptal` (1399 onay dialogu — **İptal** yerine bozuk string), `YETERSZ`/`YETERL` güç etiketleri.
  - **Çözüm:** l10n ARB; `ptal` acil düzeltme → `'İptal'`.
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P2 · UI/UX]** Bölge sekmeleri — Latince bölge adları
  - **Sorun:** Tab etiketleri `Silva Obscura`, `Caverna Profunda`, `Desertum Ignis` vb. (satır 67–73). Oyuncu dili Türkçe; bölge numarası `B1`–`B5` anlaşılır ama alt isimler RPG lore değil, çevrilmemiş placeholder.
  - **Çözüm:** `AppStrings.dungeon.zones` veya Supabase `zone_display_name`; en azından `Silva` → `Orman`.
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P2 · UI/UX]** Hapis durumu görünürlüğü
  - **Sorun:** Hastane için mini strip var; hapiste iken yalnızca buton `Hapis Kilidi` metni — üst şerit yok.
  - **Çözüm:** `_PrisonMiniStrip` veya birleşik `_RestrictionBanner`.
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P2 · UI/UX]** Zindan kartları — CTA renk tutarsızlığı
  - **Sorun:** Screenshot'ta ilk kart mavi `Zindana Gir`, ikinci turuncu; güç yeterliliği `GÜÇ YETERLİ` bar'ı bazı kartlarda var bazılarında yok.
  - **Çözüm:** Tek `DungeonCtaStyle` enum: ready=primary, locked=muted, insufficient=warning.
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

- [ ] **[P2 · UI/UX]** `_HospitalMiniStrip` — saniyede bir rebuild
  - **Sorun:** `Stream.periodic(Duration(seconds: 1))` ile hastane geri sayımı (satır ~526). Tüm strip subtree her saniye repaint.
  - **Çözüm:** Yalnızca `Text` widget'ını `Ticker` veya `CountdownText` ile izole et.
  - **Kaynak rapor:** [dungeon.md](reports/audits/audit_2026-06-27/dungeon.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_screen.dart`

### dungeon_battle — [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md)
**Kaynak kod:** `lib/screens/dungeon/dungeon_battle_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Query params — `didChangeDependencies` state
  - **Sorun:** `_paramsLoaded` flag (satır 50-65); hot reload / deep link değişiminde güncellenmez.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_battle_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** RPC sonrası flavor log — geç append
  - **Sorun:** `_battleLog.add` RPC sonrası (satır 156-168); kullanıcı savaş bitmeden log görür.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_battle_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `Timer` lifecycle
  - **Sorun:** `_countdownTimer` / `_logTimer` dispose'da cancel OK; `_startBattle` exception'da `_logTimer` cancel var ama `_phase` stuck olabilir.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_battle_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_canRetry` — energy check local
  - **Sorun:** Sunucu enerji düşürmeden retry mümkün görünür; race condition.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_battle_screen.dart`

- [ ] **[P2 · UI/UX]** Geri butonu — düşük kontrast
  - **Sorun:** `← Geri Dön` TextButton `white54` (satır 303-306); primary CTA'nın gölgesinde.
  - **Çözüm:** Outlined secondary veya AppBar back.
  - **Kaynak rapor:** [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_battle_screen.dart`

- [ ] **[P2 · UI/UX]** Idle kart — generic "Zindan" başlığı
  - **Sorun:** Screenshot query params olmadan açılmış: `_dungeonName` default `'Zindan'` (satır 30, 57); enerji maliyeti, bölge, ödül önizlemesi yok.
  - **Çözüm:** `dungeon_id` boşsa `context.pop()` veya zindan listesine yönlendir; idle'da enerji/zone badge.
  - **Kaynak rapor:** [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_battle_screen.dart`

- [ ] **[P2 · UI/UX]** Savaş fazı — statik emoji
  - **Sorun:** `_buildFightingPhase` sabit ⚔️ + flavor text (satır 340-365); gerçek hasar/HP yok.
  - **Çözüm:** HP bar simülasyonu veya en azından zone sprite.
  - **Kaynak rapor:** [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_battle_screen.dart`

- [ ] **[P2 · UI/UX]** Viewport — %65 boş alan
  - **Sorun:** Screenshot tek küçük kart + geniş boş gradient; savaş animasyonu/ düşman görseli yok.
  - **Çözüm:** Zone-themed arka plan, düşman silüeti, enerji maliyeti chip.
  - **Kaynak rapor:** [dungeon_battle.md](reports/audits/audit_2026-06-27/dungeon_battle.md)
  - **Hedef dosya:** `lib/screens/dungeon/dungeon_battle_screen.dart`

### enhancement — [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
**Kaynak kod:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Rune seçimi — drag vs dropdown karışık
  - **Sorun:** `_selectedRune` string enum; `_kRuneTypes` listede UI picker yok — yalnızca drag `rune_*` item.
  - **Çözüm:** ```
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_EnhancementDesignSystem` — tema duplicate
  - **Sorun:** Satır 19-50 inline colors/spacing; `AppColors`/`AppSpacing` overlap.
  - **Çözüm:** Theme.of(context).extension<EnhancementTheme>()!
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_ItemPickerSheet` — dead code?
  - **Sorun:** Satır 1627+ tanımlı ama grep'te kullanılmıyor; drag-only UX.
  - **Çözüm:** ```
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_buildInventoryGrid` — slotPosition only, 20 slot cap
  - **Sorun:** Satır 1391-1397: pozisyonsuz item grid'de görünmez; max 20 — büyük envanter kesilir.
  - **Çözüm:** final items = inventory.items.where((i) => _isEnhanceable(i) || _isScrollItem(i) || _isRuneItem(i));
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_enhance` — unsafe cast
  - **Sorun:** `result as Map<String, dynamic>` (satır 246) — wrong type crash.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `enhancement_screen_new.dart` — paralel implementasyon
  - **Sorun:** Repo'da iki enhancement screen; router hangisini kullanıyor belirsizlik riski.
  - **Çözüm:** ```
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · UI/UX]** 9 parşömen slotu — UI teatrı
  - **Sorun:** `_maxScrollSlots = 9` (satır 188); `_findCompatibleScroll` yalnızca ilk uyumlu scroll (satır 293-301). 9 slot KO nostalji ama işlevsel değil.
  - **Çözüm:** 1 slot + "bonus scroll" feature flag; veya tooltip.
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · UI/UX]** Client-side maliyet/şans tablosu — sunucu drift
  - **Sorun:** `_kUpgradeChances`, `_kUpgradeCosts` (satır 55-81) hardcoded; UI tablo + info panel bunları gösterir; gerçek `enhance_item` RPC farklı olabilir.
  - **Çözüm:** `get_enhancement_config` RPC; tek kaynak.
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · UI/UX]** Maliyet vs bakiye — doğru renk, yanlış erişilebilirlik
  - **Sorun:** Screenshot: Maliyet **100.0K**, Altın **50.0K** kırmızı — `_formatGold` + `hasEnoughGold` doğru. Güçlendir butonu disabled OK. Ancak `'Gerekli Parşömen'` boş (eşya seçilmemiş) — empty state net değil.
  - **Çözüm:** Empty state CTA: `'Envanterden eşya sürükleyin'`.
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · UI/UX]** Post-enhance auto-reset — 3 sn
  - **Sorun:** Satır 277-284: dialog sonrası 3 sn bekleyip seçimi sıfırlar — hızlı ardışık + basma engellenir.
  - **Çözüm:** Reset yalnız destroyed'da; success'te item seçili kalsın.
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · UI/UX]** Türkçe ASCII — panel başlıkları
  - **Sorun:** `'Envanter Izgarası'` (satır 1362), `'Oturum bulunamadi!'` (satır 213) — İ/ı/ş eksik.
  - **Çözüm:** Merkezi strings.
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

- [ ] **[P2 · UI/UX]** Üç yuva paneli — yatay sıkışma / overflow
  - **Sorun:** `_buildThreeSlotPanel` tek `Row`: Eşya + Rune + 3×3 Parşömen (flex 2) + Önizleme (satır 617-694). Dar telefonda (390pt) screenshot'ta parşömen grid kayık; label `'Parşömen (9)'` 10px.
  - **Çözüm:** Dikey stack mobil breakpoint; tek parşömen slotu (server zaten 1 scroll).
  - **Kaynak rapor:** [enhancement.md](reports/audits/audit_2026-06-27/enhancement.md)
  - **Hedef dosya:** `lib/screens/enhancement/enhancement_screen.dart`

### facilities — [facilities.md](reports/audits/audit_2026-06-27/facilities.md)
**Kaynak kod:** `lib/screens/facilities/facilities_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** Facility metadata duplicate — client-side const lists
  - **Sorun:** `_basicFacilities` / `_organicFacilities` / `_mysticalFacilities` (satır 518–540) backend `facility_types` ile drift riski.
  - **Çözüm:** final defs = ref.watch(facilityDefinitionsProvider); // single source from API/seed
  - **Kaynak rapor:** [facilities.md](reports/audits/audit_2026-06-27/facilities.md)
  - **Hedef dosya:** `lib/screens/facilities/facilities_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** `_onFacilityTap` — `canUnlock` false iken sessiz return
  - **Sorun:** Yetersiz altın/seviye durumunda yalnızca snack (satır 408–415); locked kart tıklanınca feedback gecikmeli.
  - **Çözüm:** ```
  - **Kaynak rapor:** [facilities.md](reports/audits/audit_2026-06-27/facilities.md)
  - **Hedef dosya:** `lib/screens/facilities/facilities_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_handleBribe` — rastgele ilk tesis
  - **Sorun:** `facilitiesState.facilities.first` (satır 431–434); oyuncu hangi tesise rüşvet verdiğini bilmiyor.
  - **Çözüm:** final PlayerFacility target = facilitiesState.facilities
    .reduce((a, b) => a.suspicionLevel >= b.suspicionLevel ? a : b);
  - **Kaynak rapor:** [facilities.md](reports/audits/audit_2026-06-27/facilities.md)
  - **Hedef dosya:** `lib/screens/facilities/facilities_screen.dart`

- [ ] **[P2 · UI/UX]** Aktif tesis `0/15` — boş state motivasyonu
  - **Sorun:** Screenshot smoke user 0 aktif tesis; tüm kartlar "Kilitli" ama seviye 6 ile Maden (Lv.1) açılabilir — `canUnlock` görsel fark yok (sadece border rengi `white24` vs `0x8040E0FF`).
  - **Çözüm:** `canUnlock` için yeşil "Açılabilir" badge + pulse; sort unlocked-first.
  - **Kaynak rapor:** [facilities.md](reports/audits/audit_2026-06-27/facilities.md)
  - **Hedef dosya:** `lib/screens/facilities/facilities_screen.dart`

- [ ] **[P2 · UI/UX]** Rüşvet butonu — disabled state belirsiz
  - **Sorun:** `globalSuspicion <= 0` iken `FilledButton` `onPressed: null` (satır 198–200) ama sarı dolu görünüm korunabilir; alt metin "Şüphe 0 iken..." küçük 11px. Screenshot'ta buton aktif görünümlü, metin tek ipucu.
  - **Çözüm:** `FilledButton.styleFrom(disabledBackgroundColor: ...)` + ikon kilit; butonu tamamen gizle suspicion==0.
  - **Kaynak rapor:** [facilities.md](reports/audits/audit_2026-06-27/facilities.md)
  - **Hedef dosya:** `lib/screens/facilities/facilities_screen.dart`

- [ ] **[P2 · UI/UX]** Tier etiketleri — İngilizce "Tier"
  - **Sorun:** `'🏚️ Tier 1 — Başlangıç'`, Tier 2/3 (`facilities_screen.dart` 50–52). Oyun Türkçe; "Kademe" veya "Seviye" beklenir.
  - **Çözüm:** `'Kademe 1 — Başlangıç'`; ARB dosyasına taşı.
  - **Kaynak rapor:** [facilities.md](reports/audits/audit_2026-06-27/facilities.md)
  - **Hedef dosya:** `lib/screens/facilities/facilities_screen.dart`

- [x] **[P2 · UI/UX]** `Card` widget — tema uyumsuz
  - **Sorun:** Üst kartlar `Card()` default Material — `Operasyon Merkezi` cyan accent (`0xFF67E8F9`) app gold/coral sisteminden kopuk (satır 85–138).
  - **Çözüm:** `GkkCard` veya `AppColors` surface token.
  - **Kaynak rapor:** [facilities.md](reports/audits/audit_2026-06-27/facilities.md)
  - **Hedef dosya:** `lib/screens/facilities/facilities_screen.dart`

- [x] **[P2 · UI/UX]** Şüphe çubuğu — renk uygulanmıyor
  - **Sorun:** `%` label `_suspicionColor(globalSuspicion)` kullanır (satır 169–175) ama `LinearProgressIndicator` `valueColor` yok — varsayılan tema rengi (screenshot'ta nötr/gri bar, %0 yeşil label).
  - **Çözüm:** `valueColor: AlwaysStoppedAnimation(_suspicionColor(globalSuspicion))`.
  - **Kaynak rapor:** [facilities.md](reports/audits/audit_2026-06-27/facilities.md)
  - **Hedef dosya:** `lib/screens/facilities/facilities_screen.dart`

### facility_detail — [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
**Kaynak kod:** `lib/screens/facilities/facility_detail_screen.dart`

- [x] **[P1 · UI/UX]** AppBar — generic başlık
  - **Sorun:** `title: 'Tesis Konsolu'` (satır 110-111); body'de de aynı (satır 169-170). Facility adı (`Çiftlik`) ikincil.
  - **Çözüm:** `meta?.name ?? widget.type` AppBar'da.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [x] **[P1 · UI/UX]** Empty state — CTA yok
  - **Sorun:** `facility == null` Card yalnızca metin (satır 139-151); "Tesisi aç" / facilities hub linki yok.
  - **Çözüm:** `context.go(AppRoutes.facilities)` + unlock şartları.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [x] **[P1 · UI/UX]** Tesis bulunamadı — smoke route mismatch (Screenshot QA)
  - **Sorun:** Screenshot `Tesis bulunamadı` / `Bu tesis henüz açılmamış`; muhtemel neden: screenshot `/facilities/farm` ama `_facilityMeta` anahtarı `farming` (satır 799-807). `widget.type == 'farm'` → meta null → facility loop boş.
  - **Çözüm:** Route alias `farm` → `farming`; veya smoke manifest `farming` kullan.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** 1100+ satır monolith
  - **Sorun:** Meta map, rarity math, UI aynı dosyada; bakım maliyeti yüksek.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Client-side production simulation
  - **Sorun:** `_buildLiveProductionSnapshot` (satır 1041-1123); server authoritative değil → collect mismatch.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Tab state — local string
  - **Sorun:** `_activeTab = 'overview'|'queue'` (satır 31); deep link tab yok.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_clockTimer` — her saniye `setState`
  - **Sorun:** Tüm ekran rebuild (satır 40-45); production countdown için `ValueListenableBuilder` yeterli.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `collectResourcesV2` — client seed hash
  - **Sorun:** `_hashString(productionStartedAt)` (satır 555); manipülasyon yüzeyi.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [x] **[P2 · UI/UX]** Card widget — tema dışı default
  - **Sorun:** `Card()` default Material (satır 140, 154); koyu gradient body üzerinde açık tema flash riski.
  - **Çözüm:** `GkkCard` veya `color: AppColors.bgCard`.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [x] **[P2 · UI/UX]** Nadirlik Simülatörü — 10 seviye scroll duvarı
  - **Sorun:** `List.generate(10, ...)` overview tab'de (satır 360-434); çiftlik açık olsa bile çok uzun sayfa.
  - **Çözüm:** Accordion veya ayrı "Drop tablosu" ekranı.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

- [x] **[P2 · UI/UX]** Nadirlik — İngilizce etiketler
  - **Sorun:** `_rarityLabel` → `'⚪ Common'` (satır 935-951); UI Türkçe ama rarity İngilizce.
  - **Çözüm:** `Yaygın`, `Nadir` vb. TR map.
  - **Kaynak rapor:** [facility_detail.md](reports/audits/audit_2026-06-27/facility_detail.md)
  - **Hedef dosya:** `lib/screens/facilities/facility_detail_screen.dart`

### guild — [guild.md](reports/audits/audit_2026-06-27/guild.md)
**Kaynak kod:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** RPC doğrudan ekranda — `_memberAction`
  - **Sorun:** `SupabaseService.client.rpc` screen içinde (414+); provider bypass.
  - **Çözüm:** await ref.read(guildProvider.notifier).promoteMember(memberId);
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Monolith ~1055 satır
  - **Sorun:** `_NoGuildView`, `_GuildView`, `_MemberTile`, 4 dialog tek dosyada.
  - **Çözüm:** // guild_no_guild_view.dart, guild_member_tile.dart, guild_dialogs.dart
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_StatChip` isim çakışması (pvp ile)
  - **Sorun:** Aynı private isim farklı dosyalarda; arama/refactor zor (1037).
  - **Çözüm:** class GuildStatChip extends StatelessWidget { ... }
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_myRole` karma fallback
  - **Sorun:** Birden fazla kaynaktan rol çözümü (501–516); edge case bug.
  - **Çözüm:** GuildRole get myRole => ref.watch(guildProvider).myMembership?.role ?? GuildRole.member;
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `createCost = 10000000` hardcoded
  - **Sorun:** Ekonomi değişince UI/backend uyumsuz (180).
  - **Çözüm:** final createCost = ref.watch(guildConfigProvider).createCostGold;
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `postFrameCallback` init load
  - **Sorun:** `deferProviderUpdate` pattern ile tutarsız (70–76).
  - **Çözüm:** deferProviderUpdate(() async {
  await ref.read(guildProvider.notifier).loadGuild();
});
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · UI/UX]** Arama CTA hizası
  - **Sorun:** `Lonca ara...` + sarı `Ara` butonu; klavye açılınca liste scroll davranışı belirsiz.
  - **Çözüm:** Loading/empty state inline; `TextField.onSubmitted`.
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · UI/UX]** Hitap tonu karışımı
  - **Sorun:** `Loncaya katıldınız!` (siz formu) vs dungeon `yapilamaz` (sen/ASCII).
  - **Çözüm:** Tek hitap politikası (`sen` informal oyun tonu).
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · UI/UX]** Lonca üyesi değil görünümü — bilgi yoğunluğu
  - **Sorun:** `Henüz bir loncaya üye değilsiniz.` + arama + `Önerilen Loncalar` listesi. Kartlarda `Lv.4 · Anıt Lv.8 · 41/50 üye · 2828063 güç` tek satır — küçük ekranda taşma riski.
  - **Çözüm:** Chip satırı: seviye | üye | güç ayrı satırlar; `2828063` → `2.8M`.
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · UI/UX]** Yenileme eksik
  - **Sorun:** Üye listesi / önerilen loncalar pull-to-refresh yok.
  - **Çözüm:** `RefreshIndicator` on `_NoGuildView` / `_GuildView`.
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · UI/UX]** `AlertDialog` varsayılan tema
  - **Sorun:** Ayrıl/oluştur/dağıt dialogları (116–258) açık Material tema; koyu oyun UI'sine uymuyor.
  - **Çözüm:** `backgroundColor: AppColors.bgCard`, `AppTextStyles.title`.
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

- [ ] **[P2 · UI/UX]** `Lv.` kısaltması
  - **Sorun:** Önerilen lonca satırlarında `Lv.` (721+). Türkçe tam kelime yok.
  - **Çözüm:** `'Sv.4'` veya `'Seviye 4'`.
  - **Kaynak rapor:** [guild.md](reports/audits/audit_2026-06-27/guild.md)
  - **Hedef dosya:** `lib/screens/guild/guild_screen.dart`

### guild_monument — [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
**Kaynak kod:** `lib/screens/guild/guild_monument_screen.dart`

- [x] **[P1 · UI/UX]** Tema tutarsızlığı — hardcoded renkler
  - **Sorun:** `Color(0xFF1A2030)`, `Colors.blue`, `Color(0xFFFBBF24)`, `Color(0xFF6366F1)` doğrudan (`guild_monument_screen.dart` 195–351); `AppColors` / `AppTextStyles` kullanılmıyor. Guild ekranı ve guild war farklı palette.
  - **Çözüm:** `AppColors.bgCard`, `AppColors.gold`, `AppTextStyles.title`.
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Monolith screen — 434 satır + inline widget
  - **Sorun:** `_load` 4 paralel Supabase sorgusu + username join ekranda; test/mock zor.
  - **Çözüm:** // guild_monument_repository.dart
class GuildMonumentRepository {
  Future<MonumentSnapshot> fetch(String guildId);
}
// guild_monument_provider.dart
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** State duplication — `guildProvider` vs `_guild` map
  - **Sorun:** `_guild` local `Map<String,dynamic>` provider'daki `Guild` modelinden ayrı; sync drift.
  - **Çözüm:** final guild = ref.watch(guildProvider).guild;
// monument fields guild model'e extend veya MonumentViewModel
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

- [x] **[P2 · Kod/Refaktör]** `_load` — N+1 username fetch pattern
  - **Sorun:** Contributors çek → ayrı `users.inFilter` (satır 73–76); doğru ama ekran içinde 90 satır veri katmanı.
  - **Çözüm:** final data = await client.rpc('get_monument_dashboard', params: {'p_guild_id': guildId});
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

- [x] **[P2 · Kod/Refaktör]** `_upgrade` — `as Map` unsafe cast
  - **Sorun:** `rpc('upgrade_monument') as Map` (satır 126); wrong type runtime crash.
  - **Çözüm:** if (data is! Map<String, dynamic>) { ... return; }
final result = data;
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

- [x] **[P2 · Kod/Refaktör]** `context.go` donate — stack replace
  - **Sorun:** `Bağış Yap` → `context.go(AppRoutes.guildMonumentDonate)` (satır 199); geri tuşu monument'e dönmez (go vs push).
  - **Çözüm:** context.push(AppRoutes.guildMonumentDonate);
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

- [x] **[P2 · UI/UX]** Aksiyon satırı — küçük ekran taşma
  - **Sorun:** `Row` içinde `Bağış Yap` + `Yükselt` yan yana (`guild_monument_screen.dart` 196–211). Dar genişlikte butonlar sıkışır veya overflow.
  - **Çözüm:** `Wrap` veya `Column` + full-width butonlar; `canUpgrade` için FAB.
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

- [x] **[P2 · UI/UX]** Bonus grid — `childAspectRatio: 2.2` overflow
  - **Sorun:** `kMonumentBonuses` 5+ satır, her hücrede Lv + title + effect 3 satır (`guild_monument_screen.dart` 316–342). `mainAxisSize: min` ama aspect ratio düşük → metin clip.
  - **Çözüm:** `ListView` satır bazlı; unlocked/locked accordion.
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

- [x] **[P2 · UI/UX]** Empty state — minimal bilgi
  - **Sorun:** `!hasGuild` → kırmızı metin + `Lonca Bul` (`guild_monument_screen.dart` 165–170). Screenshot merkezde tek satır; anıt sistemi ne işe yarar açıklanmıyor, görsel/ikon yok.
  - **Çözüm:** `MekanEmpty` tarzı illüstrasyon + "Loncaya katılarak anıt yükselt" + birincil/ikincil CTA.
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

- [x] **[P2 · UI/UX]** `_ResourceTile` — `childAspectRatio: 3` sıkışıklık
  - **Sorun:** Grid 2×2, label `fontSize: 10`, value `14` (`guild_monument_screen.dart` 292–304, 428). "Yapısal Kaynak" uzun label tek satırda sıkışır.
  - **Çözüm:** `childAspectRatio: 2.2`; kısa label ("Yapısal") + tooltip.
  - **Kaynak rapor:** [guild_monument.md](reports/audits/audit_2026-06-27/guild_monument.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_screen.dart`

### guild_monument_donate — [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
**Kaynak kod:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [x] **[P1 · Kod/Refaktör]** Bağış sonrası guild/player refresh yok
  - **Sorun:** Monument ekranına dönünce stale anıt seviyesi.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** RPC `p_user_id` client'tan
  - **Sorun:** `donate_to_monument` user.id gönderiyor (satır 95-100); güvenlik: server auth.uid kullanmalı.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Static daily limits
  - **Sorun:** `_maxStructural` vb. kodda sabit (satır 29-33); backend değişince drift.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_loadDailyDonations` — silent catch
  - **Sorun:** `catch (_) {}` (satır 76); limit bar yanlış kalır.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `onChanged` limit clamp — cursor jump
  - **Sorun:** `ctrl.text = '$remaining'` (satır 152-154); TextField imleç sona atlar.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [x] **[P2 · Kod/Refaktör]** İki farklı Scaffold yapısı
  - **Sorun:** `!hasGuild` vs normal (satır 173-223); chrome tutarsız.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [x] **[P2 · UI/UX]** Başarı sonrası — hard `go` monument
  - **Sorun:** `context.go(AppRoutes.guildMonument)` (satır 107); geri stack silinir.
  - **Çözüm:** `pop` + refresh veya "Başka bağış" CTA.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [x] **[P2 · UI/UX]** Envanter/stok önizlemesi yok
  - **Sorun:** Yapısal/mistik/kritik kaynak input var ama oyuncunun elinde ne kadar olduğu gösterilmiyor.
  - **Çözüm:** `inventoryProvider` ile `Sahip: X` satırı.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [x] **[P2 · UI/UX]** Input default — `'0'` her alan
  - **Sorun:** Controller `text: '0'` (satır 21-24); kullanıcı silmeden bağış yapamaz veya yanlışlıkla 0 gönderir.
  - **Çözüm:** Boş placeholder; `hintText: '0'`.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [x] **[P2 · UI/UX]** Lonca yok — kırık empty state (Screenshot QA)
  - **Sorun:** Screenshot: `Lonca bulunamadı.` tek satır, ortada (satır 173-177); AppBar bile minimal, bottom nav yok, CTA yok (`Lonca Bul` / `Geri`).
  - **Çözüm:** Empty illustration + `context.go(AppRoutes.guild)` CTA; monument donate smoke için guild fixture.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

- [x] **[P2 · UI/UX]** `suffixText: 'max $remaining'` — İngilizce
  - **Sorun:** `_resourceInput` suffix (satır 148); label Türkçe.
  - **Çözüm:** `'en fazla $remaining'`.
  - **Kaynak rapor:** [guild_monument_donate.md](reports/audits/audit_2026-06-27/guild_monument_donate.md)
  - **Hedef dosya:** `lib/screens/guild/guild_monument_donate_screen.dart`

### guild_war — [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
**Kaynak kod:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `NestedScrollView` + `TabBarView` + `SliverOverlapInjector`
  - **Sorun:** `_scrollTab` her tab için ayrı `CustomScrollView` + overlap injector; tab switch'te scroll pozisyonu korunur ama header yüksekliği değişince overlap glitch riski.
  - **Çözüm:** DefaultTabController + CustomScrollView(slivers: [header, TabBar, SliverFillRemaining(child: TabBarView(...))])
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_attackTerritory` — `context.push` sonra `_refresh` fire-and-forget
  - **Sorun:** Battle result dönüşünde `then((_) => _refresh())` mounted check yok (`guild_war_hub_screen.dart` 110).
  - **Çözüm:** await context.push(...);
if (!mounted) return;
await _refresh();
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_myRank` / `_myPoints` — O(n) linear scan
  - **Sorun:** Her build'de rankings listesi döngü (`guild_war_hub_screen.dart` 57–70); büyük sezonlarda gereksiz.
  - **Çözüm:** final myEntry = warState.rankings.cast<GuildWarRanking?>().firstWhere(
  (r) => r!.guildName == guildName, orElse: () => null);
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `initState` — sıralı await guild sonra war
  - **Sorun:** `loadGuild` bitene kadar `loadAll` bekler; skeleton süresi uzar.
  - **Çözüm:** unawaited(Future.wait([
  ref.read(guildProvider.notifier).loadGuild(),
  ref.read(guildWarProvider.notifier).loadAll(),
]));
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · UI/UX]** Bölge haritası — sabit 420pt yükseklik
  - **Sorun:** `_buildTerritoriesContent` map view `SizedBox(height: 420)` (`guild_war_hub_screen.dart` 294–301). iPhone SE viewport ~667pt; header+tab+420 harita = liste moduna geçmeden scroll zorunlu.
  - **Çözüm:** `LayoutBuilder` ile `min(420, constraints.maxHeight * 0.45)`; varsayılan Liste modu mobilde.
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · UI/UX]** Gradient duplicate — tema dışı
  - **Sorun:** Body `LinearGradient` hardcoded `0xFF090D14` (`guild_war_hub_screen.dart` 145–150); `GameScreenBackground` / `AppColors` ile aynı ton ama ayrı sabit.
  - **Çözüm:** `GameScreenBackground` veya shared gradient token.
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · UI/UX]** Lonca üyeliği uyarısı — `Lonca Bul` CTA görsel hiyerarşi
  - **Sorun:** `guildId == null` iken sarı çerçeveli tam genişlik `TextButton('Lonca Bul')` sezon kartı + 4 tab arasında sıkışık (`guild_war_hub_screen.dart` 167–185). Screenshot'ta turnuva/saldırı aksiyonları görünmeden önce tek CTA; uyarı metni yok, sadece buton.
  - **Çözüm:** Banner: "Lonca üyeliği gerekli" + ikincil "Lonca Bul"; tab'ler disabled overlay.
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · UI/UX]** Tab bar + `Savaş Kayıtları` — dikey alan tüketimi
  - **Sorun:** `GuildWarSeasonHeader` + `GuildWarTabBar` + `OutlinedButton` (Savaş Kayıtları) + `NestedScrollView` header hepsi fold üstünde (`guild_war_hub_screen.dart` 155–206). Screenshot'ta podium altı (#3+) viewport dışında; scroll gerektirir.
  - **Çözüm:** Kayıtlar butonunu AppBar action veya tab içi FAB; header compact mode.
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · UI/UX]** `GuildWarTabBar` — 4 emoji tab dar ekran
  - **Sorun:** `isScrollable: tabs.length > 3` → 4 tab scrollable (`guild_war_tab_bar.dart` 28). Label `fontSize: 11` emoji+metin; küçük cihazda "Krallık" kısmen görünür, yatay kaydırma affordance yok.
  - **Çözüm:** Scroll hint gradient veya 2×2 grid tab; `TabBar` `tabAlignment: TabAlignment.start`.
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

- [ ] **[P2 · UI/UX]** `RankingPodium` — podium tipografi
  - **Sorun:** `_PodiumSlot` guild adı `fontSize: 10`, puan `9` (`ranking_podium.dart` 86–99). Screenshot'ta #1/#2 kartlarında "aaaaaa", "kankaja" okunur ama puan satırı küçük; `#` numarası 24px kartın ~%60'ını kaplar — bilgi/ornament oranı ters.
  - **Çözüm:** İsim min 11px; dev `#` yerine medal + compact rank badge.
  - **Kaynak rapor:** [guild_war.md](reports/audits/audit_2026-06-27/guild_war.md)
  - **Hedef dosya:** `lib/screens/guild_war/guild_war_hub_screen.dart`

### guild_war_logs — [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
**Kaynak kod:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** `_load` — full `loadAll()`
  - **Sorun:** Sadece log ekranı tüm guild war state'i çekiyor (satır 29-31); ağır.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P1 · UI/UX]** Test lonca adları — prod görünüm
  - **Sorun:** Screenshot'ta `aaaaaa`, `kankaja` guild adları; `AttackLogTile` olduğu gibi render.
  - **Çözüm:** Smoke fixture isimleri QA-only; prod seed temizle.
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Filtre local — provider dışı
  - **Sorun:** `setState` + `_filter` (satır 21, 74); rebuild tüm ekran.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Hardcoded gradient
  - **Sorun:** `0xFF090D14` (satır 56-59); hub ile duplicate.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `guildId` null — filtre sessiz bozulur
  - **Sorun:** `myGuildId` null iken win/loss anlamsız (satır 36-44).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P2 · UI/UX]** Boş liste — empty state yok
  - **Sorun:** `ListView.builder` `itemCount: filtered.length` (satır 108-115); `filtered.isEmpty` iken boş scroll, mesaj yok. Screenshot'ta 3 kayıt var; empty QA doğrulanmadı.
  - **Çözüm:** `GuildWarEmptyState` veya "Henüz saldırı kaydı yok".
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P2 · UI/UX]** Filtre mantığı — savunma zaferi eksik
  - **Sorun:** `'win'` yalnızca `attackerGuildId == guildId && success` (satır 40-41); başarılı savunma "Kazandık"da görünmez.
  - **Çözüm:** Win = (attack success as attacker) OR (defend success as defender).
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P2 · UI/UX]** Liste altı — geniş boşluk
  - **Sorun:** Screenshot 3 kart sonrası ~%40 boş viewport; padding/fill yok.
  - **Çözüm:** `ListView` + footer "Daha fazla yükle" veya compact card.
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P2 · UI/UX]** Loading — empty list flash
  - **Sorun:** `isLoading` spinner (satır 103-104); önceki `filtered` temizlenmiyor → stale flash riski.
  - **Çözüm:** Load başında list clear veya skeleton.
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

- [ ] **[P2 · UI/UX]** Zaman damgası — 22g önce
  - **Sorun:** `AttackLogTile._timeAgo` (satır 25-30); seed verisi eski — OK ama format `22g` kısaltması tutarsız (`22 gün` vs `22g`).
  - **Çözüm:** `22 gün önce` tam form.
  - **Kaynak rapor:** [guild_war_logs.md](reports/audits/audit_2026-06-27/guild_war_logs.md)
  - **Hedef dosya:** `lib/screens/guild_war/war_logs_screen.dart`

### guild_war_territory_detail — [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
**Kaynak kod:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P0 · UI/UX]** `_StatTile` — label kontrastı düşük (Screenshot QA)
  - **Sorun:** `fontSize: 10`, `AppColors.textTertiary` (satır 233); screenshot'ta "Savunma", "Trade Geliri" koyu mavi üzerinde okunmuyor.
  - **Çözüm:** Min 11px + `textSecondary`; veya label üstte icon altında value.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Local `_detail` state
  - **Sorun:** `TerritoryDetail?` local (satır 29-48); provider pattern yok.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `GridView.count` shrinkWrap
  - **Sorun:** Nested scroll ListView içinde (satır 145-158); performans OK ama `childAspectRatio: 1.6` dar metin.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_addDefense` — sheet sonrası full reload
  - **Sorun:** `_load()` tüm detail (satır 80-90).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_attack` — `context.push` extra
  - **Sorun:** `AppRoutes.guildWarBattleResult` + `extra: result` (satır 77); deep link kırılgan.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `isOwner` — null owner edge case
  - **Sorun:** `isUnclaimed` bölgede owner null; `isOwner` false → Saldır gösterilir (OK) ama `ownerGuildName` boş string riski.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Bölge yok — blank screen
  - **Sorun:** `t == null` → `SizedBox.shrink()` (satır 114-115); loading sonrası boş.
  - **Çözüm:** Error empty + geri.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Hero banner — sadece isim
  - **Sorun:** 120px gradient kutu yalnızca `t.name` (satır 122-142); harita/harita pini yok.
  - **Çözüm:** Territory icon, koordinat, bonus özeti.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Saldır/Savunma CTA — lonca yok gizlenir
  - **Sorun:** `if (guildId != null)` (satır 191); loncasız oyuncu CTA görmez, açıklama da yok.
  - **Çözüm:** `Lonca üyeliği gerekli` banner.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Savunma bar — max değer tutarsızlığı
  - **Sorun:** Screenshot footer `Savunma: 2600 / 1000` kırmızı bar; `DefensePowerBar` `max: t.baseDefensePower` (satır 169-173) — current > max görsel bug.
  - **Çözüm:** `max(current, baseDefense)` veya ayrı "bonus savunma" göstergesi.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Son saldırılar — screenshot'ta görünmüyor
  - **Sorun:** `recentAttacks.isNotEmpty` koşulu (satır 177); screenshot fold altında veya boş — scroll ipucu yok.
  - **Çözüm:** Hub'daki son 3 saldırı özeti header'da.
  - **Kaynak rapor:** [guild_war_territory_detail.md](reports/audits/audit_2026-06-27/guild_war_territory_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/territory_detail_screen.dart`

### guild_war_tournament_detail — [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
**Kaynak kod:** `lib/screens/guild_war/tournament_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Local state — provider duplicate
  - **Sorun:** `_tournament`, `_participants` local (satır 25-27); hub cache ile senkron riski.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_join` — optimistic UI yok
  - **Sorun:** Join sonrası `_load` full; loading tüm ekranı kaplar.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_load` — tournament hub'dan firstOrNull
  - **Sorun:** ID listede yoksa `t` null kalır, ayrı fetch yok (satır 39-45).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `firstOrNull` — extension import
  - **Sorun:** Dart 3 collection; null tournament silent fail.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Eşleşmeler — naive pairing
  - **Sorun:** `_participants.length ~/ 2` sıralı çift (satır 153-171); gerçek bracket seed yok.
  - **Çözüm:** Backend `matches` listesi render.
  - **Kaynak rapor:** [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Katıl butonu — her zaman görünür koşul
  - **Sorun:** `t.isActive && guildId != null` (satır 176-193); zaten katılmış lonca için disabled state yok.
  - **Çözüm:** `isParticipant` badge; buton gizle/değiştir.
  - **Kaynak rapor:** [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Katılımcılar — boş liste, empty state yok (Screenshot QA)
  - **Sorun:** Screenshot `0 Lonca`, `Katılımcılar` başlığı altı tamamen boş (satır 115-145); loading bitince empty mesaj yok.
  - **Çözüm:** `GuildWarEmptyState`: "Henüz katılımcı yok" + kayıt CTA.
  - **Kaynak rapor:** [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Turnuva bulunamadı — blank screen
  - **Sorun:** `t == null` → `SizedBox.shrink()` (satır 86-87); hata/404 UI yok.
  - **Çözüm:** "Turnuva bulunamadı" + hub'a dön.
  - **Kaynak rapor:** [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Ödül metni — formatlanmamış sayı
  - **Sorun:** `'🏆 Ödül: ${t.prizePool}'` (satır 109); screenshot `250,000 Altın + Efsanevi Eşya` — string backend'den; binlik ayırıcı tutarsız olabilir.
  - **Çözüm:** Structured prize model + `NumberFormat`.
  - **Kaynak rapor:** [guild_war_tournament_detail.md](reports/audits/audit_2026-06-27/guild_war_tournament_detail.md)
  - **Hedef dosya:** `lib/screens/guild_war/tournament_detail_screen.dart`

### home — [home.md](reports/audits/audit_2026-06-27/home.md)
**Kaynak kod:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `HeroShowcase` — deprecated `withOpacity` + sabit `height: 450`
  - **Sorun:** `withOpacity(0.2)` Flutter 3.27+ deprecation; 450pt sabit yükseklik landscape/küçük cihazda ListView overflow veya aşırı boşluk. `SingleTickerProvider` breathing animasyon sürekli repaint.
  - **Çözüm:** .withValues(alpha: 0.2)
LayoutBuilder(builder: (_, c) {
  final h = (c.maxWidth * 1.05).clamp(320.0, 450.0);
  return SizedBox(height: h, child: ...);
})
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_ActiveStatusPill` — `Stream.periodic` saniyede bir tüm subtree rebuild
  - **Sorun:** Hastane/hapishane timer pill'i her saniye `AnimatedBuilder` + `BackdropFilter` blur tetikler; home scroll sırasında birden fazla pill = gereksiz GPU yükü.
  - **Çözüm:** class _CountdownText extends StatefulWidget { ... } // yalnızca Text rebuild
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_CratePromoBanner` margin `horizontal: 16` + ListView padding `AppSpacing.base` (16)
  - **Sorun:** Efektif yatay inset 32px; Pantheon tam genişlik — banner dar görünür, hizalama tutarsız.
  - **Çözüm:** // veya banner'ı edge-to-edge full bleed yap (negatif margin)
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Ölü kod — ~400 satır kullanılmayan widget sınıfları
  - **Sorun:** `_StatsGrid`, `_PrimaryActions`, `_QuestSection`, `_PotionAction`, `_SecondaryActions`, `_RecentActivitySection` tanımlı ama `_HomeDashboard.build` içinde **hiç çağrılmıyor**. `_showAllActions` `final false` — toggle imkansız. `_showPotionModal`, `_showComingSoon` dead methods.
  - **Çözüm:** // Seçenek A: Stats + PrimaryActions ListView'e ekle
// Seçenek B: dead class'ları ayrı PR'da kaldır (1563 satır → ~900)
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · UI/UX]** Ekran görüntüsü otomasyonu — daily reward modal home UI'sini maskeliyor
  - **Sorun:** Manifest `home` slug'ı altında yalnızca dialog frame'i; ana dashboard içeriği doğrulanmıyor. Splash/login QA notu ile aynı sınıf hata.
  - **Çözüm:** Screenshot harness'te `dailyRewardProvider` override veya dialog dismiss; ikinci pass `home_post_reward.png`.
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · UI/UX]** Günlük ödül dialogu — home içeriğini bloke eden modal
  - **Sorun:** `_maybeShowDailyReward()` profil `ready` olunca otomatik dialog açar; `_dailyRewardShownThisSession` yalnızca session içi. İlk girişte tüm home (kasa, hero, pantheon) görünmez — screenshot'ta kanıtlandı.
  - **Çözüm:** Non-blocking banner veya bottom sheet; "Sonra" butonu; dialog `barrierDismissible: true`; screenshot QA'da devre dışı.
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · UI/UX]** Promo banner — tipografi sistemi kopukluğu
  - **Sorun:** `GoogleFonts.urbanist` doğrudan banner içinde (`KASA AÇ`, alt metin, timer); geri kalan home `AppTextStyles` kullanır. Font weight/size (`w900`, 28px) tema `headlineSmall` ile hizalı değil.
  - **Çözüm:** `AppTextStyles.h2.copyWith(color: Colors.white)`; Urbanist zaten `app_theme.dart`'ta global.
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · UI/UX]** `HeroShowcase` — eksik ekipman slotları vs envanter
  - **Sorun:** Home hero 6 slot: weapon, head, chest, gloves, boots, necklace. `InventoryScreen._EquippedPanel` 8 slot: + legs, ring. Oyuncu home'da bacak/yüzük kuşandığını görmez; slot etiketleri de farklı (`Kask` vs `KAFA`, `Ayakkabı` vs `BOT`).
  - **Çözüm:** Paylaşılan `EquipSlotLayout` constant; home'da 8 slot compact grid veya scrollable ring.
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · UI/UX]** `PantheonBoard` — ASCII Türkçe ve tier copy
  - **Sorun:** `'Siralama'`, `'Guc liderleri • canli'`, `'Henuz siralama verisi yok.'`, `'Siralama yuklenemedi'` — `ı`, `ü`, `ç` eksik. Alt link `Tumu` → "Tümü".
  - **Çözüm:** l10n ARB; `'Güç liderleri • canlı'`.
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

- [ ] **[P2 · UI/UX]** `_CratePromoBanner` — sahte geri sayım ve yanıltıcı fiyat
  - **Sorun:** Timer sabit hardcoded: `_buildTimeBlock('06', 'Sa')`, `'32'`, `'12'` — gerçek zamanlı değil. CTA metni `500 ile Aç` + cyan diamond ikon; backend fiyat/stok ile bağlantı yok. Alt metin "Sınırlı bir süre için" süresiz görünür.
  - **Çözüm:** `loot` API'den `endsAt` + `priceGems` çek; `Stream.periodic` ile gerçek countdown veya timer kaldır. Fiyatı profil `gems` ile karşılaştır (yetersizse disabled CTA).
  - **Kaynak rapor:** [home.md](reports/audits/audit_2026-06-27/home.md)
  - **Hedef dosya:** `lib/screens/home/home_screen.dart`

### horse_race — [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
**Kaynak kod:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Phase sync — local flags + provider
  - **Sorun:** `_showingLiveRace`, `_showingResult`, `_dismissedResultRoundId` (satır 76-80) provider state ile duplicate; rebuild race.
  - **Çözüm:** enum HorseRaceUiPhase { betting, live, result }
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_gridHeight` — fixed height grid in ListView
  - **Sorun:** `NeverScrollableScrollPhysics` nested — OK ama orientation change'de recalc?
  - **Çözüm:** ```
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_parseColor` — invalid hex fallback
  - **Sorun:** Satır 13-20; server bad color → tüm atlar mavi.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `horse_race_provider.dart` — ayrı dosya iyi; screen hâlâ 747 satır
  - **Sorun:** UI + overlay logic birleşik.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · UI/UX]** At grid — düşük touch target
  - **Sorun:** `childAspectRatio: 2.65` (satır 66) — kart ~40pt yükseklik; emoji 18 + isim 13px + mult.
  - **Çözüm:** aspect 1.8-2.0; min 48dp height.
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · UI/UX]** Bahis miktarı — preset only
  - **Sorun:** `_goldPresets` / `_gemPresets` (satır 62-63); custom amount TextField yok. Yüksek roller 1M+ gold dışarıda kalır.
  - **Çözüm:** Custom input + min/max validation RPC'den.
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · UI/UX]** Immersive mod — navigasyon tamamen gizli
  - **Sorun:** `_showingLiveRace` → `appBar: null`, `bottomNavigationBar: null` (satır 103-121). Çıkış yolu yok (geri swipe `PopScope` yok live view'da).
  - **Çözüm:** Minimal top bar X veya swipe-down dismiss.
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · UI/UX]** Live view — finish bar artifact
  - **Sorun:** Screenshot sağda dikey gri/bar pixelated — `horse_race_track_painter` veya progress marker render kalitesi düşük.
  - **Çözüm:** Anti-alias paint; asset-based finish line.
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · UI/UX]** Screenshot QA — yakalanan faz yanlış
  - **Sorun:** Audit PNG **canlı yarış overlay** (`HorseRaceLiveView` countdown "2"); bahis grid, currency toggle, preset chip'ler görünmüyor. Smoke capture timing race phase'e denk gelmiş — bahis UX audit edilemedi.
  - **Çözüm:** Screenshot script'te `HorseRacePhase.betting` bekle; ayrı `horse_race_betting.png`.
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · UI/UX]** Son kazananlar — 30 item sabit grid yüksekliği
  - **Sorun:** `recentWinners.take(30)` + computed grid height (satır 538-577) — ana ListView'e büyük blok ekler; bahis UI aşağı iter.
  - **Çözüm:** Collapse "Son 5" + "Tümünü gör".
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · UI/UX]** Sonuç overlay — `won == null`
  - **Sorun:** `_buildResultOverlay` (satır 727-728): bet var ama `won` null → `'...'` sonsuz.
  - **Çözüm:** Loading spinner + timeout retry.
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

- [ ] **[P2 · UI/UX]** Türkçe diakritik — tutarsız marka
  - **Sorun:** AppBar `'At Yarisi'` (satır 106); live header `'Canlı Yarış'` (live_view); status `'Kapaniyor'`, `'Bahis acik'` ASCII.
  - **Çözüm:** `'At Yarışı'`, `'Bahis açık'`, `'Kapanıyor'`.
  - **Kaynak rapor:** [horse_race.md](reports/audits/audit_2026-06-27/horse_race.md)
  - **Hedef dosya:** `lib/screens/horse_race/horse_race_screen.dart`

### hospital — [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
**Kaynak kod:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Hospital + Prison duplicate UI
  - **Sorun:** ~%70 aynı layout (countdown, progress, gem bail, escape); iki dosyada copy-paste drift.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_healWithGems` — RPC response branch karmaşık
  - **Sorun:** `expectFree` path `was_free` check; paid path `success != true` — duplicate RPC çağrısı aynı `heal_with_gems` (satır 121–240).
  - **Çözüm:** Future<HealResult> heal({bool preferFree = true}) // repository
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_parseRestrictionUntil` vs prison `DateTime.tryParse`
  - **Sorun:** Hospital timezone-aware parse (satır 30–59); prison naive parse — aynı `hospitalUntil`/`prisonUntil` alanları farklı sonuç.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `dynamic profile` — type safety
  - **Sorun:** `_buildInHospital(dynamic profile)` (satır 393); `profile?.energy as int?` cast.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · UI/UX]** Geri sayım formatı — tutarsızlık
  - **Sorun:** `_formatCountdown` `3h 2m 5s` (`hospital_screen.dart` 280–286); `prison_screen` `MM:SS`. Aynı restriction pattern farklı UX.
  - **Çözüm:** Shared `RestrictionCountdown` widget + `DurationFormat`.
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · UI/UX]** Hastane nedeni — hardcoded metin
  - **Sorun:** `_buildInHospital` `_infoRow('Neden:', 'Zindan başarısızlığı')` sabit (satır 434). API `hospital_reason` veya profil alanı yok.
  - **Çözüm:** `profile.hospitalReason ?? 'Bilinmiyor'` backend alanı.
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · UI/UX]** Kaçış sonucu — her zaman kırmızı snack
  - **Sorun:** `_attemptEscape` başarılı kaçışta bile `AppMessenger.showError(context, message)` (satır 256–257). `success` değişkeni kullanılmıyor.
  - **Çözüm:** `escaped ? showSuccess : showError`; mesajı localize et.
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · UI/UX]** Sağlıklı state — boş viewport
  - **Sorun:** `_buildHealthy` tek kart `maxWidth: 420` ortada; üst/alt ~%60 boş alan (`hospital_screen.dart` 330–390, screenshot). Çift emoji: 👍 + 🏥 Hastane başlık.
  - **Çözüm:** Kompakt kart + son hastane geçmişi / ücretsiz taburcu hakkı özeti; veya deep link yoksa home redirect.
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · UI/UX]** Taburcu butonları — renk anlamı
  - **Sorun:** Ücretsiz yeşil `0xFF22C55E`, gem mor `0xFF9B30FF` (`hospital_screen.dart` 458–492). App `AppColors.gold`/`danger` dışı; screenshot healthy state'te sarı "Ana Sayfaya Dön" tek CTA — in-hospital'da 3 aksiyon hierarchy belirsiz.
  - **Çözüm:** Primary = ücretsiz (varsa); secondary = gem; escape tertiary outline.
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

- [ ] **[P2 · UI/UX]** Tema — hardcoded gradient
  - **Sorun:** `Color(0xFF10131D)` gradient (`hospital_screen.dart` 323–328); `AppColors` / `GameScreenBackground` kullanılmıyor.
  - **Çözüm:** Shared restriction screen scaffold.
  - **Kaynak rapor:** [hospital.md](reports/audits/audit_2026-06-27/hospital.md)
  - **Hedef dosya:** `lib/screens/hospital/hospital_screen.dart`

### inventory — [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
**Kaynak kod:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P1 · UI/UX]** 5 sütun grid — mobil touch target sınırda
  - **Sorun:** `crossAxisCount: 5`, `crossAxisSpacing: 8`, padding 12 — iPhone 390pt genişlikte slot ~`(390-24-32)/5 ≈ 67dp`. WCAG önerilen 44dp üstünde ama `LongPressDraggable` + komşu slotlar yanlış drop riski yüksek. Slot numarası `fontSize: 10`, `Colors.white12` — kontrast ~1.5:1.
  - **Çözüm:** Mobile'da 4 sütun; `LayoutBuilder` ile breakpoint. Numara rengi `white38` minimum.
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Grid `itemBuilder` içinde DnD + filter + selection — O(n) slot lookup her rebuild
  - **Sorun:** `_getItemBySlot` her index için linear scan; 20 slot × rebuild kabul edilebilir ama filter değişiminde 20× LongPressDraggable yeniden oluşur.
  - **Çözüm:** final slotMap = { for (final i in state.items) i.slotPosition: i };
// itemBuilder: final rawItem = slotMap[index];
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Monolitik 1675 satır — tek dosyada UI + DnD + dialog + API
  - **Sorun:** Bakım maliyeti; `_InventoryReadyInteractiveState` 600+ satır handler. Test izolasyonu imkansız.
  - **Çözüm:** // inventory_screen.dart — scaffold + provider switch
// widgets/equipped_panel.dart, inventory_grid.dart, item_action_panel.dart
// inventory_drag_controller.dart — drop logic unit test
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_InventoryReadyView` gereksiz passthrough wrapper
  - **Sorun:** `_InventoryReadyView` yalnızca `_InventoryReadyInteractive` döndürür — ekstra widget layer, state promotion engellenir.
  - **Çözüm:** InventoryStatus.ready => _InventoryReadyInteractive(state: inventoryState),
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_QuantityActionDialog` — `_quantity` init her zaman 1, maxQuantity edge case
  - **Sorun:** `maxQuantity < 1` ise `_quantity = 1` ama slider `max: 1, min: 1` — split dialog stack qty=1 item'da anlamsız açılabilir (guard `_handleSplit`'te var ama dialog yine açılır route'da).
  - **Çözüm:** if (!item.isStackable || item.quantity <= 1) {
  _showSnack('Bu eşya bölünemez.');
  return;
}
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `onWillAcceptWithDetails` — if without braces, lint risk
  - **Sorun:** Satır 658-661 tek satır if; future edit'te bug. `onWillAcceptWithDetails: (details) => true` equipped panel'de her payload kabul — invalid drop sonra snack ile reddedilir (geç feedback).
  - **Çözüm:** onWillAcceptWithDetails: (d) {
  final slot = EquipSlot.fromName(slotMeta.$1);
  return d.data.item.equipSlot == slot;
},
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · UI/UX]** Bölüm başlığı — yazım hatası ve ASCII Türkçe
  - **Sorun:** `'Kusanilanlar'` (satır 485, 518) — doğrusu **"Kuşanılanlar"**. Ekran görüntüsünde de aynı hatalı yazım görünüyor. Hata mesajları: `'Envanter yuklenemedi.'`, `'Islem basarisiz'`, `'Kusanma basarisiz'`.
  - **Çözüm:** Merkezi string tablosu; tüm snack/dialog metinlerinde Türkçe karakter.
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · UI/UX]** Filtre çubuğu — gizlenen item'lar boş numaralı slot bırakıyor
  - **Sorun:** `_matchesFilter` false ise `item = null` render edilir; slot yine numaralı boş hücre (`${slotIndex + 1}`). Filtre "Silah" seçiliyken envanter 0/20 gösterir ama 20 boş kutucuk — kullanıcı "item kayboldu" sanabilir.
  - **Çözüm:** Filtre modunda `itemCount: filteredItems.length` ayrı grid; veya filtre aktifken boş slotları gizle + "Bu filtrede eşya yok" mesajı.
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · UI/UX]** Kapasite göstergesi — `0/20` smoke verisi ile boş envanter
  - **Sorun:** Ekran görüntüsünde tüm slotlar boş, equipped panel boş — QA smoke hesabında starter item yok. Yeni oyuncu "envanter neden boş / oyun mu bozuk" algısı (onboarding gap).
  - **Çözüm:** Onboarding'de starter item seed; empty state illustration + "Zindandan loot topla" CTA.
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · UI/UX]** Kuşanılan slot — tek dokunuşla unequip, onay yok
  - **Sorun:** `_EquippedPanel` `onTap: hasItem ? () => onUnequip(slotMeta.$1) : null` — yanlış dokunuşta ekipman anında çıkar. Sağ üst `Icons.close` 9px — affordance zayıf, touch target ~48dp slot içinde küçük ikon.
  - **Çözüm:** Long-press unequip veya confirm dialog; close ikon minimum 24dp hit area.
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

- [ ] **[P2 · UI/UX]** `_SelectedItemPanel` — açık tema dialog koyu envanter üzerinde
  - **Sorun:** Dialog arka plan `#FFFFFF`, sarı KO-style CTA `#F2D74C`; envanter `#090D14` gradient + glass card. Bilinçli KO referansı olsa da ekran görüntüsü dışı deneyim: gece modu oyuncuya anlık flashbang. Label'lar ASCII: `ESYA ADI`, `DEGER`, `COP`, `BOL`, `KULLAN`.
  - **Çözüm:** `GkkCard` dark variant ile panel; KO layout korunup `AppColors.bgCard` zemin. Metin: `EŞYA ADI`, `DEĞER`, `ÇÖP`.
  - **Kaynak rapor:** [inventory.md](reports/audits/audit_2026-06-27/inventory.md)
  - **Hedef dosya:** `lib/screens/inventory/inventory_screen.dart`

### leaderboard — [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
**Kaynak kod:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P1 · UI/UX]** Sahte liderlik verisi (prod riski)
  - **Sorun:** RPC hata/boş dönerse `_defaultEntries()` 30 uydurma oyuncu (`GölgeKral`, `DemirKılıç`…) gösterilir (satır 35–66, 155–164).
  - **Çözüm:** Mock yalnızca `kDebugMode`; prod'da error/empty state UI.
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Hardcoded gradient body
  - **Sorun:** `0xFF10131D` tekrar; tema dışı (pvp/guild ile aynı kopya).
  - **Çözüm:** decoration: BoxDecoration(gradient: AppGradients.screenBackground),
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Supabase RPC doğrudan StatefulWidget'ta
  - **Sorun:** Provider/cache yok; test mock zor; `setState` yoğun (satır 125–209).
  - **Çözüm:** final state = ref.watch(leaderboardProvider(category, period));
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_LeaderboardEntry` local class
  - **Sorun:** Model tekrarı; JSON mapping screen'de (satır 12–25).
  - **Çözüm:** ```
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_applyFilter` her keystroke `setState`
  - **Sorun:** 30+ entry listesinde her tuş rebuild (satır 212–222).
  - **Çözüm:** Timer? _debounce;
void _onSearchChanged(String q) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 250), () => _applyFilter(q));
}
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_defaultEntries` prod fallback
  - **Sorun:** Catch bloğu sessiz; fake data set (satır 155–164).
  - **Çözüm:** } catch (e) {
  setState(() { _entries = []; _error = 'Sıralama yüklenemedi'; });
}
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · UI/UX]** Arama + podyum etkileşimi
  - **Sorun:** Arama aktifken podyum gizlenir (satır ~481); boş arama sonrası podyum geri gelir ama geçiş animasyonsuz.
  - **Çözüm:** Podyumu dim + filtre; veya arama sonuçlarında rank badge.
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · UI/UX]** Kategori `Görev` etiketi
  - **Sorun:** `level` anahtarı label `'Görev'` (30) — aslında seviye sıralaması; semantik yanlış.
  - **Çözüm:** Label `'Seviye'`.
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · UI/UX]** Podyum değer formatı — tutarsız ikon
  - **Sorun:** Screenshot'ta servet kategorisinde `1802.2M` yanında gri ay ikonu; alt listede aynı. `🪙` emoji `_formatValue` içinde tanımlı ama podyumda farklı render olabilir.
  - **Çözüm:** Kategori başına sabit `LeaderboardValueFormatter`.
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · UI/UX]** Yenileme pattern
  - **Sorun:** Yalnızca küçük refresh `IconButton` (420+); `RefreshIndicator` yok.
  - **Çözüm:** `RefreshIndicator` + mevcut ikon.
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

- [ ] **[P2 · UI/UX]** `N/A` / `Lv.` İngilizce kısaltmalar
  - **Sorun:** `_formatValue` level için `Lv.$value` (81); oyuncu kendi sırası yoksa `N/A` (342).
  - **Çözüm:** `'Sv.$value'` / `'Bilinmiyor'` veya `'—'`.
  - **Kaynak rapor:** [leaderboard.md](reports/audits/audit_2026-06-27/leaderboard.md)
  - **Hedef dosya:** `lib/screens/leaderboard/leaderboard_screen.dart`

### login — [login.md](reports/audits/audit_2026-06-27/login.md)
**Kaynak kod:** `lib/screens/auth/login_screen.dart`

- [ ] **[P1 · UI/UX]** Alt link — "Hesabin yok mu? Kayit Ol" (`TextButton`)
  - **Sorun:** `textButtonTheme.foregroundColor = AppColors.accentBlue` (#5B8FFF) kart arka planı `AppColors.bgCard` (#1A2238) üzerinde. 14px Urbanist w600 ile kontrast oranı ~4.2:1 — WCAG AA normal metin eşiği 4.5:1'in altında. Ekran görüntüsünde link, başlık beyazına (#F0F4FF) kıyasla belirgin soluk.
  - **Çözüm:** Link rengini `AppColors.accentBlue` → `Color(0xFF7AA8FF)` veya `goldLight` tonuna çek; minimum 4.5:1 doğrula. Alternatif: altın underline + `bodyBold` weight.
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** E-posta validasyonu yetersiz — `contains('@')` only
  - **Sorun:** `"a@"`, `"@@"` geçerli sayılır; gereksiz API round-trip ve kullanıcıya geç SnackBar hatası.
  - **Çözüm:** final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
if (!emailRegex.hasMatch(email)) return 'Geçerli bir e-posta girin.';
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Navigasyon tutarsızlığı — `context.push(register)` vs register'da `context.go(login)`
  - **Sorun:** Login→Register `push` (geri swipe mümkün); Register→Login `go` (stack sıfırlanır). Android predictive back davranışı tutarsız.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `InputDecoration` kısmen const — suffix `IconButton` her build'de yeni instance
  - **Sorun:** Şifre toggle `setState` ile tüm form subtree rebuild; büyük sorun değil ama `IconButton` `tooltip`/`semanticLabel` eksik (erişilebilirlik).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `Theme.of(context)` tekrarlı çağrılar — gereksiz ancestor lookup
  - **Sorun:** Gradient `build` içinde 2×, text style 3× `Theme.of(context)`; login tek ekran ama pattern kopyalanırsa jank.
  - **Çözüm:** @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final textTheme = theme.textTheme;
  // tek lookup, aşağıda colorScheme.sur
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `deviceId: 'flutter-mobile'` hardcoded — satır 38
  - **Sorun:** Çoklu cihaz oturum yönetimi / fraud analitiği için anlamsız sabit; web/desktop build'lerde de aynı ID.
  - **Çözüm:** import 'package:device_info_plus/device_info_plus.dart';
// veya uuid persisted in secure storage
deviceId: await DeviceIdentityService.currentId(),
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · UI/UX]** Auth akış tutarsızlığı — Login vs Register görsel hiyerarşi
  - **Sorun:** Login: gradient arka plan + `Card` (16px radius, `borderDefault` stroke) + ikonlu input + tam genişlik CTA. Register: düz scaffold, kart yok, ikon yok, dar buton. Aynı auth funnel'de iki farklı ürün hissi.
  - **Çözüm:** `AuthFormShell` shared widget: gradient + Card + `maxWidth: 460` + `SafeArea` + `SingleChildScrollView`.
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · UI/UX]** Dikey spacing — 8pt grid ihlali
  - **Sorun:** Kart padding `EdgeInsets.all(20)` (`AppSpacing.lg`) kullanılıyor ancak iç boşluklar karışık: başlık-altı `6px` (grid dışı), alanlar arası `12px` (`AppSpacing.md`), CTA öncesi `18px` (grid dışı), footer `8px` (`AppSpacing.sm`). Ekran görüntüsünde şifre alanı ile altın buton arası (~18px) e-posta-şifre arasından (~12px) geniş — görsel ritim bozuk.
  - **Çözüm:** Tüm gap'leri `AppSpacing` token'larına sabitle: `sm(8)` label gap, `base(16)` field gap, `lg(20)` CTA öncesi.
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · UI/UX]** Metin içerikleri — Türkçe karakter eksikliği (i18n)
  - **Sorun:** UI'da ASCII Türkçe kullanılıyor: "Hesabina", "giris", "Sifre", "Giris Yap", "Giris yapiliyor", "Hesabin yok mu? Kayit Ol". Doğrusu: "Hesabına", "giriş", "Şifre", "Giriş Yap", "Giriş yapılıyor...", "Hesabın yok mu? Kayıt Ol". Urbanist font Türkçe glyph destekliyor; sorun kaynak string'lerde.
  - **Çözüm:** Tüm auth string'lerini `lib/l10n/` veya `AppStrings` sabitlerine taşı; `flutter gen-l10n` ile TR locale zorunlu kıl.
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · UI/UX]** Yükleme durumu — `FilledButton.icon` içi spinner
  - **Sorun:** `isLoading` true iken buton içinde `CircularProgressIndicator(strokeWidth: 2)` — `valueColor` belirtilmemiş. Tema `progressIndicatorTheme.color = accentBlue` (#5B8FFF); altın buton (#F5C842) üzerinde mavi spinner + siyah metin "Giris yapiliyor..." — renk uyumsuzluğu ve düşük kontrast (mavi/altın ~2.8:1).
  - **Çözüm:** `CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDeep)` veya `onPrimary` token kullan; ikon yerine sadece spinner + metin hizası `MainAxisAlignment.center`.
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

- [ ] **[P2 · UI/UX]** `TextFormField` — autofill / klavye tipi eksikleri
  - **Sorun:** E-posta alanında `autofillHints: [AutofillHints.email]` yok; şifrede `AutofillHints.password` yok. iOS Password AutoFill ve Android Credential Manager tetiklenmez.
  - **Çözüm:** `autofillHints`, `autocorrect: false`, şifre alanında `enableSuggestions: false` ekle.
  - **Kaynak rapor:** [login.md](reports/audits/audit_2026-06-27/login.md)
  - **Hedef dosya:** `lib/screens/auth/login_screen.dart`

### loot — [loot.md](reports/audits/audit_2026-06-27/loot.md)
**Kaynak kod:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P0 · Kod/Refaktör]** Theme index vs box id
  - **Sorun:** `resolveLootChestTheme(boxIndex, ...)` — DB sırası değişince tema/kasa eşleşmesi kayar.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P0 · Kod/Refaktör]** `GoogleFonts.urbanist` — fullscreen only
  - **Sorun:** Satır 1027 loot open page; tema `AppTextStyles` bypass.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P0 · Kod/Refaktör]** `loot_hub_screen.dart` + fullscreen page — ~1500 satır tek dosya
  - **Sorun:** Hub + reel animasyon + spin math bir arada.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P0 · UI/UX]** Chest art overflow — kasıtlı ama küçük ekran
  - **Sorun:** `LootChestBanner` illustration card sınırını aşıyor (screenshot); iPhone SE'de başlık/fiyat overlap riski.
  - **Çözüm:** `LayoutBuilder` — dar ekranda art küçült.
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P0 · UI/UX]** Stat chip yatay scroll — clipping QA
  - **Sorun:** `LootChestBanner` footer `SingleChildScrollView` horizontal (satır 540-559); screenshot **Cadı Kasası** ve **Uzay Kasası**'nda üçüncü chip `'Carp.'` truncated — `Carpan: x1.00` tam görünmüyor.
  - **Çözüm:** `Wrap` veya 2 satır chip; min width garanti.
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Reel randomization — görsel bait
  - **Sorun:** `_buildRandomizedReel` komşu slotlara legendary equipment koyar (satır 834-879) — sonuç zaten belli (`targetIndex`); yanıltıcı "near miss" psikolojisi.
  - **Çözüm:** // veya disclaimer "animasyon temsilidir"
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_rowsFromRpc` — payload shape karmaşık
  - **Sorun:** Map/list dual parse (satır 101-112) — silent empty.
  - **Çözüm:** ```
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P2 · UI/UX]** Drop preview — lazy load friction
  - **Sorun:** Drop listesi varsayılan gizli; `'Goster\'a dokun'` (satır 715). 317 item kasada preview boş — oyuncu odds görmeden açabilir.
  - **Çözüm:** İlk expand otomatik veya banner altında top-5 drop.
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P2 · UI/UX]** Kasa açılış — 9 sn spin, kapatma kilitli
  - **Sorun:** `_totalSpinMs = 9000` (satır 789); close button `_finished ? pop : null` (satır 1050-1052). UX uzun; app switch during spin state belirsiz.
  - **Çözüm:** Skip animasyon (settings); max 4-5 sn.
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

- [ ] **[P2 · UI/UX]** Lokalizasyon — EN/TR karışımı
  - **Sorun:** `'Drop Preview'` (satır 610), `'Kasa Acma'` title (satır 448), `'Goster'` (satır 623 — **Göster** olmalı), `'Aciliyor...'`, `'Carpan'` badge screenshot'ta **kesilmiş** (horizontal scroll clip).
  - **Çözüm:** `AppStrings.loot.*`; `'Önizleme'`, `'Göster'`, `'Çarpan'`.
  - **Kaynak rapor:** [loot.md](reports/audits/audit_2026-06-27/loot.md)
  - **Hedef dosya:** `lib/screens/loot/loot_hub_screen.dart`

### market — [market.md](reports/audits/audit_2026-06-27/market.md)
**Kaynak kod:** `lib/screens/market/market_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** Inline `TextStyle` başlık
  - **Sorun:** `AppTextStyles` bypass (83–86).
  - **Çözüm:** style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
  - **Kaynak rapor:** [market.md](reports/audits/audit_2026-06-27/market.md)
  - **Hedef dosya:** `lib/screens/market/market_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Refresh yok
  - **Sorun:** `_loadInitial` yalnızca post-frame (30–39).
  - **Çözüm:** RefreshIndicator(onRefresh: _loadInitial, child: ...)
  - **Kaynak rapor:** [market.md](reports/audits/audit_2026-06-27/market.md)
  - **Hedef dosya:** `lib/screens/market/market_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Tab değişiminde her seferinde reload
  - **Sorun:** `_onTabChanged` browse/myMarket'te her tap `loadTickers`/`loadMyOrders` (42–50).
  - **Çözüm:** if (!ref.read(marketProvider).tickersLoaded) {
  ref.read(marketProvider.notifier).loadTickers();
}
  - **Kaynak rapor:** [market.md](reports/audits/audit_2026-06-27/market.md)
  - **Hedef dosya:** `lib/screens/market/market_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `ListView` shell — tab body için anti-pattern
  - **Sorun:** Tüm tab içeriği ListView child; unbounded height riski (75–114).
  - **Çözüm:** body: Column(
  children: [
    _MarketHeader(...),
    MarketTabBar(...),
    Expanded(child: switch (_tab) { ... }),
  ],
)
  - **Kaynak rapor:** [market.md](reports/audits/audit_2026-06-27/market.md)
  - **Hedef dosya:** `lib/screens/market/market_screen.dart`

- [ ] **[P2 · UI/UX]** ASCII Türkçe — başlık ve filtreler
  - **Sorun:** `Oyuncu Pazari` (82) → `ı` eksik; tab `Gozat`, sıralama `Ucuz`/`Pahali`, `Tum Kategoriler`, `Tum Nadirlik`, `Sonuc yok` — screenshot'ta doğrulandı.
  - **Çözüm:** `Oyuncu Pazarı`, `Gözat`, `Tüm Kategoriler`, `Sonuç yok`.
  - **Kaynak rapor:** [market.md](reports/audits/audit_2026-06-27/market.md)
  - **Hedef dosya:** `lib/screens/market/market_screen.dart`

- [ ] **[P2 · UI/UX]** Boş pazar — `Sonuc yok`
  - **Sorun:** Screenshot'ta Gözat sekmesi filtreler açık, liste boş; yalnızca gri `Sonuc yok` metni. Neden boş (gerçekten işlem yok / filtre / API) belirtilmiyor.
  - **Çözüm:** Empty state: `Henüz ilan yok` + `İlk sen sat` → Sat sekmesi.
  - **Kaynak rapor:** [market.md](reports/audits/audit_2026-06-27/market.md)
  - **Hedef dosya:** `lib/screens/market/market_screen.dart`

- [ ] **[P2 · UI/UX]** Nested scroll riski
  - **Sorun:** Shell `ListView` içinde `MarketBrowseTab` kendi scroll'unu yönetebilir; çift scroll veya shrinkWrap performans sorunu.
  - **Çözüm:** Shell `Column` + `Expanded(child: tab)`; tab içi tek scroll owner.
  - **Kaynak rapor:** [market.md](reports/audits/audit_2026-06-27/market.md)
  - **Hedef dosya:** `lib/screens/market/market_screen.dart`

- [ ] **[P2 · UI/UX]** Olumlu — tema uyumu
  - **Sorun:** Shell `AppColors.bgDeep` / `bgBase` gradient kullanıyor (68–73) — bu audit grubunda en tutarlı arka plan.
  - **Çözüm:** Diğer menü ekranlarına aynı pattern yay.
  - **Kaynak rapor:** [market.md](reports/audits/audit_2026-06-27/market.md)
  - **Hedef dosya:** `lib/screens/market/market_screen.dart`

### mekan_arena — [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
**Kaynak kod:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** 518 satır tek dosya
  - **Sorun:** Bet sheet, rank row, fighter card inline.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** PvP refresh — üç provider
  - **Sorun:** `_fight` sonrası player + pvpDashboard + pvpHistory load (satır 87-89); arena-only fight için ağır.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_RankRow` weekly reward format
  - **Sorun:** Manual K/M (satır 418-420); `formatMekanGold` ile tutarsız.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_fight` — sheet kapanma race
  - **Sorun:** `_BetSheet` `onFight` await sonra `Navigator.pop` (satır 508-511); dialog `_showResult` üst üste.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_load` — silent catch
  - **Sorun:** `catch (_) { setState loading false }` (satır 58-60); hata UI yok.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `mekanId` — sadece RPC param
  - **Sorun:** Ekran `widget.mekanId` kullanıyor; mekan kapalı/raid kontrolü yok (detail'de vardı).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · UI/UX]** Bahis sheet — wager UI
  - **Sorun:** Preset 10K–5M (satır 440); düşük level oyuncu çoğu gri disabled — OK. Custom wager yok.
  - **Çözüm:** Slider veya custom input.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · UI/UX]** Rakip listesi — qa_bot flood (Screenshot QA)
  - **Sorun:** Screenshot tüm kartlar `qa_bot_XXXX`; gerçek oyuncu yok. `_FighterCard` avatar tek harf (satır 327-329).
  - **Çözüm:** Prod'da bot filtrele veya `BOT` badge; smoke-only seed.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · UI/UX]** Rakip yok empty — iyi tasarım
  - **Sorun:** `_opponents.isEmpty` → `MekanEmpty` (satır 240-250); screenshot'ta dolu liste, empty QA yok.
  - **Çözüm:** Koru.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · UI/UX]** Sonuç dialog — hastane CTA yok
  - **Sorun:** `hospital` → `GlowChip` (satır 138-141); hastaneye git linki yok (dungeon battle'daki gibi).
  - **Çözüm:** `Hastaneye Git` butonu.
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

- [ ] **[P2 · UI/UX]** Sıralama tab — empty QA
  - **Sorun:** Screenshot Dövüş tab aktif, bot listesi dolu; Sıralama tab screenshot'ta doğrulanmadı. Kod empty: `'Henuz arena sıralamasi olusmadi.'` (satır 279-283) — ASCII ı.
  - **Çözüm:** `'Henüz arena sıralaması oluşmadı.'`
  - **Kaynak rapor:** [mekan_arena.md](reports/audits/audit_2026-06-27/mekan_arena.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_arena_screen.dart`

### mekan_create — [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
**Kaynak kod:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Create sonrası mekan list invalidate yok
  - **Sorun:** `mekanRepository.createMekan` sonra yalnızca profile reload (satır 55-59).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `MekanTypeInfo.all` — static catalog
  - **Sorun:** Server-side unlock ile drift.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_TypeArtCard` — aynı dosyada 115 satır
  - **Sorun:** Reuse `mekans_screen` ile paylaşılmıyor.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_busy` — catch'te reset
  - **Sorun:** Başarıda `go(myMekan)` öncesi `_busy` true kalır (satır 53-66); route değişince sorun yok ama hata path'te reset var.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `canCreate` — rebuild on name only
  - **Sorun:** `onChanged: (_) => setState` (satır 112); gold/level provider değişince button state güncellenir (watch var) — OK.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · UI/UX]** Başlık — tamamen büyük harf
  - **Sorun:** `'IMPARATORLUGUNU KUR'` (satır 94); Türkçe'de `İMPARATORLUĞUNU KUR`.
  - **Çözüm:** Doğru Unicode veya sentence case.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · UI/UX]** Kilitli türler — tıklanamaz ama neden belirsiz
  - **Sorun:** `locked` → `onTap: null` (satır 148); kırmızı chip level/gold gösteriyor ama tek satır açıklama yok.
  - **Çözüm:** Locked tap → `AppMessenger` ile eksik şart.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · UI/UX]** Sohbet FAB — kart overlap (Screenshot QA)
  - **Sorun:** Screenshot'ta FAB Kahvehane kartının üzerine bindiriyor; scroll padding bottom yetersiz.
  - **Çözüm:** `ListView` `padding.bottom: gameBottomContentInset(context)`.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · UI/UX]** Sticky footer CTA — seçim yokken pasif
  - **Sorun:** `canCreate` false iken `NeonButton` disabled, label `'Tur Sec'` (satır 161-166); ad girilse bile tür şart.
  - **Çözüm:** En az bir erişilebilir starter tür (düşük level) veya demo unlock.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

- [ ] **[P2 · UI/UX]** Türkçe karakter — ASCII mesajlar
  - **Sorun:** `_create()` snackbar: `'Once bir tur sec'`, `'Mekan adi gerekli'` (satır 34-38); UI label `'Mekan adi'` (satır 114) — ı/ş/ö yok.
  - **Çözüm:** `'Önce bir tür seç'`, `'Mekan adı gerekli'`, `l10n` ARB.
  - **Kaynak rapor:** [mekan_create.md](reports/audits/audit_2026-06-27/mekan_create.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_create_screen.dart`

### mekan_detail — [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
**Kaynak kod:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Contraband hardcoded ids
  - **Sorun:** `han_item_berserk` / `han_item_shadow_brew` (satır 198); data-driven olmalı.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Local `_mekan` / `_stock` state
  - **Sorun:** Her ekran instance kendi cache (satır 25-27).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Police raid — sadece snackbar
  - **Sorun:** `police_raid == true` (satır 103-104); UI banner yok, `_load` sonrası raid banner header'da var.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Route string hardcoded
  - **Sorun:** `context.go('/mekans/${mekan.id}/arena')` (satır 316); `AppRoutes` helper yok.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `CustomScrollView` + `SliverFillRemaining` empty
  - **Sorun:** Empty vitrin scroll bounce OK; owner dolu grid QA eksik.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_buy` — double inventory load
  - **Sorun:** `loadInventory` satır 90 ve 101; gereksiz RPC.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Başlık — lowercase tipografi
  - **Sorun:** Screenshot mekan adı `selcuk barı` — kullanıcı girişi; `maxLines: 2` (satır 252-256) OK.
  - **Çözüm:** Display name trim + profanity filter (server).
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Buy sheet — busy sonrası pop
  - **Sorun:** `_BuySheet` `_busy` set, `onConfirm` await, sonra `Navigator.pop` (satır 412-415); hata olsa da sheet kapanabilir.
  - **Çözüm:** Yalnızca success'te pop.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Hata yükleme — silent catch
  - **Sorun:** `_load` `catch (_) {}` (satır 52-58); hata mesajı yok, sadece loading false.
  - **Çözüm:** Error state: "Yüklenemedi" + retry.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Owner vs visitor — PvP CTA
  - **Sorun:** Owner → `Mekani Yonet` (satır 304-309); visitor + PvP → Arena. Screenshot owner değil (Arena yok) — stok boş bar vitrin.
  - **Çözüm:** PvP destekli türlerde visitor'a da arena linki header'da.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · UI/UX]** Vitrin boş — empty state iyi (Screenshot QA)
  - **Sorun:** Screenshot `0 urun satista`, `Vitrin bos` + açıklama (satır 166-175); empty state tasarımı güçlü.
  - **Çözüm:** Ziyaretçiye "Başka mekanlara göz at" linki ekle.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

- [ ] **[P2 · UI/UX]** `sohret` — ASCII
  - **Sorun:** `'${mekan.fame} sohret'` (satır 273); `şöhret` olmalı.
  - **Çözüm:** l10n düzelt.
  - **Kaynak rapor:** [mekan_detail.md](reports/audits/audit_2026-06-27/mekan_detail.md)
  - **Hedef dosya:** `lib/screens/mekans/mekan_detail_screen.dart`

### mekans — [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
**Kaynak kod:** `lib/screens/mekans/mekans_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** Local state — provider bypass
  - **Sorun:** `_mekans`, `_leaderboard`, `_loading` ekranda (`mekans_screen.dart` 20–24); `mekanRepositoryProvider` doğrudan `ref.read` init'te.
  - **Çözüm:** @riverpod
class MekansHub extends _$MekansHub {
  Future<MekansHubState> build() => ref.watch(mekanRepositoryProvider).fetchHub();
}
  - **Kaynak rapor:** [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
  - **Hedef dosya:** `lib/screens/mekans/mekans_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Leaderboard RPC — silent catch
  - **Sorun:** `fetchFameLeaderboard` catch empty (satır 42–46); RPC yoksa UI fark etmez — screenshot'ta leaderboard var ama prod'da sessiz kaybolur.
  - **Çözüm:** if (lb.isEmpty && kDebugMode) showBanner('Leaderboard RPC unavailable');
  - **Kaynak rapor:** [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
  - **Hedef dosya:** `lib/screens/mekans/mekans_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Navigation — raw string path
  - **Sorun:** `context.go('/mekans/${m.id}')` (satır 123, 228); `AppRoutes` sabiti yok.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
  - **Hedef dosya:** `lib/screens/mekans/mekans_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_filter` — client-side only
  - **Sorun:** Tüm mekanlar fetch → filter local; liste büyüyünce performans.
  - **Çözüm:** repo.fetchMekans(typeKey: _filter == 'all' ? null : _filter);
  - **Kaynak rapor:** [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
  - **Hedef dosya:** `lib/screens/mekans/mekans_screen.dart`

- [ ] **[P2 · UI/UX]** Filter bar — yatay scroll affordance
  - **Sorun:** `ListView` horizontal 6 chip, sağ padding `14` (`mekans_screen.dart` 247–283). "Yeraltı" kısmen görünür; scroll ipucu yok.
  - **Çözüm:** Fade edge gradient; veya `TabBar` scrollable.
  - **Kaynak rapor:** [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
  - **Hedef dosya:** `lib/screens/mekans/mekans_screen.dart`

- [ ] **[P2 · UI/UX]** Hero panel — viewport domine
  - **Sorun:** `_hero` + `_ctaRow` + leaderboard + filter ≈ 380pt (`mekans_screen.dart` 133–285). Screenshot'ta mekan listesi fold altında; ilk bakışta yalnızca marketing metni.
  - **Çözüm:** Collapsible hero; leaderboard ayrı tab veya swipe.
  - **Kaynak rapor:** [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
  - **Hedef dosya:** `lib/screens/mekans/mekans_screen.dart`

- [ ] **[P2 · UI/UX]** Leaderboard — owner adı truncation
  - **Sorun:** `_LeaderRow` subtitle `mekanTypeLabelKey - ownerName` `maxLines: 1` (satır 328–332). Uzun owner + tip ellipsis.
  - **Çözüm:** İki satır veya owner `@handle` kısaltma.
  - **Kaynak rapor:** [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
  - **Hedef dosya:** `lib/screens/mekans/mekans_screen.dart`

- [ ] **[P2 · UI/UX]** Türkçe diakritik eksikliği — kullanıcı metinleri
  - **Sorun:** `'$openCount acik'`, filter `'Tumu'`, `'Dovus'`, `'Lux'`, `'Yeralti'`, empty `'Yuklenemedi'`, `'acik mekan bulunamadi'` (satır 94–106, 173, 239–245). Screenshot'ta "2 acik", "Tumu" chip görünür.
  - **Çözüm:** `'açık'`, `'Tümü'`, `'Dövüş'`, `'Lüks'`, `'Yeraltı'`, `'Yüklenemedi'`.
  - **Kaynak rapor:** [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
  - **Hedef dosya:** `lib/screens/mekans/mekans_screen.dart`

- [ ] **[P2 · UI/UX]** `NeonButton` "Mekan Ac" — glow + altın
  - **Sorun:** Sağ CTA solid gold + outer glow (`mekans_screen.dart` 199–206); sol "Benim Mekanim" outline. FAB Sohbet sağ alt ile görsel rekabet.
  - **Çözüm:** Tek primary CTA; chat FAB mekan temasında küçült.
  - **Kaynak rapor:** [mekans.md](reports/audits/audit_2026-06-27/mekans.md)
  - **Hedef dosya:** `lib/screens/mekans/mekans_screen.dart`

### my_mekan — [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
**Kaynak kod:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** 880 satır monolith
  - **Sorun:** Tab'ler, stock sheet, upgrade aynı dosya; test zor.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Local state — `_mekan`, `_stock`, `_inventory`
  - **Sorun:** Provider pattern yok (satır 24-27); her tab `_load` duplicate.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `HappyHourBanner` — `DateTime.parse` crash risk
  - **Sorun:** `mekan.happyHourUntil!` (satır 285); invalid ISO → build fail.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_StockSheet` — `DropdownButtonFormField` initialValue
  - **Sorun:** Flutter 3.16+ `initialValue` deprecated pattern; state sync risk (satır 779-793).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_run` busy — global lock
  - **Sorun:** `_busy` tüm butonları kilitler (satır 84-96); toggle + happy hour aynı anda yapılamaz.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · UI/UX]** Copy — ASCII Türkçe
  - **Sorun:** `'Mekanin yok'`, `'Han ticareti icin once bir mekan ac.'`, tab `'Istatistik'`, `'Yukseltme'` (satır 111-137).
  - **Çözüm:** `Mekanın yok`, `İstatistik`, `Yükseltme` + ARB.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · UI/UX]** Empty state — iyi ama nav yanlış (Screenshot QA)
  - **Sorun:** Screenshot `Mekanin yok` + `Mekan Ac` CTA (satır 109-118) — empty state kaliteli; ancak Home bottom bar aktif.
  - **Çözüm:** Mekan rotaları Menü highlight.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · UI/UX]** Gelir formatı — binlik ayırıcı yok
  - **Sorun:** `'$revenue'` raw int (satır 184-187); `formatMekanGold` kullanılmıyor header'da.
  - **Çözüm:** `formatMekanGold(revenue)`.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · UI/UX]** PvP Arena butonu — kapalı mekanda disabled
  - **Sorun:** `onPressed: mekan.isOpen ? ... : null` (satır 303); disabled görsel ipucu zayıf.
  - **Çözüm:** Tooltip "Önce mekanı aç".
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · UI/UX]** Screenshot QA — empty vs dolu
  - **Sorun:** QA hesabında mekan yok; 4 tab, vault, stok yönetimi screenshot'ta doğrulanmadı.
  - **Çözüm:** Smoke fixture: mekan sahibi hesap + dolu stok screenshot.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · UI/UX]** Stats tab — null empty
  - **Sorun:** `_stats == null` → `'Istatistik yok'` (satır 431-436); RPC optional catch (satır 64-66).
  - **Çözüm:** Partial stats from `Mekan` model fallback.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

- [ ] **[P2 · UI/UX]** `THE VAULT` — İngilizce başlık
  - **Sorun:** `_vaultHeader` `'THE VAULT'` (satır 172-173); gelir metni Türkçe.
  - **Çözüm:** `KASA` veya `Hazine`.
  - **Kaynak rapor:** [my_mekan.md](reports/audits/audit_2026-06-27/my_mekan.md)
  - **Hedef dosya:** `lib/screens/mekans/my_mekan_screen.dart`

### onboarding_character_select — [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
**Kaynak kod:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** `_loadClasses` hata yutma — boş catch, sessiz fallback
  - **Sorun:** RPC exception'da `_error` set edilir ama `_classes` default liste kalır; `_loadingClasses false` ile kullanıcı fark etmeden stale data görür. `success == false` durumunda `return` ile `_error` set edilmez.
  - **Çözüm:** if (!success || classes == null || classes.isEmpty) {
  if (mounted) setState(() => _error = 'Sınıf listesi boş.');
  return;
}
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Monolitik 818 satır tek dosya — UI/logic/RPC karışık
  - **Sorun:** Test edilebilirlik düşük; `_CharacterClassOption` private, widget test yazılamaz.
  - **Çözüm:** // character_select_screen.dart — state + navigation
// widgets/character_stage.dart, widgets/class_carousel.dart
// data/character_class_catalog.dart
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Sunucu yanıtı başarı mantığı ters/ gevşek — satır 198
  - **Sorun:** `response['success'] != false` → `null` veya eksik `success` alanı **başarı** sayılır; RPC hata döndürse bile `persisted = true` olabilir, profil güncellenmeden home'a gidilir.
  - **Çözüm:** if (response is Map<String, dynamic> && response['success'] == true) {
  persisted = true;
}
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Sınıf tanımları üçlü tekrar — `_classes`, `presentationMap`, `iconMap`
  - **Sorun:** Yeni sınıf eklemek 3 yeri güncellemeyi gerektirir; drift riski (RPC'den gelen id `presentationMap`'te yoksa fallback `savasci.png`).
  - **Çözüm:** const _kClassCatalog = <String, CharacterClassPresentation>{
  'warrior': CharacterClassPresentation(...),
};
// _loadClasses yalnızca name_tr/description_tr merge eder
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `Hero(tag: 'character-card-${activeClass.id}')` — home `HeroShowcase` ile tag çakışma riski
  - **Sorun:** Home'a `context.go` sonrası aynı tag'li Hero flight exception veya görsel glitch (debug'da turuncu çizgi uyarısı).
  - **Çözüm:** Hero(tag: 'onboarding-character-${activeClass.id}', ...)
// veya onboarding'de Hero kullanma — go() zaten stack sıfırlar
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `build()` her frame'de `_activeClass` + tam `Stack` rebuild — glow `AnimatedBuilder` tüm stage'i sarmalıyor
  - **Sorun:** `_glowController.repeat` 2.2s döngüde sürekli repaint; 3× `BoxShadow` + `ShaderMask` + `Hero` — orta segment cihazlarda onboarding jank.
  - **Çözüm:** RepaintBoundary(
  child: AnimatedBuilder(
    animation: _glowAnimation,
    builder: (_, __) => _GlowBorder(activeClass: activeClass, t: t),
    child: _CharacterArtwork(activeClass: activeClass), /
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · UI/UX]** Alt panel — dikey alan baskısı (küçük ekran)
  - **Sorun:** `_buildBottomSheet` sabit yükseklikler: yatay `ListView` `height: 156`, iç padding `18+18`, `Operasyon Özeti` kutusu + CTA `150px` genişlikte buton. `Column` içinde `Expanded` hero stage ile birlikte iPhone SE (~667pt) SafeArea sonrası alt panel ~280pt — carousel + özet + CTA sıkışır; ekran görüntüsü olmasa da kod layout'u scroll'suz.
  - **Çözüm:** Alt paneli `DraggableScrollableSheet` veya `SingleChildScrollView` yap; carousel yüksekliğini `compact ? 120 : 156` dinamikle.
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · UI/UX]** Başlık alt metinleri — Türkçe/İngilizce dil karışımı
  - **Sorun:** Sınıf adları Türkçe (`Savaşçı`, `Simyacı`, `Gölge`) ancak `titleLine` İngilizce sabit: `Frontline Dominator`, `Arcane Field Engineer`, `Precision Elimination`. `traitSummary` de İngilizce kısaltma: `STR / DEF / AGG`, `INT / CTRL / SUP`, `DEX / SPD / BURST`. Üst etiket `GKK // CHARACTER SELECT` tamamen İngilizce.
  - **Çözüm:** `titleLine_tr` / `traitSummary_tr` alanları Supabase RPC'den veya `AppStrings.characterSelect.*` sabitlerinden gelsin; header `GKK // KARAKTER SEÇİMİ`.
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · UI/UX]** Birincil CTA — `Maceraya Başla` kontrastı sınıfa göre değişken
  - **Sorun:** `FilledButton` `backgroundColor: activeClass.accentColor`, `foregroundColor: Colors.black`. Simyacı `#63D1C5` (teal) üzerinde siyah metin ~7:1 iyi; Gölge `#8E93FF` (lavanta) üzerinde siyah ~5.5:1 sınırda. Spinner `_submitting` durumunda siyah `CircularProgressIndicator` teal/lavanta üzerinde düşük kontrast.
  - **Çözüm:** CTA için sabit `AppColors.gold` arka plan + `AppColors.bgDeep` metin; sınıf rengi yalnızca border/glow'da kalsın.
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · UI/UX]** Ekran görüntüsü otomasyonu — yanlış katman yakalanmış
  - **Sorun:** Manifest slug `onboarding_character_select` olmasına rağmen PNG tam ekran daily-reward dialogu. Arka planda onboarding ekranı hiç doğrulanmıyor; regresyon (CTA rengi, carousel scroll, seçili border) kaçırılır.
  - **Çözüm:** Screenshot öncesi `dailyRewardProvider` mock (`canClaim: false`) veya dialog `Navigator.pop` + `pumpAndSettle`; character-select rotasına **doğrudan deep link** ile git (home üzerinden değil).
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · UI/UX]** Spacing — 8pt grid ihlali
  - **Sorun:** Padding `18`, `22`, `10`, `6`, `14`, `16` karışık; `AppSpacing` (`sm=8`, `base=16`, `lg=20`) kullanılmıyor. Header altı `SizedBox(height: 18)` grid dışı.
  - **Çözüm:** Tüm gap'leri `AppSpacing` token'larına sabitle.
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · UI/UX]** Tema sistemi dışı renk/token kullanımı
  - **Sorun:** `Scaffold` arka plan `#08090C`, header altın `#D9AE57`, kart gradyanları `#15171B` / `#0E1014` — hiçbiri `AppColors.bgDeep` (#0F1523), `AppColors.gold` (#F5C842) veya `AppTextStyles` ile hizalı değil. Login/Register `Card` + Urbanist temasından görsel kopuş.
  - **Çözüm:** `accentColor` sınıf renkleri `AppColors` türevleri; metinler `AppTextStyles.h1/h3/caption`; arka plan `AppColors.bgBase` gradient.
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

- [ ] **[P2 · UI/UX]** Yatay sınıf kartları — erişilebilirlik ve seçim geri bildirimi
  - **Sorun:** `GestureDetector` + `AnimatedContainer`; `Semantics`/`selected` state yok. Seçili kart yalnızca border rengi (`selected ? cls.accentColor : white12`) — ekran okuyucuda "seçili" duyurulmaz. Kart genişliği sabit `188px`; 3 sınıfta 2. kart kısmen viewport dışında kalabilir (scroll ipucu yok).
  - **Çözüm:** `Semantics(selected: selected, label: cls.name, button: true)`; listenin sağına gradient fade + "kaydır" ipucu veya `PageView` ile sayfa göstergesi.
  - **Kaynak rapor:** [onboarding_character_select.md](reports/audits/audit_2026-06-27/onboarding_character_select.md)
  - **Hedef dosya:** `lib/screens/auth/character_select_screen.dart`

### prison — [prison.md](reports/audits/audit_2026-06-27/prison.md)
**Kaynak kod:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P1 · UI/UX]** Kaçış/başarı — `showError` her durumda
  - **Sorun:** `_attemptEscape` `AppMessenger.showError` (satır 154–155); `success` unused. Hospital ile aynı bug.
  - **Çözüm:** `showSuccess` / `showError` branch.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Duplicate restriction screen
  - **Sorun:** Prison 418 satır, hospital 546 satır — timer/escape/bail ortak.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `DateTime.tryParse(prisonUntil)` — timezone blind
  - **Sorun:** Hospital `_parseRestrictionUntil` ile tutarsız (`prison_screen.dart` 58, 82); UTC suffix olmayan DB değerleri erken/ geç serbest bırakır.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_freed` local flag — provider sync
  - **Sorun:** `_payBail` / escape sonrası `_freed = true` (satır 121, 161); profile reload gecikirse `_inPrison` false olur ama başka ekran hâlâ prison gösterir.
  - **Çözüm:** bool get _inPrison => profile?.isInPrison ?? false;
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_payBail` — yetersiz gem pre-check yok
  - **Sorun:** Dialog onay → RPC fail; hospital gem dialog shop yönlendirmesi var, prison yok.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `rawResponse as Map` — unsafe
  - **Sorun:** Escape RPC cast (satır 144); type error → boş map → generic message.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · UI/UX]** Gerekçe metni — facilities ile duplicate
  - **Sorun:** Prison `prisonReason`; facilities kartı aynı metni gösterir (`facilities_screen.dart` 141–156). İki yerde farklı stil — sync riski.
  - **Çözüm:** `PrisonStatusBanner` shared widget.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · UI/UX]** Geri sayım — saat yok
  - **Sorun:** `_formatCountdown` yalnızca `MM:SS` (satır 179–182); >60dk hapis `90:00` gibi okunmaz. Hospital `Xh Ym` formatı.
  - **Çözüm:** `Duration` adaptive format shared helper.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · UI/UX]** Kefalet butonu — disabled gri belirsiz
  - **Sorun:** `!canAfford` → `backgroundColor: Colors.grey` (satır 347–349); yetersiz gem alt metin 12px kırmızı. Aktif turuncu buton tıklanamaz görünebilir.
  - **Çözüm:** Disabled + link "Elmas satın al"; `AppRoutes.shop` deep link.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · UI/UX]** Özgür state — CTA eksik
  - **Sorun:** `_buildFree` yalnızca metin; `Ana Sayfaya Dön` butonu yok (`prison_screen.dart` 233–267). Hospital healthy state'te buton var — tutarsız.
  - **Çözüm:** Hospital ile aynı primary CTA; veya otomatik `context.go(home)` bilgi banner.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

- [ ] **[P2 · UI/UX]** Özgür state — thumbs up + cezaevi cognitive dissonance
  - **Sorun:** 👍 emoji + "Cezaevi" başlık + yeşil "Şu anda özgürsünüz!" (`prison_screen.dart` 244–257). Emoji kutlama; bağlam cezaevi.
  - **Çözüm:** 🕊️ veya muhafız ikonu; emoji kaldır.
  - **Kaynak rapor:** [prison.md](reports/audits/audit_2026-06-27/prison.md)
  - **Hedef dosya:** `lib/screens/prison/prison_screen.dart`

### pvp — [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
**Kaynak kod:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Hardcoded arena rotası
  - **Sorun:** `context.go('/mekans/${arena.id}/arena')` (satır ~221); router refactor'da kırılır.
  - **Çözüm:** context.go(AppRoutes.mekanArena(arena.id));
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Inline `_card` / `_StatChip` private helpers
  - **Sorun:** 550 satırlık screen; yeniden kullanım yok (satır 263+).
  - **Çözüm:** // widgets/pvp_stats_card.dart, widgets/pvp_arena_tile.dart
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_StatChip` × 5 tek `Row` içinde `Expanded`
  - **Sorun:** Dar ekranda `0.0%` / `1100` metin sıkışması (satır 124–133).
  - **Çözüm:** Wrap(spacing: 8, runSpacing: 8, children: statChips)
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_isRestricted` basit `DateTime.tryParse`
  - **Sorun:** UTC/timezone drift; dungeon'daki `_parseRestrictionUntil` ile duplicate logic (satır 40–44).
  - **Çözüm:** bool isActiveRestriction(String? raw) => parseRestrictionUntil(raw)?.isAfter(DateTime.now()) ?? false;
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `initState` + `activate` çift yükleme
  - **Sorun:** Her route geri dönüşünde `loadProfile` + `pvpDashboardProvider.load()` tekrar (satır 23–37).
  - **Çözüm:** ```
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · UI/UX]** Arena kartı — düşük bilgi yoğunluğu
  - **Sorun:** Screenshot'ta tek arena `test` / `Dövüş Kulübü`; oyuncu sayısı, seviye, giriş ücreti yok. CTA `Arenaya Git` tek aksiyon.
  - **Çözüm:** `onlineCount`, `minLevel`, `entryFee` badge'leri; boş isim filtrele.
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · UI/UX]** Hardcoded gradient arka plan
  - **Sorun:** `Color(0xFF10131D)` / `0xFF171E2C` (105–109); `AppColors.bgDeep` kullanılmıyor.
  - **Çözüm:** `AppColors` gradient sabiti.
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · UI/UX]** Hastane/hapis banner — statik metin
  - **Sorun:** `_isRestricted` boolean; geri sayım yok (dungeon'daki canlı strip ile tutarsız).
  - **Çözüm:** Paylaşılan `RestrictionCountdownBanner` widget.
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · UI/UX]** `Son Maçlar` — boş state
  - **Sorun:** `Henüz maç yok.` düz metin; CTA yok (`Geçmişi Aç` üstte ayrı).
  - **Çözüm:** Empty state illustration + `İlk düellonu başlat` → arena listesi.
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

- [ ] **[P2 · UI/UX]** İstatistik grid — `Rating` İngilizce
  - **Sorun:** `_StatChip` etiketi `'Rating'` (satır ~126). Diğerleri Türkçe: `Kazanma Oranı`, `Galibiyet`.
  - **Çözüm:** `'Derece'` veya `'Sıralama Puanı'`.
  - **Kaynak rapor:** [pvp.md](reports/audits/audit_2026-06-27/pvp.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_screen.dart`

### pvp_history — [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md)
**Kaynak kod:** `lib/screens/pvp/pvp_history_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Filtre client-side only
  - **Sorun:** Tüm maçlar çekilip UI'da süzülüyor; büyük geçmişte performans.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_history_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Hardcoded gradient
  - **Sorun:** `Color(0xFF10131D)` tekrarı (satır 77-82); `AppColors` drift.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_history_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `authId` çift kaynak
  - **Sorun:** Supabase `currentUser?.id` vs `playerProvider.profile?.authId` (satır 54-56); senkron kayması filtre bozar.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_history_screen.dart`

- [ ] **[P2 · UI/UX]** Başlık — emoji + uzun metin
  - **Sorun:** `title: '⚔️ PvP Maç Geçmişi'` (satır 72); AppBar'da emoji + İngilizce kısaltma karışık.
  - **Çözüm:** `'Maç Geçmişi'` veya `'Düello Kayıtları'`.
  - **Kaynak rapor:** [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_history_screen.dart`

- [ ] **[P2 · UI/UX]** Boş durum — CTA eksik
  - **Sorun:** Screenshot QA: `Henüz hiç PvP maçınız bulunmuyor.` + emoji + `Yenile` TextButton; arena/düelloya yönlendirme yok (satır 136-151).
  - **Çözüm:** `İlk düellonu başlat` → `/pvp` veya arena; Yenile ikincil.
  - **Kaynak rapor:** [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_history_screen.dart`

- [ ] **[P2 · UI/UX]** Filtre chip — kayıp maç mantığı
  - **Sorun:** `_filter == 'loss'` → `m.winnerId != authId` (satır 62-64); beraberlik veya authId boşsa yanlış sınıflandırma.
  - **Çözüm:** Explicit `isDraw` / `participantId` karşılaştırması.
  - **Kaynak rapor:** [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_history_screen.dart`

- [ ] **[P2 · UI/UX]** Viewport — %70 boş alan
  - **Sorun:** Screenshot'ta filtre bar sonrası geniş boşluk; empty state ortada küçük, illustration yok.
  - **Çözüm:** Full-height empty illustration + örnek maç mockup (dev).
  - **Kaynak rapor:** [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_history_screen.dart`

- [ ] **[P2 · UI/UX]** Ödül metni — İngilizce `Gold` / `Rep`
  - **Sorun:** Kart sağ kolon `'${m.goldStolen} Gold'` ve `'Rep'` (satır 228-242); sol metinler Türkçe.
  - **Çözüm:** `Altın` / `İtibar` veya `l10n`.
  - **Kaynak rapor:** [pvp_history.md](reports/audits/audit_2026-06-27/pvp_history.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_history_screen.dart`

### pvp_tournament — [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
**Kaynak kod:** `lib/screens/pvp/pvp_tournament_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** `_formatGold` — custom, `intl` yok
  - **Sorun:** Manuel virgül (satır 37-46); `facility_detail` ile farklı format.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_tournament_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** `load()` yalnızca `initState`
  - **Sorun:** `addPostFrameCallback` bir kez; pull-to-refresh var ama route re-enter'da stale.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_tournament_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_BracketColumn` / `_MatchCard` — aynı dosyada 70+ satır
  - **Sorun:** Test ve reuse zor; PvP bracket başka ekranlarda kopyalanabilir.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_tournament_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `join()` sonrası partial reload
  - **Sorun:** `_joinTournament` snackbar only; `load()` otomatik değil (satır 27-34).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_tournament_screen.dart`

- [ ] **[P2 · UI/UX]** Bracket yatay scroll — affordance yok
  - **Sorun:** `SingleChildScrollView` horizontal (satır 125-174); QA'da bracket boş, dolu halde scroll ipucu yok.
  - **Çözüm:** Kenar gradient fade + "kaydır" hint.
  - **Kaynak rapor:** [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_tournament_screen.dart`

- [ ] **[P2 · UI/UX]** Katılımcı sayısı — 0 gösterimi
  - **Sorun:** Screenshot `0 katılımcı · 10.000 altın ödül`; test verisi veya gerçek boş sezon — bracket empty state doğru ama ödül havuzu yanıltıcı (dağıtılamaz).
  - **Çözüm:** 0 katılımcıda ödül kartını soluklaştır veya "Sezon başlayınca" etiketi.
  - **Kaynak rapor:** [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_tournament_screen.dart`

- [ ] **[P2 · UI/UX]** Kayıt CTA — çelişkili mesajlar
  - **Sorun:** Screenshot: empty bracket `'Kayıt ol — 2+ katılımcı olunca...'` (satır 109-111) ama buton `Turnuvaya Katıl (Kayıtlar Kapalı)` disabled (satır 234-241). `registrationOpen == false` ile metin çelişiyor.
  - **Çözüm:** `registrationOpen` false iken bracket metnini güncelle; tek kaynak truth.
  - **Kaynak rapor:** [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_tournament_screen.dart`

- [ ] **[P2 · UI/UX]** Tarih formatı — İngilizce ay
  - **Sorun:** `data.title` screenshot'ta `22 Jun 2026`; `intl` tr_TR kullanılmıyor.
  - **Çözüm:** `DateFormat('d MMM yyyy', 'tr_TR')`.
  - **Kaynak rapor:** [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_tournament_screen.dart`

- [ ] **[P2 · UI/UX]** Ödül dağılımı — statik yüzdeler
  - **Sorun:** Sabit 50/30/20 (satır 193-197); backend ile senkron değil.
  - **Çözüm:** API'den `prize_distribution` çek.
  - **Kaynak rapor:** [pvp_tournament.md](reports/audits/audit_2026-06-27/pvp_tournament.md)
  - **Hedef dosya:** `lib/screens/pvp/pvp_tournament_screen.dart`

### quests — [quests.md](reports/audits/audit_2026-06-27/quests.md)
**Kaynak kod:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P1 · UI/UX]** Tab filtre — listener ters mantık (bug)
  - **Sorun:** Satır 54-57: `if (!_tabCtrl.indexIsChanging) return` — kategori **yalnızca animasyon sırasında** güncellenir; settle olunca atlanır. `_filtered` eski tab ile kalabilir.
  - **Çözüm:** `if (_tabCtrl.indexIsChanging) return;` → settle sonrası update.
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `QuestData.fromJson` — RPC shape tek nokta değil
  - **Sorun:** `_loadQuests` cast `(res as List)` — hata mesajı raw.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_QColors` — tema duplicate (~1287 satır dosya)
  - **Sorun:** Satır 18-30 inline palette; `_QuestCard` shimmer AnimationController per card — 17 görev = 17 ticker!
  - **Çözüm:** // veya static gradient overlay
class _QuestCardState {
  @override
  void initState() {
    if (widget.quest.status == QuestStatus.completed) _shimmerCtrl.repeat();
  }
}
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_QuestDetailSheet` — duplicate action logic
  - **Sorun:** `_QuestCard._buildActionButton` ile mirror kod (~200 satır duplicate).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_claimReward` — optimistic remove
  - **Sorun:** Satır 121 `_quests.removeWhere` RPC öncesi değil sonra ama fail olursa geri alma yok.
  - **Çözüm:** await rpc(...);
if (mounted) setState(() => _quests.removeWhere(...));
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_completeQuest` — full reload
  - **Sorun:** Her complete `_loadQuests()` — season redirect tetiklenebilir tekrar.
  - **Çözüm:** ```
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · UI/UX]** Enerji — ödül chip'i gibi gösteriliyor
  - **Sorun:** `_RewardChip(Icons.flash_on_rounded, '${widget.quest.energyCost}', orange)` (satır 758-763) — maliyet ama reward row'da.
  - **Çözüm:** `'⚡ -20 Enerji'` ayrı maliyet satırı; kırmızı/gri.
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · UI/UX]** Kategori heuristics — kırılgan filtre
  - **Sorun:** `_filtered` (satır 157-180): `q_d` prefix, `QuestDifficulty.easy` → daily proxy. Elite görev "Elit Avcısı" Ana tab'da; daily easy questler weekly'ye kaçabilir.
  - **Çözüm:** RPC `quest_type` alanı; client prefix tahmini kaldır.
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · UI/UX]** Sezon görevi — otomatik redirect
  - **Sorun:** `_loadQuests` completed season quest → `context.go(AppRoutes.season)` (satır 99-102) + snack. Oyuncu Görevler'e giremez.
  - **Çözüm:** In-app banner; redirect optional veya bir kez.
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · UI/UX]** Tamamlanma header — claim edilmemiş completed sayılır
  - **Sorun:** `_completionRate` `QuestStatus.completed` (satır 201-204); claim edilmemiş görevler %100 sayılıp yeşil/shimmer — screenshot 0/17 ama kartlarda active görevler var (completed yok header'da doğru).
  - **Çözüm:** `'Ödül Bekliyor'` ayrı stat; rate = claimed/total.
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

- [ ] **[P2 · UI/UX]** `_actionLoading` — global kilitleme
  - **Sorun:** Tek `bool _actionLoading` tüm kart butonlarını disable (satır 821-835).
  - **Çözüm:** Per-quest `Set<String> _loadingQuestIds`.
  - **Kaynak rapor:** [quests.md](reports/audits/audit_2026-06-27/quests.md)
  - **Hedef dosya:** `lib/screens/quests/quests_screen.dart`

### register — [register.md](reports/audits/audit_2026-06-27/register.md)
**Kaynak kod:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Padding `24` vs Login `20` — `AppSpacing` token ihlali
  - **Sorun:** Design system 8pt grid: `AppSpacing.xl` (24) vs `AppSpacing.lg` (20) auth ekranları arasında rastgele.
  - **Çözüm:** padding: AppSpacing.pagePadding, // EdgeInsets.all(16) veya auth shell'de lg(20)
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `AppBar` + `Center` çift dikey hizalama — üst dead space
  - **Sorun:** Ekran görüntüsünde form ~%55 viewport'ta; üst %25 boş (AppBar altı). `Center` widget formu dikey ortalar → klavye kapalıyken bile form aşağı itilir.
  - **Çözüm:** child: Align(
  alignment: Alignment.topCenter,
  child: SingleChildScrollView(...),
),
// veya AppBar'ı kaldırıp Login gibi in-card başlık
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `TextField` × 4 — `Form`/`TextFormField` yok
  - **Sorun:** Validasyon logic'i API katmanına kaymış; her submit gereksiz network; hata mesajı field yakınında gösterilemiyor (`AppMessenger.showError` global).
  - **Çözüm:** final _formKey = GlobalKey<FormState>();

body: SafeArea(
  child: SingleChildScrollView(
    padding: AppSpacing.pagePadding,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWid
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_submitRegister` — trim ve boş kontrol eksik
  - **Sorun:** `username` boşluk-only (`"   "`) API'ye gidebilir; `referralCode` trim ediliyor ama email/username için sadece `.trim()` submit anında, ara boşluklar field'da kalır.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `const` kullanımı minimal — tüm widget ağacı non-const
  - **Sorun:** `isLoading` her değişimde 4 `TextField` + 2 buton rebuild; `controller` olduğu için kaçınılmaz ama static `SizedBox(height: 12)` `const` yapılabilir (`const SizedBox(height: AppSpacing.md)`).
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · UI/UX]** Form validasyonu — istemci tarafı kontrol yok
  - **Sorun:** `_submitRegister()` doğrudan API çağırıyor; boş e-posta/kullanıcı adı/şifre sunucuya gider. `TextField` kullanılıyor (`TextFormField` + `Form` yok); inline hata mesajı alanı yok.
  - **Çözüm:** Login ile aynı `Form` + validator'lar: e-posta regex, kullanıcı adı min 3 / max 20, şifre min 6.
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · UI/UX]** Input alanları — leading icon yok, helper text yok
  - **Sorun:** Login'de `prefixIcon: Icon(Icons.alternate_email_rounded)` vb. var; Register'da yalnızca label. `inputDecorationTheme.contentPadding` vertical `AppSpacing.md` (12px) — efektif field yüksekliği ~48dp; border `AppColors.borderDefault` (#253154) on `bgCard` (#1A2238) kontrastı düşük (~1.8:1), ekran görüntüsünde alan sınırları zor seçiliyor.
  - **Çözüm:** Prefix icon'lar ekle; focused border `accentBlue` 1.5px zaten temada — focus testi yap.
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · UI/UX]** Layout — klavye açılınca overflow riski
  - **Sorun:** `Center` → `Padding(24)` → `Column(mainAxisSize: min)` — `SingleChildScrollView` yok. 4 input (~52dp each) + gaps + buton ≈ 320dp form; iPhone SE + klavye (~290dp) = **RenderFlex overflow** veya input'lar klavye altında kalır.
  - **Çözüm:** Login pattern: `SafeArea` + `SingleChildScrollView` + `resizeToAvoidBottomInset: true` (Scaffold default).
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · UI/UX]** Primary CTA — tam genişlik değil
  - **Sorun:** `FilledButton` intrinsic width; Login'de `SizedBox(width: double.infinity)`. Ekran görüntüsünde sarı buton ~120dp genişlikte ortada; touch target yüksekliği ~44dp (padding md×2 + 14px text) ancak genişlik dar — görsel hiyerarşi zayıf.
  - **Çözüm:** `SizedBox(width: double.infinity, child: FilledButton(...))` veya `minimumSize: Size.fromHeight(48)`.
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · UI/UX]** Tüm sayfa — Login ile görsel sistem kopukluğu
  - **Sorun:** Register ekranı Login'in `Card` + gradient + `SafeArea` + `ConstrainedBox(maxWidth: 460)` kabuğunu kullanmıyor. Düz `scaffoldBackgroundColor` (#0F1523) üzerinde ortalanmış `Column`; AppBar yalnızca "Kayit" yazıyor (sol üst, ~17px h3). Login'deki "Krallık Kapısı" marka başlığı ve açıklama metni yok.
  - **Çözüm:** Login ile aynı `AuthFormShell` wrapper'ı paylaş; başlık "Krallık Kapısı'na Katıl" + alt metin ekle.
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · UI/UX]** Türkçe karakter eksikliği — tüm label ve CTA'lar
  - **Sorun:** "Kayit", "Kullanici Adi", "Sifre", "Kayit Ol", "Kayit yapiliyor", "Giris Ekranina Don" — doğru: "Kayıt", "Kullanıcı Adı", "Şifre", "Kayıt Ol", "Kayıt yapılıyor...", "Giriş Ekranına Dön". Ekran görüntüsünde AppBar ve placeholder'lar ASCII.
  - **Çözüm:** Merkezi `AppStrings.auth.*` kullan; Register özel metinleri l10n ARB dosyasına.
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · UI/UX]** Yasal / güven metni eksik
  - **Sorun:** Kayıt CTA altında KVKK / kullanım şartları onayı yok; referral opsiyonel alan açıklaması yok.
  - **Çözüm:** CTA üstüne `Text.rich` ile şartlar linki; referral için `helperText: 'Davet kodun varsa gir'`.
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

- [ ] **[P2 · UI/UX]** Şifre alanı — görünürlük toggle yok
  - **Sorun:** `obscureText: true` sabit; `suffixIcon` yok. Login'de `IconButton` + toggle var; Register'da kullanıcı şifresini doğrulayamaz.
  - **Çözüm:** Login'deki `_obscurePassword` state pattern'ini birebir kopyala veya shared `PasswordField` widget.
  - **Kaynak rapor:** [register.md](reports/audits/audit_2026-06-27/register.md)
  - **Hedef dosya:** `lib/screens/auth/register_screen.dart`

### reputation — [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
**Kaynak kod:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P1 · UI/UX]** Mock veri — prod'da yanıltıcı defaults
  - **Sorun:** `_defaultFactions()` hardcoded rep/tasks (`reputation_screen.dart` 81–137); RPC fail `catch (_) {}` → defaults gösterilir (satır 191–193). Screenshot: Tüccarlar 45, Suç Örgütü 80 — smoke'ta gerçek server verisi mi mock mu belirsiz.
  - **Çözüm:** RPC fail → empty/error state; mock yalnızca `kDebugMode`.
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Global rep tier utility yok
  - **Sorun:** `_tierLabel`/`_tierColor` duplicate home/character logic.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Tek dosya — data + UI + dialog
  - **Sorun:** 540 satır; test isolation zor.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_Faction` / `_FactionTask` — private mutable models
  - **Sorun:** `int rep` ve `int current` mutable (satır 24, 41); list state copy yok — side effect risk.
  - **Çözüm:** Bölüm 2 refactor önerisine bakınız.
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_donate` — optimistic local update
  - **Sorun:** RPC sonrası `setState(() => faction.rep += repGain)` (satır 318–319); server reject veya farklı gain → client drift.
  - **Çözüm:** final result = await repo.donate(faction.id, goldAmount);
await _load(); // server truth
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `get_reputation` RPC — silent partial merge
  - **Sorun:** Server list boş item veya unknown faction → skip; defaults kalır (satır 163–189).
  - **Çözüm:** ```
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · UI/UX]** Bağış dialog — `TextEditingController` leak
  - **Sorun:** `TextField(controller: TextEditingController(text: '$repAmount')..selection=...)` her build'de yeni controller (`reputation_screen.dart` 247–253); dispose yok.
  - **Çözüm:** Stateful dialog widget; tek controller `initState`/`dispose`.
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · UI/UX]** Görevler — salt okunur, tamamlanmış görünüm
  - **Sorun:** `_buildTask` progress bar + `current/target` (`reputation_screen.dart` 451–492); tamamlanan görev (20/20) için claim CTA yok. Screenshot expand olmadan görevler gizli.
  - **Çözüm:** `claim_faction_task` RPC + "Ödülü Al" butonu.
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · UI/UX]** Tier badge — "Onurlu" suç örgütünde
  - **Sorun:** 80/100 rep → `_tierLabel` "Onurlu" altın badge (`reputation_screen.dart` 47–52). Suç örgütü için pozitif kelime; faction fantasy zayıf.
  - **Çözüm:** Faction-specific tier labels map.
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · UI/UX]** `_tierRewards` — faction id mismatch
  - **Sorun:** Rewards map keys: `tuccarlar`, `gizli`, `tapınak`, `hapisane`, `hastane` (satır 73–78); faction ids: `zanaatkarlar`, `maceracilar`, `muhafizlar`, `suc_orgutu`. Expand'de `rewards[i] ?? '—'` → çoğu fraksiyonda ödül satırı "—".
  - **Çözüm:** Key'leri faction id ile hizala; server-driven rewards.
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

- [ ] **[P2 · UI/UX]** İki itibar sistemi — home vs faction
  - **Sorun:** Home global `reputation` (0–356K+, `_getReputationTier` farklı eşikler); bu ekran faction rep 0–100 `_tierLabel`. Aynı "itibar" kelimesi iki ekonomi (`home_screen.dart` 1511+, `reputation_screen.dart` 47–53).
  - **Çözüm:** UI copy: "Fraksiyon İtibarı" vs "Şöhret"; home link tooltip.
  - **Kaynak rapor:** [reputation.md](reports/audits/audit_2026-06-27/reputation.md)
  - **Hedef dosya:** `lib/screens/reputation/reputation_screen.dart`

### season — [season.md](reports/audits/audit_2026-06-27/season.md)
**Kaynak kod:** `lib/screens/season/season_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** Yenileme yok
  - **Sorun:** `initState` tek load; claim sonrası stale UI riski.
  - **Çözüm:** RefreshIndicator(onRefresh: () => ref.read(battlePassProvider.notifier).loadAll(), ...)
  - **Kaynak rapor:** [season.md](reports/audits/audit_2026-06-27/season.md)
  - **Hedef dosya:** `lib/screens/season/season_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Magic `1000` BPP per level
  - **Sorun:** `currentBpp % 1000`, `/ 1000.0` (72–73); backend değişince progress bar yanlış.
  - **Çözüm:** final bppPerLevel = season.bppPerLevel;
final xpInLevel = currentBpp % bppPerLevel;
final progress = xpInLevel / bppPerLevel;
  - **Kaynak rapor:** [season.md](reports/audits/audit_2026-06-27/season.md)
  - **Hedef dosya:** `lib/screens/season/season_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Manuel tab — `_tabIndex` + custom `_buildTabs`
  - **Sorun:** Swipe/semantics eksik (275–309).
  - **Çözüm:** DefaultTabController(length: 2, child: TabBarView(...))
  - **Kaynak rapor:** [season.md](reports/audits/audit_2026-06-27/season.md)
  - **Hedef dosya:** `lib/screens/season/season_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_buildRewardsList` 90+ satır inline
  - **Sorun:** Okunabilirlik; reward tile test edilemez (312–401).
  - **Çözüm:** SeasonRewardRow(level: level, freeGrant: ..., vipGrant: ...)
  - **Kaynak rapor:** [season.md](reports/audits/audit_2026-06-27/season.md)
  - **Hedef dosya:** `lib/screens/season/season_screen.dart`

- [ ] **[P2 · UI/UX]** Hata durumu
  - **Sorun:** `Text('Hata: ${state.error}')` düz metin (50); retry/ikon yok.
  - **Çözüm:** `GkkErrorState` + `Tekrar Dene`.
  - **Kaynak rapor:** [season.md](reports/audits/audit_2026-06-27/season.md)
  - **Hedef dosya:** `lib/screens/season/season_screen.dart`

- [ ] **[P2 · UI/UX]** Limit etiketleri İngilizce
  - **Sorun:** `Dungeon Limit 0 / 300`, `PvP Limit 0 / 200` (192–197). BPP `BPP İlerlemesi` kısaltma.
  - **Çözüm:** `'Zindan Limiti'`, `'PvP Limiti'`, `'Sezon Puanı'`.
  - **Kaynak rapor:** [season.md](reports/audits/audit_2026-06-27/season.md)
  - **Hedef dosya:** `lib/screens/season/season_screen.dart`

- [ ] **[P2 · UI/UX]** Tema — `Colors.amber` / `withOpacity`
  - **Sorun:** Header `Colors.black.withOpacity(0.5)` (78); `AppColors` bypass.
  - **Çözüm:** `AppColors.gold`, `withValues(alpha:)`.
  - **Kaynak rapor:** [season.md](reports/audits/audit_2026-06-27/season.md)
  - **Hedef dosya:** `lib/screens/season/season_screen.dart`

- [ ] **[P2 · UI/UX]** VIP satın alma CTA
  - **Sorun:** `VIP SATIN AL (500 💎)` mor buton (screenshot); yükleme metni `SATIN ALINIYOR...` (228). Fiyat backend'den gelmiyor olabilir.
  - **Çözüm:** `season.vipPriceGems` provider'dan; yetersiz bakiye disabled state.
  - **Kaynak rapor:** [season.md](reports/audits/audit_2026-06-27/season.md)
  - **Hedef dosya:** `lib/screens/season/season_screen.dart`

- [ ] **[P2 · UI/UX]** Ödül listesi — tüm seviyeler `KİLİTLİ`
  - **Sorun:** Screenshot'ta Seviye 1–4 kilit ikonu; yeni oyuncu ilerleme yolu görünmez motivasyon.
  - **Çözüm:** Seviye 0/1 için unlock preview; ilk görev CTA `GÖREVLER` sekmesine yönlendir.
  - **Kaynak rapor:** [season.md](reports/audits/audit_2026-06-27/season.md)
  - **Hedef dosya:** `lib/screens/season/season_screen.dart`

### settings — [settings.md](reports/audits/audit_2026-06-27/settings.md)
**Kaynak kod:** `lib/screens/settings/settings_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Settings body `Container` gradient — `GameScreenBackground` reuse edilmemiş
  - **Sorun:** Character/inventory `GameScreenBackground` veya shared gradient; settings one-off — drift.
  - **Çözüm:** body: GameScreenBackground(
  child: ListView(...),
),
  - **Kaynak rapor:** [settings.md](reports/audits/audit_2026-06-27/settings.md)
  - **Hedef dosya:** `lib/screens/settings/settings_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Tüm ayar state local — `ConsumerStatefulWidget` anti-pattern for settings
  - **Sorun:** 7 adet ephemeral field; widget dispose olunca ayarlar kaybolur; test/mock zor.
  - **Çözüm:** @riverpod
class AppSettings extends _$AppSettings {
  @override
  Future<SettingsModel> build() => ref.read(settingsRepo).load();
  Future<void> setMusicVolume(double v) async { ... }
}
// SettingsScr
  - **Kaynak rapor:** [settings.md](reports/audits/audit_2026-06-27/settings.md)
  - **Hedef dosya:** `lib/screens/settings/settings_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_sliderTile` — mute durumunda slider `onChanged: null` ama value 0 gösterir
  - **Sorun:** `_muteAll true` iken music/sfx slider 0'da frozen — kullanıcı unmute edince önceki volume kaybolur (state korunuyor ama slider visual 0). UX: unmute → ani eski seviyeye sıçrama.
  - **Çözüm:** value: _muteAll ? 0.0 : _musicVolume,
onChanged: _muteAll ? null : (v) => setState(() => _musicVolume = v),
// unmute: restore previous volumes
  - **Kaynak rapor:** [settings.md](reports/audits/audit_2026-06-27/settings.md)
  - **Hedef dosya:** `lib/screens/settings/settings_screen.dart`

- [ ] **[P2 · UI/UX]** Bildirimler & Otomatik Savaş toggle — phantom features
  - **Sorun:** `_notifications`, `_autoBattle` local state; push notification izni (`permission_handler`) veya auto-battle backend hook yok. Otomatik savaş alt metni "PvP ve zindan savaşlarını otomatik yönet" vaat ediyor.
  - **Çözüm:** Feature flag off + disabled switch + "Yakında"; veya gerçek entegrasyon.
  - **Kaynak rapor:** [settings.md](reports/audits/audit_2026-06-27/settings.md)
  - **Hedef dosya:** `lib/screens/settings/settings_screen.dart`

- [ ] **[P2 · UI/UX]** Dil seçici — English segment fake
  - **Sorun:** `SegmentedButton` EN seçilince `AppMessenger.show(context, 'English desteği yakında eklenecek')` — segment görsel olarak seçilebilir ama `_language` state EN'e geçmiyor (early return). Screenshot'ta TR seçili — OK; kullanıcı EN'e basınca snack + TR'de kalır, segment UI TR'de kalır (confusing flash).
  - **Çözüm:** EN segment `enabled: false` veya gizle; `flutter gen-l10n` locale switch.
  - **Kaynak rapor:** [settings.md](reports/audits/audit_2026-06-27/settings.md)
  - **Hedef dosya:** `lib/screens/settings/settings_screen.dart`

- [ ] **[P2 · UI/UX]** Section card stili — `AppColors`/`GkkCard` dışı
  - **Sorun:** `_sectionCard` `Colors.black26`, `Border.all(white12)`, manuel `Divider` — envanter `_SectionCard` gradient glass farklı. Settings gradient arka plan `#10131D` → `#171E2C` hardcoded.
  - **Çözüm:** Shared `GkkSettingsSection` = `GkkCard` + `AppTextStyles.h3`.
  - **Kaynak rapor:** [settings.md](reports/audits/audit_2026-06-27/settings.md)
  - **Hedef dosya:** `lib/screens/settings/settings_screen.dart`

- [ ] **[P2 · UI/UX]** Ses ayarları — UI var, işlev yok (false affordance)
  - **Sorun:** `_musicVolume`, `_sfxVolume`, `_muteAll` yalnızca local `setState`; persist (`SharedPreferences`/Supabase) yok. Audio engine/`audioplayers` bağlantısı yok. Slider hareket ettirir ama ses değişmez.
  - **Çözüm:** `SettingsRepository` + gerçek audio mixin; slider debounce persist; mute master bus.
  - **Kaynak rapor:** [settings.md](reports/audits/audit_2026-06-27/settings.md)
  - **Hedef dosya:** `lib/screens/settings/settings_screen.dart`

- [ ] **[P2 · UI/UX]** TextField — düşük kontrast fill
  - **Sorun:** `fillColor: Colors.white.withValues(alpha: 0.05)` + `OutlineInputBorder` — ekran görüntüsünde profil bölümü kısmen görünür; dark tema input sınırları `#253154` login'e göre daha soluk. Error text `_nameError` var ama helper yok (min 3 char kuralı önceden bilinmiyor).
  - **Çözüm:** Tema `inputDecorationTheme` reuse; `helperText: 'En az 3 karakter'`.
  - **Kaynak rapor:** [settings.md](reports/audits/audit_2026-06-27/settings.md)
  - **Hedef dosya:** `lib/screens/settings/settings_screen.dart`

- [ ] **[P2 · UI/UX]** `Hesabı Sil` — tek onay, yeterli friction yok
  - **Sorun:** `_deleteAccount` bir `AlertDialog` — "Emin misiniz?" yeterli değil GDPR/Apple için çoğu uygulama typed confirm veya 2-step. Kırmızı CTA tam genişlik, hemen `Çıkış Yap` altında.
  - **Çözüm:** İkinci dialog: kullanıcı adını yaz; 30 gün soft-delete API varsa belirt.
  - **Kaynak rapor:** [settings.md](reports/audits/audit_2026-06-27/settings.md)
  - **Hedef dosya:** `lib/screens/settings/settings_screen.dart`

### shop — [shop.md](reports/audits/audit_2026-06-27/shop.md)
**Kaynak kod:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P1 · Kod/Refaktör]** `_buyGoldPackage` — client-side users.update bypass
  - **Sorun:** Satır 377-383 doğrudan Supabase update; `buy_shop_item` RPC pattern'i ile tutarsız; race condition iki sekme açıkken.
  - **Çözüm:** await SupabaseService.client.rpc('exchange_gems_for_gold', params: {...});
await ref.read(playerProvider.notifier).loadProfile();
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P1 · UI/UX]** `_GemPackagesTab` — sahte IAP / prod güvenlik
  - **Sorun:** `_buyGemPackage` (satır 402-450) doğrudan `users.update({gems: currentGems + pkg.gems})` — StoreKit/Play Billing yok, fiyat `$0.99` yalnızca UI. QA smoke hesabında ücretsiz elmas enflasyonu.
  - **Çözüm:** `in_app_purchase` + sunucu receipt doğrulama RPC; dev'de feature flag `mock_iap`.
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Hardcoded gradient — `GameScreenBackground` kullanılmıyor
  - **Sorun:** Satır 478-483 inline `LinearGradient`; home/character ile farklı ton.
  - **Çözüm:** body: GameScreenBackground(child: Column(...)),
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Monolitik `shop_screen.dart` (~1137 satır)
  - **Sorun:** 5 tab widget + RPC + IAP logic tek dosyada; test ve tema drift.
  - **Çözüm:** lib/screens/shop/widgets/gem_packages_tab.dart
lib/screens/shop/shop_repository.dart  // buy_shop_item, gold exchange RPC
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `_mapItemsForShop` legacy fallback — tüm items yükleme
  - **Sorun:** `shop_available` boşsa tüm `items` tablosu mağazaya düşer (satır 173-186) — QA'da yanlış fiyat/availability.
  - **Çözüm:** if (mappedShopItems.isEmpty) showEmptyState(); // tüm DB'yi satma
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P2 · UI/UX]** Miktar diyaloğu — TextEditingController anti-pattern
  - **Sorun:** Satır 603: `TextEditingController(text: '$_quantityInput')..selection` her rebuild'de yeni controller — focus kaybı, memory leak riski, cursor sıçraması.
  - **Çözüm:** Stateful dialog veya `TextFormField` + persistent controller.
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P2 · UI/UX]** Tab etiketleri — dil karışımı
  - **Sorun:** TabBar: `'💎 Gem'` (İngilizce) yanında `'💰 Altın'`, `'🛍️ Eşya'` (Türkçe). Kart içi `'Elmas'` Türkçe.
  - **Çözüm:** `'💎 Elmas'` veya merkezi `AppStrings.shop.tabs.gems`.
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P2 · UI/UX]** `_BattlePassTab` / `_OffersTab` — yarım özellik
  - **Sorun:** Battle Pass `'Muharebe Geçidi yakında aktif olacak.'`; Teklif sekmesi salt okunur kart — satın alma CTA yok. Screenshot Gem sekmesinde; kullanıcı diğer sekmelere geçince boş/teaser.
  - **Çözüm:** Feature flag ile sekme gizle veya `ComingSoonBadge`; Pass → `'Savaş Bileti'`.
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P2 · UI/UX]** `_GoldPackagesTab` — scroll kilitli
  - **Sorun:** `ListView.separated(physics: NeverScrollableScrollPhysics())` (satır 774) — TabBarView içinde 4 paket sığmazsa taşma/kesilme; screenshot Gem sekmesinde grid OK ama Altın sekmesi dar cihazda risk.
  - **Çözüm:** `physics: BouncingScrollPhysics()` veya `AlwaysScrollableScrollPhysics`.
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

- [ ] **[P2 · UI/UX]** `_ItemsTab` — 4 sütun grid okunabilirlik
  - **Sorun:** `crossAxisCount: 4`, isim `fontSize: 9.5`, fiyat `10` — screenshot benzeri inventory grid pattern. Uzun isimler `ellipsis`; nadir dot 6×6px.
  - **Çözüm:** `crossAxisCount: 3` veya `LayoutBuilder` breakpoint; min label 11px.
  - **Kaynak rapor:** [shop.md](reports/audits/audit_2026-06-27/shop.md)
  - **Hedef dosya:** `lib/screens/shop/shop_screen.dart`

### splash — [splash.md](reports/audits/audit_2026-06-27/splash.md)
**Kaynak kod:** `lib/screens/auth/splash_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** Hata durumunda login'e sessiz yönlendirme — `AuthStatus.error` mesajı kayboluyor
  - **Sorun:** `auth_provider.dart:76-78` session load exception'da `errorMessage` set ediliyor; splash doğrudan `/login`'e atıyor, hata snackbar'ı gösterilmiyor (login ekranı error state'i dinlemiyor çünkü status `unauthenticated` değil `error`).
  - **Çözüm:** if (next.status == AuthStatus.error) {
  context.go('${AppRoutes.login}?error=${Uri.encodeComponent(next.errorMessage ?? '')}');
  // veya login'de ref.watch ile errorMessage göster
}
  - **Kaynak rapor:** [splash.md](reports/audits/audit_2026-06-27/splash.md)
  - **Hedef dosya:** `lib/screens/auth/splash_screen.dart`

- [ ] **[P2 · Kod/Refaktör]** `SafeArea` eksik — sistem çubuğu ile spinner çakışma riski
  - **Sorun:** Notch/Dynamic Island cihazlarda spinner fiziksel olarak merkezde kalsa da gelecekte üst metin eklenirse status bar altına girer.
  - **Çözüm:** body: SafeArea(
  child: Center(child: _SplashContent()),
),
  - **Kaynak rapor:** [splash.md](reports/audits/audit_2026-06-27/splash.md)
  - **Hedef dosya:** `lib/screens/auth/splash_screen.dart`

- [ ] **[P2 · UI/UX]** Ekran görüntüsü otomasyonu — splash frame yakalanamıyor
  - **Sorun:** QA pipeline `route: "/"` için screenshot alırken `deferProviderUpdate` → `loadSession()` → `unauthenticated` → `go('/login')` zinciri tek frame içinde tamamlanıyor; manifest'te splash ve login PNG'leri özdeş.
  - **Çözüm:** Smoke harness'e `QA_HOLD_SPLASH_MS` flag'i veya `integration_test` binding ile auth provider mock'u (`AuthStatus.initial` dondurma) ekle; screenshot öncesi minimum 1 frame bekle.
  - **Kaynak rapor:** [splash.md](reports/audits/audit_2026-06-27/splash.md)
  - **Hedef dosya:** `lib/screens/auth/splash_screen.dart`

- [ ] **[P2 · UI/UX]** Erişilebilirlik — yükleme durumu duyurulmuyor
  - **Sorun:** `CircularProgressIndicator` etrafında `Semantics` / `ExcludeSemantics` yok; VoiceOver/TalkBack yalnızca "ilerleme göstergesi" der, ne yüklendiği belirsiz.
  - **Çözüm:** `Semantics(label: 'Krallık Kapısı açılıyor, lütfen bekleyin', child: ...)` ve `announceForAccessibility` ile durum geçişi.
  - **Kaynak rapor:** [splash.md](reports/audits/audit_2026-06-27/splash.md)
  - **Hedef dosya:** `lib/screens/auth/splash_screen.dart`

- [ ] **[P2 · UI/UX]** Tam ekran `Scaffold` — marka/oyun kimliği yok
  - **Sorun:** Splash yalnızca ortada varsayılan `CircularProgressIndicator` gösteriyor; GKK logosu, oyun adı, tagline veya `AppColors.gold` / `AppColors.bgBase` paletine uygun branded arka plan yok. Oyunun geri kalanı (Login kartı, altın CTA, Urbanist tipografi) ile görsel dil tamamen kopuk.
  - **Çözüm:** `Stack` içinde `AppColors.bgBase` gradient + merkezde logo asset (`assets/...`) + `AppTextStyles.h2` ile "Krallık Kapısı" + altta ince `LinearProgressIndicator` (tema: `progressIndicatorTheme.color = AppColors.accentBlue`). Minimum 800ms branded hold süresi ekle.
  - **Kaynak rapor:** [splash.md](reports/audits/audit_2026-06-27/splash.md)
  - **Hedef dosya:** `lib/screens/auth/splash_screen.dart`

- [ ] **[P2 · UI/UX]** `CircularProgressIndicator` — tema token uyumsuzluğu
  - **Sorun:** Spinner `progressIndicatorTheme` ile `AppColors.accentBlue` (#5B8FFF) kullanmalı; ancak `Scaffold` arka planı `scaffoldBackgroundColor` (#0F1523) üzerinde 40×40dp varsayılan spinner, etrafında 200+dp boş alan bırakıyor — görsel ağırlık merkezde ~2% alan kaplıyor, geri kalan %98 dead space.
  - **Çözüm:** Spinner boyutunu 32dp'ye düşürme yerine branded skeleton kullan; `Semantics(label: 'Oturum kontrol ediliyor', liveRegion: true)` ekle.
  - **Kaynak rapor:** [splash.md](reports/audits/audit_2026-06-27/splash.md)
  - **Hedef dosya:** `lib/screens/auth/splash_screen.dart`

### trade — [trade.md](reports/audits/audit_2026-06-27/trade.md)
**Kaynak kod:** `lib/screens/trade/trade_screen.dart` (+ `lib/components/trade/*`, `lib/providers/trade_invite_provider.dart`, Supabase trade migrations)

- [x] **[P0 · Kod/Refaktör]** Local state — sunucu sync yok
  - **Sorun:** `_myOffer`, `_tradeStatus` yalnızca client; app kill → stale session; `_confirmTrade` session null ise yine `done` (satır 160-168).
  - **Çözüm:** 2s polling `get_trade_session_details` + `get_my_active_trade_session` restore; confirm RPC response parse.
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`

- [x] **[P0 · Kod/Refaktör]** RPC param adı tutarsızlığı
  - **Sorun:** `add_trade_item`: `session_id`; `confirm_trade`/`cancel_trade`: `p_session_id` — overload/migration riski + ambiguous column 42702.
  - **Çözüm:** Tüm trade RPC'ler `p_session_id` / `p_item_row_id`; migration `20260627_080000_fix_add_trade_item_ambiguous`.
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`

- [ ] **[P0 · Kod/Refaktör]** `SingleChildScrollView` + `Column` trade tab — unbounded height risk
  - **Sorun:** Active state büyük; nested scroll yok; çok eşyada overflow (screenshot idle OK).
  - **Çözüm:** ConstrainedBox(constraints: BoxConstraints(maxHeight: 200), child: ListView(...))
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`

- [x] **[P0 · UI/UX]** Durum makinesi — gelen istek UI yok
  - **Sorun:** Yalnızca outbound search (`initiate_trade`); pending/active inbound trade listesi, push/badge yok.
  - **Çözüm:** `TradeInviteHost` global popup + `get_pending_trade_invites` polling; kabul/red + 4s engel.
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/components/trade/trade_invite_host.dart`

- [ ] **[P0 · UI/UX]** Miktar — her zaman 1
  - **Sorun:** `_addItemToOffer` `'quantity': 1` sabit (satır 130); stackable eşyada partial trade yok.
  - **Çözüm:** Bank/shop pattern `_askQuantity` dialog.
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`

- [x] **[P1 · Kod/Refaktör]** `_removeFromOffer` — sunucu sync yok
  - **Sorun:** Local remove only; backend offer stale kalır.
  - **Çözüm:** `remove_trade_item` RPC + session refresh.
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`

- [x] **[P1 · UI/UX]** Oturum ID — debug metni prod'da
  - **Sorun:** `'Oturum: ${_sessionId!.substring(0, 8)}...'` prod'da anlamsız.
  - **Çözüm:** Oturum ID UI kaldırıldı.
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`

- [x] **[P2 · Kod/Refaktör]** `_addToHistory` — optimistic + immediate reload
  - **Sorun:** Confirm sonrası fake id + duplicate flash.
  - **Çözüm:** Confirm tamamlanınca yalnızca `_loadHistory()`; optimistic insert kaldırıldı.
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`

- [ ] **[P2 · UI/UX]** Boş durum — viewport %60 boş
  - **Sorun:** Idle state tek kart (arama + input); screenshot'ta header sonrası geniş boş alan — görsel ağırlık üstte, CTA zayıf.
  - **Çözüm:** Illustration + "Yakındaki oyuncular" / son işlem özeti; idle'da geçmiş snippet.
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`

- [x] **[P2 · UI/UX]** Karşı teklif paneli — bilinçli ama kırıcı placeholder
  - **Sorun:** `'Gerçek zamanlı senkronizasyon henüz desteklenmiyor.'` — partner offer görünmüyordu.
  - **Çözüm:** 2s polling + jsonb parse fix; karşı teklif paneli canlı; gold sync.
  - **Kaynak rapor:** [trade.md](reports/audits/audit_2026-06-27/trade.md)
  - **Hedef dosya:** `lib/screens/trade/trade_screen.dart`

---

## C. Screenshot QA Görevleri (fix değil — fixture/seed gerekir)

Bu maddeler kod fix değil; screenshot doğrulaması için QA fixture gerektirir.

- [ ] **/guild/monument/donate**
  - **Sorun:** Loncasız hesap → yalnızca empty state; bağış formu render edilmedi
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/facilities/farm**
  - **Sorun:** Slug mismatch (farm ≠ farming) → üretim/yükseltme UI doğrulanmadı
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/dungeon/battle**
  - **Sorun:** Query params yok → savaş/zafer/hastane fazları yakalanmadı
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/pvp/history**
  - **Sorun:** Boş liste; dolu maç kartı ve filtre sonuçları yok
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/pvp/tournament**
  - **Sorun:** 0 katılımcı; bracket dolu hali yok
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/guild-war/tournament/:id**
  - **Sorun:** 0 lonca katılımcı; join CTA görünmedi
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/my-mekan**
  - **Sorun:** Mekan yok empty; 4 tab dolu hali yok
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/mekans/:id**
  - **Sorun:** Vitrin boş; satın alma sheet ve dolu grid yok
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/mekans/:id/arena**
  - **Sorun:** Sıralama sekmesi yok; qa_bot_* fixture
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/guild-war/logs**
  - **Sorun:** Empty state ve filtre-boş senaryo yok
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **/guild-war/territory/:id**
  - **Sorun:** Savunma bar overflow; saldırılar fold altında
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

- [ ] **Cross-app**
  - **Sorun:** Header `Hi` İngilizce; bottom nav `Home` İngilizce; ticker kesik
  - **Kaynak:** [SUMMARY.md](reports/audits/audit_2026-06-27/SUMMARY.md)

---
# GKK Flutter — Kod & Tasarım Audit Özeti
**Tarih:** 2026-06-27  
**Screenshot run:** `reports/screenshots/audit_2026-06-27/` (42 rota)  
**Audit klasörü:** `reports/audits/audit_2026-06-27/`

---

## Toplam Sayfa Sayısı

| Metrik | Değer |
|--------|-------|
| Manifest rotaları | 42 |
| Screenshot yakalanan | 42 |
| Audit raporu yazılan | **42** |
| Bu batch (yeni) | 12 |
| Önceki batch | 30 |

### Tüm audit dosyaları (42)

`bank`, `character`, `chat`, `crafting`, `dungeon`, `dungeon_battle`, `enhancement`, `facilities`, `facility_detail`, `guild`, `guild_monument`, `guild_monument_donate`, `guild_war`, `guild_war_logs`, `guild_war_territory_detail`, `guild_war_tournament_detail`, `home`, `horse_race`, `hospital`, `inventory`, `leaderboard`, `login`, `loot`, `market`, `mekan_arena`, `mekan_create`, `mekan_detail`, `mekans`, `my_mekan`, `onboarding_character_select`, `prison`, `pvp`, `pvp_history`, `pvp_tournament`, `quests`, `register`, `reputation`, `season`, `settings`, `shop`, `splash`, `trade`

---

## Top 10 Cross-App Kritik Sorunlar (şiddet sırasıyla)

| # | Şiddet | Sorun | Etki | Kaynak |
|---|--------|-------|------|--------|
| 1 | **P0** | `GameBottomBar._activeIndex` yalnızca 5 ana tabı tanır; menü/alt rotalarda fallback **Home** | 30+ ekranda yanlış nav highlight; oyuncu konumunu kaybeder | `game_chrome.dart:724-731`; tüm hub/sub-screen auditleri |
| 2 | **P0** | **Trade** karşı teklif senkronu yok; Onayla aktif | Dolandırılma riski algısı; yarım feature prod'da | `trade.md` |
| 3 | **P0** | **Loot** `currentRoute: AppRoutes.shop` copy-paste bug | Nav/telemetri bozuk; shop highlight riski | `loot.md` |
| 4 | **P1** | **Chat** `GameChrome` dışı; profil/kaynak header yok | Uygulama bütünlüğü kırık; mesaj hizalama bug | `chat.md` |
| 5 | **P1** | **Facility detail** route slug `farm` ≠ kod `farming` | Smoke `/facilities/farm` her zaman boş ekran | `facility_detail.md` |
| 6 | **P1** | Guild war / tournament **null state** → `SizedBox.shrink()` | Geçersiz ID'de boş ekran, 404 yok | `guild_war_tournament_detail.md`, `guild_war_territory_detail.md` |
| 7 | **P1** | **Logout** provider clear tutarsız (inventory, facilities, guild, pvp…) | Hesap değişiminde stale cache / veri sızıntısı | `trade.md`, `crafting.md`, `facilities.md`, yeni batch |
| 8 | **P2** | Ham exception / RPC metni UI'da (`$e`, `history.error!`) | Teknik hata mesajları oyuncuya görünür | `pvp_history.md`, `dungeon_battle.md`, `mekan_create.md` |
| 9 | **P2** | **Mekan modülü** ASCII Türkçe (`Mekanin`, `Istatistik`, `Once`) | Store kalitesi; l10n eksik | `mekan_create.md`, `my_mekan.md`, `mekans.md` |
| 10 | **P2** | **DefensePowerBar** current > max (2600/1000) | Progress bar anlamsız; güven kaybı | `guild_war_territory_detail.md` |

---

## Top 5 Quick Wins (kolay fix, yüksek etki)

| # | Fix | Dosya | Tahmini efor |
|---|-----|-------|--------------|
| 1 | `_activeIndex`: bilinmeyen route → **Menü** (index 4) veya nötr; prefix map (`/pvp`, `/guild`, `/mekans`…) | `game_chrome.dart` | ~30 satır |
| 2 | Loot `currentRoute: AppRoutes.loot` | `loot_hub_screen.dart` | 1 satır |
| 3 | Facility route alias: `farm` → `farming` veya smoke manifest düzelt | `app_router.dart` / `smoke_route_registry.dart` | ~5 satır |
| 4 | Tournament/Territory `t == null` → empty/error widget + geri CTA | `tournament_detail_screen.dart`, `territory_detail_screen.dart` | ~20 satır each |
| 5 | Merkezi `logout()` helper: `player`, `inventory`, `guild`, `facilities`, `pvp*` invalidate | `auth_provider` veya `game_chrome` | ~40 satır |

---

## Screenshot Kapsam / QA Boşlukları

Aşağıdaki rotalar yakalandı ancak screenshot **eksik durum**, **yanlış fixture** veya **dolgu verisi** nedeniyle UI tam doğrulanamadı:

| Rota / Slug | QA gap |
|-------------|--------|
| `/guild/monument/donate` | Loncasız hesap → yalnızca `Lonca bulunamadı.`; form hiç render edilmedi |
| `/facilities/farm` | Slug mismatch → sürekli empty; üretim/yükseltme UI doğrulanmadı |
| `/dungeon/battle` | Query params yok → generic `Zindan` idle; savaş/zafer/hastane fazları yakalanmadı |
| `/pvp/history` | Boş liste; dolu maç kartı ve filtre sonuçları yok |
| `/pvp/tournament` | 0 katılımcı + kayıt kapalı; bracket dolu hali yok |
| `/guild-war/tournament/:id` | 0 lonca katılımcı; empty participants, join CTA görünmedi |
| `/my-mekan` | Mekan yok empty; 4 tab (stok/vault/upgrade) dolu hali yok |
| `/mekans/:id` | Vitrin boş (`selcuk barı`); satın alma sheet ve dolu grid yok |
| `/mekans/:id/arena` | Sıralama sekmesi; empty opponents; gerçek oyuncu yerine `qa_bot_*` |
| `/guild-war/logs` | Dolu (3 kayıt) ama empty state ve filtre-boş senaryo yok |
| `/guild-war/territory/:id` | Savunma bar overflow (2600/1000); son saldırılar fold altında |
| Cross-app | Header `Hi` İngilizce; bottom nav `Home` İngilizce; ticker `Ahmet Efs` kesik |

### Önerilen ek screenshot senaryoları

1. **Fixture hesapları:** lonca üyesi, mekan sahibi, açık çiftlik (`farming`), zindan query params ile battle success/fail  
2. **State matrix:** empty / loading / error / dolu için PvP history, war logs, tournament bracket  
3. **Etkileşim:** trade active session, mekan buy sheet, arena bet sheet, facility collect ready  
4. **Manifest düzeltmesi:** `facilities_farm` → `facilities_farming` veya router alias

---

## Batch Notu (2026-06-27 — 12 sub-route)

Bu oturumda tamamlanan yeni raporlar:

`pvp_history`, `pvp_tournament`, `dungeon_battle`, `guild_monument_donate`, `guild_war_logs`, `guild_war_tournament_detail`, `guild_war_territory_detail`, `facility_detail`, `mekan_create`, `my_mekan`, `mekan_detail`, `mekan_arena`

**Audit tamamlandı:** manifest'teki 42 rotanın tamamı için `§1 UI/UX` + `§2 Refaktör` raporu mevcut.

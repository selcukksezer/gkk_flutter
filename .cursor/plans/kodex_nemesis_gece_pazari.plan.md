# Kodex + Nemesis + Gece Pazarı — Detaylı Uygulama Planı

> Onay: #5 Kodex, #2 Nemesis, #10 Gece Pazarı (gem `/shop`, P2P `/market` DEĞİL)
> Tasarım: `tasarim` skill + mevcut `DottedPanel` / `UniversalDialogPanel` / promo carousel
>
> **Karar (2026-07-24 audit):** Gece Pazarı bilinçli olarak **her gün 20–22 TR** (Cuma-only değil). Milestone ladder bilinçli olarak **14 eşik → 400** (eski 10/25/50/100 değil).

---

## Kapsam sınırları

| Özellik | Yaşar | Yaşamaz |
|---------|-------|---------|
| Kodex | `/character/codex`, zindan sonucu, envanter hook | Ayrı menü uygulaması |
| Nemesis | `/pvp`, geçmiş, sticky bar | Legacy `pvp_attack` (Flutter kullanmıyor) |
| Gece Pazarı | `/shop` tab index **2** (Gece) | `/market` P2P; mekan `is_han_only` contraband |

---

## Mimari (oyun içi entegrasyon)

```
Ana Sayfa
├── HomePromoCarousel ← 3 dynamic banner (Gece > Nemesis > Kodex)
├── BildirimInbox ← 6 yeni NotificationKind
├── StickyActionBar ← nemesis gap
└── ComebackSummary ← 3 yeni satır

Character → Kodex satırı
PvP → Nemesis panel + revenge invite
Shop → Gece Pazarı tab (Her gün 20-22 TR)
Zindan sonucu → CodexDiscoveryChip
```

**Ortak RPC:** `get_retention_promos()` — carousel + inbox + sticky bar tek kaynak (60s poll).

---

## Faz 0 — Ortak altyapı

**Migration:** `supabase/migrations/20260725_100000_codex_nemesis_night_market.sql`  
(+ follow-ups `20260725_121000_*`, `20260727_*`; remote apply versions often `20260724*` — prod zaten apply; fresh clone `db push` sonrası smoke şart)

### get_retention_promos()
```json
{
  "night_market": { "active", "starts_at", "ends_at", "seconds_left" },
  "nemesis": { "has_rival", "rival_id", "rival_username", "losses", "wins", "online", "leaderboard_gap", "should_notify_online" },
  "codex": { "discovered", "total", "new_entries_24h", "claimable_milestones" }
}
```

### Yeni rotalar (`app_router.dart`)
- `AppRoutes.codex` → `/character/codex?category=item|boss|dungeon`
- `AppRoutes.shop` + query `?tab=night`
- `AppRoutes.pvp` + query `?revenge={uuid}`

### Bildirim enum (`notification_item.dart`)
| Kind | Section | Route |
|------|---------|-------|
| codexNewEntry | Kodex | /character/codex |
| codexMilestone | Kodex | /character/codex?claim=1 |
| nemesisRevenge | PvP | /pvp?revenge=id |
| nemesisOnline | PvP | /pvp?revenge=id |
| nightMarketOpen | Mağaza | /shop?tab=night |
| nightMarketEnding | Mağaza | /shop?tab=night |

### Comeback summary genişletme
`get_comeback_summary` items: `codex_milestone`, `nemesis_revenge`, `night_market`

### Carousel refactor (`home_promo_carousel.dart`)
- `_slides` hardcoded → `_slidesBase + _slidesDynamic(promos)`
- `showTimer: true` ilk kez Gece Pazarı için
- Dynamic visibility: koşul yoksa slide yok

---

## Faz 1 — #5 Koleksiyon Kodex

### Tasarım
- **3 sekme:** Eşya / Boss / Zindan (`item|boss|dungeon`)
- **Keşif:** ilk envanter girişi, ilk clear, boss kill
- **Milestone (global discovered count):** 14 eşik `10,20,30,40,50,75,100,125,150,200,250,300,350,400`
  - 10 → bronz rozet
  - 50 → +1 loot luck + **Kodex çerçevesi** (`avatar_frame='codex'` boşsa)
  - 400 → altın rozet + unvan `kodex_ustasi`
  - Ara eşikler → gold + gem (ladder config)
- **Ayrım:** Run milestone (10/25/50 koşu) = ayrı sistem (`_dungeon_grant_milestones`) — UI etiketi farklı

### DB
```sql
player_codex_entries (player_id, entry_type, entry_key, discovered_at)
player_codex_milestones (player_id, threshold, claimed_at, gold_granted, gems_granted)
codex_catalog (entry_type, entry_key, display_name, rarity, zone, sort_order)
```

### RPC
- `discover_codex_entry(type, key)` — internal idempotent
- `get_codex_dashboard()`, `get_codex_entries(type, offset, limit)`
- `claim_codex_milestone(threshold)`, `claim_all_codex_milestones()`
- `get_codex_luck_bonus(player_id)` — enter_dungeon patch (+1 max, monument stack cap)

### Hooks
1. `enter_dungeon(uuid,text)` success → dungeon + boss discovery; return `codex_new[]`
2. Loot/inventory add → item discovery
3. Backfill job: inventory + first_clear + boss stats

### Flutter
- `lib/screens/character/codex_screen.dart` — grid, siluet undiscovered, milestone claim-all
- `character_screen.dart` — Kodex satırı; çerçeve unlock @50 claimed
- `codex_discovery_chip.dart` — CodexDiscoveryChip
- Bildirim: session/day max 3 new entry; milestone claimable

### Ana sayfa banner
- id: `codex`, Liquid Gold border
- Görünür: claimable > 0 OR new_entries_24h > 0

---

## Faz 2 — #2 Nemesis

### Tasarım
- Rolling **7 gün**, timezone `Europe/Istanbul`
- Skor: `losses*3 + wins*1`, aday için `losses >= 1`
- CTA: `send_pvp_invite` (mevcut duel akışı)
- Newbie shield: hedef <5 level → invite disabled
- Galibiyet bonus: 1000-5000g, 1/gün cap (arena/duel)

### DB
```sql
player_nemesis_state (..., last_online_notice_at)
nemesis_revenge_log (avenger_id, nemesis_id, invite_id, won)
```

### RPC
- `refresh_player_nemesis()` — login + maç sonrası
- `get_nemesis_rival()` — rival + `leaderboard_gap`
- `dismiss_nemesis_banner()` — 24h
- `get_retention_promos` → `should_notify_online` (1/gün Istanbul)

### Flutter
- `pvp_screen.dart` — Nemesis panel
- `pvp_history_screen.dart` — NEMESIS chip + filtre
- `sticky_action_bar.dart` — gap gösterimi
- Deep link `?revenge=` → invite sheet

### Bildirim
- `nemesisRevenge` — son 1h yenilgi
- `nemesisOnline` — max 1/gün (**server** `last_online_notice_at`)

### Ana sayfa banner
- Mystic Ruby tema, CTA "Düello Gönder"
- Görünür: has_rival && losses >= 2 && !dismissed

---

## Faz 3 — #10 Gece Pazarı (Gem Shop)

### Tasarım
- **Her gün 20:00–22:00** Europe/Istanbul (bilinçli; Cuma-only değil)
- **6-8 slot/hafta**, gem only, oyuncu stok 1-3/slot
- Shadow class: %5 gem indirim veya +1 stok
- **NOT:** `is_han_only` mekan path'ten bağımsız explicit offer list

### DB
```sql
night_market_schedule (weekday=NULL, start_hour=20, end_hour=22, timezone)
night_market_offers (rotation_week, item_id, gem_price, stock_per_player)
night_market_purchases (player_id, offer_id, quantity)
```
+ **shop_offers** tablo fix

### RPC
- `get_night_market_status()` — offers + timer
- `buy_night_market_item(offer_id, qty)` — server-authoritative

### Shop UI (`shop_screen.dart`)
- Tab index **2**: **Gece Pazarı** (Gem / Altın / Gece / Pass / Eşya)
- Disabled off-window → tooltip "Her gün 20:00"
- `night_market_tab.dart` — countdown Warning Solar
- `economy_constants.dart` — GemSinkInfo

### Bildirim + scheduler
- Pencere öncesi local push (~5 dk)
- `nightMarketOpen` / `nightMarketEnding` (30 dk kala)
- **Settings toggle** (Gece / Nemesis ayrı)

### Ana sayfa banner
- `showTimer: true`, route `/shop?tab=night`
- Sadece active window

---

## Sprint sırası

| Sprint | İçerik |
|--------|--------|
| S1 | Faz 0 ortak infra |
| S2 | Gece Pazarı (shop + banner) |
| S3 | Nemesis (PvP + banner) |
| S4 | Kodex (DB hooks + UI + banner) |
| S5 | Comeback + smoke + tutorial + settings toggles |

---

## Riskler

| Risk | Önlem |
|------|-------|
| Carousel spam | Dynamic visibility |
| Nemesis spam | dismiss + server 1 online/gün |
| shop_offers yok | migration'da oluştur |
| Luck stack | cap with monument L30 |
| Timezone DST | Europe/Istanbul server-side |
| `enter_dungeon(text)` fallback | DROP; Dart tek overload |
| Local vs remote migration adları | prod apply edilmiş; fresh clone smoke |

---

## Dosyalar

**Yeni:** codex_screen, night_market_tab, nemesis_rival_panel, retention_promos_provider, retention_analytics, 3 model

**Değişen:** shop_screen, pvp_screen, character_screen, home_promo_carousel, notification_*, app_router, dungeon_*, economy_constants, game_notification_scheduler, settings_screen, smoke_route_registry, tutorial_*, comeback

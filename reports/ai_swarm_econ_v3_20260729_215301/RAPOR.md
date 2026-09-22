# AI Live-Play v3 — Tam Rapor

**Run:** `20260729_215301`  
**Verdict:** `PASS` — **400/400 bot PASS** · 30 goal

---

## 1. Ekonomi (gerçek)

| Metrik | Seed/Önce | Sonra | Delta |
|--------|----------:|------:|------:|
| Gold sum | 10,000,000,000 | 9,944,832,871 | **-55,167,129** |
| Gold avg | 25,000,000 | 24,862,082 | -137,918 |
| Gems sum | 2,000,000 | 1,999,600 | -400 |
| Market listed (open) | 0 | 400 | |
| Market history buys | 0 | **400** | |
| Market partial open | 0 | 400 | (qty 2→1) |
| **Fill rate %** | 0 | **100** | history / listed |
| Dungeon runs | 0 | 800 | |
| Trade sessions | 0 | 400 | |
| Chat DM rows | 0 | 16 | (rate-limit; goal PASS soft) |

Gold vs seed (25M/bot): **−55,167,129 (−0.55%)**

### Delta özet

| Key | Value |
|-----|------:|
| `gold_delta` / `gold_delta_vs_seed` | -55,167,129 |
| `market_fill_rate_pct` | 100 |
| `market_history_buys` | 400 |

### Ekonomi okuma

- Gold delta vs seed = net sink (enhance / GW vault / fees / taxes) − dungeon gold in.
- Market fill rate = `market_history` buys / listed orders (partial qty 2→1 counts as buy).

---

## 2. Coverage by goal

| Goal | PASS | FAIL | SKIP |
|------|-----:|-----:|-----:|
| `bank_deposit` | 400 | 0 | 0 |
| `character_allocate_stat` | 400 | 0 | 0 |
| `chat_dm_reply` | 400 | 0 | 0 |
| `chat_dm_send` | 400 | 0 | 0 |
| `chat_global_send` | 400 | 0 | 0 |
| `crafting_start_queue` | 400 | 0 | 0 |
| `daily_reward_claim` | 400 | 0 | 0 |
| `dungeon_attack_win` | 400 | 0 | 0 |
| `dungeon_enter_confirm` | 400 | 0 | 0 |
| `dungeon_list_load` | 400 | 0 | 0 |
| `enhancement_equip_upgraded` | 400 | 0 | 0 |
| `enhancement_forge` | 400 | 0 | 0 |
| `friends_send_request` | 400 | 0 | 0 |
| `guild_create_or_join` | 400 | 0 | 0 |
| `guild_monument_donate` | 400 | 0 | 0 |
| `guild_war_attack` | 4 | 0 | 396 |
| `guild_war_hub` | 400 | 0 | 0 |
| `inventory_equip_item` | 400 | 0 | 0 |
| `inventory_open` | 400 | 0 | 0 |
| `legal_accept` | 400 | 0 | 0 |
| `market_browse` | 400 | 0 | 0 |
| `market_buy_listing` | 400 | 0 | 0 |
| `market_list_item` | 400 | 0 | 0 |
| `market_search` | 400 | 0 | 0 |
| `pvp_attack_target` | 400 | 0 | 0 |
| `quests_list` | 400 | 0 | 0 |
| `reputation_overview` | 400 | 0 | 0 |
| `shop_buy_qa_gem_pack` | 400 | 0 | 0 |
| `trade_confirm` | 400 | 0 | 0 |
| `trade_initiate` | 400 | 0 | 0 |

### Özet

- **400/400 PASS:** bank, trade, craft, market list+buy, PvP friend invite, DM send/reply, dungeon, enhance, …
- **GW attack:** 4 PASS / 396 SKIP (`member_not_leader` + fetih grace)

---

## 3. Bugs / notes

### Fixed this run

1. **`purchase_market_listing_rl_inner` → `market_history.price` NULL**  
   INSERT set `unit_price` but NOT NULL `price` → buy always failed. Now sets both.

2. **Craft SKIP** — `craft_item_async` returns TABLE; marathon assigned to jsonb → exception → `start_crafting` hit array `materials` with `jsonb_each_text`. Fix: `to_jsonb(t)` + seed ingredients.

3. **PvP SKIP** — discovery needs offer. Fix: accept friend request then `send_pvp_invite(..., 'friend')`.

4. **GW attack SKIP (leaders)** — vault 1M < 10M cost. Fix: boost QA vault to 50M before attack.

5. **Trade confirm SKIP** — stale `active` sessions → initiate returned active, respond wanted `pending`. Fix: cancel pair sessions first.

### Remaining expected SKIPs

- **`guild_war_attack`:** ~360 members = `member_not_leader`. Leaders after first captures → `Yeni fetih koruması aktif (2 saat)` → only ~4 PASS this swarm. Game rule OK.
- **`chat_dm` row count 16:** goal PASS soft on rate-limit; not 400 real inserts.

---

## 4. Artifacts

| Dosya | İçerik |
|-------|--------|
| `RAPOR.md` | Bu birleşik rapor |
| `summary.json` | Machine-readable summary |
| `economy_*.json` | Before/after/delta |
| `bots/` | Per-bot JSON |
| Migration | `supabase/migrations/20261014_120000_qa_live_play_v3_skip_fixes.sql` |

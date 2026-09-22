# Bugs / notes — AI Live-Play v3

## Fixed this run

1. **`purchase_market_listing_rl_inner` → `market_history.price` NULL**  
   INSERT set `unit_price` but NOT NULL `price` → buy always failed. Now sets both.

2. **Craft SKIP** — `craft_item_async` returns TABLE; marathon assigned to jsonb → exception → `start_crafting` hit array `materials` with `jsonb_each_text`. Fix: `to_jsonb(t)` + seed ingredients.

3. **PvP SKIP** — discovery needs offer. Fix: accept friend request then `send_pvp_invite(..., 'friend')`.

4. **GW attack SKIP (leaders)** — vault 1M < 10M cost. Fix: boost QA vault to 50M before attack.

5. **Trade confirm SKIP** — stale `active` sessions → initiate returned active, respond wanted `pending`. Fix: cancel pair sessions first.

## Remaining expected SKIPs

- **`guild_war_attack`**: ~360 members = `member_not_leader`. Leaders after first captures → `Yeni fetih koruması aktif (2 saat)` → only ~4 PASS this swarm. Game rule OK.
- **`chat_dm` row count 16**: goal PASS soft on rate-limit; not 400 real inserts.

## Economy reading

- Gold delta vs seed = net sink (enhance/GW vault spend/dungeon fees/taxes) minus dungeon gold in.
- Market fill rate = filled / (open + filled) after swarm buys.

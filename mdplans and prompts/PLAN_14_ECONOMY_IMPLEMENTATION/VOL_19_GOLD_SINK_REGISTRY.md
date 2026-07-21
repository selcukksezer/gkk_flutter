# PLAN 14 — Cilt 19: Altın Sink Sistemleri Kayıt Defteri

> **Öncelik:** P1 — Tüm altın OUT kaynaklarının tek referansı

---

## Sink Tablosu

| Sistem | RPC / Mekanizma | Skala | Cilt |
|--------|-----------------|-------|------|
| Enhancement | `enhance_item` | 100K → 1B+ / attempt | VOL_14 |
| Crafting | `start_crafting`, `craft_item_async` (fix) | 10K → 25M / recipe | VOL_15 |
| Tesis unlock/upgrade | `unlock_facility`, `upgrade_facility` | 798M max all | VOL_17 |
| Shop | `buy_shop_item` | base_price catalog | — |
| Gold loot box | `open_loot_box` | 80K–200K | VOL_04 |
| Market fee | `purchase_market_listing` | %5 destroy | VOL_09 |
| Lonca anıt | `donate_to_monument` | 10M gold/gün cap | §19.1 |
| At yarışı bahis | `place_horse_race_bet` | 10K–5M (kayıp) | §19.2 |
| Hastane healer | gold path (varsa) | 100K–1M PLAN | §19.3 |
| PvP | transfer (net-zero) + mekan %5 | §19.4 |

---

## §19.1 Lonca Anıt Bağış

- `donate_to_monument` — günlük limit 10M gold
- Yapı/mystical/critical item + gold
- **Migration tune:** `20260722_160000_monument_sink_audit.sql`

---

## §19.2 At Yarışı

- House edge 92% RTP — net gold sink (kayıp bahis)
- Gem + gold bahis
- **Cilt detay:** `VOL_22_HORSE_RACE_ECONOMY.md`
- daily_bet_limit default set önerilir

---

## §19.3 Hastane

- `heal_with_gems` — elmas sink (VOL_24)
- Gold healer PLAN_06 — RPC var mı doğrula

---

## §19.4 PvP Altın

- `gold_stolen` transfer — net-zero (kazanan +, kaybeden −)
- Mekan komisyon %5 — sink
- Wash trade detect (VOL_23)

---

## Kabul

- [ ] Her sink sim'de gold_out > 0 (tam sim)
- [ ] Sink registry canlı dashboard (VOL_37)

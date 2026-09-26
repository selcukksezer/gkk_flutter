# PLAN 14 — Cilt 20: Altın Musluk Sistemleri Kayıt Defteri

> **Öncelik:** P1 — Tüm altın IN kaynaklarının tek referansı

---

## Musluk Tablosu

| Sistem | RPC | Tune | Cilt |
|--------|-----|------|------|
| Zindan | `enter_dungeon` | VOL_05, VOL_05B | ✓ |
| Vendor satış | `sell_inventory_item_by_row` | VOL_03 %35 | ✓ |
| Günlük ödül | `claim_daily_reward` | §20.1 | |
| Quest | `claim_quest_reward` | §20.2 | |
| Battle Pass | `bp_claim_reward` | §20.3 | |
| Tesis collect→sell | `collect_facility_resources_v2` | VOL_17 | |
| Pazar satış | `purchase_market_listing` | %95 seller | |
| At yarışı kazanç | horse race resolve | §20.4 | |
| Referral | gems only | — | |
| Tutorial | client grants | §20.5 | |
| PvP çalma | transfer | net-zero | |

---

## §20.1 Günlük Ödül

- 20 gün döngü: base 287.500 gold / 86 gem
- Level scale: `×(1 + min(level,70)×0.02)`
- Yıllık perfect L70: ~12.6M gold
- **Tune:** gem scale yok — bilinçli; gold band audit

---

## §20.2 Quest

| Quest | Gold | Gem |
|-------|------|-----|
| q_dungeon_runner | 500 | 10 |
| q_elite_slayer | 1000 | 50 |
| q_treasure_hunter | 0 | 20 |

Daily/weekly cap — inflation audit

---

## §20.3 Battle Pass

- Free track 20 level: **570K gold** / 14 gün
- VIP +500 gem → +400K gold
- **Not:** VOL_01'de "dokunulmaz" kaldırıldı — BP gem/gold budget IAP ile dengele

---

## §20.4 At Yarışı Kazanç

- RTP 92% — net kayıp beklenir (sink)
- Kazanan musluk — düşük mult strateji

---

## §20.5 Tutorial

- Client-side grants — server RPC'ye taşınmalı (güvenlik)
- dng_001 farm fix (VOL_05)

---

## Kabul

- [ ] Musluk toplamı sim gold_in breakdown ile eşleşir
- [ ] Tutorial server-authoritative

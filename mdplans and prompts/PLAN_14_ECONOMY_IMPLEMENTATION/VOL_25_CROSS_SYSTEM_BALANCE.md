# PLAN 14 — Cilt 25: Cross-System Denge Matrisi

> **Öncelik:** P2 — Tüm ciltler arası bağımlılık

---

## Bağımlılık Zincirleri

### Zincir 1: Loot → Vendor → Enflasyon
```
open_loot_box → item → sell @ 35% → gold_in
qa_loot_box_ev vendor RTP ↔ gerçek satış değeri UYUMLU (VOL_03+04)
```

### Zincir 2: Enerji → Zindan → Gold
```
energy_limit → dungeon_runs/day → gold_in
whale gem_refill bypass → VOL_16 cap
```

### Zincir 3: Enhancement → Item → Gold
```
enhance fail destroy → item_out
re-craft gold_cost → gold_out (VOL_15 fix)
```

### Zincir 4: IAP → Gem → Sink
```
verify_and_grant_gems → gems_in
loot/VIP/hospital/bank → gems_out
VOL_21 ledger balance
```

### Zincir 5: Sezon Reset → Economy
```
perform_season_reset → gold=1000, inv clear
gems persist → whale head start (PLAN_06)
BP 14-day independent (VOL_08 §terminology)
```

---

## Sim Senaryoları (Zorunlu)

| ID | Bot profili | Beklenen |
|----|-------------|----------|
| XS-01 | Casual 30d | gold/day PLAN band alt %50 |
| XS-02 | Hardcore 30d | enhancement gold_out > 0 |
| XS-03 | Whale + gem refill | energy cap enforce |
| XS-04 | Trader market only | net gold neutral, fee sink |
| XS-05 | Full ecosystem 10k | inflation ≤ 12% |

---

## Kabul

- [ ] 5 cross-system sim PASS
- [ ] Dependency graph güncel (MASTER_INDEX)

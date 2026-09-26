# PLAN 14 — Ek D: Test Matrisleri

---

## D.1 Vendor Satış (VOL_03)

| ID | Tür | Senaryo | Girdi | Beklenen |
|----|-----|---------|-------|----------|
| V-01 | Unit | Normal satış | vendor=10000, qty=1 | gold=3500 |
| V-02 | Unit | Sıfır vendor | vendor=0 | gold=0 |
| V-03 | Unit | Stack satış | vendor=100, qty=5 | gold=175 |
| V-04 | Integration | RPC auth | anon | error |
| V-05 | Sim | 10k bot 30g | post-migration | inflation ↓ |

---

## D.2 Loot RTP (VOL_04)

| ID | Tür | Senaryo | Kriter |
|----|-----|---------|--------|
| L-01 | SQL | Script 2 | 0 hedef dışı |
| L-02 | SQL | Script 3 | 0 sıfır vendor |
| L-03 | Integration | open_loot_box ×100 | avg ≈ qa_ev ±10% |
| L-04 | Integration | Pity 8 common | 9. rare+ |
| L-05 | UI | Preview visible | screenshot |

---

## D.3 Zindan (VOL_05)

| ID | Tür | Senaryo | Kriter |
|----|-----|---------|--------|
| Z-01 | Unit | dng_001 farm exempt | mult ≥ 1.0 success |
| Z-02 | DB | zone 2 gold | min/max ×3 |
| Z-03 | Integration | dng_030 10 run L45 | daily ~7M band |
| Z-04 | Integration | overfarm L70 dng_011 | gold < 5K/run |

---

## D.4 IAP (VOL_06)

| ID | Tür | Senaryo | Kriter |
|----|-----|---------|--------|
| I-01 | Unit | Mock verify success | gems += package |
| I-02 | Security | Duplicate receipt | reject |
| I-03 | Security | Invalid receipt | reject |
| I-04 | Sandbox | 4 packages iOS | all grant |
| I-05 | Sandbox | 4 packages Android | all grant |
| I-06 | Regression | buy_shop_item gold | unchanged |

---

## D.5 Sezon Reset (VOL_08)

| ID | Tür | Senaryo | Kriter |
|----|-----|---------|--------|
| R-01 | Integration | perform_season_reset | gold=1000 all |
| R-02 | Integration | badge kept | in inventory |
| R-03 | Integration | gems unchanged | exact |
| R-04 | Integration | top1 reward | +10000 gems |

---

## D.6 Simülasyon (VOL_07)

| ID | Tür | Senaryo | Kriter |
|----|-----|---------|--------|
| S-01 | Smoke | 10k/30d | gold_inflation ≤12% |
| S-02 | Smoke | 10k/30d | item_inflation ≤15% |
| S-03 | Smoke | exploits | 0% success |
| S-04 | Smoke | class balance | <5% spread |

---

## D.7 UI (VOL_11)

| ID | Tür | Senaryo | Kriter |
|----|-----|---------|--------|
| U-01 | Widget | formatGems(500.0) | "500" |
| U-02 | Widget | formatGold(50000) | "50K" |
| U-03 | Integration | loot route | not shop highlight |
| U-04 | Screenshot | 42 routes | audit PASS |

---

## D.8 Regresyon Paketi (Her Release)

```bash
flutter test
flutter test integration_test/smoke/smoke_gate_test.dart
./scripts/run_comprehensive_smoke_10k.sh 1000 7
```

## D.9 Crafting (VOL_15) — KRİTİK

| ID | Senaryo | Beklenen |
|----|---------|----------|
| CR-01 | craft_item_async common recipe | gold -= gold_cost |
| CR-02 | insufficient gold | reject |
| CR-03 | start_crafting parity | same cost as async |
| CR-04 | sim craft gold_out | > 0 |

## D.10 Enhancement (VOL_14)

| ID | Senaryo |
|----|---------|
| EN-01 | mythic +1 gold 1.2M |
| EN-02 | L6 destroy no rune |
| EN-03 | sim enhancement gold_out > 0 |

## D.11 Daily / Quest (VOL_20)

| ID | Senaryo |
|----|---------|
| DR-01 | claim_daily_reward once/day |
| DR-02 | streak reset miss day |
| QU-01 | claim_quest_reward gems |

## D.12 Horse Race (VOL_22)

| ID | Senaryo |
|----|---------|
| HR-01 | fairness smoke PASS |
| HR-02 | daily_bet_limit enforce |

## D.13 Trade (VOL_23)

| ID | Senaryo |
|----|---------|
| TR-01 | gold escrow on confirm |
| TR-02 | wash trade flag |

## D.14 Bank / Hospital (VOL_24)

| ID | Senaryo |
|----|---------|
| BK-01 | expand_bank_slots 5 gem |
| HO-01 | heal_with_gems level scale |

## D.15 Cross-System (VOL_25)

| ID | Senaryo |
|----|---------|
| XS-01–05 | VOL_25 §Sim Senaryoları |

## D.16 Sim Fidelity (VOL_13)

| ID | Senaryo |
|----|---------|
| SF-01 | tam sim side insert ON |
| SF-02 | segment economy JSON present |

**Toplam test sayısı (tam genişletme):** 300+ senaryo

# PLAN 14 — Ek A: Migration Kayıt Defteri

> v1.1 — Gap taraması sonrası güncellendi

---

## Uygulama Sırası (Zorunlu)

| # | Dosya | Cilt | Not |
|---|-------|------|-----|
| 1 | `20260722_010000_vendor_sell_35_percent.sql` | VOL_03 | Faz 0 yedek |
| 2 | **`20260722_130000_craft_item_async_gold_cost.sql`** | **VOL_15** | **KRİTİK sink fix** |
| 3 | `20260722_030000_dungeon_tutorial_farm_penalty_exempt.sql` | VOL_05 | |
| 4 | `20260722_020000_dungeon_gold_zone234_multiplier.sql` | VOL_05 | |
| 5 | `20260722_150000_dungeon_gold_zone567_multiplier.sql` | VOL_05B | |
| 6 | `20260722_040000_loot_rtp_prod_tune.sql` | VOL_04 | #1 vendor |
| 7 | `20260722_140000_energy_refill_daily_cap.sql` | VOL_16 | |
| 8 | `20260722_110000_qa_sim_segment_economy_breakdown.sql` | VOL_13 | |
| 9 | — **Tam sim kapısı geç** — | VOL_13+07 | enhancement/facility/craft OUT > 0 |
| 10 | `20260722_050000_iap_transactions_table.sql` | VOL_06 | Sim PASS |
| 11 | `20260722_060000_verify_and_grant_gems.sql` | VOL_06 | |
| 12 | `20260722_070000_market_price_bands.sql` | VOL_09 | Faz 3 |
| 13 | `20260722_080000_referral_abuse_limits.sql` | VOL_10 | |
| 14 | `20260722_160000_monument_sink_audit.sql` | VOL_19 | |
| 15 | `20260722_180000_trade_rate_limits.sql` | VOL_26 | |
| 16 | `20260722_190000_horse_race_daily_bet_limit.sql` | VOL_22 | |
| 17 | `20260722_090000_perform_season_reset.sql` | VOL_08 | |
| 18 | `20260722_100000_season_rewards_distribution.sql` | VOL_08 | |

---

## Mevcut Ekonomi Migration Zinciri (Referans)

| Tarih | Dosya | Konu |
|-------|-------|------|
| 20260224 | enforce_gold_only_sales | sell_inventory RPC |
| 20260301 | craft_queue | craft_item_async **gold yok** |
| 20260613 | dungeon_reward_balance | farm mult |
| 20260614 | remove_spin_wheel | spin kaldırıldı |
| 20261013 | secure_shop + loot eco | trigger, RTP |
| 20261013 | remove_gem_gold_exchange | exchange disabled |

---

## Merge Kontrol Listesi

- [ ] `supabase db reset` local PASS
- [ ] **VOL_15 craft gold** staging manuel test
- [ ] Tam sim 10k/30g PASS
- [ ] Rollback APPENDIX_E

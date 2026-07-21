# PLAN 14 — Ek A: Migration Kayıt Defteri

> Tüm PLAN_14 migration dosyalarının sırası ve bağımlılıkları

---

## Uygulama Sırası (Zorunlu)

| # | Dosya | Cilt | Bağımlılık |
|---|-------|------|------------|
| 1 | `20260722_010000_vendor_sell_35_percent.sql` | VOL_03 | Faz 0 yedek |
| 2 | `20260722_030000_dungeon_tutorial_farm_penalty_exempt.sql` | VOL_05 | — |
| 3 | `20260722_020000_dungeon_gold_zone234_multiplier.sql` | VOL_05 | — |
| 4 | `20260722_040000_loot_rtp_prod_tune.sql` | VOL_04 | #1 (vendor etkisi) |
| 5 | — Sim kapısı geç — | VOL_07 | #1–4 |
| 6 | `20260722_050000_iap_transactions_table.sql` | VOL_06 | Sim PASS |
| 7 | `20260722_060000_verify_and_grant_gems.sql` | VOL_06 | #6 |
| 8 | `20260722_070000_market_price_bands.sql` | VOL_09 | Faz 2 |
| 9 | `20260722_080000_referral_abuse_limits.sql` | VOL_10 | Faz 2 |
| 10 | `20260722_090000_perform_season_reset.sql` | VOL_08 | Faz 2 |
| 11 | `20260722_100000_season_rewards_distribution.sql` | VOL_08 | #10 |

---

## Mevcut Ekonomi Migration Zinciri (Referans)

| Tarih | Dosya | Konu |
|-------|-------|------|
| 20260224 | enforce_gold_only_sales | sell_inventory RPC |
| 20260613 | dungeon_reward_balance | farm mult |
| 20261013 | secure_shop_currency | trigger, shop |
| 20261013 | loot eco3/eco4/eco4b | RTP ladder |
| 20261013 | remove_gem_gold_exchange | exchange disabled |

---

## Merge Kontrol Listesi

- [ ] `supabase db reset` local PASS
- [ ] Migration timestamp çakışması yok
- [ ] GRANT/REVOKE doğru
- [ ] SECURITY DEFINER search_path set
- [ ] Rollback script APPENDIX_E

# PLAN 14 — Ek E: Geri Alma (Rollback) Prosedürleri

---

## E.1 Genel İlkeler

1. PLAN_12 yedekten restore her zaman mümkün olmalı
2. Tek migration rollback tercih edilir (full restore son çare)
3. Rollback sonrası sim smoke zorunlu
4. Oyuncu duyurusu hazır tut

---

## E.2 Vendor %35 Rollback

```sql
-- 20260224_236000_enforce_gold_only_sales.sql içindeki
-- sell_inventory_item_by_row tanımını yeniden uygula (tam vendor fiyat)
```

**Etki:** Oyuncular satış değeri artar — duyuru gerekmez (geri alma nadir).

---

## E.3 Zindan Gold Çarpan Rollback

```sql
-- Orijinal değerler 20260307_030000_dungeon_system.sql seed'den
UPDATE public.dungeons SET
  gold_min = <original>,
  gold_max = <original>
WHERE zone BETWEEN 2 AND 4;
```

Backup'tan `SELECT id, gold_min, gold_max FROM dungeons` export edilmiş olmalı.

---

## E.4 Loot RTP Tune Rollback

eco4b öncesi migration snapshot veya:
```sql
-- loot_box_drop_entries weight backup tablosundan restore
UPDATE loot_box_drop_entries e
SET weight = b.weight
FROM loot_box_drop_entries_backup_plan14 b
WHERE e.id = b.id;
```

**Önlem:** Tune öncesi `CREATE TABLE loot_box_drop_entries_backup_plan14 AS SELECT * FROM loot_box_drop_entries;`

---

## E.5 IAP Rollback

1. Feature flag `iap_enabled=false`
2. shop_screen toast moduna dön
3. Migration revoke: `REVOKE EXECUTE ON verify_and_grant_gems FROM authenticated`
4. iap_transactions korunur (audit)

---

## E.6 Sezon Reset Rollback

**Tehlikeli** — oyuncu verisi silindi. Yalnızca full DB restore.

Dry-run staging'de zorunlu; production'da backup olmadan çalıştırma.

---

## E.7 Rollback Karar Matrisi

| Belirti | Rollback kapsamı |
|---------|------------------|
| gold_inflation > 25% post-deploy | Vendor + zindan |
| IAP double grant | IAP disable + transaction audit |
| Loot RTP > 80% | Loot weight restore |
| Sezon reset hata | Full restore |

---

## E.9 Craft Gold Fix Rollback

Önceki `craft_item_async` — gold deduct yok. Rollback = free craft path geri (enflasyon riski).

## E.10 Enhancement Tune Rollback

`get_enhancement_config` + `enhance_item` backup from `20260720_100000`.

## E.11 Energy Refill Cap Rollback

Remove daily counter column / RPC check.

## E.12 Horse Race daily_bet_limit Rollback

Set `daily_bet_limit = NULL` in settings.

## E.13 Trade Rate Limit Rollback

Remove `enforce_rate_limit` wrapper from trade RPCs.

## E.14 Monument / Daily Reward Config Rollback

Restore seed rows from backup table.

## E.8 Rollback Test (Quarterly)

- [ ] Staging backup restore süresi ölçüldü
- [ ] Tek migration rollback script test edildi
- [ ] **VOL_15 craft rollback** test edildi
- [ ] Runbook güncel

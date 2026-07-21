# PLAN 14 — Cilt 15: Crafting Ekonomisi

> **Öncelik:** P0 — **Kritik bug**  
> **Migration:** `20260722_130000_craft_item_async_gold_cost.sql`

---

## 1. Problem

İki crafting yolu var:

| RPC | Altın düşer? | Kullanım |
|-----|--------------|----------|
| `start_crafting` | **Evet** — `gold_cost × qty` | Eski/sync path |
| `craft_item_async` | **Hayır** — yalnızca malzeme | **Ana queue path** |

`craft_item_async` (`20260301_020000`) malzeme düşer, **gold_cost düşmez** → crafting sink bypass → enflasyon.

---

## 2. Hedef Davranış

```sql
-- craft_item_async içine ekle (start_crafting ile aynı):
v_total_gold := (v_recipe.gold_cost * p_batch_count)::BIGINT;
IF v_user.gold < v_total_gold THEN
  RETURN QUERY SELECT false, NULL, 'Insufficient gold';
  RETURN;
END IF;
UPDATE public.users SET gold = gold - v_total_gold WHERE auth_id = v_user_id;
```

---

## 3. Tarif Maliyetleri (Referans)

| Rarity | Gold/recipe |
|--------|-------------|
| common | 10.000 |
| uncommon | 50.000 |
| rare | 250.000 |
| epic | 1.000.000 |
| legendary | 5.000.000 |
| mythic | 25.000.000 |

Kaynak: `20260613_150000_crafting_categories_and_missing_recipes.sql`

---

## 4. Yan Etkiler

- Erken oyuncu craft daha pahalı — PLAN_06 ile uyumlu
- Quest `q_craft_master` hâlâ ulaşılabilir (200 gold reward)
- Sim craft gold_out > 0 olmalı

---

## 5. Rollback

APPENDIX_E §E.10 — gold refund policy yok; migration geri alınırsa async path tekrar free

---

## 6. Kabul

- [ ] craft_item_async gold deduct staging test
- [ ] start_crafting ile maliyet parity
- [ ] Sim craft gold_out > 0

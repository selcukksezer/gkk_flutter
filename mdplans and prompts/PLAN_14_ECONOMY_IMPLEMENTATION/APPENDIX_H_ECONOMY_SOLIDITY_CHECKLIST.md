# PLAN 14 — Ek H: Ekonomi Sağlamlık Kontrol Listesi (Master Checklist)

> Launch öncesi **tüm** maddeler işaretlenmeli

---

## A. Güvenlik (Değiştirilemez)

- [ ] `enforce_users_currency_via_rpc_only` aktif
- [ ] Shop server fiyat
- [ ] Inventory mint revoke
- [ ] IAP server-only grant
- [ ] Exploit sim 0%

---

## B. Musluk Kontrolü (Gold IN)

- [ ] Zindan Bölge 1–7 tune (VOL_05, VOL_05B)
- [ ] Vendor satış %35 (VOL_03)
- [ ] Günlük/quest band audit (VOL_20)
- [ ] Tesis collect→sell chain (VOL_17)
- [ ] Tutorial server-side (VOL_20 §20.5)

---

## C. Sink Kontrolü (Gold OUT)

- [ ] craft_item_async gold deduct (VOL_15) **KRİTİK**
- [ ] Enhancement sim active (VOL_14)
- [ ] Tesis upgrade sim active (VOL_17)
- [ ] Market %5 fee (VOL_09)
- [ ] Monument donate (VOL_19)
- [ ] Horse race net sink (VOL_22)

---

## D. Elmas Dengesi

- [ ] IAP live (VOL_06)
- [ ] Gem mint/spend ledger (VOL_21)
- [ ] Bank UI 5 gem (VOL_24)
- [ ] All sinks listed VOL_21

---

## E. Loot / Kasa

- [ ] 36 kutu RTP band (VOL_04)
- [ ] vendor_sell=0 items cleaned
- [ ] Odds UI visible (VOL_11)
- [ ] Soft pity tested

---

## F. Simülasyon

- [ ] Hızlı smoke 10k/30g
- [ ] **Tam sim** side insert ON (VOL_13)
- [ ] gold_inflation ≤ 12%
- [ ] item_inflation ≤ 15%
- [ ] Segment JSON (VOL_13)

---

## G. Cross-System

- [ ] Enerji cap whale (VOL_16)
- [ ] VOL_25 five scenarios PASS
- [ ] PLAN_06 traceability APPENDIX_G

---

## H. Operasyon

- [ ] PLAN_12 backup
- [ ] Dashboard VOL_12
- [ ] Rollback APPENDIX_E
- [ ] Season reset dry-run (VOL_08) veya bilinçli erteleme doc

---

## İmza

Tüm A–G tamamlanmadan production ekonomi migration **YOK**.

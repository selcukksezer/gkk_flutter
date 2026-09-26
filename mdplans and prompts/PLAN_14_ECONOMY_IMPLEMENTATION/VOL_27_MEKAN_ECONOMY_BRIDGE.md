# PLAN 14 — Cilt 27: Mekan Ekonomisi (PLAN_07 Köprüsü)

> **Öncelik:** P1 — PLAN_06 §2.1 Mekan geliri  
> **Bağımlılık:** PLAN_07_MEKAN_SYSTEM.md

---

## Musluk

- Mekan sahibi kira/stok karı
- PvP bahis komisyonu
- `buy_from_mekan` owner_profit

---

## Sink

- Stok yenileme maliyeti
- Bakım/upgrade
- Detox içecek (50K–500K gold PLAN_06)

---

## Enerji

- Han potları yalnızca Mekan'da — enerji gate (VOL_16)
- `is_han_only=true`, market trade ban

---

## PLAN_14 Scope

Tam Mekan impl PLAN_07'de; PLAN_14 yalnızca **ekonomi cross-ref**:

- [ ] Mekan gold_in sim segment
- [ ] Han pot trade ban enforce
- [ ] PvP %5 mekan cut sim'de

---

## Kabul

- [ ] PLAN_07 cross-ref APPENDIX_G satırı
- [ ] Enerji↔Mekan zinciri VOL_25'te

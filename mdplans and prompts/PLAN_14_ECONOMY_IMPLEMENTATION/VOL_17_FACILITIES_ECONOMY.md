# PLAN 14 — Cilt 17: Tesis Ekonomisi

> **Öncelik:** P0  
> **RPC:** `collect_facility_resources_v2`, `unlock_facility`, `upgrade_facility`  
> **Maliyet toplam max:** ~798M altın (15 tesis L10)

---

## 1. Musluk + Sink Döngüsü

```
unlock/upgrade (GOLD OUT) → production → collect → vendor sell (GOLD IN @ 35%)
```

VOL_03 vendor %35 uygulandıktan sonra tesis NPC satış musluğu **%65 azalır** — kasıtlı.

---

## 2. PLAN_06 Hedef vs Impl

| Metrik | PLAN_06 | Impl |
|--------|---------|------|
| 15 tesis L10 | 500M | 798M (+60%) |
| Günlük tesis geliri (end) | 50M–100M | collect rate × vendor × 0.35 |

---

## 3. Tune

| Aksiyon | Detay |
|---------|-------|
| Upgrade maliyet | Opsiyonel −15% migration |
| Collect output | Zone/level scale audit |
| Vendor chain | VOL_03_TASK_002 **tamamla** — tesis satış yolu doğrula |

---

## 4. Sim

Tam sim'de `facility_gold_out` (upgrade) ve `facility_gold_in` (collect→sell) ayrı ölçülmeli.

---

## 5. Kabul

- [ ] VOL_03_TASK_002 impact analizi dolu
- [ ] Tesis satış vendor %35 kullanıyor
- [ ] Sim facility gold_out > 0

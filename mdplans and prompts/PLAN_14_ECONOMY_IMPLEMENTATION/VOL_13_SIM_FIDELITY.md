# PLAN 14 — Cilt 13: Simülasyon Gerçekçiliği (Sim Fidelity)

> **Öncelik:** P0 — VOL_07 kapılarından **önce** zorunlu  
> **Problem:** Mevcut smoke `qa_sim_skip_side_inserts=true` → enhancement, tesis, craft sink'leri sim'de eksik → +56% enflasyon **güvenilmez**

---

## 1. Amaç

Ekonomi simülasyonunun production RPC davranışını yansıtması. Kapı geçişi yalnızca **side insert açık** tam sim ile onaylanır.

---

## 2. Mevcut Durum

| Sim türü | Script | Side insert | Sink kapsamı |
|----------|--------|-------------|--------------|
| Hızlı smoke | `qa_smoke_comprehensive_10k` | **Kapalı** | Zindan, quest kısmi |
| Tam sim | `qa_run_30_day_simulation` | Açık | Enhancement, tesis, craft, market |

**Kural:** Production deploy öncesi **her ikisi de** çalıştırılır; hızlı smoke regresyon, tam sim **nihai kapı**.

---

## 3. Segment Bazlı Ekonomi JSON (Eksik — Eklenecek)

Migration: `20260722_110000_qa_sim_segment_economy_breakdown.sql`

Sim çıktısına eklenecek alanlar:

```json
{
  "segment_economy": {
    "hardcore": { "gold_in": 0, "gold_out": 0, "gems_in": 0, "gems_out": 0 },
    "casual": { "...": "..." },
    "whale": { "...": "..." }
  }
}
```

---

## 4. Zorunlu Kapılar (Güncellenmiş)

| KPI | Hızlı smoke | Tam sim | Hedef |
|-----|-------------|---------|-------|
| gold_inflation_pct | ≤ 15% (uyarı) | **≤ 12%** (hard) | PLAN_13 |
| item_inflation_pct | ≤ 18% | **≤ 15%** | PLAN_13 |
| enhancement_gold_out | N/A | > 0 (sink aktif) | Yeni |
| facility_gold_out | N/A | > 0 | Yeni |
| craft_gold_out | N/A | > 0 (start_crafting path) | Yeni |

---

## 5. Uygulama Adımları

1. `qa_sim_skip_side_inserts` default'u staging'de `false` yap (migration veya config)
2. Segment economy breakdown RPC patch
3. `./scripts/run_comprehensive_smoke_10k.sh 10000 30` — regresyon
4. Yeni script: `./scripts/run_full_economy_sim_10k.sh 10000 30` — tam sim
5. Her ikisi JSON arşivle

---

## 6. Kabul Kriterleri

- [ ] Tam sim enhancement/facility/craft gold_out > 0
- [ ] Tam sim gold_inflation ≤ 12%
- [ ] Segment breakdown JSON mevcut
- [ ] CI: PR hızlı smoke, main tam sim

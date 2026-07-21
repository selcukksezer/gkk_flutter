# PLAN 14 — Cilt 12: Canlı Operasyon ve İzleme

> **Öncelik:** P2 — Production deploy sonrası

---

## 1. Ekonomi Metrikleri (Günlük)

| Metrik | Kaynak | Alarm eşiği |
|--------|--------|---------------|
| Toplam gold_in / gold_out | RPC log aggregate | inflation > 15% |
| gems minted (IAP+F2P) | iap_transactions + daily | anomaly +50% |
| gems spent | loot, VIP, hospital | sink < mint |
| Market volume | market_history | — |
| Loot box opens | player_loot_box_logs | — |
| Avg vendor RTP (sample) | qa_loot_box_ev weekly | out of band |

---

## 2. Dashboard Önerisi

Supabase + Grafana veya Metabase:

- Günlük altın net mint grafiği
- Elmas kaynak/sink stacked bar
- Segment retention (D1/D7/D30)
- IAP revenue (store raporları ile reconcile)

---

## 3. Haftalık Ekonomi Raporu Şablonu

```markdown
## Hafta YYYY-WW Ekonomi Özeti
- gold_inflation_7d: X%
- gems_net: +Y
- Top sink: enhancement / loot / facilities
- Anomaly: ...
- Action items: ...
```

---

## 4. Müdahale Runbook

| Senaryo | Aksiyon |
|---------|---------|
| Gold enflasyon > 20% | Zindan farm mult sıkılaştır |
| Gem sink < mint | Kasa fiyat artır veya VIP maliyet |
| IAP fraud spike | Receipt verify sıkılaştır, rate limit |
| Market manipülasyon | Fiyat band daralt |

---

## 5. Feature Flags

| Flag | Amaç |
|------|------|
| `economy_vendor_35` | Vendor %35 kademeli açılış |
| `iap_enabled` | IAP canary |
| `dungeon_gold_mult_z2` | Bölge çarpanları ayrı ayrı |

---

## 6. Kabul Kriterleri

- [ ] Dashboard canlı
- [ ] Haftalık rapor otomasyonu
- [ ] Runbook ekiple paylaşıldı

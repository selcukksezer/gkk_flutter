# GKK Ekonomi Özet Raporu (TR)

**Tarih:** 2026-07-24  
**Kaynak:** `comprehensive_smoke_10000_30d.json` + Supabase canlı sorgular + sim aktivite dökümü  
**Sim:** 10.000 bot · 30 gün · ~300.000 günlük event

---

## 1. Genel Sağlık (Knight Online perspektifi)

| Metrik | Değer | Gate (PLAN_13) | Durum |
|--------|-------|----------------|-------|
| **Altın enflasyon** | **56,33%** | ≤ 12% | ❌ KRİTİK |
| **Item enflasyon** | **50,02%** | ≤ 15% | ❌ KRİTİK |
| **Exploit başarı** | 0% | ≤ 5% | ✅ |
| **D1 retention (genel)** | 92,4% | — | ✅ |
| **D7 retention (genel)** | 69,5% | — | ⚠️ |
| **D30 retention (genel)** | 29,0% | — | ⚠️ |
| **Casual D30** | **11,5%** | ≥ 15% | ❌ |
| **Newbie D30** | **4,3%** | ≥ 10% | ❌ |

**KO tarzı verdict:** Ekonomi **aşırı faucet** — grind → altın birikimi optimal, sink yetersiz. Hardcore/whale tutunur; casual/newbie D30'da düşer. Exploit kapıları sağlam; asıl risk **enflasyon + zayıf erken oyun sink'i**, dupe değil.

> **Not:** `gates.plan13` içindeki `casual_d30_retention: 0.0038` değeri segment sorgusuyla uyuşmuyor (gerçek casual D30 = **11,5%**). Gate raporlamasında bug şüphesi — karar için segment sorgusunu esas al.

---

## 2. Altın & Item Akışı (10k sim, 30 gün)

| | Miktar |
|--|--------|
| Altın üretimi (gold_in) | **202.427.892** |
| Altın tüketimi (gold_out) | **88.405.844** |
| Net altın | **+114.022.048** |
| Item üretimi | 599.568 |
| Item tüketimi | 299.688 |
| Gem harcaması | 46.476 |

**Enflasyon formülü:** `(gold_in - gold_out) / gold_in = 56,33%`

---

## 3. Top Altın Kaynakları (sim katsayıları × aktivite)

Sim formülü: `300 + quest×220 + dungeon×650 + market_sell×380 + mekan×300 + rand(0-500)`

| Kaynak | Aktivite (30g) | Tahmini altın payı |
|--------|----------------|-------------------|
| **Zindan (dungeon)** | 449.375 run | ~**%45-50** (en büyük faucet) |
| **Pazar satış (market_sell)** | 300.599 | ~**%25-28** |
| **Günlük base + RNG** | 300k event | ~**%15** |
| **Quest** | 300.107 | ~**%12** |
| **Mekan geliri** | 150.109 | ~**%8** |
| PvP | 299.622 saldırı | XP ağırlıklı; altın doğrudan düşük |

---

## 4. Top Altın Sink'leri

Sim formülü: `120 + market_buy×350 + craft×180 + guild×120 + rand(0-350)`

| Sink | Aktivite | Tahmini pay |
|------|----------|-------------|
| **Base + RNG harcama** | 300k event | ~**%35** |
| **Craft** | 449.346 | ~**%30** |
| **Pazar alım (market_buy)** | 149.554 | ~**%20** |
| **Lonca (guild)** | 149.816 | ~**%7** |
| Hastane/hapishane gem | 46.476 gem | Gem sink; whale ağırlıklı |

**Eksik sim sink'leri:** Kuşatma (siege), P2P trade, enhancement fail gold burn, vergi/repair — live'da var, sim'de **yok** veya zayıf.

---

## 5. Segment Ekonomisi (D30)

| Segment | Gold in | Gold out | Net | D30 aktif |
|---------|---------|----------|-----|-----------|
| Hardcore | 1,57M | 0,44M | +1,13M | 52,7% |
| Normal | 1,11M | 0,59M | +0,52M | 26,5% |
| Casual | 1,10M | 0,59M | +0,51M | **11,5%** |
| Whale | 1,05M | 0,29M | +0,76M | 57,4% |
| Newbie | 0,82M | 0,44M | +0,38M | **4,3%** |

Whale gem sink yoğun; casual/newbie altın biriktirir ama **oyunda kalmaz** (session ~5-9 dk vs hardcore ~130 dk).

---

## 6. Retention (segment bazlı)

| | D1 | D7 | D30 |
|--|-----|-----|------|
| **Genel** | 92,4% | 69,5% | 29,0% |
| **Casual** | 88,5% | 56,3% | **11,5%** |
| **Newbie** | 90,7% | 47,9% | **4,3%** |

D1 güçlü → onboarding OK. D7-D30 drop → **midgame hedef + sink motivasyonu** zayıf.

---

## 7. Siege / Trade / Craft / Sell Etkisi

| Sistem | Sim durumu | Ekonomi etkisi |
|--------|------------|----------------|
| **Kuşatma (siege)** | RPC smoke PASS; sim'de ayrı faucet/sink yok | Canlı bonus çarpanları var — sim enflasyonu **eksik düşük** gösterebilir |
| **Trade (P2P)** | Sim'de **simüle edilmiyor** | Altın transferi / arbitraj test dışı |
| **Craft** | 449k action | Sink var ama faucet (dungeon loot + sell) daha güçlü |
| **NPC sell** | Migration `20260725_040000` uygulu | `vendor_sell ≈ base_price × 0,35` (ör. 175/500) |
| **Mekan shop** | Canlı örnek: shop 100g vs NPC 175g | Shop **ucuz** → NPC satış teşviki zayıf |

### NPC vs Shop fiyat audit (canlı DB örneği)

| Item | NPC sell | Shop sell | Base |
|------|----------|-----------|------|
| Rawhide | 175 | 100 | 500 |
| Stone Talisman | 760 | 100 | — |
| Iron Ore (envanter) | 175 | — | 500 |

KO mantığı: NPC satış = düşük ama güvenli sink. Shop fiyatı NPC'nin altında kalınca **item → gold dönüşümü** cazip değil.

---

## 8. Canlı DB Dağılımı (10.024 aktif user)

| | Değer |
|--|-------|
| Ortalama altın | **1.094.337** |
| Medyan altın | **394.510** |
| Max altın | **1.802.168.964** |

Whale/alt birikimi uç değer — sink olmadan KO ekonomisi **hyperinflation** yolunda.

---

## 9. At yarışı adalet (200 run smoke)

- En düşük gold çarpan kazanma: **27,5%** (RTP ~104%) — hafif ev bias
- En yüksek çarpan: **9%** kazanma (RTP ~86%)
- **Verdict:** Makul; ekonomi ana risk değil

---

## 10. Öneriler (5 aksiyon)

1. **Zindan gold faucet −30~40%** — en büyük kaynak; KO'da end-game grind kısıtlı olmalı
2. **Global repair/enhancement fail tax** — her combat/craft döngüsünde %2-5 altın yakımı
3. **NPC sell floor yükselt + shop markup** — shop ≥ NPC×1,5; satış anlamlı sink olsun
4. **Casual D7 quest hattı** — 15 dk session'da net gold **negatif** veya sıfıra yakın hedef
5. **Siege slot vergi** — hold başına günlük 5k-25k altın (guild treasury sink); faucet bonus ile dengele

---

## 11. QA Durumu (paralel)

| Test | Sonuç |
|------|-------|
| Horse race smoke | ✅ Parser fix OK |
| Unit smoke (`test/smoke/`) | 25 pass / 2 fail (audit coverage 92/350 — tam audit bekliyor) |
| Integration audit (önceki) | 76 pass / **14 fail** / 258 missing |
| PLAN_11 passives | ✅ |
| Exploit battery | ✅ 0% success |

---

## Tekrar çalıştırma

```bash
# Ekonomi sim (1000 bot hızlı)
./scripts/run_comprehensive_smoke_10k.sh 1000 30

# Tam 10k
./scripts/run_comprehensive_smoke_10k.sh 10000 30

# At yarışı
./scripts/run_horse_race_fairness_smoke.sh 500

# Tam QA audit
./scripts/bootstrap_qa_accounts_from_db.sh 20
./scripts/run_full_action_audit.sh
./scripts/run_nightly_qa.sh
```

---

*Rapor otomatik üretildi — sim + Supabase MCP + mevcut smoke JSON.*

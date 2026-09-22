# Lonca Savaşı — Küçük Lonca Ezilme Smoke Raporu

**Tarih:** 2026-07-29  
**Amaç:** Plandaki güç-garnizon + lider saldırı modelinde küçük loncaların ezilip ezilmediğini ölçmek; ezilme varsa alternatifleri karşılaştırmak.  
**Ham veri:** `reports/guild_war_small_guild_crush_smoke.json`  
**Script:** `scripts/guild_war_small_guild_crush_smoke.py` (üretim DB’ye yazmaz — Monte Carlo)

> Plan dosyası (`bolge_gelir_fetih_savunma_kasa.plan.md`) **değiştirilmedi**. Bu rapor ayrı inceleme notudur.

---

## 1. Özet karar

| Soru | Cevap |
|------|--------|
| Küçük loncalar eziliyor mu? | **Evet — canlı formülle eziliyor.** |
| Canlı senaryo verdict | `FAIL_CRUSH` |
| Micro+small (popülasyonun %50’si) toprak payı | **%0** (30 gün sonunda) |
| Mega crush index (land/pop) | **3.94×** |
| Territory Gini | **0.83** (çok eşitsiz) |

**Sonuç:** Hissin doğru. Σ `users.power` tabanlı saldırı/savunma + düz maliyet ekonomisi → büyük kadro + yüksek ortalama güç loncaları haritayı süpürüyor. Sadece ROI maliyeti / soft-cap / vergi ile düzelmiyor; **güç toplama kuralı** değişmeli.

---

## 2. Simülasyon kurulumu

### 2.1 Popülasyon

| Tier | Üye aralığı | Lonca sayısı | Power band (canlı-benzer) |
|------|-------------|--------------|---------------------------|
| micro | 2–5 | 70 | weak |
| small | 6–12 | 90 | avg |
| mid | 13–25 | 80 | avg |
| large | 26–40 | 50 | strong |
| mega | 41–50 | 30 | elite |
| **Toplam** | | **320** | |

### 2.2 Harita

- Canlı DB’den 7 bölge ekonomisi kopyalandı (2026-07-29 linked):

| Zone | Gelir/gün | `attack_gold_cost` (canlı) | base_def |
|------|-----------|----------------------------|----------|
| 1 Demir Kalesi | 12M | **10M flat** | 1000 |
| 2 Altın Ovası | 14M | 10M | 800 |
| 3 Ejderha Tepesi | 16M | 10M | 2500 |
| 4 Karanlık Liman | 18M | 10M | 600 |
| 5 Cehennem Kapısı | 20M | 10M | 3000 |
| 6 Gökyüzü Burcu | 22M | 10M | 3800 |
| 7 Efsanevi Sınır | 25M | 10M | 4800 |

- Ölçek: 12 kopya → **84 territory** (320 lonca için rekabet alanı).
- Süre: **30 gün**, lonca başına günde max 2 saldırı.
- Grace: 1 gün (canlı 2 saat’in ayrık vekili).

### 2.3 Canlı savaş formülü (approx)

Kaynak: linked `attack_guild_war_territory`:

```
atk = leader.power + Σ(support_pledge)
def = garrison_share + gem_defense_boost
success = (random() * atk) > (random() * max(def, 1))
```

Simülasyonda:

- Support ≈ üyelerin %85’i pledge eder.
- Garrison: 1 üye → 1 bölge kuralı → güç `owned` sayısına bölünür.
- Unowned: `base_defense_power`.

---

## 3. Ana bulgular — senaryo A (canlı)

### 3.1 Tier sonuçları

| Tier | Lonca | Win% | Toprak payı | Gelir payı | Topraklı lonca |
|------|-------|------|-------------|------------|----------------|
| micro | 70 | 6.2% | **0%** | 0% | 0/70 |
| small | 90 | 17.9% | **0%** | 0% | 0/90 |
| mid | 80 | 35.2% | 16.7% | 12.9% | 12/80 |
| large | 50 | 57.8% | **46.4%** | 44.2% | 29/50 |
| mega | 30 | 67.7% | **36.9%** | 42.9% | 25/30 |

**Crush index** = toprak_payı / popülasyon_payı:

| micro | small | mid | large | mega |
|-------|-------|-----|-------|------|
| 0.00 | 0.00 | 0.67 | **2.97** | **3.94** |

### 3.2 Neden eziliyor? (kök nedenler)

1. **Σ power snowball**  
   50 kişilik lonca atk/def havuzu ≈ 5×10 kişilik. Formül lineer toplama → sayı kazanır.

2. **Çift avantaj**  
   Gerçekte büyük loncalar hem daha kalabalık hem ortalama power band’i daha yüksek (elite recruit). Simde de `strong`/`elite` band kullandık → etki abartılı ama yön doğru.

3. **Ucuz saldırı (E1 — planda da var)**  
   Canlı maliyet sabit **10M**; günlük gelir 12–25M → ROI ~0.4–0.8 gün. Büyük lonca gelir biriktirir → spam saldırı. Küçük lonca ilk kayıptan sonra vault’u toplayamıyor.

4. **Gelir → güç döngüsü**  
   Toprak alan → gelir → daha çok saldırı → daha çok toprak. Gini(territory)=0.83.

5. **Sadece ROI artırmak yetmez**  
   Senaryo B (`cost = 1.75 × income`) küçükleri **daha kötü** etti: mid sıfırlandı, mega crush 6.6×. Pahalı savaş = sadece zengin (büyük) oynar.

---

## 4. Alternatif senaryolar

| # | Senaryo | Verdict | Micro+small toprak | Mega crush | Not |
|---|---------|---------|-------------------|------------|-----|
| A | Canlı (Σ power, flat 10M) | **FAIL_CRUSH** | 0% | 3.94 | Baseline |
| B | ROI 1.75× gelir | FAIL_CRUSH | 0% | 6.60 | Küçüğü boğar |
| C | Underdog + soft-cap def | FAIL_CRUSH | 0% | 7.11 | WR artar, toprak yine mega |
| D | Size bracket (±1 tier) | FAIL_CRUSH | 7% | 7.49 | Biraz nefes |
| E | Max 3 territory / lonca | FAIL_CRUSH | 0% | 7.62 | Mega hâlâ doldurur |
| F | Hybrid tax+underdog+cap4 | FAIL_CRUSH | 2% | 7.49 | Yetersiz |
| G | Power = **mean** (size-neutral) | FAIL_CRUSH | 0% | 10.7 | Elite avg hâlâ ezer |
| H | Power = sum/√size | FAIL_CRUSH | 0% | 9.14 | Yetersiz tek başına |
| I | **mean + bracket + cap3 + tax** | **PASS_IMPROVED** | **22.6%** | 8.13* | Küçük hayatta |
| J | Eşit quality + canlı Σ | FAIL_CRUSH | 9.5% | 2.67 | Sadece size bile ezer |
| K | Eşit quality + mean+bracket+cap | **PASS_IMPROVED** | **41.7%** | 5.59* | En adil yön |

\* Bracket altında mega kendi liginde biriktiği için crush index yüksek kalabilir; önemli metrik **küçük lonca toprak payı** ve **micro win%**.

### 4.1 İzolasyon testi (J)

Üye başına power band’i tüm tier’larda aynı (`avg`) yapılınca bile:

- micro+small toprak **%9.5** (hâlâ düşük)
- large+mega birlikte **%68** toprak

→ Sorun sadece “büyük lonca daha güçlü oyuncu çeker” değil; **Σ power kuralının kendisi** size avantajı üretiyor.

### 4.2 En iyi yön (K)

`mean power` + size bracket + territory cap + hafif gelir vergisi:

| Tier | Win% | Toprak | Gelir |
|------|------|--------|-------|
| micro | **50%** | **26%** | 26% |
| small | 49% | 15% | 15% |
| mid | 46% | 6% | 4% |
| large | 35% | 0%* | 0% |
| mega | 40% | 52% | 54% |

\* Bracket yan etkisi: large, mid↔mega arasına sıkışıp mega’ya yem olabiliyor. Bracket tasarımı ince ayar ister (ör. overlapping bands veya power-MMR).

---

## 5. Önerilen çözüm paketi (implementasyon yönü)

Planda “Σ garnizon power” doğru his (tutmak = adam koymak) ama **cross-size açık savaş** küçük loncayı öldürür. Öneri: hibrit.

### 5.1 Mutlaka (P0)

1. **Saldırı eşleştirme bandı (size veya power MMR)**  
   Lonca sadece ±1 size tier veya benzer `total_power` / `avg_power` bandındaki hedeflere saldırabilsin (veya band dışı saldırıda ağır vergi / win% soft-cap).

2. **Atk/Def agregasyonunu yumuşat**  
   Seçenekler (tercih sırası):
   - **A)** `effective = mean(member_power)` × `f(garrison_fill)`  
   - **B)** `effective = Σ power / sqrt(n)` (azalan getiri)  
   - **C)** Soft-cap: `def_eff = min(def, atk * 2.5)` + underdog bonus

3. **`attack_gold_cost` = f(income) ama vault gate adil**  
   Plan §7: ~1.5–2× günlük gelir.  
   Ek: ilk N saldırı/gün küçük loncaya maliyet indirimi **veya** başarısız saldırıda kısmi iade (grief koruması).

4. **Territory soft-cap**  
   Lonca başına 2–3 bölge soft limit (4+ için savunma −% / saldırı maliyeti +%). Çok bölge = güç bölme zaten var; cap snowball’u keser.

### 5.2 Güçlü ek (P1)

5. **Koruma ligleri / starter zones**  
   Zone 1–2 sadece ≤12 üyeli loncalara açık (veya rank_score bandı).

6. **Gelir paylaşım / anti-hoard**  
   Günlük gelirin %5–10’u “zayıf yarı” kasalarına redistrib (Clash prize dışındaki soft balance). Simde tek başına yetmedi; P0 ile birlikte işe yarar.

7. **Clash / turnuva ayrı MMR**  
   Açık harita ≠ turnuva. Turnuvada bracket zaten size/MMR ile kurulmalı (plan §16 ile uyumlu).

### 5.3 Yapma

- Sadece ROI’yi yükseltmek (B) → küçük lonca savaş dışına itilir.  
- Sadece underdog WR buff (C) → toprak sahipliği düzelmiyor.  
- Sadece mean (G) → elite ortalama hâlâ eziyor; **bracket şart**.

---

## 6. Canlı sistemle ilişki (plan checklist)

| Plan riski | Bu smoke | Öneri |
|------------|----------|--------|
| E1 ucuz ROI (~%5 / flat 10M) | Doğrulandı; B tek başına zararlı | 1.5× income **+** küçük lonca safety net |
| C1 full-power her bölge | Garrison split modellendi; tek bölgede kalın duvar mega lehine | Split kalsın + cap |
| Σ power = savunu | Doğru his, adil değil | mean/√n + bracket |
| Küçük lonca hissi | FAIL_CRUSH | P0 paketi |

---

## 7. Tekrar üretme

```bash
python3 scripts/guild_war_small_guild_crush_smoke.py
# → reports/guild_war_small_guild_crush_smoke.json
```

Parametreler: `SEED=20260729`, `N_GUILDS=320`, `N_DAYS=30`, `MAP_COPIES=12`.

---

## 8. Net tavsiye (1 paragraf)

**Canlı / plan-as-is model küçük loncayı eziyor.** 320 loncalık smoke’ta micro+small (%50 pop) 30 günde **hiç toprak tutamadı**. Düzeltme: (1) size/MMR bracket, (2) Σ yerine mean veya √n güç, (3) territory soft-cap, (4) ROI’yi gelir oranlı yaparken küçük loncaya saldırı erişimi koru. En iyi sim sonucu: **K = equal-quality + mean + bracket + cap** → küçük toprak payı %42’ye çıktı. Sonraki adım: bu P0 kurallarını migration + Flutter preview’a döküp QA smoke’u RPC seviyesinde tekrarlamak.

---

## 9. L senaryosu — anıt size tersi atk bonusu (shipped)

**Config:** `L_monument_inverse_atk`  
**Formül:** `effective_atk = CEIL(raw_atk / guild_size_multiplier(size))` — sadece saldırı; def aynı.

| Metrik | A (pre-bonus canlı Σ) | L (monument inverse atk) | Yön |
|--------|----------------------|--------------------------|-----|
| Verdict | `FAIL_CRUSH` | `FAIL_CRUSH` | Hâlâ crush (bilinçli scope) |
| Micro win% | 6.2 | **19.3** | ↑ |
| Small win% | 17.9 | **37.4** | ↑ |
| Micro+small toprak payı | **%0** | **%15.5** | ↑ |
| Mega toprak payı | %36.9 | %32.1 | ↓ hafif |
| Mega win% | 67.7 | 67.2 | ≈ aynı |

**Okuma:** Küçük lonca saldırıda nefes alır (win% + land ↑). Mega hâlâ güçlü — savunma buff yok → tam ezilme çözümü değil; plan kapsamı bilinçli. Bracket/mean ayrı iş.

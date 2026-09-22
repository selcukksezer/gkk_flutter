# Zone level-gate smoke — 100 karakter

**Tarih:** 2026-07-31  
**Script:** `scripts/zone_level_gate_smoke_100chars.py`  
**Çıktı:** bu klasör (`characters.csv`, `attempts.csv`, `access_matrix.csv`, `summary.json`)  
**Verdict:** **HEALTHY** — sağlıklı level atlama (dungeon-only alt sınır)

---

## 1. Method

1. Live Supabase’ten okundu (`project-0-gkk_flutter-supabase`):
   - `public.dungeon_zones` → required_level gates
   - `public.dungeons` → `xp_reward`, `energy_cost`, `power_requirement`, `zone`
   - `public.xp_needed_for_level(n)` → `floor(100 * n * (1 + n * 0.15))`
   - `users.max_energy` ort. ≈ **100**
2. Gate modeli = `dungeon_zone_level_gate_error`: `player.level < zone.required_level` → deny (`zone_level_gate`).
3. **100** karakter (seed `20260731`): level 1–70 yayılımı + gate kenarı ağırlığı (14/15/24/25/…).
4. Her karakter ~8 dungeon denemesi: açık zone + kilitli zone karışık → **789** attempt.
5. Softlock tanımı (bilinçli dar):
   - **FAIL** = pre-gate penceresinde (≥ gate−3) next-gate’e ≥10 gün full-energy farm **veya** açık dungeon yok
   - **WARN** = pre-gate’te ≥4 gün **veya** tek level-up ≥2 gün dungeon-only
   - 10-level band clear süresi softlock sayılmaz (pacing bilgisi)

### Assumptions (açık)

| Varsayım | Değer |
|----------|--------|
| Farm | Her zaman en yüksek XP’li **açık** dungeon |
| XP | Sadece `dungeons.xp_reward` — monument / farm / class mult **yok** |
| Diğer XP | Quest / craft / arena **modellenmedi** → dungeon-only **alt sınır** |
| Power | Zone gate enforce etmez; `power_proxy` sadece ipucu (level×5500 ±25%) |
| Ölüm / hastane | Yok |
| Energy | 100/gün, refill varsayımı |

---

## 2. Live gates + zone XP

| Zone | Ad | Dungeons | required_level | XP min–max (avg) |
|------|-----|----------|----------------|------------------|
| Z1 | Gölgeli Orman | 1–10 | **1** | 30–160 (87) |
| Z2 | Derin Mağara | 11–20 | **15** | 180–470 (306) |
| Z3 | Ateş Çölü | 21–30 | **25** | 520–1200 (821) |
| Z4 | Fırtına Dağı | 31–40 | **35** | 1320–3080 (2089) |
| Z5 | Yeraltı Cehennemi | 41–50 | **45** | 3380–7960 (5385) |
| Z6 | Kırık Gökyüzü | 51–60 | **55** | 8760–20650 (13949) |
| Z7 | Efsanevi Tehlikeler | 61–65 | **65** | 22700–33200 (27720) |

Level cap: **70**.

---

## 3. Access matrix (level band)

| Level band | Açık zone | Enterable dungeon # | Next gate |
|------------|-----------|---------------------|-----------|
| 1–14 | Z1 | 10 | Z2@15 |
| 15–24 | Z1–Z2 | 20 | Z3@25 |
| 25–34 | Z1–Z3 | 30 | Z4@35 |
| 35–44 | Z1–Z4 | 40 | Z5@45 |
| 45–54 | Z1–Z5 | 50 | Z6@55 |
| 55–64 | Z1–Z6 | 60 | Z7@65 |
| 65–70 | Z1–Z7 | 65 | — |

Tam satır satır: `access_matrix.csv`.

---

## 4. Pre-gate softlock stress (en kritik)

Full-energy, best open dungeon → next gate (son level = gate−1):

| Level | Open zones | Best farm | XP/run | Gün → next level = next gate | Softlock |
|------:|------------|-----------|-------:|-----------------------------:|----------|
| 14 | Z1 | dng_010 | 160 | **2.26** | WARN_SLOW_LEVEL |
| 24 | Z1–2 | dng_020 | 470 | **2.94** | WARN_SLOW_LEVEL |
| 34 | Z1–3 | dng_030 | 1200 | **3.46** | WARN_SLOW_LEVEL |
| 44 | Z1–4 | dng_040 | 3080 | **2.71** | WARN_SLOW_LEVEL |
| 54 | Z1–5 | dng_050 | 7960 | **3.09** | WARN_SLOW_LEVEL |
| 64 | Z1–6 | dng_060 | 20650 | **1.64** | OK |

**Sonuç:** Hiçbir pre-gate kenarı FAIL değil. En yavaş kenar **Lv34 → Z4@35 ≈ 3.5 gün** dungeon-only. İçerik var (10–60 dungeon); dead zone / hard softlock yok.

### Band clear pacing (bilgi — softlock değil)

Dungeon-only, band başı → next gate:

| Start Lv | → Gate | Gün (alt sınır) |
|---------:|--------|----------------:|
| 1 | Z2@15 | 13.4 |
| 15 | Z3@25 | 20.7 |
| 25 | Z4@35 | **26.9** (en uzun) |
| 35 | Z5@45 | 22.3 |
| 45 | Z6@55 | 26.3 |
| 55 | Z7@65 | 14.3 |
| 65 | — | 0 |

Quest/craft/arena eklenince gerçek süre daha kısa.

---

## 5. 100 karakter özeti

| Metrik | Değer |
|--------|------:|
| Karakter | 100 |
| Unique level | 59 / 70 |
| Attempt | 789 |
| ALLOW_OK | 424 |
| DENY_OK | 365 |
| **False positive** (low→high zone) | **0** |
| **False negative** (high wrongly blocked) | **0** |
| Softlock OK / WARN / FAIL | 54 / 46 / **0** |
| Her karakter farm yapabilir? | **Evet** (`can_always_farm`) |

Band dağılımı (chars): Z1-only 22 · Z1–2 15 · Z1–3 13 · Z1–4 15 · Z1–5 14 · Z1–6 10 · all 11.

WARN kırılımı: `WARN_SLOW_LEVEL` 31 · `WARN_SLOW_TO_GATE` 15 (pre-gate penceresi 3 level — beklenen pacing uyarı, softlock değil).

Tam tablo: `characters.csv`. Attempt log: `attempts.csv`.

### Power proxy (zone gate dışı)

Allowed attempt’lerin **47/424**’ünde `power_proxy < power_requirement`. Bu zone gate bug’ı değil; combat/power progression ayrı risk. Smoke power’ı enforce etmedi.

---

## 6. Gap analysis (sorulan senaryolar)

| Soru | Cevap |
|------|--------|
| Lv14 sadece Z1 stuck? | Z1 açık (10 dungeon). dng_010 farm → ~2.3g → Lv15. Softlock **yok**. |
| Lv24 sadece Z1–Z2? | 20 dungeon. dng_020 → ~2.9g → Lv25. Softlock **yok**. |
| Lv34 / 44 / 54? | Aynı pattern; en kötü Lv34 ≈ 3.5g. |
| High level yanlış block? | FP/FN = 0. Gate contract temiz. |
| Low level high zone? | 0 false positive. |

---

## 7. Pass / fail — “sağlıklı level atlama”

| Kriter | Sonuç |
|--------|--------|
| Server gate doğru (FP=0, FN=0) | PASS |
| Her level’de XP farm içeriği | PASS |
| Pre-gate softlock FAIL | PASS (0) |
| Catastrophic dead zone | YOK |
| **GENEL** | **HEALTHY / PASS** |

Uyarılar (PASS bozmaz):
- Pre-gate tek level dungeon-only çoğu yerde 2–3.5 gün → grind hissi olabilir.
- Z3 band (25→35) dungeon-only ~27 gün → pacing uzun; diğer XP kaynakları şart.
- Power yetersizliği zone açılsa bile farm’ı fiilen kesebilir (ayrı balance konusu).

---

## 8. Threshold tweak önerisi

**Production threshold değişikliği: YOK.** Softlock catastrophic değil; evidence FAIL=0.

İsteğe bağlı (sadece pacing hissi için, zorunlu değil):

1. **Z4 required_level 35 → 32/33** — Lv25–34 band clear kısalsın (en uzun dungeon-only band).
2. Veya Z3 max XP / energy verimliliğini artır (dng_028–030) — gate düşürmeden Lv34 kenarını yumuşatır.
3. Z1→Z2 (1→15) zaten makul (13.4g dungeon-only); dokunma.

Öncelik: önce quest/craft XP’nin gerçek pacing’e katkısını ölç; sonra threshold’a bak.

---

## 9. Re-run

```bash
python3 scripts/zone_level_gate_smoke_100chars.py \
  --out reports/zone_level_gate_smoke_100chars_20260731
```

DB değişince: script içindeki `ZONES` / `DUNGEONS_RAW` snapshot’ını MCP `execute_sql` ile yenile, tekrar koş.

---

## 10. Appendix dosyalar

| Dosya | İçerik |
|-------|--------|
| `characters.csv` | 100 profil + farm metrik |
| `attempts.csv` | 789 enter sim |
| `access_matrix.csv` | Lv1–70 zone/dungeon erişim |
| `summary.json` | Makine-okur verdict + aggregates |

# Stat Enflasyonu — Denge Planı (İnceleme)

**Tarih:** 2026-07-31  
**Rol:** Lead systems / balance  
**Kapsam:** Power / HP / DEF / Luck / ATK — gear + enhance + sınıf + allocate  
**Durum:** IMPLEMENTED 2026-07-31 — Faz 0+1+2 live (bkz. §10)  
**Kanıt:** canlı Supabase MCP + client formüller (`power_formula.dart`, `enhancement_stats.dart`)  
**İlgili:** `reports/power_spike_smoke_20260731/RAPOR.md` (luck×50 double-count fix — ayrı bug)

---

## 0. Executive summary

| Soru | Cevap |
|------|--------|
| Luck 45k nereden? | **Model A bake:** mythic gear luck × enh → `users.luck` |
| Power 2.5M bug hâlâ var mı? | **Hayır** (fix sonrası). `theking` live power ≈ **302k** |
| Asıl kırılma | Sheet ATK/DEF/HP/Luck **gösterim + farm input** şişmesi; +10 → ladder tavanı |
| Softcap hospital/gold | **Canlıda var** — ama 45k zaten softcap’i çoktan aşmış (fayda doygun) |
| Set bonus var mı? | **Yok** — “set” = 8 slot toplamı |

**Tek satır:** Power formülü düzeldi; **karakter sheet + loot luck hâlâ gear’ı 1:1 bake ediyor** → 45k luck / 186k HP hissi. Luck **asla 45k bandına çıkmamalı** (gösterim + efektif farm).

---

## 1. Problem diagnosis

### 1.1 Formül haritası (bugünkü gerçek)

```
enhanced_stat(base, enh) = floor(base × (1 + enh × 0.15))
  +0 → ×1.00 … +4 → ×1.60 … +10 → ×2.50

item_power = (atk + def + hp/10 + luck×2) × enh_mult

users.equip_bonus_* = Σ enhanced_stat(item.*, enh)   // 8 slot
users.attack/defense/max_health/luck = base_* + equip_bonus_*

total_power =
    Σ item_power × monument_stat_mult
  + level × 500
  + reputation × 0.1
  + (users.luck − equip_bonus_luck) × 50 × monument_stat_mult
```

| Kaynak | Dosya / RPC |
|--------|-------------|
| Client enh | `lib/core/utils/enhancement_stats.dart` |
| Client power / dungeon % | `lib/core/utils/power_formula.dart` |
| Equip bake | `sync_user_equipment_stats` (`20261016_100000_…`) |
| Server power | `calculate_user_total_power` (`20261016_130000_…` — equip luck hariç) |
| Stat point | `allocate_stat_points` — ATK/DEF/Luck +1; HP ×10 |
| Sınıf/level | `character_classes.*_per_level` (warrior ATK+3/DEF+2/HP+15/Luck+1) |

**Not:** Ayrı “set bonus” tablosu yok. Full set = 8 slot sum.

### 1.2 Whale örnek — `theking` (canlı 2026-07-31)

| Alan | Değer | Not |
|------|------:|-----|
| level / class | 70 / warrior | |
| power (stored = live) | **302,026** | double-count fix sonrası |
| `users.luck` | **45,305** | sheet’te görünen |
| `equip_bonus_luck` | **45,221** | neredeyse tamamı gear |
| base luck (luck − eq) | **84** | class + allocate (~14) + level |
| attack / defense | 74,019 / 78,963 | eq ≈ 73.8k / 78.8k |
| max_health | **185,641** | eq HP ≈ 184,396 |
| gear | 8× **mythic +4** | base luck sum **28,265** |

**45k yolu (sayısal):**

```
Σ mythic base luck (8 slot) = 28,265
× +4 enh (1.60)             = 45,224 ≈ equip_bonus_luck
+ base ~84                  = users.luck ≈ 45,305
```

**+10 projeksiyon (aynı set, enh=10):**

| Metrik | +4 (şimdi) | +10 (proj) | Δ |
|--------|----------:|-----------:|---|
| equip luck | 45,221 | **~70,661** | ×2.5 / ×1.6 |
| equip ATK / DEF | 74k / 79k | **~115k / ~123k** | |
| equip HP | ~184k | **~288k** | |
| Σ item_power | ~261k | **~409k** | ×1.563 |
| approx total power (Lv70) | ~302k | **~450k+** | ≈ `dng_065` tavan |

→ +10 full mythic ≈ **tüm dungeon ladder’ı power ile ezme**. “Ölümsüz set” hissi haklı.

### 1.3 Luck zinciri — nerede besleniyor?

| Sistem | Formül | Softcap | 45k’da ne olur? |
|--------|--------|---------|-----------------|
| Dungeon success luck | `+ luck×0.001` | **+5% @ luck≥50** | Zaten max (50’de doygun) |
| Hospital risk | `× (1 − luck×0.003)` | **−30% @ luck≥100** | Canlıda capped (`20260731_223000_…`) |
| Gold loot | `× (1 + luck×0.002)` | **+100% @ luck≥500** | Canlıda capped (`20260731222000_…`) |
| XP loot | `× (1 + luck×0.001)` | **+100% @ luck≥1000** | Cap uygulandı (gold patch ile) |
| Power luck terimi | `base_luck×50` | yok (ama equip hariç) | **84×50 ≈ 4.2k** — sağlıklı |
| Loot rarity shift | `LEAST(0.10/0.20, luck×…)` | mevcut smoke | Cap’ler erken doygun |
| Codex / monument | +küçük (≤11 / loot bonus) | küçük | ihmal |

**Kritik etkileşim:** Hospital/gold **cap’lendi** → 45k luck farm’da ekstra vermez. Ama:

1. UI / liderlik / “karakter gücü” dili 45k gösteriyor → **oyun doğası kırık**.
2. Gelecek uncapped `users.luck` kullanımı (yeni RPC) → anında patlar.
3. Client `calculateDungeonSuccessPercent` hâlâ `profile.luck` (45k) geçiyor — softcap sayesinde % aynı, ama semantik yanlış.

### 1.4 HP / DEF / ATK enflasyonu

- PvE başarı **çoğunlukla `power`** (`attack_dungeon` / `enter_dungeon` power oranı).
- `users.attack/defense` power formülüne **girmez** (sadece item_power sum).
- Buna rağmen sheet’te 74k ATK / 79k DEF / 186k HP → “ölümsüz” hissi + gelecekteki gerçek combat formülleri için zehir.
- Guild war: `power` snapshot; hasar ≈ `% max_health` → yüksek HP = büyük mutlak sayı, oran aynı. Yine de UI korkutucu.

### 1.5 Stat allocate / gem — şişirme kaynağı mı?

| Kaynak | Üst sınır (Lv70) | vs gear |
|--------|------------------|---------|
| Stat points | `(70−1)×3 = 207` pt | ATK/DEF/Luck +207 max — **ihmal** |
| HP allocate | ×10 → +2070 HP | vs 184k gear — **ihmal** |
| Class growth (warrior) | ~207 ATK / 138 DEF / 1035 HP / 69 Luck | **ihmal** |
| Gem | Guild war attack/defense boost (geçici) | karakter sheet şişirmez |

→ Enflasyon **katalog mythic base + linear enh (0.15)** kaynaklı; allocate değil.

### 1.6 PvE vs PvP eğri (kısa)

| | PvE (dungeon) | PvP (guild war) |
|--|---------------|-----------------|
| Ana skor | `users.power` vs `power_requirement` | `power` sum / garrison |
| Luck | success +5% softcap; loot/hospital softcap | yok / dolaylı |
| Ladder tavan | `dng_065` = **450k** | sezon / territory |
| +4 mythic whale | ~302k → Z4 net, Z5 zor | güçlü garrison |
| +10 mythic | ~450k → **ladder bitti** | baskın |

PLAN_06 hedefi: yıl sonu power ~450k, +10 nadir. **Bugün +4 whale zaten ~302k; +10 = tasarım tavanı.**

---

## 2. Goals (hedef bantlar)

| Metrik | Hedef bant | Gerekçe |
|--------|------------|---------|
| **Görünen / efektif farm luck** | Endgame **≤ 800–1,200** (hard ceiling önerisi **1,500**) | Softcap’ler 50–500’de doygun; 45k anlamsız |
| **Base luck (class+allocate)** | Lv70 ≈ **50–250** | Şimdi theking 84 — OK |
| **Equip luck (ham, bake öncesi)** | Full mythic +10 set **≤ ~600–900** ham veya softcap sonrası efektif ≤1200 | Katalog veya DR |
| Dungeon success luck katkısı | Max **+5%** kalsın; doygunluk **luck≈50–100 efektif** | Mevcut niyet |
| Hospital luck mitigation | Max **−30%**; doygun **≤100 efektif** | Cap zaten var |
| Gold luck mult | Max **+100%**; doygun **≤500 efektif** | Cap zaten var |
| Mythic +4 total power | **220k–320k** (şimdiki ~302k kabul edilebilir) | Z4–Z5 arası |
| Mythic +10 total power | **380k–420k** — ladder’ı **zorlar, ezmez** | `dng_065=450k` üstünde değil |
| Sheet HP (full mythic +10) | **≤ ~40k–60k** (şimdi 288k proj) | “Ölümsüz” hissini kır |
| Sheet ATK/DEF | Power ile orantılı okunabilir; **5 haneli mid OK, 6 hane sınır** | UX |
| Immortal +10 | Yasak: tek set ile tüm zone farm + hospital neredeyse 0 risk | Risk + loot hâlâ anlamlı |

---

## 3. Option A / B / C

### Option A — Softcap / diminishing returns (efektif luck & farm)

**Ne:** Ham gear luck kalsın veya kısmen kalsın; **her farm/combat formülünde** `effective_luck = softcap(base + f(equip))`.

Örnek sketch:

```
effective_luck = base_luck
  + 400 * (1 - exp(-equip_luck / 800))   -- asymptote +400
-- veya piecewise:
-- 0–200: 100%, 200–600: 40%, 600+: 10%, hard cap 1200
```

Hospital/gold/success **zaten** ayrı softcap’li; A bunları **tek `effective_luck()`** altında birleştirir + UI’da efektif gösterir.

| Artı | Eksi |
|------|------|
| Whale gear silinmez | Sheet hâlâ yüksek ham sayı gösterebilir (UI netleştirilmezse) |
| Hızlı SQL patch | Yeni sistem her RPC’ye bağlanmalı |
| Geri alınabilir | “Gerçek luck 45k ama efektif 900” karmaşası |

### Option B — Enhance eğrisini yeniden ayarla + katalog sıkıştır

**Ne:**

1. `enh_mult = 1 + enh×0.15` → örn. `1 + enh×0.10` veya piecewise (`+7` sonrası yavaş).
2. Mythic (ve belki legendary) **base luck/HP** ×0.25–0.40 retune.
3. İsteğe bağlı: power içinde `luck×2` → `luck×0.5`.

| Artı | Eksi |
|------|------|
| Kök nedeni (katalog) vurur | Mevcut whale’lar sert düşer → öfke |
| +10 ladder’ı korur | Büyük content retune + smoke |
| Sheet sayıları da düzelir | Enhance ekonomisi (maliyet algısı) sarsılır |

### Option C — Combat vs farm stat ayrımı + bake kaldırma

**Ne:**

1. `users.luck` = **sadece** class + allocate (+ küçük buff). Gear luck **bake etme**.
2. Farm: `loot_luck = f(equipped item luck)` ayrı kolon / runtime sum.
3. Combat power: mevcut `item_power` (luck×2 içerir) kalsın veya farm luck’ı power’dan çıkar (`luck×2` → 0 veya küçük).
4. UI: “Savaş gücü” vs “Yağım şansı” iki sayı.

| Artı | Eksi |
|------|------|
| 45k **asla** `users.luck` olmaz | Model A sync refactor |
| Gelecek bug yüzeyi küçülür | Client + tüm loot RPC |
| Tasarım dili net | Kısa vadede en çok iş |

### Karşılaştırma

| | Hız | Kalıcılık | Whale acısı | UX netliği |
|--|-----|-----------|-------------|------------|
| A Softcap | ★★★★ | ★★☆ | düşük | orta |
| B Retune | ★★ | ★★★★ | yüksek | yüksek |
| C Ayrım | ★★ | ★★★★★ | orta (gösterim düşer) | yüksek |

---

## 4. Recommended plan (fazlı)

**Öneri: C (mimari) + A (hemen koruma) + B (hafif, sonra).**  
Saf B ile katalog wipe → son çare.

### Faz 0 — Koruma (1–2 gün, SQL ağırlıklı) — **önce**

1. Tek helper: `effective_player_luck(p_user)` =
   `base_luck + softcap(equip_bonus_luck)` (hedef asymptote ~400–600, hard ≤1200).
2. `enter_dungeon` / loot / hospital / success **hepsi** bu helper’ı kullansın (cap’ler kalsın; girdi zaten sıkışmış olur).
3. Client preview aynı helper sabiti (veya RPC).
4. **Whale:** gear silinmez; görünen ham luck geçici olarak yüksek kalabilir — toast/tooltip: “Etkin şans: X”.

**Migration vs client:** Server authoritative; client mirror. Sync bake’e henüz dokunma.

### Faz 1 — Bake kaldırma / Model A düzelt (3–5 gün) — **asıl fix**

1. `sync_user_equipment_stats`: `users.luck/attack/defense/max_health` **base only** tut **veya** UI için ayrı `display_*` view.
   - Tercih: combat sheet = base + “ekipman katkısı” satırları (toplam ayrı).
   - `users.luck` ≤ ~few hundred.
2. Loot path: equipped sum veya `equip_bonus_luck` kolonunu **sadece loot** için oku (power’a değil).
3. Backfill: tüm user `luck = luck - equip_bonus_luck` (zaten track var); sonra `equip_bonus_luck` loot-only semantiği.
4. Client: character panel split; power badge değişmez (zaten base_luck).

**Whale handling (Faz 1):**

| Strateji | Tavsiye |
|----------|---------|
| Grandfather 45k luck | **Hayır** — hedef ihlali |
| Softcap forever | Faz 0 için OK, uzun vadede yetmez |
| Respec scroll | Allocate için yeterli; gear için gerekmez |
| Görünür sayı düşüşü | **Şeffaf patch notu** + “etkin şans aynı/üstünde softcap” |

### Faz 2 — Eğri / katalog (1 hafta, sezon içi)

1. Enhance: `0.15 → 0.12` **veya** `+8..+10` için `0.08` (düşük riskli piecewise).
2. Mythic base **luck** ×0.35, **health** ×0.40 (attack/def daha hafif ×0.70 — power ladder’ı koru).
3. Smoke: `item_enhancement_matrix`, `late_dungeon_luck_loot`, power spike replay.
4. Hedef: mythic +10 total power **≤ 420k**.

### Faz 3 — Telemetry & PvP (sürekli)

1. Dashboard: p50/p90 `users.luck`, `equip_bonus_*`, power vs dungeon clear.
2. Guild war: power dağılımı; gerekirse garrison softcap.
3. PLAN_06 power tavanı (450k) ile uyum kontrolü.

**Yapma (şimdi):** toplu dungeon `power_requirement` ×N; full enhance economy wipe; allocate nerf.

---

## 5. Target formula sketches (tartışma)

### 5.1 Effective luck (Faz 0/1)

```
base_luck      = class + allocate + level gains          -- ~50–250
equip_luck_raw = Σ floor(item.luck × (1 + enh×k))       -- ham

equip_luck_eff = 500 * (1 - exp(-equip_luck_raw / 1000))
                 -- raw 0 → 0; raw 28k → ~500; raw ∞ → 500

effective_luck = min(1500, base_luck + equip_luck_eff)

-- mevcut sink’ler:
success += min(0.05, effective_luck * 0.001)
hospital *= (1 - min(0.30, effective_luck * 0.003))
gold     *= (1 + min(1.0, effective_luck * 0.002))
```

### 5.2 Enhance piecewise (Faz 2 opsiyon)

```
mult(enh) =
  enh <= 6: 1 + enh * 0.12          -- +6 → 1.72
  enh <= 10: 1.72 + (enh-6) * 0.08  -- +10 → 2.04
-- eski +10 = 2.50 → ~%18 daha düşük item power
```

### 5.3 Katalog sıkıştır (Faz 2)

```
new_mythic_luck   = round(old * 0.35)   -- boots 5666 → ~1983
new_mythic_health = round(old * 0.40)
-- full set +4 luck raw: 28k → ~10k → effective_luck ~400–500 band
```

### 5.4 Power (koru, luck ağırlığını ayır)

```
item_power = atk + def + hp/10 + luck_combat
luck_combat = item.luck * 0.5   -- eski *2 idi; farm luck ayrı

total_power = Σ item_power * monument
            + level*500 + rep*0.1
            + base_luck*50 * monument
```

*(luck_combat katsayısı debate konusu — 0.5 vs 1.0.)*

### 5.5 +10 immortal testi (kabul kriteri)

| Test | Pass |
|------|------|
| Mythic +10 power | `< 430k` |
| `dng_065` success @ o power | `< 90%` (ezme yok) |
| `users.luck` sheet | `< 1500` |
| Hospital @ fail | risk hâlâ hissedilir (mitigation ≤30%) |
| Gold @ cap | ≤ ×2 base — zaten |

---

## 6. Risks

| Alan | Risk | Mitigasyon |
|------|------|------------|
| **Ekonomi** | Luck softcap → whale gold aynı (zaten cap); katalog nerf → market mythic fiyat düşer | Fazlı; market izle |
| **PvP** | Power düşerse garrison zayıflar | Power formülünü Faz 2’ye kadar sabitle; önce luck UI/farm |
| **Dungeon** | Power retune ladder’ı zorlaştırır | `power_requirement` şimdi **yükseltme**; 1 hf telemetry |
| **Hospital** | Cap var; efektif luck düşünce risk artar | Bilinçli — “ölümsüz” bitmeli; ilk 3 dungeon 0 kalsın |
| **UX öfke** | 45k → 900 görünür düşüş | Patch notu + “etkin şans” + ham gear tooltip |
| **Double-count regresyon** | Bake geri gelirse power tekrar patlar | `equip_bonus` asla `luck×50`’ye girmez (test) |
| **Client/server drift** | Preview vs RPC | Tek helper + smoke |

---

## 7. Open questions (karar lazım)

1. **`users.luck` sheet’te ne görünsün?**  
   (a) Sadece base ≤250  
   (b) Base + efektif softcap  
   (c) Ham gear ayrı satır + etkin şans  
2. **Mythic katalog nerf oranı?** 0.35 luck / 0.40 HP önerisi OK mi, yoksa sadece luck?  
3. **Enhance:** global 0.15→0.12 mi, yoksa sadece +8..+10 piecewise mi?  
4. **Whale comms:** sessiz softcap mi, duyurulu respec/season reset mi?  
5. **Power içindeki `luck×2`:** kalsın mı, düşürülsün mü, farm’dan tamamen ayrılsın mı?  
6. **Hedef endgame luck tavanı:** 800 / 1200 / 1500 — hangisi marka dili?  
7. **PvP:** power snapshot’a dokunulsun mu bu sezon, yoksa sadece PvE/farm?  
8. **Mevcut +4 mythic (theking):** power ~302k “mid-end” kabul mü, yoksa katalog ile ~200k’ya mı çekilsin?

---

## 8. Kaynak indeksi

| Kanıt | Yer |
|-------|-----|
| Power double-count fix | `20261016_130000_fix_power_exclude_equip_luck.sql` + `power_spike_smoke_20260731` |
| Equip bake | `20261016_100000_equip_level_gate_stat_sync.sql` |
| Hospital luck cap | `20260731_223000_enter_dungeon_hospital_luck_cap.sql` |
| Gold/XP luck cap | `20260731222000_fix_enter_dungeon_gold_int_overflow.sql` |
| Enh formül | `lib/core/utils/enhancement_stats.dart` |
| Dungeon success | `lib/core/utils/power_formula.dart` |
| Enhance maliyet | `reports/ENHANCEMENT_SET_COST_TR.md` |
| Ekonomi hedef | `mdplans and prompts/PLAN_06_ECONOMY_BALANCE.md` |

---

## 9. Verdict (plan)

1. **45k luck = bug değil, Model A + mythic katalog × linear enh.**  
2. Softcap’ler farm’ı **çoktan doyurmuş**; sayı hâlâ oyun doğasını bozuyor.  
3. **Önerilen yol:** Faz 0 effective_luck → Faz 1 bake kaldırma (`users.luck` küçük kalsın) → Faz 2 hafif katalog/enhance.  
4. +10 set **ladder tavanına yapışmamalı** (~420k power altı).  
5. Implementasyon **bu dokümandan sonra**, karar soruları cevaplanınca.

---

## 10. IMPLEMENTED (2026-07-31)

**Path shipped:** Faz 0 + Faz 1 + Faz 2 (recommended C+A+B light). Live via Supabase MCP.

### Migrations (live)

| MCP name | Ne |
|----------|-----|
| `stat_inflation_phase0_1_effective_luck_unbake` | `equip_luck_effective`, `effective_player_luck`; `sync` luck unbake; luck backfill; `calculate_user_total_power` base luck; `enter_dungeon` wire |
| `stat_inflation_phase2a_enhance_catalog` | `enhancement_stat_multiplier` piecewise; `calculate_item_power` + `sync` use it; mythic ×0.35 luck / ×0.40 HP / ×0.70 ATK·DEF |
| `stat_inflation_phase2b_resync_equip_power` | set-based equip_bonus + power resync |

Repo mirrors: `supabase/migrations/20261017_200000_…`, `20261017_210000_…`.

### Client

- `lib/core/utils/effective_luck.dart` — mirror softcap
- `enhancement_stats.dart` — piecewise mult
- `power_formula.dart` — dungeon success uses effective luck; power uses base luck
- Character panel: **Etkin şans** (+ subtitle `baz N`)
- Dungeon hospital preview → effective luck

### Smoke — `theking` before → after

| Metrik | Önce | Sonra |
|--------|-----:|------:|
| `users.luck` | 45,305 | **84** |
| `equip_bonus_luck` | 45,221 | **14,642** |
| `effective_player_luck` | (n/a / softcap doygun) | **~584** |
| `power` | 302,026 | **174,840** |
| `max_health` | 185,641 | **69,469** |
| +10 power proj (same set) | ~450k+ | **~225k** |

Goals: sheet luck ≤1.5k ✅ · +10 power ≤420k ✅ · no immortal +10 ✅.

### Deferred / residual

- **Faz 3** telemetry / PvP garrison softcap — not shipped
- Sheet ATK/DEF still **baked** (luck unbaked; HP catalog cut further 2026-07-31 night — see below)
- Mythic +4 power ~173k **under** goal mid band 220–320k (catalog×0.70 + piecewise) — ladder safer; market mythic price may drop
- Open Qs unanswered → used RAPOR sketch defaults (hard 1500, piecewise, mythic ratios as written)
- ATK/DEF full Model-C unbake + display split — deferred
- `luck×2` → `luck_combat×0.5` power tweak — **not** applied (kept ×2)

### HP + potion follow-up (same day, post-smoke)

Live MCP `stat_inflation_hp_cut_potion_pct` (+ repo `20261017_230000_…`):

| Change | Effect (`theking`) |
|--------|---------------------|
| Mythic HP ×0.50 again | max_health 69,469 → **35,360** |
| Legendary HP ×0.40 | catalog parity (was tankier than mythic) |
| Potions → % max_hp | minor 25% / major 50% / supreme 100% / Restoratio 40% |
| Client | `heal_amount`→`health_restore`, % preview, tolerance (not addiction) |

+10 HP proj ~48k (band 40–60k ✅). Power −~1.5k (PvP soft). Full smoke: `SMOKE.md`.

# Power Spike Smoke — +4 Set → ~2.5M

**Tarih:** 2026-07-31  
**Workspace:** `/Users/selcuk/Documents/gkk-web/gkk_flutter`  
**Kanıt:** canlı Supabase MCP (`execute_sql` / `apply_migration`) + client formül  
**Kapsam:** power formülü, `sync_user_equipment_stats` etkileşimi, dungeon `power_requirement` ladder, smoke, öneri paketi

---

## 1. Executive summary

| Soru | Cevap |
|------|--------|
| +4 set → ~2.5M bug mu? | **BUG** — luck double-count |
| Epic set mi? | Canlı örnek (`theking`) = **mythic +4 full set** (8 slot), epic değil |
| Dungeon min yükselt? | **Hayır (şimdi).** Önce formül fix; ladder retune opsiyonel sonra |
| Fix uygulandı mı? | **Evet** — SQL canlı + client patch |

**Tek satır kök neden:** `sync_user_equipment_stats` gear luck’ı `users.luck`’a yazıyor → `calculate_user_total_power` `users.luck * 50` yapıyor → aynı luck zaten `calculate_item_power` içinde `luck * 2 * enh_mult` ile sayılmış → **~+2.2M sahte power**.

| Metrik | Buggy (pre-fix live fn) | Correct (post-fix) |
|--------|-------------------------:|--------------------:|
| `theking` power | **2,548,520** | **276,164** |
| Epic best-set +4 Lv25 | ~1,317,650 | **122,700** |
| Mythic best-set +4 Lv55 | ~3,592,870 | **331,770** |

---

## 2. Root cause

### Power formülü (doğru tasarım)

```
equipment = Σ calculate_item_power(item, enh)
           = Σ (atk + def + hp/10 + luck*2) * (1 + enh*0.15)

total = equipment * monument_mult
      + level * 500
      + reputation * 0.1
      + base_luck * 50 * monument_mult
```

Client eşdeğeri: `lib/core/utils/power_formula.dart` + `enhancedItemPowerContribution` (`lib/core/utils/enhancement_stats.dart`).  
Enhancement: `+4 → ×1.6`, `+10 → ×2.5`. Set bonus ayrı yok (full-set = 8 slot sum).

### Ne bozuldu (`20261016_100000_equip_level_gate_stat_sync.sql`)

Model A: kuşanılan item statları `users.attack/defense/max_health/luck`’a `equip_bonus_*` ile bake edildi (UI için doğru).

Ama `calculate_user_total_power` hâlâ:

```sql
+ (COALESCE(v_user.luck, 0) * 50 * v_stat_mult)
```

→ `users.luck` artık **base + equip_bonus_luck**. Gear luck iki kez:

1. Item power (`luck * 2 * 1.6`)
2. Character luck term (`equip_bonus_luck * 50`) ← **asıl patlama** (`*50` vs `*2`)

### Canlı kanıt — `theking` (mythic +4)

| Alan | Değer |
|------|------:|
| level | 23 |
| equipped | 8× mythic, hepsi `enhancement_level=4` |
| equipment_power | 261,448 |
| `users.luck` | 45,258 |
| `equip_bonus_luck` | 45,221 |
| base_luck | 37 |
| luck term buggy (`45258*50`) | **2,262,900** |
| luck term correct (`37*50`) | 1,850 |
| live fn **önce** | **2,548,520** |
| stored power (sync sırası: power UPDATE öncesi eski luck) | 276,164 |
| live fn **sonra** (fix) | **276,164** |

Not: `stored_power` bir süre “doğru” kaldı çünkü `sync_user_equipment_stats` power’ı **luck UPDATE’ten önce** hesaplıyordu. Home / `calculateTotalPower(player.luck)` ise `users.luck` okuyunca **~2.5M** gösteriyordu. Bir sonraki equip/enhance → DB `power` da 2.5M’e yazılacaktı.

ATK/DEF/HP double-count **yok** — power formülü `users.attack/defense` kullanmıyor; sadece equipment sum.

---

## 3. Smoke test method + results

### Method

1. Canlı `pg_get_functiondef` → `calculate_user_total_power`, `calculate_item_power`
2. Hero probe: `theking` gear + breakdown
3. Synthetic builds: best common/epic/mythic per-slot catalog, `+0/+4/+10`
4. Dungeon ladder: `dungeons.power_requirement` (65 entry)
5. Fix apply + re-probe

### Table A — Synthetic builds (base_luck=50, no monument)

| Build | Equip power | Correct total | Buggy total (synced luck×50) | Buggy luck term |
|-------|------------:|--------------:|-----------------------------:|----------------:|
| common +0 Lv10 | 8,577 | 16,077 | 101,527 | 87,950 |
| epic +0 Lv25 | 67,312 | 82,312 | 829,162 | 749,350 |
| **epic +4 Lv25** | **107,700** | **122,700** | **1,317,650** | **1,197,450** |
| mythic +0 Lv55 | 188,607 | 218,607 | 2,256,807 | 2,040,700 |
| **mythic +4 Lv55** | **301,770** | **331,770** | **3,592,870** | **3,263,600** |
| mythic +10 Lv55 | 471,516 | 501,516 | 5,597,016 | 5,098,000 |

### Table B — Live heroes (post-fix)

| User | Lv | stored=live power | base_luck | equip_bonus_luck | Pre-fix live |
|------|---:|------------------:|----------:|-----------------:|--------------:|
| theking | 23 | **276,164** | 37 | 45,221 | **2,548,520** |
| testet | 53 | 61,147 | 284 | 4,072 | 265,765 |
| selcukksezer | 99 | 57,741 | 103 | 556 | 85,541 |

### Table C — theking gear (+4 mythic)

| Slot | item_id | enh | item_power |
|------|---------|----:|-----------:|
| weapon | `wpn_sword_mythic` | 4 | 45,039 |
| gloves | `gloves_mitts_mythic` | 4 | 37,920 |
| head | `head_circlet_mythic` | 4 | 36,200 |
| ring | `ring_signet_mythic` | 4 | 31,919 |
| legs | `legs_greaves_mythic` | 4 | 31,160 |
| chest | `chest_chain_mythic` | 4 | 29,160 |
| boots | `boots_sandals_mythic` | 4 | 25,651 |
| necklace | `neck_talisman_mythic` | 4 | 24,399 |
| **Σ** | | | **≈261,448** |

---

## 4. Dungeon vs power gap

### Ladder (özet)

| Anchor | id | `power_requirement` |
|--------|-----|--------------------:|
| Z1 boss | `dng_010` | 10,000 |
| Z2 boss | `dng_020` | 40,000 |
| Z3 boss | `dng_030` | 100,000 |
| Z4 boss | `dng_040` | 220,000 |
| Z5 boss | `dng_050` | 340,000 |
| Z6 boss | `dng_060` | 420,000 |
| Final | `dng_065` | 450,000 |

### Gap (correct power, post-fix)

| Build / hero | Power | Clears | Stuck before |
|--------------|------:|--------|--------------|
| epic +4 Lv25 | 122,700 | Z3 boss (100k) | Z4 (`dng_031` 110k ≈ edge; Z4 boss 220k hayır) |
| theking mythic +4 | 276,164 | Z4 boss (220k) | Z5 (`dng_050` 340k) |
| mythic best +4 Lv55 | 331,770 | Z4; Z5 boss’a yakın | final 450k |
| buggy theking 2.55M | — | **tüm ladder ezme** | — |

**Okuma:** dungeon min’ler 2.5M’e göre düşük değildi — **power yanlış şişmişti**. Correct curve’de mythic+4 hâlâ Z4’ü rahat geçer; Z5+ için grind/enhance gerekir → sağlıklı. Epic+4 mid-game (Z3) uygun.

Dungeon min toplu artırma → undergeared / doğru-power oyuncuları cezalandırır. **Şimdi yapma.**

---

## 5. Options (tradeoffs)

| # | Lever | Etki | Tradeoff |
|---|--------|------|----------|
| A | **Fix luck double-count** (base_luck = luck − equip_bonus_luck) | 2.5M → ~276k | Zorunlu; bug fix |
| B | Enhancement curve nerf (0.15 → 0.10) | +4 1.6x→1.4x | Tüm enhance ekonomisi sarsılır; gerek yok |
| C | Item catalog / epic-mythic base stats nerf | Equip power ↓ | Content retune büyük; ayrı sezon işi |
| D | Set bonus (yok zaten) ekleme/çıkarma | N/A | Bug set bonus değil |
| E | Dungeon `power_requirement` ×N | Gate sıkılaşır | Doğru-power oyuncuyu da vurur; semptom tedavisi |
| F | Region/zone level gates | Progression gate | Ayrı sistem; power spike çözmez |
| G | luck×50 ağırlığını düşür | Allocate luck zayıf | Gear zaten luck*2; allocate ayrı kalsın |

---

## 6. Recommended action

**Paket (uygulandı / uygulanacak):**

1. **P0 — Bug fix (DONE canlı):** `calculate_user_total_power` → `v_base_luck = luck - equip_bonus_luck`  
   Migration: `supabase/migrations/20261016_130000_fix_power_exclude_equip_luck.sql`  
   MCP apply: `fix_power_exclude_equip_luck` + equipped user `power` backfill.
2. **P0 — Client (DONE workspace):** `power_formula.dart` base luck; `PlayerProfile.equipBonusLuck` (`equip_bonus_luck`).
3. **P1 — Playtest:** theking / home power badge ≈ 276k; dungeon success% Z4/Z5; enhance +1 → power delta makul (~%15 equip slice).
4. **P2 — Dungeon retune:** **şimdi yok.** 1 hafta telemetry sonra Z5+ yumuşak +10–15% düşünülebilir.
5. **P3 — sync sırası (opsiyonel):** `sync_user_equipment_stats` içinde power’ı luck UPDATE sonrası hesapla (artık base_luck ile doğru; temizlik).

**Yapma:** toplu dungeon min bump, enhancement 0.15 nerf, catalog wipe.

---

## 7. Playtest next

- [ ] `theking` (veya eşdeğer mythic+4) login → power **~276k** (2.5M değil)
- [ ] Home `calculateTotalPower` = `users.power` (fark <1% monument)
- [ ] Unequip 1 slot → power düşer; re-equip → sync + power tutarlı
- [ ] Enhance +4→+5 → total ≈ eski + ~%15 o item’ın contrib’i
- [ ] `dng_040` (220k) success yüksek; `dng_050` (340k) underpowered hissi
- [ ] Epic-only +4 karakter → ~100–130k band; Z3 OK, Z4 zor
- [ ] QA bot power’ları aşırı sıçramasın (equip_bonus_luck bak)

---

## 8. Files touched

| Path | Change |
|------|--------|
| `supabase/migrations/20261016_130000_fix_power_exclude_equip_luck.sql` | SQL fix + backfill |
| `lib/core/utils/power_formula.dart` | base luck for luck×50 |
| `lib/models/player_model.dart` | `equipBonusLuck` |
| `reports/power_spike_smoke_20260731/RAPOR.md` | this report |

---

## 9. Verdict

**BUG (intended inflation değil).**  
`sync_user_equipment_stats` × `luck*50` etkileşimi.  
Dungeon min değiştirme.  
Fix sonrası mythic+4 ≈ **276k**, epic+4 ≈ **123k** — ladder ile uyumlu.

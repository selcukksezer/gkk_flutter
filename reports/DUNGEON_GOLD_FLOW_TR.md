# Zindan Altın Akışı — Teknik Rapor (TR)

**Tarih:** 2026-07-24  
**Kaynak:** Canlı Supabase RPC + `dungeon_runs` istatistikleri + migration incelemesi + Flutter UI  
**İlgili:** `reports/ECONOMY_SUMMARY_TR.md` §13, §10.A

---

## 1. Özet (oyuncu perspektifi)

| Durum | Altın | Doğrulama |
|-------|-------|-----------|
| **İlk temizleme** (dungeon başına bir kez) | Normal ödülün **~×1,75** üstü | Canlı `attack_dungeon` yolu; eski kayıtlarda `gold_max×5` patlaması var |
| **Tekrar temizleme** | `gold_min..gold_max` taban + çarpanlar; overlevel farm cezası (%20 floor) | Canlı ortalama makul; enflasyon ana kaynağı değil |
| **Ölüm / hastane** | **0 altın** | `v_hospitalized=true` → gold sıfırlanır |
| **Başarısız + hastane yok** (nadir, Z4+) | `gold_min × 0,3` teselli | Oyuncunun gördüğü “ölüm” = hastane → altın yok |

**Kritik bulgu:** Enflasyon önerisindeki “tüm zindan altını −%35” **yanlış hedef**. Sorun **ilk geçiş bonusu** (ve hâlâ DB'de duran legacy RPC). Tekrar koşulara dokunulmamalı veya çok hafif ayar yeterli.

---

## 2. RPC zinciri

```
Flutter dungeon_battle_screen
  └─ attack_dungeon(p_dungeon_id)
       └─ attack_dungeon_rl_inner
            └─ enter_dungeon(p_player_id, p_dungeon_id)   ← CANLI YOL (2-arg)
```

Alternatif (fallback — **tehlikeli**):

```
DungeonRepository.enterDungeon
  └─ enter_dungeon(p_player_id, p_dungeon_id)  [birincil]
  └─ enter_dungeon(p_dungeon_id)               [fallback — legacy 1-arg]
```

| Fonksiyon | Durum | İlk geçiş | Başarısız |
|-----------|-------|-----------|-----------|
| `enter_dungeon(uuid, text)` | **Prod yolu** (`attack_dungeon`) | `_dungeon_farm_reward_multiplier` → **×1,75** | Hastane varsa **0**; yoksa `gold_min×0,3` |
| `enter_dungeon(text)` | **Legacy — silinmeli veya eşitlenmeli** | Taban + **`gold_max × 5`** düz bonus | **Her zaman 0** |

Migration referansları:
- `20260613_131000_dungeon_reward_balance.sql` — flat `gold_max×5` kaldırıldı, ×1,75 çarpan
- `20260502_020000_no_rewards_when_hospitalized.sql` — hastane = ödül yok
- `20260722_100000_dungeon_siege_forward.sql` — kuşatma `gold_mult` (+25% slot, +15% hold)
- `20260724_210000_reputation_buffs_gameplay.sql` — rep `gold_boost` buff

---

## 3. Altın formülü (canlı 2-arg `enter_dungeon`)

### Başarılı koşu

```
1. v_gold = random(gold_min .. gold_max)
2. Kritik (10%): ×1,5
3. Luck: ×(1 + luck × 0,002)
4. Warrior + boss: ×1,15
5. _dungeon_farm_reward_multiplier(level, power_req, success_rate, is_first_clear)
     - overlevel: min %20 (gap 30+ → ~×0,20)
     - success ≥90%: farm cezası min ×0,45
     - is_first_clear: ×1,75
6. Monument Lv10+: gold bonus
7. Kuşatma slot (prime): gold_mult (config, ~×1,25–1,40 stack)
8. Rep shop gold_boost buff
```

**İlk geçiş bayrağı:** `player_dungeon_stats.first_clear_at IS NULL` → başarılı run sonrası set edilir.

### Başarısız koşu

```
1. v_gold = floor(gold_min × 0,3)   -- sadece hastane YOKSA
2. Hastane şansı (Z4+): (1 - success_rate), luck ile azalır
3. IF hospitalized: v_gold = 0, v_xp = 0, loot = []
```

Z1–3: hastane şansı **0** → teorik teselli altın var; UI “düştün” gösterir ama hastane yok.

---

## 4. Örnek zindanlar — teorik vs canlı

Taban ortalama = `(gold_min + gold_max) / 2`. Çarpansız, luck/crit/siege yok.

| Zindan | Bölge | gold_min | gold_max | Tekrar (taban ort.) | İlk geçiş ×1,75 | Legacy 1-arg (+gold_max×5) |
|--------|-------|----------|----------|---------------------|-----------------|----------------------------|
| **dng_001** | Z1 erken | 5.000 | 12.000 | **8.500** | **14.875** | **68.500** |
| **dng_020** | Z2 orta boss | 55.000 | 115.000 | **85.000** | **148.750** | **660.000** |
| **dng_050** | Z5 geç boss | 1.030.000 | 2.120.000 | **1.575.000** | **2.756.250** | **12.175.000** |
| **dng_065** | Z7 end | 4.400.000 | 8.860.000 | **6.630.000** | **11.602.500** | **50.930.000** |

### Canlı `dungeon_runs` (2026-07-24 MCP sorgusu)

| Zindan | is_first_clear | runs | avg gold | min | max |
|--------|----------------|------|----------|-----|-----|
| dng_001 | true | 13 | 58.603* | 4.772 | 73.766 |
| dng_001 | false | 2.473 | **9.322** | 48 | 21.231 |
| dng_020 | true | 1 | 601.166† | — | — |
| dng_020 | false | 4 | 64.689 | 26.721 | 98.327 |

\* Eski `gold_max×5` kayıtları ortalamayı şişiriyor.  
† Legacy flat bonus dönemi (2026-06 öncesi).

**Son 15 ilk geçiş (2026-07):** 4.772 – 28.665 arası — **×1,75 yolu**; flat bonus yok.

### Ölüm / fail altın

| Zindan | hospitalized | runs | avg gold |
|--------|--------------|------|----------|
| dng_001 | false | 5 | 300 (≈ gold_min×0,06 — eski/küçük örnek) |
| dng_020 | true | 2 | **0** |
| dng_030 | true | 1 | **0** |
| dng_050 | false | 1 | 309.000 (= 1.030.000×0,3, hastane yok) |

Oyuncu “ölünce altın yok” → **hastane path** doğru. Teselli sadece hastaneye düşmeden fail (nadir).

---

## 5. Flutter UI

| Bileşen | Dosya | Ne gösterir |
|---------|-------|-------------|
| Giriş onay | `dungeon_confirm_entry_dialog.dart` | `gold_min..gold_max` aralığı; farm cezası önizlemesi |
| Farm önizleme | `dungeon_screen.dart` + `power_formula.dart` | `calculateDungeonRewardMultiplier` — ×1,75 ilk geçiş |
| Sonuç | `dungeon_result_widgets.dart` | `gold_earned`, “İLK GEÇİŞ — Bonus ödül çarpanı aktif!” banner |
| Savaş | `dungeon_battle_screen.dart` | `attack_dungeon` RPC; hastane mesajı = 0 altın |

Onay dialogu **ilk geçiş patlamasını** ayrı göstermez — sadece taban aralık + çarpan chip.

---

## 6. Milestone / wrapper ekstra (altın değil run başına)

- `_dungeon_grant_milestones`: 10/25/50. koşuda **ayrı** gold (zone’a göre 7k–90k+) — ilk geçiş değil, kümülatif attempt
- `attack_dungeon` wrapper: ilk **oyuncu** koşusunda garantili ekipman + scroll (gold yok)

---

## 7. Revize enflasyon önerisi

| Eski (yanlış) | Yeni (doğru) |
|---------------|--------------|
| Tüm zindan gold −%35 global | **Sadece ilk geçiş:** `first_clear_mult` **1,75 → 1,25** (veya 1,30) |
| Fail teselli 0,3 → 0,2 | **Dokunma** — oyuncu zaten hastanede 0 görüyor; teselli marjinal |
| Tekrar grind kes | **Tekrar tabanı koru** — farm cezası zaten overlevel’ı sınırlıyor |
| — | **`enter_dungeon(text)` legacy sil** veya 2-arg ile birleştir (`gold_max×5` riski) |
| Sim `dungeon×650` düz | Sim’e **first_clear ağırlığı** ekle (~%65 run repeat, ~%35 etki ilk geçişten) |

**Beklenen etki:** Her oyuncu dungeon başına **1 büyük faucet daraltılır**; günlük grind ekonomisi bozulmaz.

---

## 8. Test sonuçları (2026-07-24)

| Test | Sonuç |
|------|-------|
| `flutter test test/dungeon_siege_*.dart test/smoke/dungeon_siege_smoke_test.dart` | **23/23 pass** |
| `./scripts/run_dungeon_siege_smoke.sh` | **PASS 11/11** + unified defense 7/7 |
| Canlı MCP: `enter_dungeon` imza denetimi | 2-arg: farm_mult ✓, flat bonus ✗ / 1-arg: flat bonus ✓ (legacy) |

---

## 9. Cross-ref

- `reports/ENHANCEMENT_SET_COST_TR.md` — **mevcut değil** (2026-07-24); oluşturulunca tekrar koşu gold vs +8 set maliyeti timeline eklenecek.
- Ekonomi özeti: `reports/ECONOMY_SUMMARY_TR.md` §13

---

*Rapor: kod + canlı DB + smoke test — otomatik derleme.*

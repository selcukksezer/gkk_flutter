# PLAN 14 — Cilt 5: Zindan Altın Eğrisi (Bölge 1–4)

> **Öncelik:** P0  
> **Migration:**  
> - `20260722_020000_dungeon_gold_zone234_multiplier.sql`  
> - `20260722_030000_dungeon_tutorial_farm_penalty_exempt.sql`

---

## 1. Problem Özeti

PLAN_06 Ay 2–4 günlük altın hedefi: **5 milyon – 30 milyon**.  
Simülasyon bot başına ~**22 altın/gün** — hedefin binde biri.

Zindan seed değerleri tek koşuda makul (dng_030 avg ~227.500) ancak:
- Erken oyuncu yüksek zindanlara ulaşamaz
- dng_001 %45 farm cezası tutorial'ı sıkıştırır
- Enerji kısıtı koşu sayısını sınırlar

---

## 2. Düzeltme Paketi A — Tutorial Muafiyeti

**Dosya:** `_dungeon_farm_reward_multiplier`

```sql
-- power_requirement = 0 ise success_mult cezası uygulanmasın
IF COALESCE(p_dungeon_power_requirement, 0) = 0 THEN
  v_success_mult := 1.0;
END IF;
```

**Etki:** dng_001 ortalama gold ~8500 → farm 0.45 yerine 1.0 → ~8500/koşu (ilk clear 1.75× = ~14875).

PLAN_06 "ilk 5 zindan 25K–100K" hedefine yaklaşır.

---

## 3. Düzeltme Paketi B — Bölge Çarpanları

| Bölge | Zindan ID | Çarpan | Gerekçe |
|-------|-----------|--------|---------|
| 1 | dng_001–010 | ×1.0 | Tutorial ayrı fix |
| 2 | dng_011–020 | ×3.0 | Ay 1–2 köprü |
| 3 | dng_021–030 | ×5.0 | Ay 2–4 alt band |
| 4 | dng_031–040 | ×8.0 | Ay 4–6 band |

```sql
UPDATE public.dungeons SET
  gold_min = FLOOR(gold_min * CASE zone
    WHEN 2 THEN 3.0 WHEN 3 THEN 5.0 WHEN 4 THEN 8.0 ELSE 1.0 END),
  gold_max = FLOOR(gold_max * CASE zone
    WHEN 2 THEN 3.0 WHEN 3 THEN 5.0 WHEN 4 THEN 8.0 ELSE 1.0 END)
WHERE zone BETWEEN 2 AND 4;
```

---

## 4. Projeksiyon Tablosu (On-Level, %70 Başarı, 10 Koşu/Gün)

| Zindan | Eski avg/run | Yeni avg/run | Günlük (10×0.7) |
|--------|--------------|--------------|-----------------|
| dng_016 | 55.000 | 165.000 | 1.155.000 |
| dng_020 | 85.000 | 255.000 | 1.785.000 |
| dng_030 | 227.500 | 1.137.500 | 7.962.500 |
| dng_040 | 596.500 | 4.772.000 | 33.404.000 |

dng_030 PLAN alt sınırına (5M) yaklaşır; dng_040 üst banda (30M) girer.

---

## 5. Farm Cezası — Değiştirilmeyecek

Overlevel farm: min %9 ödül (level_mult × success_mult). Bu PLAN_06 enflasyon kontrolü için korunur.

**Sadece tutorial muafiyeti** — genel farm mantığına dokunma.

---

## 6. İlk Temizleme Bonusu

`first_clear_mult = 1.75` korunur. İlk kez tamamlanan zindan ödülü anlamlı kalır.

---

## 7. Flutter Değişiklikleri

| Dosya | Değişiklik |
|-------|------------|
| `lib/screens/dungeon/dungeon_battle_screen.dart` | Ödül preview farm mult göster (opsiyonel) |
| Zindan listesi | gold_min–gold_max band güncelle (server'dan) |

---

## 8. Oyun Tasarımı Onay Noktaları

- [ ] Bölge 2 ×3 onay
- [ ] Bölge 3 ×5 onay
- [ ] Bölge 4 ×8 onay
- [ ] Bölge 5+ tune ayrı faz (bu cilt kapsam dışı — genişletme)

---

## 9. Test Senaryoları

| # | Test | Beklenen |
|---|------|----------|
| Z1 | dng_001 L1 10 koşu | avg gold > 5000/run |
| Z2 | dng_016 L35 on-level | ~165000 avg |
| Z3 | L70 dng_011 overfarm | < 5000/run |
| Z4 | first clear dng_020 | 1.75× bonus |
| Z5 | Sim 10k 30g post-tune | gold_in artış + inflation kontrol |

**Not:** Zindan artışı enflasyonu artırabilir — VOL_03 vendor %35 ile birlikte sim'de net etki ölçülmeli.

---

## 10. Kabul Kriterleri

- [ ] Tutorial muafiyeti staging'de aktif
- [ ] Bölge 2–4 gold band DB'de güncel
- [ ] Sim gold_inflation_pct ≤ 12% (VOL_03 ile birlikte)
- [ ] PLAN_06 projeksiyon tablosu staging log ile ±30% uyum (dng_030)

---

## 11. Genişletme — Bölge 5–7 (Ayrı Cilt Taslağı)

| Bölge | Önerilen çarpan | PLAN günlük hedef |
|-------|-----------------|-------------------|
| 5 | ×10 | 30M–60M |
| 6 | ×12 | 60M–120M |
| 7 | ×15 | 80M–265M |

Her bölge için 10 zindan × ayrı alt görev belgesi = 30 belge × 20 sayfa.

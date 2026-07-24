# Enhancement Set Maliyet Raporu (TR)

**Tarih:** 2026-07-24  
**Kaynak:** `enhance_item` RPC + `get_enhancement_config` + Monte Carlo (100k iterasyon) + canlı `enhancement_history`  
**Referans ekonomi:** `reports/ECONOMY_SUMMARY_TR.md` (10k bot · 30 gün · %56,33 enflasyon)

---

## Sorun

`ECONOMY_SUMMARY_TR.md` enflasyonu **%56,33** olarak raporlar; sim formülünde `craft`, `market_buy`, `guild` sink'leri var ama **`enhance_item` altın yakımı yok**. Oyuncu perspektifinde ise midgame hedef doğrudan **+8/+9 set** — tek +1 item maliyeti değil, **8 slot × (altın + parşömen + yanık item)**.

**Paradoks:** Sim enflasyonu enhancement olmadan yüksek görünüyor; ama enhancement o kadar pahalı ki canlıda da neredeyse kullanılmıyor (90 günde 48 deneme). Ana sink teoride devasa, pratikte erişilemez.

---

## 1. Sistem Haritası

### 1.1 Ekipman slotları (tam set = 8 parça)

| # | Slot | `EquipSlot` enum |
|---|------|------------------|
| 1 | Silah | `weapon` |
| 2 | Göğüs | `chest` |
| 3 | Kafa | `head` |
| 4 | Bacak | `legs` |
| 5 | Bot | `boots` |
| 6 | Eldiven | `gloves` |
| 7 | Yüzük | `ring` |
| 8 | Kolye | `necklace` |

Kaynak: `lib/models/item_model.dart` — KO tarzı 8 slot; `helmet` ayrı enum yok (`head` kullanılır).

### 1.2 RPC ve migration

| Bileşen | Dosya | Not |
|---------|-------|-----|
| Ana RPC | `supabase/migrations/20260307_040000_plan_05_enhancement_system.sql` | `enhance_item(player_id, row_id, rune_type)` |
| Anıt indirimi | `supabase/migrations/20260307_090000_apply_monument_and_class_bonuses.sql` | Lonca anıt Lv90 → altın **-%5** |
| Config RPC | `supabase/migrations/20260720_100000_get_enhancement_config.sql` | Tek kaynak tablo (auth gerekli) |
| Flutter config | `lib/models/enhancement_config_model.dart` | RPC fallback ile aynı tablolar |
| UI | `lib/screens/enhancement/enhancement_screen.dart` | `get_enhancement_config` + `enhance_item` |
| Geçmiş | `enhancement_history` tablosu | Her deneme loglanır |

**Kullanılmayan:** `upgrade_item_enhancement` (legacy stub) — client `enhance_item` kullanır.

### 1.3 Maliyet tablosu (base × rarity çarpanı)

**Base altın** (`enhancement_level` → bir sonraki seviye denemesi):

| +→ | Base altın | Başarı % | Fail yok olma % |
|----|-----------|----------|-----------------|
| +1 | 100.000 | 100 | 0 |
| +2 | 200.000 | 100 | 0 |
| +3 | 300.000 | 100 | 0 |
| +4 | 500.000 | 100 | 0 |
| +5 | 1.500.000 | 70 | 0 (fail → -1 lvl) |
| +6 | 3.500.000 | 60 | 0 (fail → -1 lvl) |
| +7 | 7.500.000 | 50 | **100** (fail → item yanar) |
| +8 | 15.000.000 | 35 | **100** |
| +9 | 50.000.000 | 20 | **100** |
| +10 | 200.000.000 | 10 | **100** |

**Rarity çarpanı:** common ×1, uncommon ×1,5, **rare ×2,5**, epic ×4, legendary ×7, mythic ×12.

**Her deneme tüketir:** 1 parşömen (rarity'ye göre low/middle/high) + opsiyonel 1 rune.

**Item duplicate / kurban yok** — sadece +7 ve üzeri fail'de item **tamamen silinir** (+0 yeni item gerekir).

**Parşömen eşlemesi (rare gear):** `scroll_upgrade_middle` (Rare/Epic itemler).

### 1.4 Rune etkileri (opsiyonel)

| Rune | Başarı bonusu | Yok olma |
|------|---------------|----------|
| `basic` | +5% | — |
| `advanced` | +10% | — |
| `superior` | +15% | ×0,5 |
| `legendary` | +25% | ×0,25 |
| `protection` | — | **0** (yok olma yok) |
| `blessed` | +20% | ×0,5; fail'de seviye sabit |

Rune'suz simülasyon = tipik casual/hardcore baseline (runes pahalı, craft ağır).

### 1.5 Mevcut sim / smoke

| Kaynak | Enhancement? |
|--------|--------------|
| `qa_bot_simulation` / comprehensive smoke | **Yok** — `gold_out` enhancement içermez |
| `full_action_audit.json` | UI smoke: `enhancement_screen.action_04` **PASS** |
| `enhancement_history` (canlı, 90 gün) | 48 deneme, 248,5M altın yakıldı |
| Dedicated `qa_smoke_enhancement*` script | **Yok** |

---

## 2. Monte Carlo Maliyet Tabloları

**Metod:** `enhance_item` kuralları birebir; 100.000 iterasyon; rune yok; anıt indirimi yok.  
**Tipik gear:** **Rare (×2,5)** — zindan loot orta tier. **Epic (×4)** — hardcore hedef.

RNG — min / medyan / ortalama / max gösterilir.

### 2.1 Tek parça — Rare (×2,5)

| Hedef | Altın (min) | Altın (medyan) | Altın (ort) | Altın (max) | Parşömen (ort) | Ek item yanması (ort) |
|-------|-------------|----------------|-------------|-------------|----------------|----------------------|
| **+5** | 6,5M | 6,5M | **8,6M** | 41,5M | 6 | 0 |
| **+6** | 15,2M | 20,2M | **27,3M** | 212,8M | 9 | 0 |
| **+7** | 34,0M | 69,0M | **91,4M** | 748,5M | 20 | 1 |
| **+8** | 71,5M | 270,0M | **369M** | 3,7B | 59 | 5 |
| **+9** | 196,5M | 1,77B | **2,46B** | 23,5B | 297 | 28 |

**Garantili segment (+0→+4, rare):** **2,75M** altın, **4 parşömen**, 0 yanma (100% başarı).

### 2.2 Tek parça — Epic (×4)

| Hedef | Altın (ort) | Parşömen (ort) | Ek item (ort) |
|-------|-------------|----------------|---------------|
| **+8** | **591M** | 59 | 5 |
| **+9** | **3,96B** | 299 | 28 |

### 2.3 Seviye bazlı altın dağılımı (+8 rare, ortalama)

| Geçiş | Deneme başı altın | Başarı % | Ort. deneme | Ort. altın payı |
|-------|-------------------|----------|-------------|-----------------|
| +0→+1 | 250K | 100 | 5,8 | 1,4M |
| +1→+2 | 500K | 100 | 5,8 | 2,9M |
| +2→+3 | 750K | 100 | 5,8 | 4,3M |
| +3→+4 | 1,25M | 100 | 9,9 | 12,3M |
| +4→+5 | 3,75M | 70 | 13,7 | 51,4M |
| +5→+6 | 8,75M | 60 | 9,6 | 84,0M |
| +6→+7 | 18,75M | 50 | 5,8 | 107,8M |
| +7→+8 | 37,5M | 35 | 2,9 | 107,5M |

> +6 sonrası fail = **%100 item yanması** → üst seviyelerde maliyet patlar; +0→+4 tekrarları tabloda "ort. deneme" olarak görünür.

### 2.4 Tam set (8 slot) — özet

| Set | Rare (ort) | Epic (ort) |
|-----|------------|------------|
| **+8 set altın** | **2,95B** | **4,73B** |
| **+8 parşömen** | ~469 | ~469 |
| **+8 toplam item** | 8 base + ~38 yedek ≈ **46 item** | aynı |
| **+9 set altın** | **19,7B** | **31,7B** |
| **+9 parşömen** | ~2.379 | ~2.388 |
| **+9 toplam item** | 8 + ~220 yedek ≈ **228 item** | aynı |

### 2.5 Koruma runesi stratejisi (+8 rare)

+6 ve üzeri her denemede `rune_protection` kullanılırsa (yok olma yok, sadece -1 lvl):

| Metrik | Rune'suz | Protection (+6+) |
|--------|----------|------------------|
| Ort. altın | 369M | **294M** (−20%) |
| Ort. parşömen | 59 | 26 |
| Ort. rune | 0 | 9 |
| Ek item yanması | 5 | **0** |

Trade-off: altın biraz düşer ama **9 koruma runesi** craft maliyeti (2,5M altın + nadir materyal / rune başına) ayrıca hesaba katılmalı.

---

## 3. Oyuncu Perspektifi: 30 Gün Zindan Gold'u Yetiyor mu?

Kaynak: `ECONOMY_SUMMARY_TR.md` segment ortalamaları (10k sim · 30 gün).

| Segment | 30g toplam altın (gold_in) | Zindan payı (~%47) | Tek rare +8 parça (369M ort) | +8 tam set (2,95B) |
|---------|---------------------------|--------------------|-----------------------------|---------------------|
| Hardcore | 1,57M | ~738K | **234×** aylık gelir | **1.878×** |
| Normal | 1,11M | ~522K | 332× | 2.657× |
| Casual | 1,10M | ~517K | 335× | 2.682× |
| Newbie | 0,82M | ~386K | 450× | 3.598× |

### Cevap

**Hayır.** 30 gün zindan/hardcore geliri +8 set için **binlerce kat yetersiz**.

Daha gerçekçi ara hedefler:

| Hedef | Rare ort. maliyet | Hardcore 30g gelire oran |
|-------|-------------------|--------------------------|
| Tek parça +5 | 8,6M | **5,5×** |
| Tek parça +6 | 27,3M | **17×** |
| 8 slot +4 (garantili) | 22M | **14×** |
| Tek parça +8 | 369M | **235×** |

**Sonuç:** +5/+6 tek silah midgame hedefi bile hardcore'un **tüm 30g altınını** aşabilir. +8 set **aylar/yıllar** grind veya whale ekonomisi gerektirir — KO +8/+9 fantasy ile uyumlu ama mevcut faucet hızına göre **pratikte ulaşılamaz**.

Canlı doğrulama: son 90 günde tüm sunucuda **48 enhancement denemesi**, **248,5M** altın yakıldı — sim'deki 10k bot × 30g toplam `gold_out` (88M) ile kıyaslandığında enhancement canlıda da **ihmal edilebilir sink**.

---

## 4. Smoke Test Sonuçları

| Test | Sonuç | Detay |
|------|-------|-------|
| `flutter test test/ --name enhancement` | ⚠️ Kısmi | `item_sell_price` enhancement testi **PASS**; `rpc_test.dart` **FAIL** (önceden var — `main` yok) |
| `item_model_test` + `route_registry_test` | ✅ PASS | `/enhancement` route smoke registry'de |
| `full_action_audit.json` | ✅ PASS | `enhancement_screen.action_04` — UI auto_tap OK |
| Supabase `enhance_item` | ✅ Var | Canlı DB'de fonksiyon mevcut |
| Supabase `get_enhancement_config` | ✅ Var | Service role ile `auth.uid()` null → `{error:'unauthorized'}` (beklenen) |
| `enhancement_history` (90g) | ✅ Tutarlı | Lv7-8 fail'de destroy görülüyor; başarı oranları tablo ile uyumlu |
| Comprehensive sim (1000 bot, 30g) | ❌ Enhancement yok | `gold_out` enhancement içermiyor — sim boşluğu doğrulandı |

**Canlı deneme dağılımı (90 gün):**

| attempted_level | Deneme | Ort. altın | Başarı % | Destroy |
|-----------------|--------|------------|----------|---------|
| +1–+4 | 30 | 205K–1,03M | 100% | 0 |
| +5 | 7 | 2,68M | 57% | 0 |
| +6 | 4 | 7,0M | 100% | 0 |
| +7 | 4 | 15,0M | 50% | 2 |
| +8 | 2 | 37,5M | 50% | 1 |
| +9 | 1 | 50,0M | 0% | 1 |

---

## 5. Enflasyon Analizine Etkisi

### Mevcut durum (%56,33)

Sim `gold_out` formülü: `120 + market_buy×350 + craft×180 + guild×120 + rand` — **enhancement yok** (`ECONOMY_SUMMARY_TR.md` §4 satır 72).

10k · 30g sim:

| | Miktar |
|--|--------|
| gold_in | 202,4M |
| gold_out | 88,4M |
| Enflasyon | **56,33%** |

### Enhancement sim'e eklenirse (teorik)

Enhancement altın yakımı sim'deki tüm `gold_out`'u **gölgede bırakır**:

| Senaryo | Ek gold_out (10k bot) | Yeni enflasyon (tahmin) |
|---------|----------------------|-------------------------|
| %10 bot × 3 item +5 (rare) | ~26B | **−12.764%** (deflasyon) |
| %30 bot × 3 item +5 | ~78B | **−38.405%** |
| %5 bot tam +8 set (rare) | ~148B | **−73.000%** |

> Rakamlar sim ölçeğine göre — enhancement erişilebilir olsaydı **en büyük altın sink** olurdu ve %56 enflasyon **ciddi şekilde düşer / deflasyona döner**.

### Gerçekçi revize tahmin

| Katman | Etki |
|--------|------|
| **Sim bug/eksik** | %56 → enhancement dahil edilirse model **aşırı deflasyon** gösterir (sink fazlası) |
| **Canlı gerçek** | 90g/248M yakım → mevcut enflasyonu **~0,1%** düzeyinde etkiler (ihmal) |
| **Tasarım gerçeği** | Enhancement ** teorik ana sink**, **pratikte kapalı sink** — maliyet >> faucet |

**Revize enflasyon yorumu:**

1. Raporlanan **%56** enhancement'ı **eksik saydığı için sink tarafını olduğundan düşük gösterir**.
2. Ancak enhancement maliyeti mevcut 30g gelirle **oynanabilir değil** → sink devreye girmiyor → **%56 yapısal olarak kalır**.
3. Ekonomi dengelemesi için ya **faucet düşürülmeli** ya da **+4/+5 bandı erişilebilir**, **+8/+9 endgame** olarak kalmalı — aksi halde sim ve canlı diverge eder.
4. Item enflasyonu (%50) açısından: +8 set başına ~38 yedek item yanması **güçlü item sink** olurdu — yine erişilebilirlik sorunu aynı.

**Öneri (ekonomi raporu revizyonu):** `ECONOMY_SUMMARY_TR.md` §4'e enhancement sink satırı ekle; %56'yı "enhancement-excluded upper bound" olarak etiketle; ayrı metrik: **"enhancement-accessible inflation"** (oyuncuların gerçekten harcayabildiği sink'ler).

---

## 6. Anahtar Rakamlar (özet)

| Metrik | Rare | Epic |
|--------|------|------|
| **Tek parça +8 altın (ort)** | **369M** | 591M |
| **Tam +8 set altın (8 slot)** | **2,95B** | 4,73B |
| **Tam +8 parşömen** | **~469** | ~469 |
| **Tam +8 item (base+yedek)** | **~46** | ~46 |
| **Tek parça +9 altın (ort)** | **2,46B** | 3,96B |
| **Tam +9 set altın** | **19,7B** | 31,7B |
| **Tam +9 item** | **~228** | ~228 |
| Hardcore 30g gelir / +8 set | — | **1.878× yetersiz** |
| Smoke | UI audit **PASS**, DB RPC **OK**, sim **enhancement yok** |

---

*Monte Carlo: Python · `enhance_item` kuralları · seed-independent · 100k iterasyon. Canlı veri: Supabase MCP `enhancement_history`.*

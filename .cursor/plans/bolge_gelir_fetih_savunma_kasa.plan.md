# Bölge Gelir · Fetih · Savunma · Kasa — Mantık Audit + Yeniden Tasarım Planı

> Tarih: 2026-07-29  
> Kaynak: canlı DB + `20260730_120000_territory_income_20m_loot_defense_reset.sql` + vault migrations  
> Amaç: mevcut uçtan-uca akışı belgele, tutarsızlıkları listele, dengeli yeniden tasarım kararlarını netleştir.  
> **Update:** §13 güç-savunma · §14 prestij puanı · **§16 Lonca Turnuva (aktif Clash)**

---

## 1. Tek cümle özet

**Eski (as-is):** Lonca saldırıyla fetheder → tutar → günlük altın+eşya → kasa pending → lider collect → dağıt. Fetihte **yalnız elmas savunma** sıfırlanır.  
**Sıralama (as-is):** sadece bölge saldırı win/lose (+100/+10) → `guild_war_rankings.points`.

**Hedef:**  
- §13 Savunma = garnizon Σ power + elmas; sadece lider saldırır; üyeler destekler.  
- §14 Lonca puanı = **savaş + güç + PvP + aktiflik + ekonomi**.  
- §16 Turnuva = pasif bracket değil → **aktif Lonca Clash** (üyeler pencere boyunca katkı).

---

## 2. Mevcut sayılar (canlı — 2026-07-29)

| Zone | Bölge | `trade_income`/gün | `attack_gold_cost` | `min_defense_gems` |
|------|-------|--------------------|--------------------|--------------------|
| 1 | Demir Kalesi | 12,000,000 | 600,000 | 20 |
| 2 | Altın Ovası | 14,000,000 | 700,000 | 25 |
| 3 | Ejderha Tepesi | 16,000,000 | 800,000 | 30 |
| 4 | Karanlık Liman | 18,000,000 | 900,000 | 35 |
| 5 | Cehennem Kapısı | 20,000,000 | 1,000,000 | 40 |
| 6 | Gökyüzü Burcu | 22,000,000 | 1,100,000 | 45 |
| 7 | Efsanevi Sınır | 25,000,000 | 1,250,000 | 50 |

| Parametre | Değer | Not |
|-----------|-------|-----|
| Saldırı maliyeti / günlük gelir | ~%5 | ROI ≈ **1.2 saat** gelir = 1 saldırı maliyeti |
| Altın → savunma | **1000g = +1** `defense_power` | Kalıcı |
| Elmas → savunma | **1💎 = +10** `gem_defense_boost` | **Her an** eklenir; **yalnızca fetih kaybında** sıfırlanır (prime wipe YOK) |
| Saldırı gücü | `level × 50` | Gear/power **yok** |
| Fetih sonrası | **yalnız `gem_defense_boost = 0`** | `defense_power` / garnizon gücü “yatırım wipe” değil; garnizon boş → güç doğal 0 |
| Günlük loot | **6 veya 7** item / bölge | Common hariç; ağırlıklı rarity |
| Accrual cap | 168 saat (7 gün) | |
| Siege slot vault credit | `GREATEST(250, trade_income/20)` | Z7 ≈ **1.25M**/claim — şişmiş |

Loot rarity ağırlıkları:
- uncommon 40% · rare 30% · epic 18% · legendary 8% · mythic 4%

---

## 3. Uçtan uca akış (as-is)

### 3.1 Fetih

**RPC:** `attack_guild_war_territory(p_territory_id)`

1. Combat ready + PvP health assert
2. Saldıran lonca üyesi olmalı; kendi bölgesine saldıramaz
3. Maliyet = `attack_gold_cost` (yoksa `trade_income * 0.05`)
4. Lonca **`vault_gold`** yeterliliği kontrol → her durumda (win/lose) düşülür
5. Atk = `level * 50`; Def = `defense_power + gem_defense_boost`
6. Roll: `(random() * atk) > (random() * max(def, 1))`
7. **Başarıysa:**
   - Eski sahibe `_accrue_guild_vault` (son pending’i yaz)
   - `owner_guild_id = attacker`
   - **yalnız** `gem_defense_boost = 0` (elmas yatırımı kaybolur)
   - `defense_power` **dokunulmaz** (eski gold duvar / ileride garnizon cache)
   - garnizon tablosu wipe (yeni tasarım) → güç savunu yeni sahip için doğal boş
8. Rep / season puan / HP kaybı / attack log

**Siege:** bölge sahibi `dungeon_siege_territory_owner_for_zone` ile **okunur** — ownership **transfer etmez**. Slot claim → `credit_guild_vault_pending`.

### 3.2 Savunma tutma

| Katman | Kaynak | Savaşta? | Fetihtе |
|--------|--------|----------|---------|
| `defense_power` | `add_territory_defense_gold` (**kaldırılacak**) | Evet (geçiş) | **dokunulmaz** → gold miras riski (C2) |
| `gem_defense_boost` | `add_territory_defense` (**her an**) | Evet | → 0 **sadece fetih kaybında** |
| `defense_line_level` | kolon | **Hayır (ölü)** | — |
| `base_defense_power` | seed | **Hayır (ölü)** | kalır |

`min_defense_gems` → UI ipucu; **RPC enforce etmiyor**.

### 3.3 Gelir birikimi (accrual)

**Tetik:** `get_guild_war_territories` / `get_territory_detail` / `get_guild_vault` / saldırı başarı / preview yolları → `_accrue_guild_vault(guild_id)`

```
hours = min(now - vault_last_accrual_at, 168)
delta = Σ (trade_income × hours / 24)  // sahip olunan bölgeler
vault_gold_pending += delta
vault_last_accrual_at = now
+ _accrue_guild_vault_territory_loot (24h cooldown / bölge)
```

### 3.4 Loot

**RPC (internal):** `_accrue_guild_vault_territory_loot`

- Sahip olunan her bölge için 24s cooldown (`guild_vault_territory_loot_state`)
- 6 + (%50 → +1) = 6 veya 7 drop
- `_pick_territory_loot_item_id()` → weighted rarity → `guild_vault_items`
- Eski `loot_item_id` kolonu **artık kullanılmıyor** (sadece display kalıntısı)

### 3.5 Kasa: topla → dağıt

```
vault_gold_pending  ──collect_guild_vault_rewards──►  vault_gold
                                                         │
                         ┌───────────────────────────────┼───────────────────────────┐
                         ▼                               ▼                           ▼
              attack_spend (saldırı)          defense_gold (savunma)     distribute_* (üyelere)
```

| RPC | Kim | Etki |
|-----|-----|------|
| `get_guild_vault` | üye | accrue + görüntüle |
| `collect_guild_vault_rewards` | **lider** | pending → `vault_gold` |
| `distribute_guild_vault_gold` | **lider** | `equal` veya `allocations` → `users.gold` |
| `distribute_guild_vault_item` | **lider** | vault item → envanter |
| `credit_guild_vault_pending` | internal | siege / turnuva |

**Withdraw yok.** “Çekme” = lider dağıtımı.

#### Equal dağıtım

```
per = floor(amount / member_count)
her üyeye +per
vault -= per * member_count   // kalan remainder kasada kalır
```

#### Allocations dağıtım

```
payload.allocations = [{user_id, amount}, ...]
Σ amounts == amount zorunlu
hedef üye loncada olmalı
```

Ledger: `accrue` · `territory_loot` · `collect` · `distribute_gold` · `distribute_item` · `attack_spend` · `defense_gold`

---

## 4. Flutter yüzeyler

| Ekran | Ne gösterir |
|-------|-------------|
| `guild_war_hub_screen` | toplam gelir, hourly, pending |
| `territory_card` | gelir/gün, loot etiketi, gem |
| `territory_detail_screen` | gelir, ödül, maliyet, kasa özeti |
| `guild_war_attack_screen` | maliyet, ROI, win% preview |
| `guild_war_defense_sheet` | altın/elmas savunma ekleme (**stale oran**) |
| `guild_vault_screen` | collect + equal/allocations + item dağıt |

Modeller: `lib/models/guild_war_model.dart`, `guild_vault_model.dart`  
Provider: `guild_war_provider.dart`, `guild_vault_provider.dart`  
Repo: `guild_vault_repository.dart`

---

## 5. Tespit edilen mantıksızlıklar / delikler

### P0 — ekonomi kırığı

1. **Fetih ROI ~1.2 saat**  
   20M/gün bölge, saldırı 1M → bir bölgeyi tutmak ≈ 1 saldırı maliyeti kadar gelir üretiyor **çok hızlı**. Loncalar sürekli flip-flop veya “al → 2 saat bekle → sat/kaç” meta.

2. **Fetihte sıfırlanan = sadece elmas savunma**  
   `gem_defense_boost → 0`. Üye güç/garnizon “satın alınan savunu” değil → wipe değil, yeni sahip garnizonu boş başlar.  

3. **Siege claim gold şişmesi**  
   `trade_income/20` formülü 20M ekonomisine scale edilmedi → Z7 claim ≈ 1.25M pending/tek claim. Vault’u territory gelirinden bağımsız şişirir.

4. **Accrual ownership backfill**  
   Son tick’ten beri `hours` × **şu anki** sahiplik. Ortada bölge alındıysa, **sahip olunmayan saatler** de ödenir.

### P1 — tutarsızlık / stale

5. **Defense sheet UI stale**  
   UI: `500g = +50` (`/10`), min 500.  
   SQL: `1000g = +1`, min 1000.  
   → Oyuncu yanlış preview görür; <1000 RPC reject.

6. **Preview/detail fallback `*0.05` vs `*0.55`**  
   Attack/list güncel `*0.05`; `get_territory_attack_preview` / bazı detail fallback hâlâ `*0.55`. Seed kolon dolu olduğu için çoğu zaman görünmez ama tehlikeli.

7. **`get_territory_detail` loot alanları eksik**  
   Hub listesinde loot label var; detail RPC’de yok → ekranlar tutarsız.

8. **Vault UI hâlâ “loot %” dili**  
   Oyun artık garanti 6–7 item; şans % gösterimi yanıltıcı.

### P2 — ölü / yarım sistem

9. **`defense_line_level` combat’a girmiyor**  
10. **`base_defense_power` combat’a girmiyor**  
11. **`min_defense_gems` enforce yok**  
12. **Saldırı gücü = sadece level×50** — item power yok → gold wall veya boş bölge uçları aşırı

### P3 — governance / abuse

13. **Her üye vault’tan saldırı harcayabilir** — lider/officer gate yok → grief spend  
14. **Preview win% ≠ gerçek roll formülü** (oran vs `random*atk > random*def`)  
15. Loot cooldown stamp, pick fail olsa bile yazılabilir (edge)

---

## 6. İstenen “sağlam mantık” hedefi (karar bekleyen)

Aşağıdaki sorulara cevap ver → sonra implement fazı.

### 6.1 Gelir

| Soru | Seçenekler | Öneri (taslak) |
|------|------------|----------------|
| Günlük gelir bandı | 1–3M / **10–25M** / 50M+ | **10–25M** kalabilir ama saldırı maliyeti oranı yükseltilmeli |
| Gelir kime akar | sadece vault / vault+%üye passive | Sadece vault (mevcut) — net kalsın |
| Accrual tick | ownership-aware timeline / anlık sahip×saat | **Ownership timeline** veya “son sahip değişiminden beri” |

### 6.2 Fetih maliyeti & ROI

| Soru | Seçenekler | Öneri |
|------|------------|-------|
| Hedef ROI | 0.05 gün (~1h) / **1–2 gün** / 3–7 gün | **1.5–2 gün gelir ≈ 1 saldırı** → maliyet ≈ `trade_income * 1.5..2` |
| Maliyet kaynağı | vault only / vault+kişisel | Vault only (mevcut) |
| Kim harcayabilir | her üye / **officer+leader** | Officer+leader |

### 6.3 Savunma reset

| Soru | Seçenekler | Öneri |
|------|------------|-------|
| Fetih sonrası def | 0 / atk gücü / **base_defense** / grace buffer | **`base_defense_power`** + kısa **grace (örn. 2s saldırılamaz)** |
| Gold def oranı | 1000g=1 / 10k=1 / dinamik | Gelire göre: örn. `trade_income/20000` gold = +1 (Z5: 1000g=1 kalır) |
| Gem def | prime-only / her an | **Her an**; sıfır = sadece fetih kaybı |
| Defense line | sil / combat’a bağla | Combat’a bağla **veya** kolonu kaldır |

### 6.4 Loot

| Soru | Seçenekler | Öneri |
|------|------------|-------|
| Adet | 6–7 sabit / zone scale 3→10 | 6–7 OK; zone ile +0..+2 opsiyon |
| Pool | tüm non-common / curated loot table | **Curated table** (ekipman+scroll+rune; name-change vs hariç) |
| UI | “6–7/gün” | Şans % kaldır |

### 6.5 Kasa & pay

| Soru | Seçenekler | Öneri |
|------|------------|-------|
| Collect | lider only | Kalsın |
| Equal | floor remainder | Kalsın + UI “kalan kasada” |
| Allocations | lider free / %cap per member | **Max %40 tek üyeye** (abuse) |
| Saldırı harcama yetkisi | herkes / officer | Officer+leader |
| Siege credit | `income/20` / flat / `income/200` | **`income/200`** veya flat tier (Z1:50k … Z7:200k) |

---

## 7. Önerilen hedef ekonomi (v2 — onay sonrası)

> Bu bölüm **henüz uygulanmadı**. Onay = implement.

### 7.1 Sayı tablosu (örnek)

| Zone | Gelir/gün | Saldırı maliyeti (~1.75× gün) | Starter def (fetih sonrası) | Siege claim credit |
|------|-----------|-------------------------------|-----------------------------|--------------------|
| 1 | 12M | 21M | `base_defense` | 60k |
| 2 | 14M | 24.5M | base | 70k |
| 3 | 16M | 28M | base | 80k |
| 4 | 18M | 31.5M | base | 90k |
| 5 | 20M | 35M | base | 100k |
| 6 | 22M | 38.5M | base | 110k |
| 7 | 25M | 43.75M | base | 125k |

**Grace:** fetih sonrası 2 saat `updated_at` koruması — saldırı reddi: “Yeni fetih koruması”.

**Gold def:** `10000g = +1` (20M ekonomide 1M gold ≈ +100 def; level100 atk=5000 → anlamlı yatırım).

### 7.2 Accrual düzeltmesi

```
v_from = GREATEST(vault_last_accrual_at, territory.updated_at)  -- bölge bazında
-- veya ownership event log
delta_terr = income * owned_hours / 24
```

Bölge kaybedilince eski sahip için son accrual zorunlu (zaten attack success’te var) — yeni sahip `updated_at`’ten başlar.

### 7.3 Kasa yetki matrisi

| Aksiyon | Leader | Officer | Member |
|---------|--------|---------|--------|
| Collect pending | ✅ | ❌ | ❌ |
| Distribute gold/item | ✅ | ❌ | ❌ |
| Attack spend vault | ✅ | ✅ | ❌ |
| Defense gold/gem | ✅ | ✅ | ❌ (veya ✅ gem only) |
| View vault | ✅ | ✅ | ✅ |

### 7.4 Pay dağıtım kuralları (net)

1. Pending birikir (pasif) — üyeye otomatik gitmez  
2. Lider **collect** → harcanabilir kasa  
3. Lider **equal**: herkese eşit; floor kalanı kasada  
4. Lider **allocations**: manuel pay; tek üye ≤ %40 toplam; Σ == amount  
5. Item dağıt: 1 item → 1 üye envanter (stack kuralları mevcut inventory RPC)  
6. Ledger her hareketi yazar — UI’da son 50 hareket

---

## 8. Implement fazları (onay sonrası)

### Faz A — Acil tutarlılık (bugfix, ekonomi kararı beklemeden)

- [ ] Defense sheet: 1000g=+1, min 1000, max slider yükselt
- [ ] Preview/detail fallback `*0.05` hizala
- [ ] Detail RPC loot alanları + hub ile aynı label
- [ ] Vault UI “6–7/gün” dili; % şans kaldır
- [ ] Siege claim credit formülünü gelirle orantısız şişirmeyecek şekilde düzelt

### Faz B — Ekonomi dengesi (sayı onayı gerekir)

- [ ] `attack_gold_cost` yeniden seed (hedef ROI)
- [ ] Fetih sonrası `defense_power = base_defense_power` (+ opsiyonel grace)
- [ ] Gold def oranı yeniden kalibre
- [ ] Accrual ownership-aware
- [ ] Attack/defense vault yetki gate

### Faz C — Kasa governance

- [ ] Allocations %40 cap
- [ ] Officer rolü netleştir (`guild_role`)
- [ ] Ledger UI iyileştir
- [ ] (opsiyonel) otomatik haftalık equal payout toggle

### Faz D — Ölü sistem temizliği

- [ ] `defense_line_level` → combat formülüne bağla **veya** drop
- [ ] `base_defense_power` fetih starter olarak kullan (Faz B ile)
- [ ] `min_defense_gems` enforce
- [ ] Curated loot table (name-change / junk hariç)

---

## 9. RPC / dosya haritası

| Bileşen | Yer |
|---------|-----|
| Attack + def wipe | `attack_guild_war_territory` — `20260730_120000_...sql` |
| Accrue gold | `_accrue_guild_vault` — `20260730_080000_...sql` |
| Accrue loot | `_accrue_guild_vault_territory_loot` + `_pick_territory_loot_item_id` |
| Collect | `collect_guild_vault_rewards` — `20260726_280000_guild_vault.sql` |
| Distribute gold | `distribute_guild_vault_gold` |
| Distribute item | `distribute_guild_vault_item` |
| Gold def | `add_territory_defense_gold` |
| Gem def | `add_territory_defense` |
| Hub list | `get_guild_war_territories` |
| Detail | `get_territory_detail` |
| Preview | `get_territory_attack_preview` |
| Flutter vault | `lib/screens/guild/guild_vault_screen.dart` |
| Flutter defense UI | `lib/screens/guild_war/guild_war_defense_sheet.dart` |

---

## 10. Karar checklist

### Kilitli (2026-07-29 — kullanıcı)

- [x] Savunma = **lonca üyelerinin toplam gücü** (+ ekstra elmas boost)
- [x] Altın ile savunma ekleme → **KALDIR**
- [x] Bölge tutma / fetih saldırısı → **sadece lonca başkanı (leader)**
- [x] Diğer üyeler → **destek** rolü (mekanik §13’te)
- [x] Lonca puanı / sıralama → **sadece savaş değil**; güç + PvP + aktiflik + ekonomi (§14)
- [x] Turnuva → **aktif Clash** (pasif bracket değil) (§16)
- [x] Haftalık Arena ödül havuzu = **100M g**; Sezon Finali = **300M g + efsanevi +7** (§16.7)
- [x] Elmas savunma: **her an eklenir**; prime dışı **sıfırlanmaz**; yalnız **bölge kaybında gem sıfır** (`130000`+`131000`)
- [x] “Savunma sıfırlanır” = **sadece elmasla alınan**; güç/garnizon wipe≠yatırım sıfırlama

### Hâlâ açık

- [ ] Destek modeli: **A garnizon** / B saldırı takviyesi / C hibrit (öneri: **A+B hibrit** — §13)
- [ ] Günlük gelir bandı kalsın mı? (12–25M)
- [ ] Hedef saldırı ROI: ___ gün gelir
- [ ] Grace (fetih koruması): ___ saat
- [ ] Siege claim credit düzeltmesi
- [ ] Loot pool: tüm non-common / curated
- [ ] Allocations cap: %___ / yok
- [ ] Prestij ağırlık: `season + 0.25×prestige` OK mi? (§14.11)
- [ ] PvP haftalık cap / hold tick (§14.11)
- [ ] Elmas ekleme: lider-only mi, üye kendi gem’iyle mi?

---

## 11. Risk notları

- Gelir 20M + saldırı %5 → **meta = sürekli savaş**, tutmak değersiz.  
- Savunma 0 + düşük maliyet → **ping-pong fetih**.  
- Siege credit scale bug → vault’u “bedava” doldurur, saldırı spam.  
- UI/SQL oran drift → oyuncu güveni kırılır (buton basar, RPC hata).  
- Accrual backfill → haksız gold; exploit potansiyeli düşük ama adaletsiz.  
- **Yeni:** Tüm bölgeler aynı `Σ power` alırsa 7 bölge = 7× aynı duvar → **garnizon zorunlu** (güç bölünmeli).  
- **Yeni:** Sadece lider saldırırsa lider offline = lonca felç → saldırı **planla/pencere** + üye takviye kritik.  
- **Yeni:** Tek eksen puan (sadece fetih) → AFK güçlü / PvP main loncalar görünmez — §14 şart.

---

## 12. Sonraki adım

1. §13 destek + §14.11 ağırlık + **§16.14 Clash süre/slot** onayla.  
2. Kalan §10 açık maddeleri doldur.  
3. Faz A → E → F → **G (turnuva)**.

---

## 13. YENİ TASARIM — Güç Savunması · Lider Fetih · Üye Destek

> Kullanıcı kararı: savunma = üye toplam güç + elmas; lider tutar/saldırır; üyeler destekler.  
> Aşağısı **önerilen net kurallar** — onay → implement.

### 13.1 Tek cümle (yeni)

```
LİDER saldırır (vault altın) → lonca sahip olur
  → SAVUNMA = Σ(garnizon üyeleri power) + gem_boost
  → Üyeler garnizona yazılır / saldırıya takviye verir
  → Gelir kasa pending → lider collect → dağıt
```

### 13.2 Savunma formülü

```
guild_member_power(u) = users.power   -- cached combat power (mevcut kolon)
garrison_power(terr)  = Σ power(u)  WHERE u garnizon(terr)'da
effective_defense     = garrison_power + gem_defense_boost
```

**Kurallar:**

1. Altın savunma (`add_territory_defense_gold`) → **sil / disable**.  
2. `defense_power` kolonu artık kalıcı yatırım değil → **cache** (garnizon toplamı), saldırı anında yeniden hesap opsiyonel.  
3. Elmas boost: lider (veya üye?) harcar → `gem_defense_boost`. **Her an eklenebilir.** Prime wipe **YOK**. Sıfırlanma = **yalnızca bölge kaybı (fetih)**.  
4. Üye loncadan çıkınca / power değişince garnizon toplamı güncellenir.  
5. Fetih kaybı: **yalnız elmas savunma sıfır** (`gem_defense_boost=0`). Garnizon boşalır (güç savunu yeni sahip için 0’dan kurulur). Yeniden elmas yatırılır.

**Çok bölge tuzağı (önemli):**  
Aynı üye **aynı anda tek bölgeye** garnizon olabilir.  
→ 7 bölge tutmak = gücü bölmek. Strateji doğar.  
Lonca tek bölge tutuyorsa tüm güç orada → kalın duvar.

### 13.3 Kim ne yapar

| Aksiyon | Leader | Member |
|---------|--------|--------|
| Bölgeye saldır (fetih) | ✅ tek yetkili | ❌ |
| Vault’tan saldırı altını harca | ✅ | ❌ |
| Garnizona kendini yaz / çıkar | ✅ | ✅ |
| Üyeyi garnizona ata / çıkar | ✅ | ❌ |
| Elmas savunma ekle | ✅ | ❌ (veya ✅ kendi gem’i) |
| Collect / distribute kasa | ✅ | ❌ |
| Saldırı takviyesi (support pledge) | — | ✅ |
| Bölge listesi / detay gör | ✅ | ✅ |

### 13.4 Üye desteği — 3 seçenek

#### Seçenek A — Garnizon (SAVUNMA desteği) ★ temel

```
Üye: "Bu bölgede nöbet tutuyorum"
  → power'ı o bölgenin defense'ine eklenir
  → başka bölgeye yazılamaz
  → çıkınca defense düşer
```

- UI: bölge detay → **Nöbete katıl / Ayrıl**  
- Lider: üye listesinden sürükle-bırak / ata  
- Offline üye de sayılır (power cache) — aktiflik şartı yok (basit)  
- İsteğe bağlı v2: son 48s login yoksa power ×0.5

**Neden iyi:** Anlaşılır, “tutmak = üyeleri oraya koy”. Çok bölge = zayıf her yer.

#### Seçenek B — Saldırı takviyesi (SALDIRI desteği)

```
Lider: "X bölgesine saldırı planı" açar (örn. 30–60 dk pencere)
Üyeler: "Destek ver" → power'larının %N'i saldırı havuzuna
Saldırı gücü = lider_power + Σ(takviye)  (cap: örn. Σguild_power * 0.5)
Lider pencere bitince / hazır olunca saldırıyı basar
```

- Maliyet hâlâ lider/vault  
- Üye katkı = geçici (sadece o saldırı)  
- Üye “savaşta varım” hissi

**Neden iyi:** Lider offline değilken bile hazırlık; üyeler fetihe katılır.

#### Seçenek C — Hibrit (ÖNERİLEN) = A + B

| Durum | Üye ne yapar |
|-------|----------------|
| Barış / tutma | Garnizona yazılır → savunma |
| Fetih hazırlığı | Lider plan açar → üyeler takviye pledge |
| Saldırı anı | `atk = lider.power + Σ(pledge)` vs `def = rakip garnizon + gem` |

**Kısıt:** Garnizondaki üye aynı anda başka bölgeye takviye verebilir (saldırı uzak) — OK.  
Aynı üye **kendi garnizonundan çıkmadan** saldırı takviyesi verebilir (power hem def’te hem atk’ta mı?)  

→ **Net kural (öneri):** Takviye veren üye o an garnizon power’ından **düşmez** (basit).  
Alternatif sert: takviye = geçici olarak garnizondan çıkar (karmaşık, sonra).

### 13.5 Savaş formülü (yeni)

```
atk = leader.power + Σ(support_pledge.power * k)   -- k=1.0 veya 0.5
def = Σ(defender_garrison.power) + gem_defense_boost
success = (random() * atk) > (random() * max(def, 1))
```

Eski `level*50` **kaldır** → gerçek `users.power`.

Maliyet: vault `attack_gold_cost` (sadece lider tetikler).

Başarı: ownership transfer; **garnizon wipe**; **yalnız `gem_defense_boost=0`** (elmas yatırımı). `defense_power` kolonuna “hepsini sıfırla” yok.

### 13.6 Veri modeli (yeni tablolar)

```sql
-- Garnizon: üye ↔ bölge (1 üye → en fazla 1 bölge)
guild_war_garrison (
  guild_id uuid,
  territory_id uuid,
  user_id uuid PRIMARY KEY,  -- bir üye tek satır
  joined_at timestamptz
)

-- Saldırı planı + takviye
guild_war_attack_plan (
  id uuid,
  territory_id uuid,
  attacker_guild_id uuid,
  leader_id uuid,
  opens_at, closes_at,
  status text  -- open|launched|cancelled|expired
)

guild_war_attack_support (
  plan_id uuid,
  user_id uuid,
  power_snapshot int,  -- pledge anındaki power
  PRIMARY KEY (plan_id, user_id)
)
```

Cache: `guild_war_territories.defense_power` = son hesaplanan garnizon toplamı (UI hızlı; combat’ta recompute).

### 13.7 UI akışı

**Bölge detay (sahip lonca üyesi):**
- Savunma bar: `garnizon_güç + gem`  
- Liste: nöbetçiler (avatar, power)  
- Buton: Nöbete katıl / Ayrıl  
- Lider: Elmas ekle · Üye ata/çıkar

**Bölge detay (düşman / sahipsiz) — sadece lider:**
- Saldır → önce **Plan aç** (30 dk)  
- Plan paneli: kim takviye verdi, toplam atk preview, maliyet  
- Saldırışı başlat (closes_at öncesi)

**Üye (düşman bölge planı açıkken):**
- Push/inbox: “Başkan X’e saldırı planladı — destek ver”  
- Destek ver → power_snapshot kaydı

**Kasa:** değişmez (lider collect/dağıt).

### 13.8 Kaldırılacak / deprecate

| Eski | Yeni |
|------|------|
| `add_territory_defense_gold` | kaldır |
| Defense sheet altın slider | kaldır |
| `attack` her üye | leader-only gate |
| `defense_power = level*50` atk | `users.power` + support |
| Fetih sonrası def=0 çıplak | garnizon boş (=0) ama UI “nöbetçi yok” |
| `defense_line_level` | drop veya sonra |

### 13.9 Denge notları (güç savunu)

- 10 üyeli lonca, ort. 5k power → tek bölge def ≈ 50k + gem.  
- Aynı lonca 5 bölge → ortalama 10k/bölge (güç bölünür) → genişleme riski.  
- Saldırı: lider 8k + 6 üye takviye 4k = 32k atk → denk eşleşme.  
- ROI: saldırı maliyeti hâlâ yüksek tutulmalı (plan §7); güç duvarı tek başına yetmez.

### 13.10 Implement fazı E (bu tasarım)

1. Migration: `guild_war_garrison` + RPC join/leave/assign  
2. `effective_defense` = garnizon Σ power + gem  
3. `attack_guild_war_territory` → leader-only + power formülü  
4. Altın def RPC/UI kaldır  
5. Attack plan + support RPC/UI  
6. Inbox/notif: “saldırı planı / destek”  
7. Hub/detail: garnizon listesi + güç breakdown  
8. QA smoke: leader attack, member blocked, garrison move, support pledge

### 13.11 Senin tek cevabın yeterli

**Destek modeli:**  
- `A` sadece garnizon  
- `B` sadece saldırı takviyesi  
- `A+B` hibrit (**öneri**)

+ Elmas ekleme yetkisi: lider-only mi, üye kendi gem’iyle mi?  
  (Sıfırlama kuralı kilitli: her an ekle / yalnız fetih kaybında sıfır.)

Cevap gelince Faz E’ye geçilir.

---

## 14. Lonca Prestij Puanı — çok eksenli sıralama

> As-is sorun: `guild_war_rankings.points` **sadece** bölge saldırısından geliyor (win +100 / lose +10).  
> Güçlü ama savaşmayan lonca = sıfır. Aktif PvP lonca = görünmez. Şişman AFK roster = sırada yok ama savunmada OP olacak (§13).  
> Hedef: **tek sıralama**, ama puan = savaş + güç + PvP + aktiflik + ekonomi.

### 14.1 Tasarım ilkeleri

1. **Çok ayaklı masa** — tek meta (sadece fetih spam / sadece alt hesap power) kazanmasın.  
2. **Soft cap + diminishing** — 50 AFK üye ≥ 10 aktif üye olmasın.  
3. **Sezon skoru** vs **anlık prestij** ayrımı net.  
4. **Şeffaf UI** — oyuncu “neden 3.üz” görsün (breakdown).  
5. **Krallık / turnuva** aynı skordan beslensin (tek kaynak).

### 14.2 İki katman

| Katman | Ad | Ne | Ne zaman |
|--------|-----|-----|----------|
| **A** | `prestige` (anlık) | Canlı formül — güç/aktiflik/hold | Her hub açılışında / 15 dk cron recompute |
| **B** | `season_score` (sezon) | Biriken olay puanları — fetih, PvP, quest… | Event anında += |

**Sıralama anahtar:**  
```
rank_score = season_score + floor(prestige * 0.25)
```
→ Sezon olayları baskın (%~75 his), güç/aktiflik sürekli taban sağlar (%~25 his).  
Ağırlık ayarlanabilir (aşağıda W).

### 14.3 Beş sütun (pillars)

```
                    ┌─────────────┐
                    │ LONCA SKORU │
                    └──────┬──────┘
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
     [Savaş/Hold]    [Güç/Roster]    [PvP]
           ▼               ▼               ▼
      [Aktiflik]      [Ekonomi/İç]
```

| # | Sütun | Kaynak | Rol |
|---|-------|--------|-----|
| 1 | **War** | fetih win/lose, hold süresi, garnizon doluluk | Klasik lonca savaşı |
| 2 | **Power** | Σ üye `power`, top-N, median | “Ne kadar güçlüyüz” |
| 3 | **PvP** | üye `pvp_wins` / `pvp_rating` sezon delta | Arena / duel katkısı |
| 4 | **Activity** | `last_active_at` 24s/7g login oranı, chat, zindan | AFK lonca cezası |
| 5 | **Economy** | vault collect, bölge gelir hold, monument | İç sistem / sürdürülebilirlik |

### 14.4 Formüller (v1 — onay sonrası kod)

#### Prestige (anlık, 0–10000 soft scale)

```
-- POWER (diminishing: top 15 üye sayılır, altı %30)
power_raw = Σ power(u) for top 15 by power
power_extra = Σ power(u) for rest * 0.30
P_power = log2(1 + power_raw + power_extra) * 120

-- ACTIVITY (0–1)
active_7d = count(members where last_active_at > now()-7d)
active_ratio = active_7d / max(member_count, 1)
P_activity = active_ratio * 800
           + min(active_7d, 20) * 25

-- HOLD (bölge)
hold = Σ for owned terr:
         zone_weight[zone] * (1 + garrison_fill)   -- garrison_fill 0–1
P_hold = hold * 180

-- PVP snapshot (rating tabanı, spam win değil)
avg_rating = avg(pvp_rating of members with pvp_rating > 0)
P_pvp_snap = log2(1 + avg_rating) * 90
           + min(count(pvp_rating>0), 15) * 20

-- ECONOMY snap
P_econ = log2(1 + vault_gold + vault_gold_pending/2) * 40
       + monument_level * 30

prestige = P_power + P_activity + P_hold + P_pvp_snap + P_econ
```

`zone_weight`: Z1=1.0 … Z7=1.8 (zengin bölge tutmak daha kıymetli).

#### Season score (biriken olaylar)

| Olay | Puan | Not / cap |
|------|------|-----------|
| Bölge fetih **win** | **+80** | eski 100 → biraz düşür (sütun dengesi) |
| Bölge saldırı **lose** | **+8** | katılım ödülü, spam cezası yok |
| Bölge **hold tick** (6s cron) | **+zone_weight×3** / sahip olunan bölge | “tutmak” = puan |
| Garnizon’a ilk yazılma (üye/gün) | **+5** | max 50/lonca/gün |
| Saldırı **takviye** pledge | **+4** / üye | max 40/plan |
| Üye **PvP win** (sezon) | **+6** | cap 300/lonca/hafta (smurf farm) |
| Üye **PvP lose** | **+1** | cap 100/hafta |
| Lonca üyesi **zindan clear** | **+1** | cap 200/hafta |
| Lider **vault collect** | **+10** | günde 1 kez |
| Lider **equal/alloc dağıtım** | **+15** | günde 1 kez (paylaşım teşvik) |
| Monument level up | **+40** | |

**Anti-abuse:**
- Aynı rakibe 1 saat içinde 3+ saldırı → 3.’den itibaren win puanı ×0.25  
- Sezon ortası toplu üye alımı: yeni üyenin PvP/zindan puanı **48s gecikmeli** sayılır  
- `member_count` ile power puanı log scale → 40 AFK alt hesap şişirmez

### 14.5 Ağırlık özeti (hedef his)

Sezon sonu tipik sağlıklı lonca skor katkısı:

| Sütun | Hedef pay |
|-------|-----------|
| War (fetih+hold+destek) | **35%** |
| Power | **20%** |
| PvP | **20%** |
| Activity | **15%** |
| Economy | **10%** |

→ Sadece savaşan ama ölü lonca zirveye oturmaz.  
→ Sadece güçlü AFK roster zirveye oturmaz.  
→ PvP main lonca savaşsız da görünür ama kral olamaz.

### 14.6 As-is vs hedef

| | As-is | Hedef |
|--|-------|-------|
| Kaynak | sadece `attack_guild_war_territory` | 5 sütun |
| Win/lose | +100 / +10 | +80 / +8 + hold tick |
| Güç | yok | prestige P_power |
| PvP | yok | event + snapshot |
| Aktiflik | yok | login oranı |
| UI | tek sayı | breakdown chip’ler |
| Recompute | event | event + 15 dk job |

### 14.7 Veri modeli

```sql
-- season event ledger (audit + recompute)
guild_season_score_events (
  id bigserial,
  season_id uuid,
  guild_id uuid,
  kind text,           -- conquest_win, pvp_win, hold_tick, ...
  points int,
  actor_id uuid null,
  payload jsonb,
  created_at timestamptz
)

-- rankings genişlet
guild_war_rankings:
  points              -- = season_score (event toplamı)  [mevcut kolon reuse]
  prestige            -- anlık cache
  rank_score          -- points + floor(prestige*0.25)  → ORDER BY bu
  breakdown jsonb     -- {war, power, pvp, activity, economy}
  wins, losses        -- kalır
```

RPC:
- `recompute_guild_prestige(guild_id)` / `recompute_all_guild_prestige()`
- `get_guild_war_rankings()` → `rank_score`, `breakdown` döner
- Event helper: `_guild_season_add_points(guild, kind, pts, actor, payload)`

### 14.8 UI (hub sıralama)

```
#2  [TAG] Lonca Adı
    12.450 prestij skoru
    ▓▓▓▓ Savaş 34%  ▓▓▓ Güç 22%  ▓▓ PvP 18%  ▓ Aktif 16%  ▓ Eko 10%
    3 bölge · 12/15 aktif · PvP ort 1420
```

Detay sheet: sütun açıklamaları + “nasıl yükselir” ipuçları.

### 14.9 Krallık / turnuva bağlantısı

- **Haftalık sıralama ödülü** → `rank_score` top N  
- **Krallık seçimi** adaylık eşiği → min `rank_score` veya min War sütunu  
- Turnuva seed → `rank_score` bracket

Tek skor kaynağı = tartışma azalır.

### 14.10 Implement fazı F

1. Kolonlar: `prestige`, `rank_score`, `breakdown`  
2. `guild_season_score_events` + `_guild_season_add_points`  
3. Attack win/lose puanlarını yeni tabloya yaz (eski +100 yolunu değiştir)  
4. Hold tick cron (6s)  
5. PvP settle → lonca puanı (cap’li)  
6. `recompute_guild_prestige` + rankings RPC  
7. Flutter podium + breakdown UI  
8. QA: AFK lonca < aktif lonca; power-only < dengeli; fetih spam cap

### 14.11 Karar (kısa)

- [x] Puan sadece savaş olmasın — **kilitli**  
- [ ] `rank_score = season + 0.25*prestige` ağırlığı OK mi? (veya 0.15 / 0.40)  
- [ ] PvP haftalık cap 300 OK mi?  
- [ ] Hold tick 6s OK mi?  
- [ ] Top-15 power softcap OK mi?

---

## 15. Birleşik yol haritası (özet)

| Faz | Konu |
|-----|------|
| A | Stale UI/SQL (def oran, loot label, siege credit) |
| E | §13 güç-savunma + lider saldırı + garnizon/takviye |
| F | §14 prestij puanı + breakdown sıralama |
| **G** | **§16 Lonca Clash turnuva (aktif)** + hub tasarım |
| B/C | Ekonomi ROI + kasa governance |

**Bağımlılık:**  
E → F hold/garnizon.  
F `rank_score` → G seed.  
G Clash katkıları → F season_score event’leri (döngü).

---

## 16. Lonca Turnuva — AKTİF “Clash” sistemi

> As-is: join + bracket seed + **pending forever**. Match play/advance/resolve **yok**. Prize çoğu zaman `kazanan yok`. Hub Turnuva tabı = **vitrin**.  
> Hedef: lonca kısmı **aşırı aktif** — her üye her gün “bugün ne yapayım?” bilsin.

### 16.1 As-is vs hedef

| | As-is | Hedef |
|--|-------|-------|
| Kayıt | `join_guild_war` | Lider kaydeder + pencere |
| Bracket | seed by `points`, detail açınca | Cron: start_at’te seed by **`rank_score`** |
| Maç | skor 0, status pending | **Clash penceresi** (4–12s) — canlı skor |
| Üye rolü | yok | PvP / zindan / rally / fetih katkı |
| İlerleme | yok | Kazanan sonraki tura otomatik |
| Bitiş | stuck `active` | end_at / final → completed + prize |
| UI | “bracket yakında” | **Canlı skor board** + CTA banner |
| Ödül | `prize_gold` çoğu 0 | rotate seed’ler gerçek gold + item |

### 16.2 Turnuva takvimi (haftalık ritim)

```
Pzt 00:00  Haftalık Arena REG (kayıt açılır, 24s)
Sal 00:00  REG kapanır → bracket seed (8/16 slot)
Sal–Cmt    Round’lar peş peşe Clash pencereleri
           R1: 12s → R2: 12s → SF: 12s → Final: 12s
Paz        Ödül + dinlenme + Sezon Finali (aylık) countdown
```

| Tip | Kim girer | Slot | Ödül (**kilitli**) |
|-----|-----------|------|---------------------|
| **Haftalık Arena** | kayıt + min `rank_score` / üye sayısı | 8 veya 16 | **100,000,000g** havuz (aşağı dağılım) |
| **Sezon Finali** | sezon `rank_score` top 8 **otomatik** | 8 | **300,000,000g** havuz + **efsanevi ekipman +7** |

> Eski `50,000` / `250,000` metin ödüller **çöp** — 20M/gün bölge ekonomisine göre anlamsız. Rotate seed `prize_gold` zorunlu büyük sayı.

`rotate_guild_war_season` → turnuva satırlarına **`prize_gold` zorunlu yaz** (Haftalık `100_000_000`, Final `300_000_000`).

### 16.3 Maç modeli: Lonca Clash (pencere)

Tek maç ≠ tek tık simülasyon.  
Tek maç = **zaman pencereli katkı yarışı**.

```
MATCH OPEN (örn. 12 saat)
  ├─ Her iki lonca üyeleri katkı üretir → clash_score
  ├─ Canlı skor hub + detail + push
  └─ WINDOW CLOSE → resolve
        higher clash_score → winner
        tie → higher seed (rank_score)
        → advance bracket / final prize
```

#### Clash skoru formülü (maça özel)

```
clash_score =
    W_pvp   * clamp(pvp_points,   0, CAP_pvp)
  + W_dung  * clamp(dungeon_pts,  0, CAP_dung)
  + W_war   * clamp(war_pts,      0, CAP_war)
  + W_rally * rally_power_score
  + W_act   * active_member_bonus
```

| Kaynak | Nasıl | Puan | Cap / maç |
|--------|-------|------|-----------|
| **PvP** | Üye PvP win (herhangi rakip) | +12 | 180 |
| | PvP lose | +2 | 40 |
| **Zindan** | Üye dungeon clear | +4 | 120 |
| **War** | Lider fetih win (herhangi bölge) | +25 | 75 |
| | Fetih lose / saldırı denemesi | +5 | 25 |
| | Garnizon’a yazılma (maç sırasında) | +3 | 30 |
| **Rally** | Üye “Clash’e katıl” pledge | `log2(1+Σ power) * 15` | — |
| **Aktiflik** | Maç penceresinde ≥1 aksiyon yapan üye | +8 / üye | max 15 üye = 120 |

**Ağırlık hissi (hedef):** PvP %30 · Zindan %20 · War %20 · Rally(güç) %20 · Aktif üye %10  
→ Saf power AFK lonca kaybeder. Saf zindan farmer da PvP’siz zorlanır.

**Anti-abuse:**
- Aynı rakibe farm PvP: 3+ maç/saat sonrası ×0.2  
- Yeni üye (<48s loncada) Clash’e sayılmaz  
- Alt hesap: aynı device/IP soft flag (mevcut anticheat’e bağla)  
- Rally: üye başına 1 kez / maç; power snapshot pledge anında

### 16.4 Lider / üye rolleri (turnuva)

| Aksiyon | Leader | Member |
|---------|--------|--------|
| Turnuvaya kayıt | ✅ | ❌ |
| Clash sırasında fetih | ✅ (§13) | takviye (§13) |
| Rally (Clash’e katıl) | ✅ | ✅ |
| PvP / zindan katkı | ✅ | ✅ |
| Maç sonucu itiraz | ✅ (staff) | ❌ |
| Ödülü vault’tan dağıt | ✅ (mevcut distribute) | ❌ |

### 16.5 Bracket & lifecycle RPC’ler (yeni)

```
register_guild_war_tournament(tournament_id)     -- leader, REG window
seed_guild_war_tournament_bracket                -- start_at cron / staff; rank_score
open_tournament_match(match_id)                  -- status=live, window_start/end
contribute handled via hooks:
  on_pvp_settle / on_dungeon_clear / on_territory_attack / rally_rpc
  → _tournament_clash_add(match_id, guild_id, kind, pts, actor)
resolve_tournament_match(match_id)               -- end window; set winner; advance
close_guild_war_tournament(tournament_id)        -- final done → winner_guild_id, prize
cron_tournament_tick()                           -- open/resolve/close by time
```

Matches kolon ekleri:
```
window_start, window_end
guild1_clash_score, guild2_clash_score
status: pending|live|completed|forfeit
```

Contribution ledger:
```
guild_war_tournament_contributions (
  match_id, guild_id, user_id, kind, points, created_at
)
```

### 16.6 Seed kuralı

```
ORDER BY rank_score DESC, prestige DESC, random()
```
1 vs 8, 4 vs 5, 2 vs 7, 3 vs 6 (klasik).  
Slot dolmazsa bye → otomatik advance.

Kayıt şartı (Haftalık):
- Lider
- `member_count >= 3`
- En az 2 üye son 48s aktif
- (opsiyonel) min `rank_score`

### 16.7 Ödül (**kilitli sayılar**)

#### Haftalık Arena — havuz **100,000,000g**

| Sıra | Vault gold | Item | Season score |
|------|------------|------|--------------|
| **1** | **60,000,000** (havuzun %60) | 3× non-common roll | +200 |
| **2** | **25,000,000** (%25) | 2× non-common | +100 |
| **SF (×2)** | **7,500,000** each (%7.5) | 1× non-common | +40 |
| Katılım | — | — | +15 |

`prize_gold = 100_000_000` (toplam havuz; dağıtım yukarıdaki oran).  
`prize_pool` text: `"100,000,000 Altın"`.

#### Sezon Finali — havuz **300,000,000g** + efsanevi +7

| Sıra | Vault gold | Item | Season / unvan |
|------|------------|------|----------------|
| **1** | **180,000,000** (%60) | **1× legendary ekipman @ enhancement_level = 7** (rastgele legendary weapon/armor, `max_enhancement >= 7`) + 2× non-common | +500 · sezon şampiyonu tag |
| **2** | **75,000,000** (%25) | 1× legendary @ **+5** + 1× non-common | +250 |
| **SF (×2)** | **22,500,000** each (%7.5) | 1× epic/legendary @ **+3** | +80 |
| Katılım (top8) | — | — | +30 |

`prize_gold = 300_000_000`.  
`prize_pool` text: `"300,000,000 Altın + Efsanevi +7"`.

**Efsanevi +7 grant kuralları:**
1. Pool: `items` where `rarity = legendary` AND `can_enhance = true` AND `max_enhancement >= 7` AND equip_slot dolu (silah/zırh).  
2. Insert `guild_vault_items` with metadata `enhancement_level: 7` (vault item satırına enhancement kolonu yoksa → `payload` / ayrı `guild_vault_items.enhancement_level` kolonu ekle).  
3. Lider `distribute_guild_vault_item` → üye envanterine **+7 korumalı** geçer (enhancement korunur).  
4. Market/trade: mevcut bind kuralları; öneri **sezon ödülü bind-on-pickup** (satılamaz) — abuse önler.

`grant_guild_war_tournament_prize` → final resolve’dan **otomatik**; vault open’a bağımlı olmasın.  
Eski 50k/250k seed’ler migration ile **UPDATE** edilir.

### 16.8 Hub / UI — tasarım değişikliği (pasif → aktif)

Lonca Savaşı hub şu an 4 tab: Sıralama | Turnuva | Bölge | Krallık — Turnuva **ölü liste**.

#### A) Hub üst banner (her zaman görünür)

```
┌─────────────────────────────────────────────┐
│ ⚔ CANLI CLASH · Demir Kaplanlar vs Gölge    │
│ ████████░░ 142–98 · 03:12:44 kaldı          │
│ [Maça git]  [Rally ol]  [PvP aç]            │
└─────────────────────────────────────────────┘
```

Canlı maç yoksa:
```
│ Sonraki Clash 2s 14dk · Kayıt açık: Haftalık Arena │
```

#### B) Turnuva tab yeniden

1. **Aktif turnuva kartı** (büyük) — progress, senin tur, CTA  
2. Bracket görseli — live skor animasyonu  
3. **Lonca katkı board** — bu maçta kim kaç puan (üyeleri motive)  
4. Geçmiş turnuvalar collapse

#### C) Turnuva detail

- Üst: VS + canlı skor + countdown  
- Orta: “Nasıl katkı?” chip’leri (PvP · Zindan · Rally · Fetih) — her biri deeplink  
- Alt: bracket + katkı listesi  
- Match card tıklanınca → clash panel (artık read-only değil)

#### D) Bildirim / retention

| Event | Notif |
|-------|-------|
| Kayıt açıldı | lider |
| Bracket seed | tüm üyeler |
| Senin maçın LIVE | tüm üyeler + push |
| Rakip önde (her 25 puan fark) | uyarı |
| 1s kala | son çağrı |
| Kazandınız / elendiniz | sonuç |

`get_retention_promos` / inbox kind: `guild_clash_live`, `guild_clash_result`.

#### E) Ana sayfa sticky (opsiyonel)

Clash live iken StickyActionBar / promo carousel’e **Lonca Clash** slide — Gece/Nemesis yanına.

### 16.9 Prestij (§14) ile bağ

| Clash olayı | Season score |
|-------------|--------------|
| Turnuva kaydı | +15 |
| Clash win (maç) | +50 |
| Clash lose | +12 |
| Final win | +200 |
| Üye katkı (PvP/dung in clash) | mevcut PvP/dung event’leri + clash bonus ×1.5 |

Seed = `rank_score` → iyi sezon yapan lonca bracket’te avantaj; ama Clash penceresinde **aktif üye** kazanır.

### 16.10 Bölge / garnizon (§13) ile bağ

- Clash sırasında fetih hâlâ lider-only; takviye üyelerden.  
- War katkıları Clash skoruna yazar.  
- **Öneri:** Clash penceresinde rakip loncanın tuttuğu bölgeye saldırı → War puanı ×1.5 (kan davası).  
- Garnizon doluluk prestige’i besler; turnuva seed’i dolaylı etkiler.

### 16.11 Forfeit / AFK

- Pencere boyunca **0 katkı** → forfeit (rakip walkover)  
- Lider maça hiç bakmasa bile üyeler Rally+PvP ile kurtarabilir → “aşırı aktif üye” meta  
- İki taraf da 0 → yüksek seed geçer

### 16.12 Implement fazı G

1. Match kolonları + contributions tablosu  
2. `cron_tournament_tick` (open/resolve/close)  
3. Hook: PvP / dungeon / attack / rally → `_tournament_clash_add`  
4. `register_*` leader + window checks; `prize_gold` rotate fix  
5. Flutter: hub live banner + clash panel + katkı board  
6. Notif kinds + retention promo  
7. QA: 2 lonca fake clash → skor → advance → prize vault

### 16.13 Tasarım checklist (UI)

- [ ] Hub live Clash banner  
- [ ] Turnuva tab: büyük aktif kart + bracket anim  
- [ ] Match detail: katkı CTA chip’leri (deeplink)  
- [ ] Üye katkı leaderboard  
- [ ] Countdown + skor bar  
- [ ] Empty state “bracket yakında” **sil** → “Clash başlayınca burada canlı skor”  
- [ ] Ana sayfa promo (live iken)

### 16.14 Karar

- [x] Turnuva pasif kalmayacak — **kilitli**  
- [ ] Clash pencere süresi: **12s** / 6s / 24s?  
- [ ] Slot: **8** mi **16** mu (haftalık)?  
- [ ] Rakip bölgeye saldırı ×1.5 bonus OK mi?  
- [ ] Ana sayfa Clash promo: evet / hayır?

---

## 17. Final audit — mantıksız / çelişkili / eksik (2026-07-29)

> Bu bölüm planın kendi iç tutarlılık kontrolü. Implement öncesi çözülmeli.

### 17.1 Kritik çelişkiler (P0 — karar şart)

| # | Çelişki | Nerede | Ne yapmalı |
|---|---------|--------|------------|
| C1 | **“Tüm üye gücü” vs garnizon** | Kullanıcı: savunma = lonca üye toplam güç. Plan §13: sadece **garnizona yazılanlar**. 7 bölgeye full Σ power yazılırsa meta ölür. | **Kilitle: garnizon zorunlu** (öneri) VEYA “tüm güç / sahip olunan bölge sayısına bölünür”. Literal “her bölgeye full Σ” **yapma**. |
| C2 | **Fetihte `defense_power` dokunulmaz** | §131000 canlı: gem=0, `defense_power` kalır. → Yeni sahip **eski loncanın altın duvarını miras alır**. Altın def kaldırılana kadar exploit. | Altın def **hemen disable** + `defense_power` fetihte `base` veya garnizon recompute. “Sadece gem sıfır” + gold miras = **bug**. |
| C3 | **Altın savunma: kaldır vs hâlâ bak** | §10 kilit: KALDIR. Ama §2/§7/Faz A hâlâ gold oran fix, §7.3 officer gold def. | Faz A’dan gold sheet fix **sil**. Faz E: RPC+UI gold **kaldır**. §7 gold satırlarını deprecate işaretle. |
| C4 | **Saldırı yetkisi** | §10: sadece lider. §6.2/§7.3: officer+leader. DB’de `officer` rolü **yok** (sadece leader/member). | Kilitle: **sadece leader**. Officer yoksa matriste yazma. |
| C5 | **Turnuva ödül kaynağı belirsiz** | Haftalık 100M / Final 300M vault’a giriyor. Mint mi, havuz mu, tax mı? | **Sistem mint** (en basit) yaz; yoksa enflasyon / “ödül yok çünkü kasa boş” krizi. |

### 17.2 Ekonomi tutarsızlıkları (P1)

| # | Sorun | Etki |
|---|-------|------|
| E1 | Canlı saldırı maliyeti ~%5 gün (~1.2s ROI). §7.1 öneri ~1.75× gün. | Flip-flop meta devam; §7 uygulanmadan §13 güç duvarı yetmez. |
| E2 | Haftalık 1. = **60M**; Z5 günlük gelir 20M → turnuva ≈ 3 gün tek bölge. Final 180M ≈ 9 gün. | Turnuva > bölge tutma (bilinçli olabilir) — **açık yaz**: “asıl jackpot turnuva”. |
| E3 | Siege claim `income/20` → Z7 **1.25M**/claim hâlâ açık. | Vault spam; saldırı/ödülle çatışır. |
| E4 | Accrual ownership backfill hâlâ açık. | Haksız gold. |
| E5 | Loot 6–7/bölge/gün × 7 bölge = **42–49 item/gün** tek lonca. | Enflasyon; curated pool + belki “lonca başına toplam cap” düşün. |

### 17.3 Tasarım / skor çift sayım (P1)

| # | Sorun | Not |
|---|-------|-----|
| S1 | Aynı `users.power` → garnizon def + prestige Power + Clash Rally | Kabul edilebilir; Rally’yi “katıldım” token’ı yap (düz power yerine sabit + küçük bonus) daha temiz. |
| S2 | PvP hem season event (+6) hem prestige snapshot | Katmanlı OK; UI’da “olay vs anlık” ayır. |
| S3 | Clash’te “herhangi bölgeye fetih” War puanı | Rakip dışı farm mümkün. ×1.5 sadece rakibe; diğer fetih ×0.5 veya Clash dışı say. |
| S4 | Hold tick 6s × 7 bölge = pasif puan yağmuru | Cap: örn. günde max N hold puanı / lonca. |
| S5 | `rank_score = season + 0.25×prestige` sezon başı ≈ saf güç sıralaması | Bilinçli; sezon 48s “sezon event ağırlığı düşük” uyarısı UI’da. |

### 17.4 Metin / tablo stale (P2 — dokümantasyon)

| # | Stale | Düzelt |
|---|-------|--------|
| D1 | §1 “şimdi def=0” | → “fetihte yalnız gem=0” |
| D2 | §3.2 tablo `defense_power` → 0 | → dokunulmaz / cache recompute |
| D3 | §5 P0-2 “fetihte sıfır” hâlâ P0 bug gibi | → kilitli tasarım; P0’dan çıkar, C2 miras uyarısına bağla |
| D4 | §11 “Savunma 0 + ping-pong” | → güncelle: gem-only + ROI düşük = asıl risk |
| D5 | §9 “Attack + def wipe” migration ref eski | → `131000` gem-only |
| D6 | Faz A gold sheet fix | → gold kaldırılacaksa atla |

### 17.5 Eksik / belirsiz (açık karar listesi — sıkıştırılmış)

Zorunlu kilitle (implement bloklar):

1. **Savunma gücü modeli:** garnizon (öneri) / paylaşılmış Σ / full Σ her bölge  
2. **ROI / attack_gold_cost** çarpanı (öneri 1.5–2× gün)  
3. **Destek:** A / B / A+B  
4. **Elmas kim ekler:** lider / her üye kendi gem  
5. **Clash:** pencere süresi + slot 8/16  
6. **Ödül mint:** sistem basar (öneri)  
7. **Grace:** 0 / 2s  
8. **Siege credit** yeni formül  
9. **Legendary +7:** vault `enhancement_level` kolonu + bind-on-pickup evet/hayır  
10. Prestij `0.25` ağırlık + PvP/hold cap

### 17.6 Mantık olarak SAĞLAM kalan omurga

```
Lider fetih (vault) → sahip
Savunma = garnizon Σ power + gem (her an; kayıp → gem sıfır)
Gelir → pending → lider collect → dağıt
Sıralama = season olay + prestige (güç/pvp/aktif/eko)
Turnuva = Clash penceresi (üyeler katkı) → büyük jackpot
```

Bu omurga tutarlı. Kırılan yerler: **gold miras (C2)**, **full-power her bölge riski (C1)**, **ödül mint (C5)**, **ROI hâlâ %5 (E1)**, **officer hayali rol (C4)**.

### 17.7 Önerilen “son kilitleme” paketi (tek onay)

Implement’e geçmeden şu varsayılanları onayla:

| Madde | Varsayılan |
|-------|------------|
| Savunma | **Garnizon** (1 üye → 1 bölge) + gem |
| Altın def | **Sil** (hemen); fetihte defense_power = garnizon recompute/0 cache |
| Saldırı | **Sadece lider**; atk = lider.power + takviye (A+B) |
| ROI | attack_cost ≈ **1.5 × daily income** |
| Grace | **2 saat** |
| Gem ekle | **Lider + üye kendi gem’i** (üye kendi elmasını yakar) |
| Clash | **12s** pencere, **8** slot haftalık |
| Ödül | **Sistem mint** 100M / 300M+leg+7; bind-on-pickup |
| Siege credit | `income/200` |
| Prestij | `season + 0.25×prestige` kalsın |

Onay → Faz A (stale, gold kaldır, siege credit) → E → F → G.

# GKK Ekonomi Özet Raporu (TR)

**Tarih:** 2026-07-24 (§13 zindan altın revizyonu)  
**Kaynak:** `comprehensive_smoke_10000_30d.json` + Supabase canlı sorgular + sim aktivite dökümü  
**Sim:** 10.000 bot · 30 gün · ~300.000 günlük event

> **Mağaza notu:** Canlı genel shop şu an **QA test modu** (tüm katalog, altın). Prod vizyon: **elmas + ~%10 katalog** — §7, §10.C, §12.

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

> **Sim uyarısı:** Sim `dungeon×650` düz katsayı kullanır — **ilk geçiş ×1,75** (canlı) veya eski **`gold_max×5`** patlamasını ayırmaz. Gerçek enflasyon kaynağı **dungeon başına ilk temizleme**; tekrar koşular taban ödül + farm cezası ile daha düşük. Detay: **§13**, `reports/DUNGEON_GOLD_FLOW_TR.md`.
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

> **Sim boşluğu (shop):** Ekonomi sim'i `market_buy` / `market_sell` ile altın akışını tahmin eder; **genel mağaza (`buy_shop_item`) ve elmas fiyatlı satış simüle edilmez**. Canlıda shop gem para birimine geçince sim altın sink'ini **eksik** gösterir.

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

## 7. Siege / Trade / Craft / Sell / Shop Etkisi

| Sistem | Sim durumu | Ekonomi etkisi |
|--------|------------|----------------|
| **Kuşatma (siege)** | RPC smoke PASS; sim'de ayrı faucet/sink yok | Canlı bonus çarpanları var — sim enflasyonu **eksik düşük** gösterebilir |
| **Trade (P2P)** | Sim'de **simüle edilmiyor** | Altın transferi / arbitraj test dışı |
| **Craft** | 449k action | Sink var ama faucet (dungeon loot + sell) daha güçlü |
| **NPC sell** | Migration `20260725_040000` uygulu | `vendor_sell ≈ base_price × 0,35` (ör. 175/500) — **prod altın sink ana hattı** |
| **Genel mağaza (`/shop`)** | Sim'de **yok**; canlıda test modu | Tüm katalog açık + altın fiyat — **prod tasarımı değil** |
| **Mekan shop** | Sim'de `mekan_actions×300` altın proxy | Oyuncu dükkanı; altın; fiyat bandı var — genel shop'tan **ayrı sistem** |

### Ürün vizyonu: test shop ≠ prod shop

| | **Şu an (test/QA)** | **Prod hedefi (kullanıcı kararı)** |
|--|---------------------|-------------------------------------|
| **Genel mağaza katalog** | Migration `20261013_030000` → `shop_available=true` **tüm item'lar** | Katalogun **~%10'u** — seçilmiş subset (iksir, scroll, QoL vb.) |
| **Para birimi** | `shop_currency='gold'` (çoğu item) | **`gems` (elmas)** — altın shop satışı prod'da yok |
| **Fiyat kaynağı** | `items.base_price` (RPC `buy_shop_item` server-side) | Elmas fiyat tablosu — altın NPC/market/mekan ile karışmaz |
| **Ekonomi rolü** | QA kolaylığı; altın arbitraj testi | **Gem sink** (IAP sonrası harcama); altın enflasyonu ile **doğrudan bağlı değil** |

**Mekan shop ayrı kalır:** `mekan_stock` + `buy_from_mekan` — oyuncu dükkanı, **altın**, owner fiyat bandı (`mekan_price_band`). Prod genel shop ile karıştırılmamalı.

**Itibar mağazası ayrı:** Reputation puanı ile satın alma — ne altın ne elmas.

### Mevcut kod durumu (canlı)

| Bileşen | Dosya / RPC | Not |
|---------|-------------|-----|
| Genel shop UI | `lib/screens/shop/shop_screen.dart` | `items.shop_available=true` filtreler; `shop_currency` gold/gems destekler |
| Satın alma | `buy_shop_item` | Client fiyatı yok sayar; `base_price` + `shop_currency` kullanır |
| Test seed | `20261013_030000_enable_all_items_in_shop.sql` | Açık yorum: *"Temporary … full catalog for now"* |
| Mekan stok | `mekan_stock`, `update_mekan_stock`, `buy_from_mekan` | Sadece iksir + Han item; altın ödeme |
| NPC satış | `compute_npc_sell_price` | Fazla loot → altın dönüşüm sink'i |

### Test ortamı fiyat örneği (prod kararını yansıtmaz)

| Item | NPC sell | Test shop (gold) | Base |
|------|----------|------------------|------|
| Rawhide | 175 | 100 | 500 |
| Stone Talisman | 760 | 100 | — |
| Iron Ore | 175 | — | 500 |

Bu tablo **QA test envanteri** içindir. Prod'da Rawhide vb. genel shop'ta **satılmayacak**; altın sink için **NPC satış** ana kanal kalır.

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

## 10. Öneriler — 5 aksiyon (oyuncu ve ekonomi etkisi)

**Durum özeti:** Oyunda altın çok hızlı üretiliyor, harcanmıyor. Simülasyonda **%56,33 enflasyon** var; hedef **%12'nin altı**. Yani üretilen altının yarısından fazlası havuzda kalıyor — fiyatlar anlamını yitiriyor, yeni oyuncular geride kalıyor.

Bu bölümde **5 somut aksiyon** var. Her biri: ne sorunu çözüyor, oyuncu ne hissedecek, ne kadar iş.

### Özet tablo

| Aksiyon | Oyuncuya etkisi | Öncelik |
|---------|-----------------|---------|
| **A — İlk geçiş zindan bonusu düşür** | Her zindanın **ilk temizlemesindeki** altın patlaması azalır; tekrar grind aynı kalır | 🔴 1 — en acil |
| **B — Başarısız işlemlerde ek altın yakımı** | Enhancement/craft/zindan kaybında küçük ekstra maliyet; riskli oyun daha pahalı | 🟠 2 |
| **C — NPC satış floor + prod shop elmas** | Fazla loot NPC'ye satılır (altın sink); genel shop elmas + ~%10 katalog — altın shop yok | 🟠 2 |
| **D — Casual oyuncu görev hattı** | 15 dk oynayan biri ne kazanır ne kaybeder; 7. günde oyunda kalma artar | 🟡 3 |
| **E — Kuşatma slot günlük vergisi** | Lonca slot tutmak altın harcar; bonus biraz düşer ama sistem dengelenir | 🟡 3 |

**Hepsi birlikte uygulanırsa:** enflasyon **%56 → yaklaşık %22–28** (hâlâ hedefin üstünde; ikinci tur ayar gerekebilir).

---

### 10.A — İlk geçiş zindan bonusunu hedefle (tekrar koşulara dokunma)

**Sorun ne?**  
Zindan en büyük altın kaynağı (~**%45–50** sim payı) ama sorun **sürekli grind değil** — oyuncu her yeni zindanı **ilk kez** temizleyince abartılı altın alıyor. Canlı yol (`attack_dungeon` → `enter_dungeon(uuid,text)`): `_dungeon_farm_reward_multiplier` ile **ilk geçiş ×1,75**. Tekrar koşularda aynı taban + overlevel farm cezası (min **%20**); canlı `dng_001` tekrar ort. **~9.300** altın.  
Eski **`enter_dungeon(text)`** legacy RPC hâlâ DB'de: **`gold_max × 5`** düz bonus — fallback veya eski kayıtlarda patlama (ör. `dng_001` ilk geçiş max **73.766**).

**Ölüm / teselli (doğrulandı):** Hastaneye düşünce **0 altın** (`20260502`). Oyuncunun gördüğü “ölüm” = hastane → teselli yok. Kodda hastane olmadan fail için `gold_min×0,3` var (Z4+ nadir); ana deneyim **altınsız ölüm**.

**Ne yapacağız?**  
- **`first_clear_mult` 1,75 → 1,25** (veya 1,30) — sadece ilk geçiş  
- **Tekrar `gold_min..gold_max` tabanına dokunma**  
- Legacy **`enter_dungeon(text)` kaldır veya 2-arg ile birleştir** (`gold_max×5` riski)  
- Kuşatma / rep buff tavanı ayrı (§10.E)  
- Sim: `dungeon×650` yerine first-clear ağırlıklı model

**Oyuncu ne hisseder?**  
Yeni zindan açılışında hâlâ “ilk geçiş ödülü” var ama servet sıçraması azalır. Günlük farm ve tekrar koşu hissi **aynı**.

**Sayısal hedef:** İlk geçiş kaynaklı gold_in **~−40–50%** (65 zindan × bir kez); genel enflasyondan **~8–12 pp** (tekrar dokunulmadığı için eski −35% global hedefinin yarısı kadar).

<details>
<summary><strong>Teknik detay</strong></summary>

- **Canlı RPC:** `attack_dungeon` → `enter_dungeon(p_player_id uuid, p_dungeon_id text)` — patch: `20260724_210000_reputation_buffs_gameplay.sql`
- **Gold formülü (başarı):** `random(gold_min..gold_max)` → crit ×1,5 → luck → warrior boss ×1,15 → **`_dungeon_farm_reward_multiplier`** (overlevel min **%20**, **first clear ×1,75**) → monument → siege `gold_mult` → rep `gold_boost`
- **Fail:** hastane → **0**; değilse `gold_min×0,3` (oyuncu deneyiminde marjinal)
- **Legacy risk:** `enter_dungeon(text)` — flat **`gold_max×5`** + fail **0**; `DungeonRepository` fallback
- **Örnek (teorik taban ort., çarpansız):**

| Zindan | Tekrar | İlk ×1,75 | Legacy (+×5 max) |
|--------|--------|-----------|-----------------|
| dng_001 | 8.500 | 14.875 | 68.500 |
| dng_020 | 85.000 | 148.750 | 660.000 |
| dng_050 | 1.575.000 | 2.756.250 | 12.175.000 |

- **Migration önerisi:** `first_clear_mult` 1,75→1,25; `DROP enter_dungeon(text)` veya sync
- **Dosyalar:** `20260613_131000_dungeon_reward_balance.sql`, `dungeon_battle_screen.dart`, `dungeon_confirm_entry_dialog.dart`, `power_formula.dart`
- **Test:** `./scripts/run_dungeon_siege_smoke.sh` PASS 11/11; `./scripts/run_player_journey_smoke.sh` PASS 6/6; `flutter test test/dungeon_siege_*` 23/23
- **Tam rapor:** `reports/DUNGEON_GOLD_FLOW_TR.md`

</details>

---

### 10.B — Başarısız işlemlerde ek altın harcama yeri (%2–5 bandı)

**Sorun ne?**  
Enhancement başarısız olunca, craft patlayınca veya zindanda hastaneye düşünce altın gidiyor ama **ekstra bir "kaybetme maliyeti" yok**. Oyuncu risk alıp tekrar deniyor; sistem altını geri alamıyor. Tamir sistemi de henüz yok — ekipman yıpranması altın harcatmıyor.

**Ne yapacağız?**  
Başarısız enhancement, başarısız craft ve zindanda hastaneye düşme anında, o işlemin maliyetinin **%3'ü kadar ekstra altın yakılacak** (ortalama band **%2–5**). İleride ekipman tamiri eklenecek — her tamir item fiyatının **%2'si** kadar altın harcatacak. Ekranda "başarısızlık vergisi" gösterilecek.

**Oyuncu ne hisseder?**  
Enhancement ve craft artık "bedava deneme" değil — her fail küçük bir ekstra maliyet. Whale oyuncular yüksek seviye enhancement'ta daha çok hisseder; casual oyuncu düşük maliyetli işlemlerde farkı az görür. Zindanda ölünce sadece zaman değil, biraz altın da gider.

**Ne kadar sürer?**  
**Büyük iş** — yeni altın kayıt sistemi + 3 farklı oyuna bağlama + ekran güncellemesi.

**Sayısal hedef:** Harcanan altın **%8–12 artar** → enflasyondan **5–8 yüzde puan** düşüş.

<details>
<summary><strong>Teknik detay</strong></summary>

- **RPC'ler:** `public.enhance_item`, `public.craft_item_async`, `enter_dungeon` (hospitalized branch)
- **Yeni fn:** `public.economy_apply_fail_tax(p_user_id, p_base_amount, p_source)` — `tax := floor(p_base_amount * 0.03)`, `economy_ledger` log
- **Migration:** `20260726_020000_economy_fail_tax.sql`
- **Faz 2:** `repair_equipment(p_row_id)` — `floor(base_price × 0.02)` per repair
- **Dosyalar:** `20260307_040000_plan_05_enhancement_system.sql`, `20260720_100000_get_enhancement_config.sql`, `20260301_020000_create_craft_queue_and_rpcs.sql`, `lib/screens/enhancement/enhancement_screen.dart`
- **Risk:** Whale L7+ fail tax büyük — cap `LEAST(tax, floor(gold*0.05))` düşün

</details>

---

### 10.C — NPC satış floor güçlendir + prod shop elmas (~%10 katalog)

**Sorun ne?**  
İki ayrı konu karışıyor:

1. **Altın sink:** Oyuncu fazla loot biriktiriyor; NPC satış (`vendor_sell ≈ base×0,35`) düşük hissettiriyor — loot → altın dönüşümü zayıf kalıyor.  
2. **Test shop yanılsaması:** Canlıda genel mağaza **tüm katalog + altın fiyat** — migration `20261013_030000` ile QA için açılmış. Bu **prod ekonomisi değil**. Prod'da shop = **elmas**, katalog **~%10**.

Test ortamındaki "shop 100g vs NPC 175g" karşılaştırması prod kararını yansıtmaz; altın shop markup önerisi **prod için geçerli değil**.

**Ne yapacağız?**  
1. **NPC satış floor** — common malzeme **175g → 220g+** (`compute_npc_sell_price`); fazla item için **birincil altın sink**.  
2. **Prod shop whitelist** — `shop_available=true` sadece seçilmiş ~%10 item; geri kalan `false`.  
3. **Prod shop para birimi** — whitelist item'larda `shop_currency='gems'` + elmas fiyat tablosu (`base_price` veya ayrı kolon).  
4. **Test env temizliği** — launch öncesi `20261013_030000` geri al / flag; QA-only build'de tam katalog kalabilir.  
5. Envanterde **NPC satış fiyatı** gösterimi (zaten planlı).

**Oyuncu ne hisseder?**  
Loot'u NPC'ye satmak daha anlamlı altın getirir. Genel mağazadan alışveriş **elmas** ile — IAP/etkinlik elmasını harcama yeri. Altın shop yok → altın arbitraj döngüsü kapanır. Mekan dükkanları (oyuncu) altınla kalır — ayrı ekonomi.

**Ne kadar sürer?**  
**Orta iş** — NPC formül + whitelist migration + shop_currency gem + UI elmas gösterimi.

**Sayısal hedef:** NPC satış artışı → **2–4 yüzde puan** altın enflasyon düşüşü. Gem shop altın enflasyonuna **doğrudan etki etmez** (gem sink ayrı metrik).

<details>
<summary><strong>Teknik detay</strong></summary>

- **NPC RPC:** `public.compute_npc_sell_price(...)` — migration `20260725_040000_item_sell_knight_online_economy.sql`
- **Migration (NPC):** `20260726_030000_shop_npc_price_floor.sql` — common `v_sell_pct **0.35→0.42**` (shop markup kaldırıldı; sadece NPC floor)
- **Migration (prod shop):** `shop_available` whitelist (~%10); `shop_currency='gems'`; test seed rollback
- **Test seed (QA):** `20261013_030000_enable_all_items_in_shop.sql` — prod'da **uygulanmamalı** veya `qa_full_shop=true` flag
- **RPC:** `buy_shop_item` zaten server-side `shop_currency` + `base_price` kullanır
- **Mekan ayrı:** `update_mekan_stock` / `buy_from_mekan` — altın, fiyat bandı; genel shop kurallarından muaf
- **Dosyalar:** `lib/screens/shop/shop_screen.dart`, `20261013_000000_secure_shop_currency_inventory.sql`, `lib/core/utils/item_sell_price.dart`

</details>

---

### 10.D — Casual oyuncu için 7 günlük görev hattı (15 dk = sıfır net altın)

**Sorun ne?**  
Casual oyuncu 15 dakika oynayıp **binlerce altın biriktiriyor** ama **7. günde oyundan ayrılıyor** (D7 retention **%56,3**). Yeni oyuncu 30 günde neredeyse tamamen kayboluyor (**%4,3 D30**). Günlük görevler çok altın veriyor (500g, 300g, 200g); 7. gün login ödülü **25.000 altın**. Oyuncu altın biriktiriyor ama "ne yapacağım?" sorusu cevapsız kalıyor.

**Ne yapacağız?**  
1. **7 günlük yeni görev zinciri** — her gün küçük altın (50–150g), asıl ödül XP ve itibar.  
2. **Günlük görev altınları %60 düşür** — 500→200, 300→120, 200→80.  
3. **Login ödülleri %40 düşür** — 7. gün 25.000→12.000 (eşya ödülü kalır).  
4. Bazı görevler küçük altın giriş ücreti isteyecek — enerji ve iksir tüketimi zorunlu.  
5. Oyun içi rehber: "Casual 7 gün" takibi.

**Oyuncu ne hisseder?**  
15 dakika oynayan biri gün sonunda **−500 ile +500 altın arasında** kalır — ne zenginleşir ne fakirleşir. Görevler "bugün ne yapmalıyım?" sorusunu cevaplar. Hardcore oyuncu günlük ödül azalmasından şikâyet edebilir — kademeli açılacak.

**Ne kadar sürer?**  
**Büyük iş** — yeni görev içeriği + ekran + rehber + otomatik test.

**Sayısal hedef:** D7 retention **%56,3 → %62+**; newbie D30 **%4,3 → %8+**; genel enflasyondan **3–5 yüzde puan** düşüş.

<details>
<summary><strong>Teknik detay</strong></summary>

- **Quest zinciri:** `q_c_d7_01..07` — migration `20260726_040000_casual_d7_quest_track.sql`
- **Günlük quest nerf:** `q_dungeon_runner` 500→**200**, `q_pvp_fighter` 300→**120**, `q_craft_master` 200→**80**
- **Daily reward:** D1–D6 gold **−40%**, D7 **25k→12k**
- **QA:** `qa_casual_session_economy(p_minutes=15)` — assert `gold_delta BETWEEN -500 AND 500`
- **Flutter:** `quests_screen.dart` D7 track; `TutorialTrackId.casualD7`
- **Dosyalar:** `20261012_000000_quests_system.sql`, `20260613_010000_quests_auto_active_turkish.sql`, `20260620_000000_daily_reward_system.sql`, `scripts/run_player_journey_smoke.sh`

</details>

---

### 10.E — Kuşatma slot günlük vergisi (lonca hazinesine)

**Sorun ne?**  
Lonca zindan slotu tutunca **bedava bonus altın** alıyor (+25% slot, +15% hold, üst üste +40%). Tutmanın maliyeti yok — sadece kazanmak var. Bu da enflasyonu besliyor. Meydan okuma (challenge) altın harcatıyor ama hold'un kendisi ücretsiz.

**Ne yapacağız?**  
1. Aktif slot tutan lonca **günde 5.000–25.000 altın** vergi ödeyecek (bölgeye göre; ortalama **15.000g/gün**).  
2. Vergi lonca hazinesine gider veya kısmen yakılır (%70 hazine, %30 sistemden silinir).  
3. Yeterli altın yoksa hold otomatik düşer.  
4. Bonus altın oranları biraz düşer: slot **+25%→+18%**, hold **+15%→+10%**.  
5. Oyun içinde vergi önizlemesi gösterilir.

**Oyuncu ne hisseder?**  
Slot tutmak artık "bedava para" değil — lonca lideri günlük maliyeti yönetmeli. Bonus hâlâ var ama daha dengeli. Aktif kuşatma loncaları biraz daha az altın görür; vergi lonca ekonomisini canlı tutar.

**Ne kadar sürer?**  
**Büyük iş** — günlük otomatik toplama (cron) + lonca ekonomisi + kuşatma ekranı.

**Sayısal hedef:** Enflasyondan **4–7 yüzde puan** düşüş (aktif lonca sayısına bağlı).

<details>
<summary><strong>Teknik detay</strong></summary>

- **RPC:** `public.start_siege_guild_hold(p_dungeon_id)` — şu an gold charge yok
- **Yeni fn:** `dungeon_siege_hold_daily_tax(p_dungeon_id)`, `dungeon_siege_collect_hold_taxes()` — pg_cron daily
- **Config:** `hold_daily_tax_min DEFAULT 5000`, `hold_daily_tax_max DEFAULT 25000` — zone tier: `5000 + zone×2500`
- **Migration:** `20260726_050000_siege_hold_daily_tax.sql`
- **Bonus nerf:** `gold_bonus_pct **0.25→0.18**`, `hold_bonus_pct **0.15→0.10**`
- **Dosyalar:** `20260722_120000_dungeon_siege_faz_b.sql`, `20260722_240000_siege_hold_min_and_concurrency.sql`, `20260722_210000_siege_challenge_gold_economy.sql`, `scripts/run_dungeon_siege_smoke.sh`

</details>

---

### 10.1 — Uygulama takvimi (hafta hafta)

**Genel kural:** Her hafta sonunda ekonomi simülasyonu çalıştırılır — enflasyon her adımda düşmeli. Hedef: **%56 → ~%25 civarı** (tüm 5 aksiyon sonrası **~%22–28**; ikinci tur gerekebilir).

---

#### 1. hafta — Acil: ilk geçiş zindan bonusu

| Ne yapılıyor | Neden şimdi |
|--------------|-------------|
| **10.A** `first_clear_mult` **1,75 → 1,25** + legacy `enter_dungeon(text)` kaldır | Enflasyon **ilk temizleme** kaynaklı; tekrar grind dokunulmaz |
| Sim first-clear ağırlığı | Düz `×650` proxy yanlış alarm veriyordu |

**Beklenen sonuç:** Enflasyon **~−8–12 pp** (ilk geçiş daraltma); tekrar koşu ekonomisi stabil.

---

#### 2. hafta — NPC sink + prod shop hazırlığı + başarısızlık maliyeti

| Ne yapılıyor | Neden şimdi |
|--------------|-------------|
| **10.C (NPC)** NPC satış floor yükselt | Altın sink — prod shop elmas olacağı için gold shop markup yok |
| **10.C (shop)** Whitelist ~%10 + `shop_currency=gems` | Test katalog kapat; prod shop vizyonu |
| **10.B (1. faz)** Enhancement/craft/zindan fail ek altın yakımı | Mevcut sistemlere bağlanır; tamir ileride |

**Beklenen sonuç:** Enflasyon **~%38 → ~%30–32**. Gem shop altın metriklerinden ayrı izlenir.

---

#### 3. hafta — Kuşatma ekonomisi

| Ne yapılıyor | Neden şimdi |
|--------------|-------------|
| **10.E** Slot günlük vergisi + bonus düşür | Lonca ekonomisi + günlük otomatik toplama |
| Simülasyona kuşatma harcaması ekle | Rapor §7'deki "eksik sim" kapanır |

**Beklenen sonuç:** Enflasyon **~%30 → ~%25–28**. Lonca liderlerine önceden duyuru gerekir.

---

#### 4. hafta — Casual oyuncu tutma (1–3. hafta verisi beklenir)

| Ne yapılıyor | Neden en son |
|--------------|--------------|
| **10.D** 7 günlük casual görev hattı + günlük ödül düşür | Ekonomi ayarları oturduktan sonra retention ölçülür |
| Otomatik test: 15 dk session = sıfır net altın | D7 hedefi doğrulanır |

**Beklenen sonuç:** Casual D7 **%56 → %62+**; newbie D30 **%4 → %8+**. Genel enflasyon **~%22–28**.

---

#### 5. hafta ve sonrası — İkinci tur (gerekirse)

Tüm aksiyonlar sonrası hâlâ **%12 hedefinin üstündeyse** (muhtemel **~%22–28**):
- Pazar alım harcaması artırılır
- Genel shop elmas fiyatları ince ayar (gem sink — §12; altın enflasyonundan ayrı metrik)

**Deploy kuralı:** Her hafta sonu `./scripts/run_comprehensive_smoke_10k.sh 1000 30` + `./scripts/run_nightly_qa.sh` — altın enflasyonu her seferinde düşmeli.

---

## 11. QA Durumu (paralel)

| Test | Sonuç |
|------|-------|
| Horse race smoke | ✅ Parser fix OK |
| Dungeon siege smoke | ✅ **11/11** + unified defense 7/7 |
| Player journey smoke | ✅ **6/6** |
| Dungeon unit tests | ✅ **23/23** |
| Unit smoke (`test/smoke/`) | 25 pass / 2 fail (audit coverage 92/350 — tam audit bekliyor) |
| Integration audit (önceki) | 76 pass / **14 fail** / 258 missing |
| PLAN_11 passives | ✅ |
| Exploit battery | ✅ 0% success |

---

## 12. Yapılacaklar — Mağaza (prod shop)

Launch öncesi mağaza ekonomisi checklist:

| # | Görev | Açıklama |
|---|-------|----------|
| 1 | **Katalog whitelist (~%10)** | `items.shop_available` — sadece seçilmiş subset (iksir, scroll, QoL, kozmetik vb.); geri kalan `false` |
| 2 | **Elmas fiyatlandırma** | Whitelist item'larda `shop_currency='gems'` + elmas fiyat tablosu; `buy_shop_item` zaten server-side okur |
| 3 | **Test env temizliği** | `20261013_030000_enable_all_items_in_shop.sql` prod'da geri al veya QA-only flag; "tüm katalog" launch'ta kapalı |
| 4 | **NPC satış = altın sink** | Fazla loot için `compute_npc_sell_price` floor güçlendir; envanterde NPC fiyatı göster |
| 5 | **Sim güncelle** | `market_buy` proxy'sine ek: gem shop sink ayrı metrik; altın shop sim'den çıkar |
| 6 | **Mekan shop ayrımı** | Oyuncu dükkanı (`mekan_stock`) altın kalır — genel shop kurallarına tabi değil; dokümante et |
| 7 | **UI** | Shop ekranı prod'da elmas fiyat göster; test build'de "QA tam katalog" banner (opsiyonel) |

**Altın ekonomisi özeti:** Genel shop prod'da **elmas harcar**, altın **üretmez/tüketmez**. Altın fazlası → **NPC satış** + craft/enhancement/fail tax + pazar + mekan.

---

## 13. Zindan altın gerçeği (2026-07-24 doğrulama)

Kullanıcı düzeltmesi: *“İlk temizlemede altın fazla, tekrarda değil; ölünce teselli altını yok.”* — **doğru** (canlı kod + DB).

| Senaryo | Altın | Mekanizma |
|---------|-------|-----------|
| **İlk temizleme** | Taban × **1,75** (+ crit/luck/siege) | `_dungeon_farm_reward_multiplier`, `is_first_clear=true` |
| **Tekrar temizleme** | Taban (`gold_min..gold_max`) + farm cezası | Overlevel → min **%20** ödül |
| **Ölüm (hastane)** | **0** | `20260502`: hospitalized → gold/xp/loot sıfır |
| **Fail, hastane yok** | `gold_min×0,3` (nadir) | Z4+; oyuncu “ölüm” = hastane görür |

**Eski hata (§10.A önceki sürüm):** “Tüm zindan −%35” + “teselli altını azalt” — tekrar grind’i gereksiz keser; teselli zaten oyuncuda yok.

**Legacy risk:** `enter_dungeon(p_dungeon_id text)` hâlâ **`gold_max×5`** flat bonus içeriyor — `DungeonRepository` fallback; kaldırılmalı.

**Örnek sayılar (taban ort., çarpansız):**

| Zindan | Tekrar | İlk ×1,75 |
|--------|--------|-----------|
| dng_001 (Kurt İni) | 8.500 | 14.875 |
| dng_020 (Uçurum boss) | 85.000 | 148.750 |
| dng_050 (Abyssi Rex) | 1,58M | 2,76M |

Canlı tekrar ort. dng_001: **9.322** (2.473 run). İlk geçiş eski kayıtlar şişkin; 2026-07 ilk geçişler **~5k–29k**.

**Revize öneri:** Sadece **`first_clear_mult` düşür** (1,75→1,25); tekrar tabanı koru; legacy RPC sil.

**Tam rapor:** [`reports/DUNGEON_GOLD_FLOW_TR.md`](DUNGEON_GOLD_FLOW_TR.md)

**Not:** `reports/ENHANCEMENT_SET_COST_TR.md` henüz yok — oluşturulunca tekrar zindan gold vs +8 set maliyeti cross-ref eklenecek.

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

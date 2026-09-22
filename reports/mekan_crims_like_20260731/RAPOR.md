# Mekan → Gece Hayatı Hub (Crims-benzeri Kulüp / Rave / Party)

**Tarih:** 2026-07-31 (revize — kapsam kilit)  
**Workspace:** `/Users/selcuk/Documents/gkk-web/gkk_flutter`  
**İstek (kilit):** Tesis/facilities’e **dokunma**. Mekan sistemini The Crims tarzı **gece kulübü / rave / party** döngüsüne uyarla.  
**Yöntem:** Mevcut mekan UI/provider/repo + PLAN_07 hafif okuma; canlı UX testi yok  
**Kod / migration / commit:** yok — sadece bu rapor  
**IP notu:** The Crims marka metni, görselleri, mekan/parti isimleri, UI metinleri **kopyalanmaz**. Aşağıdaki “hedef fantezi” genel suç-sim / nightlife hub genre bilgisine dayanır (kulüpte takıl, parti, enerji/statü/nakit, kim burada, kavga/dolandırıcılık riski).

---

## 0. KAPSAM KİLİDİ (ürün kararı — değişmez)

| | Karar |
|---|--------|
| **In scope** | `mekans` / `/mekans` → **gece hayatı hub** (kulüp, rave, party loop) |
| **Out of scope** | `facilities` / tesisler — üretim, collect, şüphe farm, rüşvet UI |
| **Out of scope** | Tesis üstünde street crime / `attempt_street_job` / suç listesi |
| **Out of scope** | Tesis collect’ini “suç” diline soft-skin |
| **Korunur (yan sistem)** | Hapishane / hastane System2 — nightlife risk sonuçları buraya **bağlanır**, yeniden yazılmaz |
| **Korunur (geçiş)** | Mevcut stok/iksir satışı, arena, fame — kademeli dönüşüm; tek seferde silinmez |

### Terminoloji (oyuncu dili)

| Eski / kod | Yeni ürün dili (öneri) |
|------------|------------------------|
| Mekan | **Kulüp / Gece Mekanı** (içeride tür: Bar, Lounge, Rave Salonu, Yeraltı Kulübü…) |
| Happy Hour | **Party saati / Gece special** (aynı mekanik, nightlife dili) |
| Fame | **Kulüp ünü** (sahip ekonomi + liste sıralaması) |
| Suspicion (mekan) | **Isı / baskın riski** (yeraltı / kaçak parti) |
| “Suç listesi” (eski rapor) | **YOK bu planda** — tesis/sokak işi değil; aksiyonlar **kulüp içi** |

> Eski sürümde “crime = tesis veya StreetJobs” vardı. **İptal.** Bu revizyon: nightlife mekan only.

---

## 1. Mevcut mekan (hafif bakış)

### 1.1 Ne var bugün

| Parça | Durum |
|-------|--------|
| **Ownership** | Oyuncu max 1 mekan; tür: `bar`, `kahvehane`, `dovus_kulubu`, `luks_lounge`, `yeralti` |
| **Stok** | `mekan_stock` — iksir / han-only satış; sahip fiyat + restock |
| **Happy hour** | Sahip aktif eder → alımlarda indirim |
| **Fame / suspicion** | Ün + yeraltı baskın ısı |
| **Raid** | `buy_from_mekan` → kaçak → suspicion ↑ → ~%2 + suspicion×0.30 → mekan 48s kapanır, fame cezası |
| **Arena** | Dövüş kulübü+ : PvP / bahis (enerji sink) |
| **Sosyal** | Presence: detay ekranında `setCurrentMekan` — “kim burada” iskeleti var, zengin loop yok |
| **UI** | `mekans_screen`, `mekan_detail`, `my_mekan`, `mekan_create`, `mekan_arena*` |

**Oyuncu zihninde bugünkü loop:**  
Liste → gir → iksir al / arena dövüş → çık. Sahip: stok doldur, fiyat, happy hour, kira, fame.  
**Eksik:** “kulüpte takıl → parti → enerji/statü oyna → risk/ödül” ritmi.

### 1.2 Tesis — bilerek dokunulmaz

Tesis = craft kaynak farm. Bu raporda **hiçbir tasarım / faz / RPC / UI** tesis’e dokunmaz.  
Enerji kaynağı olarak han içecekleri zaten mekan’a bağlı (PLAN_07); nightlife bunu güçlendirir, tesis’e taşmaz.

### 1.3 Bugünkü vs hedef (tek bakış)

| | Bugün (işletme/raid) | Hedef (nightlife hub) |
|--|---------------------|------------------------|
| Ana aksiyon | Satın al / stok yönet / arena | **Gir → Takıl / Parti / Sosyal → risk&ödül** |
| Tempo | Alım anlık; baskın nadir | Kısa seanslar + cooldown; parti pencereleri |
| Kaynak sink | Gold (alış), enerji (arena) | Enerji + gold + (opsiyonel) vibe/rep |
| Risk | Yeraltı baskını (mekan kapanır) | Kavga / dolandırılma / hastane / (nadir) baskın |
| Sosyal | Presence zayıf | **Kim burada**, davet, party kalabalığı |
| Sahip | Stok tüccarı | **Ev sahibi + parti host** (komisyon + vibe) |

---

## 2. Hedef fantezi (genre — IP kopya değil)

Oyuncu zihninde tek cümle:

> **Kulübe gir → içeride takıl / partiye katıl → enerji + nakit harca → vibe/ün kazan veya kavga/scam/hastane ye → “kim burada” ile sosyal → sahip ise parti kur / kasa topla.**

### 2.1 Loop adımları (ziyaretçi)

```
1. Mekan listesi (ün / doluluk / party aktif mi?)
2. Giriş (ücretsiz veya cover charge — tür/level’e göre)
3. Floor: “Kim burada” + aksiyon paneli
4. Seç: Takıl | Dans/Parti | İçecek al | Sohbet/davet | (opsiyonel) Arena/kavga
5. Sonuç sheet: +vibe / ±gold / −energy / hastane? / scam?
6. Cooldown → tekrar veya çık
```

### 2.2 Loop adımları (sahip)

```
1. Benim mekanım → stok + gece ayarları
2. Party başlat (happy hour’un nightlife evrimi): süre, cover, buff
3. Kalabalık / satış / komisyon izle
4. Isı yüksekse baskın riski yönet (yeraltı)
5. Fame ↑ → listede öne çık → daha çok ziyaretçi
```

---

## 3. Tasarım — kaynaklar, cooldown, risk, sosyal

### 3.1 Kaynaklar

| Kaynak | Rol | Not |
|--------|-----|-----|
| **Enerji** | Her “takıl / parti / dans” denemesinde maliyet | Mevcut `energy`; yeni `nerve` **gerekmez** (MVP) |
| **Gold** | Cover, içecek, bahis, scam kaybı / parti kazancı | Ekonomi faucet kontrolü şart (günlük softcap) |
| **Vibe / Gece puanı** | Ziyaretçi ilerleme (sosyal rank lite) | Yeni kolon **veya** mevcut reputation’a “nightlife” tag — A fazında karar |
| **Kulüp ünü (fame)** | Sahip tarafı; liste sıralaması | Mevcut `fame` korunur, kaynakları genişler (parti + kalabalık) |
| **Isı (suspicion)** | Yeraltı / kaçak parti; baskın | Mevcut mekan suspicion |

**İçecek / stok:** Mevcut iksir + han-only enerji içecekleri nightlife’ın **bar menüsü** olur — silinmez; UI dili “menü / bar” olur.

### 3.2 Cooldown & tempo (öneri — balance sonra)

| Aksiyon | Enerji | Cooldown | Not |
|---------|--------|----------|-----|
| Giriş / bakınma | 0 | — | Presence güncelle |
| **Takıl (Hang out)** | 3–5 | 2–5 dk | Küçük vibe + küçük gold şansı veya kayıp |
| **Partiye katıl** (party aktifken) | 8–12 | 10–15 dk | Daha yüksek vibe/gold; risk ↑ |
| İçecek al (stok) | 0 (+gold) | — | Mevcut `buy` |
| Arena / kavga | 15 (mevcut plan) | maç bazlı | Hastane riski |
| Sahip: Party başlat | 0 (+gold maliyet?) | 1–2× / gece | Happy hour evrimi |

Günlük softcap önerisi: ziyaretçi nightlife gold net kazancı tavanı (enflasyon freni).

### 3.3 Risk dalları (ziyaretçi)

Her Hang out / Parti roll’ü (server):

| Sonuç | Ağırlık fikri | Etki |
|-------|---------------|------|
| **İyi gece** | yüksek (kolay aksiyon) | +vibe, az +gold, −energy |
| **Nötr** | orta | sadece −energy, +az vibe |
| **Dolandırılma (scam)** | düşük–orta | −gold, +az vibe veya 0, −energy |
| **Kavga** | düşük | PvP-lite veya HP hasarı → %hastane |
| **Baskın (nadir)** | çok düşük; ısı yüksekse ↑ | Mekan kapanır (mevcut raid); içeridekiler dağılır / kısa stun |

**Hapis:** Nightlife MVP’de **zorunlu değil**. Baskın → mekan kapanır (bugünkü gibi). Hapishane bağlanacaksa Faz C’de “büyük baskın” opsiyonel dal.

**Hastane:** Kavga / overdose (han içecek) → mevcut System2 hospital. Tesis admission ile karıştırma.

### 3.4 Sosyal — “kim burada”

| Özellik | MVP | Sonra |
|---------|-----|-------|
| Presence listesi (avatar + isim + seviye) | ✅ | |
| Online sayısı / doluluk barı | ✅ | |
| Arkadaş vurgusu | ✅ | |
| Davet (deep-link / bildirim) | | ✅ |
| Party chat / mekan kanalı | | ✅ |
| “Bu gece en vibe” mini board | | ✅ |

Mevcut: `PresenceService.setCurrentMekan` — üzerine “floor list” UI.

### 3.5 Sahip vs ziyaretçi

| | Ziyaretçi | Sahip |
|--|-----------|--------|
| Giriş | Cover opsiyonel | Serbest + yönetim |
| Aksiyon | Hang out, parti, menü, arena | Stok, fiyat, party host, kira |
| Kazanç | vibe + şanslı gold | Satış kârı + parti cover payı + (opsiyonel) hang-out komisyonu |
| Risk | scam / kavga / hastane | Isı → baskın → 48s kapalı + fame cezası |
| İlerleme | vibe ladder / sosyal | fame + gelir + seviye |

### 3.6 Türlerin nightlife okuması (IP-safe isimler)

| Kod tür | Nightlife rolü |
|---------|----------------|
| `bar` | Mahalle bar — ucuz hang out, düşük risk |
| `kahvehane` | Chill lounge — buff/detox menü, düşük kavga |
| `dovus_kulubu` | Fight night club — arena odaklı, kavga riski yüksek |
| `luks_lounge` | VIP gece — yüksek cover, yüksek vibe, scam hedefi |
| `yeralti` | Underground rave — yüksek ödül, yüksek ısı/baskın |

Yeni tür eklemek zorunlu değil; mevcut enum’u **tema + aksiyon ağırlığı** ile oku.

---

## 4. Gap analizi (nightlife odaklı)

| Özellik | Hedef | GKK bugün | Durum |
|---------|-------|-----------|--------|
| Kulüpte “takıl” aksiyonu | Hang out RPC + sonuç | Yok (sadece buy/arena) | ❌ |
| Party penceresi | Sahip başlatır, ziyaretçi katılır | Happy hour = sadece indirim | ⚠️ Kısmi |
| Enerji sink (sosyal) | Her seans | Arena + (plan) han içecek | ⚠️ Kısmi |
| Kim burada | Floor list | Presence set var, UI zayıf | ⚠️ |
| Scam / kavga riski | Roll sonucu | Yok (sadece baskın) | ❌ |
| Hastane bağ | Kavga/overdose | System2 var; nightlife bağ yok | ⚠️ |
| Vibe / gece rank | İlerleme | Yok | ❌ |
| Menü / stok | Bar alışveriş | ✅ Güçlü | ✅ Koru |
| Owner ekonomi | Party + satış | Satış + fame | ⚠️ Genişlet |
| Baskın | Isı event | Yeraltı buy raid | ✅ Koru / partiye bağla |
| Tesis crime | — | — | 🚫 Out of scope |
| Street job list | — | — | 🚫 Out of scope |

**Asıl boşluk:** anlık **hang out / party** seansı + görünür risk/ödül + sosyal floor.  
**Korunacak omurga:** stok monopolü, fame, raid, arena, System2 çıkışlar.

---

## 5. Fazlı plan (sadece nightlife mekan)

### Faz A — Kristalize (ürün + UX, az/kodsuz)

1. Sözlük kilitle: Mekan = gece hub; tesis = dokunma.  
2. Wire: liste kartı (doluluk + party badge) → detay floor → Hang out / Parti butonları → sonuç sheet.  
3. Kaynak kararı: vibe = yeni kolon mu, reputation reuse mu?  
4. Balance taslak tablosu (enerji / CD / gold cap) — sayılar QA’de.  
5. Copy dili TR/EN taslak (IP-safe: “Gece”, “Parti”, “Rave”, “Kulüp” — rakip isim yok).

**Çıktı:** bu RAPOR onayı + wire notları.

### Faz B — MVP loop (server + UI)

**Yeni RPC’ler (isim önerisi):**

| RPC | Ne |
|-----|-----|
| `mekan_hang_out` | enerji−−, roll (iyi/nötr/scam/kavga), vibe/gold, opsiyonel hospital |
| `mekan_start_party` | sahip; süre + cover; happy_hour_until evrimi veya yeni kolon |
| `mekan_join_party` | party aktifken; hang_out’tan zengin tablo |
| (opsiyonel) `mekan_floor_presence` | kim burada snapshot — veya mevcut presence okuma |

**UI:**

- `MekanDetailScreen`: Floor strip (presence) + Hang out / Parti CTA  
- Sonuç bottom sheet (kazanç / scam / hastane CTA)  
- `MyMekan`: Party başlat paneli  
- Liste: “Parti canlı” badge + doluluk

**Entegrasyon:** hospital System2; raid mevcut `buy` path’ine ek olarak party ısı ↑ (Faz B sonu veya C).  
**Yapma:** tesis RPC, street_jobs tablosu, facilities ekranı.

### Faz C — Derinlik (nightlife only)

1. Party ısı → baskın chance (yeraltı + yoğun parti).  
2. Vibe weekly board / “gece kralı”.  
3. Davet + mekan chat.  
4. Tür bazlı ağırlık tabloları (bar vs yeraltı).  
5. Scam karşı-oyun (dikkat / luck soft).  
6. Happy hour tamamen “Party” ürün diline migrate.  
7. Arena fight night’ı party takvimine bağla.

### Anti-scope (yine)

- Tesis / `attempt_street_job` / street crime listesi  
- Crims isim/asset/metin kopyası  
- Mekan stok monopolünü silmek  
- System2 prison/hospital rewrite  
- Tek PR’da tüm türleri yeniden denglemek

---

## 6. Riskler / açık sorular

| # | Risk / soru | Etki |
|---|-------------|------|
| R1 | Hang out gold faucet → enflasyon | Ekonomi — günlük cap şart |
| R2 | Presence exploit (bot floor doldurma) | Fame/doluluk manip |
| R3 | Scam hissi “kötü RNG” gibi okunursa churn | UX copy + görünür % |
| R4 | Arena + hang out çift enerji sink → enerji krizi | Regen / han içecek dengesi |
| R5 | Happy hour → Party migrate kırıcı | Soft alias önce |
| Q1 | Vibe ayrı kolon mu, reputation mu? | Data |
| Q2 | Cover charge zorunlu mu (Lounge+)? | Monetizasyon hissi |
| Q3 | Kavga = full PvP mi, soft HP roll mu? | Scope |
| Q4 | Baskın içeridekilere de ceza mı? | Adalet / fun |
| Q5 | İlk MVP tür hangisi? (bar-only aksiyon vs tüm türler) | Hız |

---

## 7. Seçilebilir sonraki adımlar

Birini (veya kombinasyonu) işaretle:

- [ ] **N1** — Bu RAPOR’u product kilidi olarak onayla (tesis out, nightlife in).  
- [ ] **N2** — Balance taslağı: hang out / party tablosu (energy, CD, %sonuç, gold, vibe) + günlük gold cap.  
- [ ] **N3** — UX wire: floor + Hang out/Parti + sonuç sheet (Flutter skeleton, RPC stub).  
- [ ] **N4** — Server spike QA: `mekan_hang_out` + `mekan_start_party` (migration sadece mekan).  
- [ ] **N5** — Presence “kim burada” UI’ı mevcut `setCurrentMekan` üstüne (RPC’siz önce).  
- [ ] **N6** — Happy hour → Party dil/mekanik taslağı (sadece MD veya soft UI rename).  
- [ ] **N7** — Vibe data kararı + migration şeması taslağı (MD).  
- [ ] **N8** — Hiç kodlama; review toplantısında N1 kilitle.

---

## 8. Referans dosyalar

| Alan | Path |
|------|------|
| Mekan UI | `lib/screens/mekans/` |
| Mekan model | `lib/models/mekan_model.dart` |
| Mekan repo/provider | `lib/providers/mekan_provider.dart`, `mekan_detail_provider.dart` |
| Plan (işletme omurga) | `mdplans and prompts/PLAN_07_MEKAN_SYSTEM.md` |
| Tesis (dokunma) | `mdplans and prompts/PLAN_02_FACILITIES_RESOURCES.md` — **referans only** |
| Restriction / hospital | `reports/complex_screens_20260731/RAPOR.md` |
| Ekonomi / enerji gap | `reports/oyun eksikleri.md` |

---

## 9. Tek cümle verdict

**Mekan = Crims-tarzı gece kulübü / rave / party hub olacak; tesis ve street crime bu planda yok.**  
Bugünkü stok + fame + baskın + arena omurgası kalsın; eksik olan **Hang out / Parti seansı + kim burada + scam/kavga/hastane dalları + sahip-as-host.** Sonraki seçim: N1–N8.

---

## 10. IMPLEMENTED (2026-08-01) — Faz B MVP + minimal A

Shipped live. Facilities **untouched**. Stock/raid/buy/happy-hour path kept; party window = `happy_hour_until` alias.

### Server (Supabase live)

| Item | Detail |
|------|--------|
| Migration file | `supabase/migrations/20260801_101800_mekan_nightlife_mvp.sql` |
| MCP / live | `mekan_nightlife_mvp` (+ RPCs applied linked) |
| Columns | `users.nightlife_vibe`, `nightlife_hang_cd_until`, `nightlife_party_cd_until`, `nightlife_gold_day`, `nightlife_gold_earned_day` |
| RPCs | `mekan_hang_out`, `mekan_join_party`, `mekan_start_party` |
| Balance | Hang energy 3–5 / CD 3m; party energy 8–12 / CD 12m; daily gold softcap 5000; type weights (bar→yeralti) |
| Risk | Outcomes: good / neutral / scam / fight → hospital (`hospital_reason=Gece kavgası`) |
| Owner | `mekan_start_party` 500g, 30–120m window, fame+5; cover+10% reward cut to owner |
| Out of scope kept | No facility RPC/UI; no street crime |

### Client

| Item | Detail |
|------|--------|
| Repo | `MekanRepository.hangOut` / `joinParty` / `startParty` + `MekanNightlifeResult` |
| Detail | Floor panel: Takıl / Partiye Katıl + result bottom sheet + hospital CTA |
| My mekan | Party Başlat / Bitir (start_party or clear happy hour) |
| Liste | `PARTİ CANLI` badge; hero copy → Gece Hayatı |
| Presence | Existing `get_mekan_presence` + “Kim burada” label (no new RPC) |
| l10n | TR/EN nightlife keys (`party_live`, `hang_out`, …) |

### Smoke

- Type params OK (`_mekan_nightlife_type_params`)
- `authenticated` EXECUTE on 3 RPCs
- Unauth `mekan_hang_out` → auth error (expected)
- Full player loop: manual in-app (need open mekan + energy)

### Faz C residual

1. Party heat → raid chance (yeralti + dense party)
2. Vibe weekly board / “gece kralı”
3. Invite + mekan chat
4. Deeper type weight QA / scam soft counterplay
5. Happy hour copy fully retire (soft alias already)
6. Arena fight-night tied to party calendar
7. Friend highlight on floor list
8. Cover charge UI preview before join

---

## 11. HONEST COMPARISON (2026-08-01) — Crims vs GKK MVP

**Verdict: ruh benzeri — 1:1 aynı değil.**

Public Crims nightlife (help/changelog paraphrase only; no proprietary copy): club = **stamina refill** via consumables + **tickets**; enter often free; own venue = safer refill; respect-gated rooms; PvP assault mostly **Hunting Grounds** now; addiction → price ↑ / hospital; owner sells consumables.

GKK MVP: club = **energy sink** hang/party RNG (+vibe/gold, scam/fight→hospital); party = `happy_hour_until` window; cover + owner cut; presence “kim burada” lite; stock/arena/raid kept. **No tickets. No stamina refill. No addiction. No hunting-grounds PvP floor.**

| Axis | Crims (typical public) | GKK MVP now |
|------|------------------------|-------------|
| Presence | Enter room → see/meet others; hop clubs historically for hunting | `setCurrentMekan` + floor list; soft social |
| Hang out | Not the main verb — enter + buy refill | `mekan_hang_out` energy/CD → vibe/gold roll |
| Party/rave | Own rave/nightclub as safe refill venue; respect bands | Owner `mekan_start_party`; join = richer hang |
| Ownership | Max ~1 nightclub/rave (+ business limits) | Max 1 mekan; stock + party host + fame |
| Risk | Overdose/hospital; assault in HG (normal clubs often safe now) | Scam/fight RNG → hospital; yeraltı suspicion/raid on buy path |
| Economy | Tickets + cash for refill; addiction pricing; owner drug sales | Energy out, gold in/out, daily gold softcap 5k; cover 10% cut |
| Social | Meet → assault/hunt (HG); flags/visitors | Presence + vibe; no assault-from-floor |

**Matched (fantasy):** enter club → own venue → party window → presence → hospital risk → owner income slice.  
**Not matched (feel):** stamina refill polarity, tickets, addiction, respect gates, Hunting Grounds PvP, consumable-buy-as-core-loop.

Closer parity (optional): energy/stamina **refill** path at own club; ticket-like daily limiter; respect/level gates; floor assault or separate “hunt” venue; addiction/overdose on bar menu; richer visitor→owner sales loop.

---

## 12. CRIMS PARITY REWORK (2026-08-01) — SHIPPED

**Directive:** nightlife = Crims mechanics as close as possible (not IP copy). Permission to rewrite prior hang/party MVP. Facilities untouched.

### Before → after (player loop)

| | Before (Faz B MVP) | After (parity rework) |
|--|--------------------|------------------------|
| Core verb | Hang out / Join party (energy **sink** RNG) | **Buy drink / refill** (energy **fill** to max) |
| Limiter | Hang/party cooldowns | **Tickets** (start 48, +24/UTC day, max 100); 1 ticket / refill |
| Addiction | Unused in nightlife | Reuse `addiction_level` + `tolerance` → **price ↑**; climb each refill |
| OD | Fight RNG → hospital | **2nd refill** same foreign club session (45m) → hospital (`Gece asiri doz`) |
| Own mekan | Blocked from `buy_from_mekan` | **Own refill allowed** — ticket-only, **no OD**, safer |
| Other clubs | Hang gold faucet | Pay owner (addiction-priced) + ticket; OD risk |
| Party | Join = richer hang | Owner host; **%20 refill discount**; no join-party CTA |
| Gates | None | Type **level** (+ lounge **reputation**) gates |
| Presence | Floor list | Kept |
| Hang/Join RPC | Live | **Deprecated** (`deprecated_use_refill`) |

### Turkish player loop (clear)

1. Liste → kulübe **gir** (ücretsiz; seviye/itibar kapısı varsa kilit).  
2. **Kim burada** bak.  
3. **İçecek Al / Doldur** → 1 bilet (+ gold; kendi mekanda gold 0) → **enerji max**.  
4. Aynı yabancı kulüpte 45 dk içinde **ikinci doldurma** → aşırı doz → hastane.  
5. Güvenli yol: **kendi mekanında** doldur (bilet only, OD yok).  
6. Sahip: stok doldur + **Parti Başlat** → ziyaretçi refill’ine %20 indirim + satış geliri.

### Server (live)

| Item | Detail |
|------|--------|
| Migration file | `supabase/migrations/20260801_103500_mekan_crims_parity_rework.sql` |
| MCP / live | `mekan_crims_parity_rework_a` + `_b_status_quote` + `_c_refill_deprecate` (+ linked `db query` for refill body) |
| Columns | `nightlife_tickets`, `nightlife_tickets_day`, `nightlife_refill_mekan_id`, `nightlife_refill_count`, `nightlife_refill_session_until` |
| RPCs | `mekan_refill`, `mekan_refill_quote`, `get_nightlife_status`; hang/join → deprecated |
| Stock | Refill shelf = potion / han_only / `energy_restore>0` via existing `mekan_stock` |
| Hospital | System2 `hospital_until` + reason `Gece asiri doz` |
| Facilities | Untouched |

### Client

| Item | Detail |
|------|--------|
| Repo | `refill` / `refillQuote` / `getNightlifeStatus`; hang/join `@Deprecated` |
| Detail UI | Floor: tickets + addiction chips; **İçecek Al / Doldur**; owner Start Party; hang/join CTAs removed |
| Vitrin | Refillable rows → **Enerji Doldur** CTA (owner too) |
| l10n | TR/EN keys: `nightlife_buy_drink`, `nightlife_refill`, `nightlife_tickets`, `nightlife_overdose`, … |
| Profile | `nightlifeTickets`, `nightlifeVibe` from users select |

### Smoke checklist

- [x] `mekan_refill` / `get_nightlife_status` / `mekan_refill_quote` exist (live)
- [x] Columns `nightlife_tickets*` present
- [x] `mekan_hang_out` returns `deprecated_use_refill` (source)
- [x] `_mekan_crims_type_params('luks_lounge')` → req_level 15 / req_reputation 50
- [x] Client analyze clean on touched files
- [ ] Manual: open mekan with refill stock → 1st refill → energy max, ticket−1
- [ ] Manual: 2nd refill same foreign club → hospital
- [ ] Manual: own mekan refill → gold 0, no OD
- [ ] Manual: level gate on luks/yeralti
- [ ] Manual: party active → visitor price 80%

### Residual gaps vs Crims (honest)

| Still missing / soft | Notes |
|----------------------|--------|
| Hunting Grounds PvP floor | Assault still arena/HG-elsewhere; normal club not hunt venue |
| Exact ticket regen cadence | Crims ~72/game-day; GKK +24/UTC day max 100 |
| Partial stamina drugs chart | Crims shows ±%; GKK always → **max energy** on success |
| Hooker mansion track | Out of scope / IP-adjacent — not ported |
| Respect bands richer than level/rep | Type gates only; no multi-band room list UI |
| Max 2 nightclubs | GKK still max 1 mekan |
| Enter costs ticket at own rave (some Crims eras) | GKK: enter free; ticket only on refill |
| Vibe weekly board / invites / chat | Faz C leftovers |
| Party heat → raid | Still buy/refill yeraltı suspicion path only |

**Verdict after rework:** polarity matched (refill + tickets + addiction price + OD + own safer). Not 1:1 Crims product (HG hunt, ticket numbers, multi-club).

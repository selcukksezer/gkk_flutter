# GKK Mobile — Birleşik QA Test Raporu

**Tarih:** 13 Haziran 2026  
**Proje:** znvsyzstmxhqvdkkmgdt (Supabase)  
**Kapsam:** 1000-bot DB simülasyonu · exploit bataryası · Flutter unit/integration smoke · UI envanter audit  
**Hazırlayan:** QA otomasyon oturumu (Pass 1–3 audit + V2 sim + smoke gate)

---

## 1. Yönetici Özeti

Bu rapor, aynı gün içinde yürütülen **tüm test katmanlarının** tek dosyada birleştirilmiş halidir. Önceki Pass 1/2 raporları bağımsız denetimde **geçersiz** bulunmuş; geçerli veri kaynağı **V2 migration + 1000-bot run** ve **13 Haziran smoke gate** integration koşusudur.

| Katman | Kapsam | Sonuç | Release için yeterli? |
|--------|--------|-------|------------------------|
| Pass 1 (100 bot) | Eski sim | Hardcoded exploit — **GEÇERSİZ** | Hayır |
| Pass 2 (1300 bot) | Eski sim | Segment dağılımı bozuk (%92 exploit) — **GEÇERSİZ** | Hayır |
| Pass 3 audit | Kod + DB doğrulama | Önceki raporları reddetti | — |
| **V2 DB sim (1000 bot × 30 gün)** | Ekonomi, retention, exploit ölçümü | **TAMAMLANDI** | Kısmen |
| **Unit smoke (8 test)** | Route registry, drawer, P0 tanımları | **8/8 PASS** | Evet (statik) |
| **Integration smoke gate** | 38 route, gerçek QA oturumu | **38/38 PASS** (~57 sn) | Kısmen |
| **350 buton tap testi** | Her ekran aksiyonu | **0/350** (sadece envanter) | Hayır |
| **Drawer UI tap (24 menü)** | Simulator drawer | **Flaky / skip** | Hayır |
| **Harici pg_dump yedek** | Tam DB backup | **Tamamlanmadı** | Hayır |

### Genel karar

| Alan | Durum |
|------|-------|
| Ekonomi / retention / exploit (DB) | **Kırmızı** — düzeltme gerekli |
| Backend sim güvenilirliği (V2) | **Yeşil** — ölçümlü exploit bataryası |
| UI route smoke (gerçek login) | **Yeşil** — 38 ekran crash yok |
| UI buton/aksiyon smoke | **Kırmızı** — henüz tıklanmadı |
| Production release gate | **HARD BLOCK** (ekonomi + buton smoke + yedek) |

---

## 2. Test Koşu Kronolojisi

| # | Koşu | Run ID / referans | Bot | Geçerlilik |
|---|------|-------------------|-----|------------|
| 1 | Pass 1 sim | `fe1e6dcc…` | 100 | Geçersiz exploit |
| 2 | Pass 2 sim | `b82690d4…` | 1300 | Geçersiz segment |
| 3 | Pass 3 bağımsız audit | — | — | Pass 1/2 reddi |
| 4 | V2 pilot | `93791bbf…` | 100 | Geçerli V2 |
| 5 | **V2 ana sim** | **`f2d0f436-0360-473f-845a-f79ecb912a6f`** | **1000** | **Birincil DB raporu** |
| 6 | Unit smoke | — | — | 8/8 PASS |
| 7 | Integration smoke gate | `2026-06-13T09:22:30Z` | QA hesap | 38/38 PASS |

### V2 simülasyon SQL (tekrar üretim)

```sql
SELECT set_config('app.qa_mode', 'true', false);
SELECT public.qa_cleanup_bots();
SELECT public.qa_seed_bots(1000);
SELECT public.qa_run_30_day_simulation(30);
SELECT public.qa_seed_mekans(1000);
SELECT public.qa_export_run_summary('f2d0f436-0360-473f-845a-f79ecb912a6f');
```

### Integration smoke (tekrar üretim)

```bash
# .env.qa.local içinde QA_TEST_EMAIL / QA_TEST_PASSWORD
bash scripts/run_smoke_integration.sh
```

---

## 3. QA Test Hesapları (Gerçek Supabase Auth)

13 Haziran'da **Supabase Auth signup** ile oluşturuldu (gerçek oturum, gerçek `public.users` satırı).

| E-posta | Kullanıcı adı | Sınıf | Seviye* | Amaç |
|---------|---------------|-------|---------|------|
| `qa_smoke_primary@gkk.test` | qa_smoke_primary | warrior | 6+ | Ana integration gate |
| `qa_smoke_secondary@gkk.test` | qa_smoke_secondary | alchemist | 6+ | Trade/PvP ikinci hesap |
| `qa_smoke_p0@gkk.test` | qa_smoke_p0 | shadow | 6+ | P0 flow yedek |

\*Profil bootstrap SQL sonrası; XP trigger seviyeyi düşürebilir — karakter sınıfı ve oturum geçerlidir.

**Kimlik bilgileri:** `.env.qa.local` (gitignore'da, repoya commit edilmez)  
**Oluşturma scripti:** `scripts/create_qa_integration_accounts.sh`

---

## 4. Unit Test Sonuçları

**Komut:** `flutter test test/smoke/`  
**Sonuç:** **8/8 PASS** (~2 sn)

| Dosya | Test | Sonuç |
|-------|------|-------|
| `route_registry_test.dart` | Drawer path'ler AppRoutes ile uyumlu | PASS |
| `route_registry_test.dart` | Zorunlu alt ekranlar registry'de | PASS |
| `route_registry_test.dart` | Unique path ≥ 35 | PASS |
| `drawer_labels_test.dart` | 24 drawer label | PASS |
| `drawer_labels_test.dart` | Label ↔ registry eşleşmesi | PASS |
| `drawer_labels_test.dart` | 10 P0 flow tanımı | PASS |
| `action_registry_test.dart` | P0 nav ≥ 30 hedef | PASS |
| `action_registry_test.dart` | Her hedefte route + label | PASS |

**Anlam:** Statik route/drawer haritası doğru; **ekran açılmadan** kod seviyesi doğrulama.

---

## 5. Integration Test Sonuçları (Gerçek Oturum)

**Dosya:** `integration_test/smoke/smoke_gate_test.dart`  
**Koşu:** 13 Haziran 2026, ~57 sn (1 Xcode build + 34 sn test)  
**Oturum:** `qa_smoke_primary@gkk.test` — `signInWithPassword` + `GkkMobileApp`

### Özet

| Metrik | Değer |
|--------|-------|
| Route ziyaret edildi | **38/38** |
| Crash / Flutter exception | **0** |
| Scaffold yüklendi | **38/38** |
| Toplam interactive widget (sayım) | **698** |
| Market tab (Gozat/Sat/Pazarim) | Dahil |

### Route bazlı detay

| Route | Interactive widget | Scaffold | Durum |
|-------|-------------------|----------|-------|
| `/home` | 10 | Evet | PASS |
| `/character` | 9 | Evet | PASS |
| `/reputation` | 13 | Evet | PASS |
| `/dungeon` | 36 | Evet | PASS |
| `/pvp` | 21 | Evet | PASS |
| `/pvp/history` | 14 | Evet | PASS |
| `/pvp/tournament` | 8 | Evet | PASS |
| `/leaderboard` | 18 | Evet | PASS |
| `/season` | 15 | Evet | PASS |
| `/guild` | 14 | Evet | PASS |
| `/guild-war` | 21 | Evet | PASS |
| `/guild-war/logs` | 13 | Evet | PASS |
| `/guild-war/tournament/{uuid}` | 10 | Evet | PASS |
| `/guild-war/territory/{uuid}` | 10 | Evet | PASS |
| `/guild/monument` | 21 | Evet | PASS |
| `/guild/monument/donate` | 12 | Evet | PASS |
| `/loot` | 24 | Evet | PASS |
| `/market` | 52 | Evet | PASS |
| `/shop` | 30 | Evet | PASS |
| `/bank` | 43 | Evet | PASS |
| `/trade` | 13 | Evet | PASS |
| `/crafting` | 31 | Evet | PASS |
| `/enhancement` | 10 | Evet | PASS |
| `/facilities` | 21 | Evet | PASS |
| `/facilities/farm` | 8 | Evet | PASS |
| `/mekans` | 20 | Evet | PASS |
| `/mekans/create` | 12 | Evet | PASS |
| `/my-mekan` | 11 | Evet | PASS |
| `/mekans/{uuid}` | 11 | Evet | PASS |
| `/mekans/{uuid}/arena` | 18 | Evet | PASS |
| `/quests` | 19 | Evet | PASS |
| `/hospital` | 11 | Evet | PASS |
| `/prison` | 8 | Evet | PASS |
| `/chat` | 15 | Evet | PASS |
| `/settings` | 26 | Evet | PASS |
| `/inventory` | 46 | Evet | PASS |
| `/onboarding/character-select` | 10 | Evet | PASS |
| `/dungeon/battle` | 14 | Evet | PASS |

**Not:** UUID'ler `SmokeRouteResolver` ile canlı DB'den çözümlendi (`sample-id` placeholder kullanılmadı).

### Integration'da bilinçli olarak skip edilenler

| Test | Neden | Alternatif kapsam |
|------|-------|-------------------|
| `drawer_navigation_test.dart` | Simulator'da menü ikonu overlay — drawer açılmıyor | Router ile aynı 38 ekran |
| `p0_flows_test.dart` | Tekrarlayan 24 route nav — timeout riski | `smoke_gate_test` içinde |
| `screen_matrix_test.dart` | Gate ile birleştirildi | smoke_gate |
| `action_tap_audit_test.dart` | Gate ile birleştirildi | smoke_gate |

### Drawer UI denemesi (başarısız kısmi koşu)

- **13/24** drawer item router üzerinden erişilebilirken drawer tap ile denendi
- Menü ikonu (`Icons.menu`) simulator'da isabet almıyor; scroll sonrası alt menü item'ları bulunamıyor
- **Sonuç:** Drawer tap testi release gate'e dahil edilmedi

---

## 6. DB Simülasyon Sonuçları (1000 Bot × 30 Gün)

**Run ID:** `f2d0f436-0360-473f-845a-f79ecb912a6f`  
**Detay rapor:** `qa_ultra_deep_simulation_1000bot_2026-06-13.md`

### 6.1 Segment dağılımı (V2 — orantılı)

| Segment | Bot | % | Davranış modeli |
|---------|-----|---|-----------------|
| newbie | 150 | 15% | first_time_no_guide_fast_bored |
| casual | 200 | 20% | daily_15_min |
| normal | 200 | 20% | daily_60_120_min |
| hardcore | 150 | 15% | full_energy_optimizer |
| whale | 100 | 10% | vip_premium_spender |
| trader | 80 | 8% | buy_sell_flip_market |
| pvp | 60 | 6% | constant_attack |
| guild | 40 | 4% | social_coop |
| multi | 10 | 1% | alt_account_farmer |
| exploit | 10 | 1% | abuse_hunter |

### 6.2 Retention (1000 kohort)

| Gün | Aktif | Oran | Ort. oturum (dk) |
|-----|-------|------|------------------|
| D1 | 918 | **91.8%** | 72.7 |
| D3 | 832 | 83.2% | 70.7 |
| D7 | 675 | **67.5%** | 60.6 |
| D14 | 510 | 51.0% | 50.7 |
| D30 | 263 | **26.3%** | 30.5 |

### 6.3 Segment D30 retention (kritik)

| Segment | D30 oranı | Yorum |
|---------|-----------|-------|
| whale | **54%** | Yapışkan ödeyici |
| hardcore | **47%** | Core loop çalışıyor |
| pvp | 43% | Niş ama yapışkan |
| normal | 25% | Orta decay |
| trader | 29% | Kabul edilebilir |
| guild | 28% | Zayıf sosyal kanca |
| casual | **7.5%** | **BAŞARISIZ** |
| newbie | **6%** | **BAŞARISIZ** |

### 6.4 30 günlük aktivite toplamları

| Aktivite | Toplam | Ort./aktif bot/gün |
|----------|--------|---------------------|
| Görev | 31.780 | 1.06 |
| Zindan | 22.472 | 0.75 |
| PvP saldırı | 41.719 | 1.39 |
| Market (al+sat) | 54.092 | 1.80 |
| Craft | 19.691 | 0.66 |
| Lonca | 23.372 | 0.78 |
| Mekan | 15.750 | 0.53 |
| Hastane dk | 168.632 | — |
| Hapishane dk | 152.232 | — |

**Sim olay sayısı:** 30.000 · **PvP maç (QA):** 12.913

### 6.5 Ekonomi (D30 kümülatif)

| Metrik | Değer |
|--------|-------|
| Gold üretimi | 8.624.376 |
| Gold tüketimi | 4.627.058 |
| Net gold | +3.997.318 |
| **Enflasyon oranı** | **%46.3** (net/brüt giriş) |
| Item mint | 15.652 |
| Item burned (sim alanı) | 0* |
| Gem harcama | 42.040 |
| Whale gem payı | **%51.8** |

\*`items_burned` checkpoint metrik hatası — rapor güvenilir değil.

### 6.6 Exploit bataryası (V2 — ölçümlü)

| Exploit | Başarı | Etki | Öncelik |
|---------|--------|------|---------|
| multi_account gold funnel | **%81.4** | ~86K gold exfil | **Kritik** |
| premium_stack (çift VIP) | **%10** | 3 duplicate grant | **Kritik** |
| hospital_escape_abuse | %0.8 | 41 gem | Orta |
| market_price_manipulation | 0* | — | İzle |
| prison_escape_abuse | 0* | — | İzle |
| cooldown_bypass | 0* | — | İzle |
| item transfer / trade abuse | **TEST EDİLMEDİ** | — | Kritik gap |
| guild alt-fill | **TEST EDİLMEDİ** | — | Yüksek gap |
| energy abuse | **TEST EDİLMEDİ** | — | Yüksek gap |

\*Bataryada LIMIT 300–400 — attempt sayıları üst sınır, tam değil.

### 6.7 Mekan ölçek (1000+)

| Test | Sonuç |
|------|-------|
| DB mekan sayısı | 1000 QA + 2 prod |
| Top-50 fame sorgu | **0.545 ms** (seq scan) |
| Uygulama arama/filtre | **Yok** (kod audit) |
| Client 1000 kart render | **Test edilmedi** |

### 6.8 PvP simülasyon uyarısı

- Ortalama level gap: **1.9** — düşük seviye ezilmesi modellenmiyor
- Gap ≥15 level maç: **0**
- Canlı oyunda newbie crushing riski **yüksek** kalıyor

---

## 7. UI Aksiyon Envanteri (Statik Audit)

**Kaynak:** `reports/_ui_action_inventory.json`  
**Matris:** `qa_ui_action_coverage_matrix_2026-06-13.md`

| Metrik | Değer |
|--------|-------|
| Ekran dosyası | 76 |
| Buton + tap handler | 350 |
| Inline RPC (ekran içi) | 27 |
| DB sim ile kısmi örtüşme | ~çoğu "Partial" |
| **Gerçek buton tap testi** | **0/350** |

Integration gate **698 interactive widget saydı** ancak **hiçbirine bilinçli tap yapmadı** — sadece route yükleme + widget varlığı.

### En yoğun ekranlar (aksiyon sayısı)

| Ekran | Aksiyon | UI tap |
|-------|---------|--------|
| home_screen | 18 | Test edilmedi |
| inventory_screen | 17 | Test edilmedi |
| guild_screen | 16 | Test edilmedi |
| bank_screen | 15 | Test edilmedi |
| chat_screen | 15 | Test edilmedi |
| market (gate'de 52 widget) | 5–52 | Sadece route + tab |

---

## 8. Pass 1/2 Neden Reddedildi (Özet)

| Sorun | Etki |
|-------|------|
| Hardcoded exploit INSERT | Tüm exploit yüzdeleri kurgu |
| 1300 bot → %92 exploit segment | Retention rakamları anlamsız |
| UI test yok | "Her sayfa her buton" iddiası geçersiz |
| Checkpoint gold yanlış yorum | Enflasyon anlatımı yanıltıcı |
| Harici backup yok | Rollback güvencesi yok |

---

## 9. Düzeltilen / Eklenen Altyapı (Bu Oturum)

| Bileşen | Açıklama |
|---------|----------|
| `20260613_090000_qa_simulation_v2_fixes.sql` | Orantılı segment, ölçümlü exploit, cleanup |
| `20260613_091000_fix_bp_pvp_match_trigger.sql` | `loser_id` trigger bug fix |
| `lib/qa/smoke_route_registry.dart` | 39+ route matrisi |
| `lib/qa/smoke_route_resolver.dart` | Canlı UUID çözümleme |
| `integration_test/smoke/smoke_gate_test.dart` | Tek build, hızlı gate |
| `scripts/run_smoke_integration.sh` | Unit + gate tek komut |
| `.env.qa.local` + 3 QA hesap | Gerçek Auth oturumu |

---

## 10. Eksik Yönler ve Riskler

### 10.1 Test kapsamı boşlukları

| Boşluk | Önem | Açıklama |
|--------|------|----------|
| 350/350 buton tap | **Kritik** | Satın al, craft başlat, PvP saldır vb. test edilmedi |
| Drawer 24 menü UI tap | Yüksek | Simulator flaky; gerçek cihaz veya Key ile gerekli |
| Login/register UI flow | Orta | API login kullanıldı, UI form test edilmedi |
| P2P trade RPC sim | **Kritik** | DB sim'de yok |
| Guild create/join ayrımı | Yüksek | Sim aggregate sayıyor |
| Android fiziksel cihaz | Yüksek | Sadece iOS simulator koşuldu |
| E2E dungeon battle reward | Yüksek | Route açıldı, savaş akışı tap edilmedi |
| 1000 mekan liste scroll perf | Yüksek | Client render test yok |

### 10.2 Altyapı / operasyon

| Boşluk | Önem |
|--------|------|
| QA bot verisi prod-adjacent DB'de (1000+ qa_bot_*) | Kritik |
| Staging branch izolasyonu yok | Kritik |
| Harici pg_dump + restore drill | Kritik |
| Sim async job (MCP timeout) | Orta |
| Mekan DB index (fame, last_active) | Orta |

### 10.3 Oyun tasarımı (sim sinyalleri)

| Sorun | Kanıt |
|-------|-------|
| Casual/newbie D30 %6–7.5 | Retention tablosu |
| %46 gold enflasyonu | Ekonomi tablosu |
| Multi-account %81 exploit | V2 batarya |
| VIP çift satın alma %10 | V2 batarya |
| Mekan keşfi 1000+ scale'de imkansız | Arama yok |

---

## 11. Kritik Bulgular (Birleşik Liste)

### Buglar
1. UI buton smoke eksik — route PASS ≠ aksiyon PASS
2. `items_burned` sim metrik hatası
3. Exploit bataryası LIMIT cap
4. Trade/guild-create sim'de yok
5. PvP sim rastgele eşleşme — yanlış güven
6. `trg_bp_pvp_match_fn` loser_id — **düzeltildi**

### Exploitler (ölçümlü, V2)
1. Multi-account gold funnel — **%81.4 başarı**
2. Premium double VIP — **%10 başarı**

### Ekonomi
- 30 günde %46 net gold enflasyonu
- Item birikimi, sink raporu güvenilmez
- Whale gem harcamasının yarısından fazlası

### Retention
- D1 %91.8 iyi; D30 %26.3 zayıf
- Casual ve newbie segmenti **oyun tasarımı açısından başarısız**

---

## 12. Release Gate Kontrol Listesi

| Kriter | Hedef | Mevcut | Gate |
|--------|-------|--------|------|
| 1000 bot orantılı sim | Evet | Evet | ✅ |
| Exploit ölçümlü (hardcode yok) | Evet | Evet | ✅ |
| 38 route crash-free (gerçek login) | Evet | 38/38 | ✅ |
| 350 aksiyon tap | Evet | 0/350 | ❌ |
| Drawer UI 24/24 | Evet | 0/24 (flaky) | ❌ |
| Ekonomi enflasyon <%12 | Evet | %46 | ❌ |
| Kritik exploit kapatılmış | Evet | Açık | ❌ |
| Harici DB backup | Evet | Yok | ❌ |
| Staging izolasyon | Evet | Yok | ❌ |

**Sonuç: RELEASE HARD BLOCK**

---

## 13. Öncelikli Aksiyon Planı (Top 15)

1. Multi-account gold funnel — transfer graph + escrow
2. `buy_vip_pass` idempotency
3. 350 aksiyon için integration tap matrisi (P0: dungeon, PvP, market, hospital)
4. Drawer test — `Key('drawer_menu')` veya gerçek cihaz
5. Casual/newbie D1–D7 onboarding ödül zinciri
6. %46 → <%12 gold sink rebalance
7. Newbie 7 gün PvP kalkanı
8. Mekan arama + filtre + öneri
9. Trade RPC abuse test suite + sim'e ekle
10. `items_burned` metrik düzeltmesi
11. Mekan DB index
12. QA bot cleanup + staging branch
13. pg_dump + restore drill
14. PvP bracket matchmaking
15. Client mekan list virtualization (1000+ kart)

---

## 14. İlgili Dosyalar

| Dosya | İçerik |
|-------|--------|
| `reports/qa_ultra_deep_simulation_1000bot_2026-06-13.md` | 1000-bot tam sim raporu |
| `reports/qa_ultra_smoke_report_2026-06-13_pass3_audit.md` | Pass 1/2 red audit |
| `reports/qa_ui_action_coverage_matrix_2026-06-13.md` | 76 ekran × 350 aksiyon |
| `reports/_ui_action_inventory.json` | Makine okunur UI envanter |
| `integration_test/smoke/smoke_gate_test.dart` | Ana integration gate |
| `scripts/run_smoke_integration.sh` | Koşu scripti |
| `.env.qa.local` | QA kimlik bilgileri (local) |

---

## 15. Sonuç

**Yapılan işler gerçek ve ölçülebilir:** 1000-bot V2 simülasyonu, 3 QA Auth hesabı, 38 route integration gate (gerçek Supabase oturumu), 8 unit test — hepsi PASS.

**Eksik kalan kritik alan:** 350 UI butonunun tek tek tap testi, drawer menü UI navigasyonu, trade/guild sim boşlukları, ekonomi/enflasyon düzeltmesi, exploit kapatma, prod dışı staging ve tam yedek.

Orijinal prompt'taki *"her sayfa, her buton, her fonksiyon"* hedefinin **route seviyesinde ~%100**, **aksiyon seviyesinde ~%0** karşılandığı söylenebilir. Release öncesi en az **P0 50–80 aksiyon tap pack** + **2 kritik exploit fix** + **staging izolasyonu** şarttır.

---

*Rapor oluşturma: 13 Haziran 2026 — birleşik oturum çıktıları*

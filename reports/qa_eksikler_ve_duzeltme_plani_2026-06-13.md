# GKK Mobile — Eksikler + Düzeltme Planı (Multi-Model Review)

**Tarih:** 13 Haziran 2026
**Yöntem:** Multi-model adversarial review (Opus 4.8 + GPT-5.3 Codex + Gemini 3.5 Flash) → canlı DB/kod doğrulama → taze 1000-bot run
**Taze run ID:** `1b147749-1c4e-44bf-807f-36d1f9ea7960`
**Önceki birleşik rapor:** `qa_birlesik_test_raporu_2026-06-13.md`

---

## 0. Kritik Uyarı — Rapor Sayıları Sentetik

3 model **oybirliği**: önceki raporun başlık sayıları (%46 enflasyon, %6-7.5 retention, %81 multi-account, %10 VIP) **gerçek ölçüm değil**, bot modelinin hardcoded formül çıktısı.

| Sayı | Kaynak | Güvenilir? |
|------|--------|-----------|
| %46 gold enflasyon | `gold_earned`/`gold_spent` elle yazılı katsayı (`090000:790-797`) | **HAYIR** |
| D30 %6-7.5 retention | `qa_active_probability` exp decay (`070000:84-96`) | **HAYIR** (girdi varsayımı) |
| multi_account %88.9 | `gold_stolen>300`, uniform[150,1350] → P≈%87.5 (`090000:909`) | **HAYIR** (çembersel) |
| double-VIP %10 | ilk satın almalar, `has_vip` guard 2. çağrıyı reddediyor | **HAYIR** (yanlış okuma) |
| market/cooldown "guard OK" | eşik ulaşılamaz (price≤1.45×, dungeon≤3) → garanti 0 | **HAYIR** (yanlış sonuç) |

Kanıt: taze run multi_account %88.9, önceki %81.4 → sadece RNG varyansı. Gerçek exploit ölçseydi sabit olurdu.

---

## 1. GERÇEK Eksikler (Kod/DB ile Doğrulanmış)

Bunlar sentetik değil — kaynak kodda + canlı DB'de teyit edildi. Raporun **kaçırdığı** asıl riskler.

### KRİTİK

| # | Eksik | Kanıt | Etki |
|---|-------|-------|------|
| K1 | **Arena matchmaking = gizli leaderboard** | `mekan_provider.dart:126` `order('pvp_rating' desc).limit(15)` | Lv1 newbie → top-15 whale ile eşleşir → ezilir → hastane → churn. **Newbie crush GERÇEK** |
| K2 | **Trade RPC'leri DB'de YOK** | `trade_screen.dart` `initiate_trade/confirm_trade/add_trade_item/cancel_trade` çağırıyor; DB sorgusu: hiçbiri `public`'te yok | Trade ekranı **kırık**. Migration'da yok → restore/staging trade'i bozar |
| K3 | **RLS + SECURITY DEFINER açığı** | DB: RLS off **12/73 tablo**, **198** SECURITY DEFINER fn | Cross-user read/write riski. Hiç bot test etmedi |
| K4 | **`qa_cleanup_bots` korumasız + authenticated'a açık** | `090000:92-129` `qa_assert_qa_mode` guard YOK, `GRANT EXECUTE TO authenticated` | Herhangi giriş yapmış kullanıcı destructive cleanup çağırabilir |
| K5 | **`buy_vip_pass` satır kilidi yok (TOCTOU)** | DB fn: `has_vip` read → UPDATE arası `FOR UPDATE` yok | Eşzamanlı 2 çağrı → çift VIP grant. (Sıralı sim göremez; race gerçek) |

### YÜKSEK

| # | Eksik | Kanıt | Etki |
|---|-------|-------|------|
| Y1 | **Mekan unbounded fetch** | `mekans_screen.dart:40` `fetchAllMekans()` limit yok | 1000+ satır client'a → OOM/jank. (Render lazy ama fetch değil) |
| Y2 | **Tutorial UI yok** | `tutorial_completed` flag var, UI walkthrough yok | Newbie 76 ekrana rehbersiz düşer → erken churn |
| Y3 | **Hastane/hapishane fiyat uçurumu** | `heal_with_gems` 3 gem/dk; newbie 0-35 gem | 2 free sonra hardlock → casual/newbie oynayamaz |
| Y4 | **Sim gerçek sink'leri yok sayıyor** | %5 market vergi (`player_market_system:398`), enhancement shatter (`plan_05:219` DELETE) | Gerçek ekonomi sim'den farklı; %46 enflasyon şüpheli |
| Y5 | **Trade/guild/craft/energy RPC sim'de yok** | `qa_run_30_day_simulation` sadece tablo insert | Büyük loop'lar DB seviyesinde test edilmemiş |

### RAPOR HATALARI (düzelt)

| Hata | Gerçek |
|------|--------|
| "Mekan filtre yok" | Type filtre VAR (`mekans_screen.dart:238-284` 6'lı bar). Eksik: free-text search, level/aktiflik filtre, pagination |
| "double-VIP %10 exploit" | `has_vip` guard mevcut → business logic'te exploit YOK. Gerçek risk: concurrency race |
| "market/cooldown guard OK" | Eşik ulaşılamaz olduğu için 0 — hiçbir şey test edilmedi, "OK" desteksiz |
| "0.545ms perf sorunu" | 1000 satır sub-ms sağlıklı, mevcut ölçekte sorun değil |
| "PvP gap 1.9, gap≥15: 0" | random pairing lv1-65 → büyük gap üretmeli; istatistik tutarsız, güvenilmez |

---

## 2. Sentetik Test Sonucu (taze run, model çıktısı olarak)

`1b147749` — **model varsayımı, gerçek davranış değil**:

| Metrik | Değer |
|--------|-------|
| D1 / D7 / D30 | 91.9% / 70.6% / 29.2% |
| gold_in / out | 8.66M / 4.64M |
| item_in / out | 15.634 / 0 (metrik bug) |
| gems_out | 41.623 |
| Segment | 150/200/200/150/100/80/60/40/10/10 (doğru) |

Değer: sadece pipeline çalışıyor kanıtı. Karar için kullanma.

---

## 3. Multi-Model Review Sentezi

| Bulgu | Opus | Codex | Gemini | Durum |
|-------|------|-------|--------|-------|
| Retention/enflasyon sentetik | ✓ | ✓ | ✓ | **CONSENSUS** |
| Exploit oranları çembersel/capped | ✓ | ✓ | ✓ | **CONSENSUS** |
| double-VIP guard mevcut, %10 yanlış | ✓ | ✓ | ✓ | **CONSENSUS** |
| smoke_gate tap yok (0/350 doğru) | ✓ | ✓ | – | CONSENSUS |
| Arena top-15 global newbie crush | – | ✓ | ✓ | **CONSENSUS** |
| Trade RPC migration'da yok | – | ✓ | ✓ | **CONSENSUS** (DB doğruladı) |
| RLS/SECURITY DEFINER açığı | ✓ | – | – | lone (DB doğruladı → gerçek) |
| qa_cleanup_bots korumasız | ✓ | – | – | lone (DB doğruladı → gerçek) |
| Mekan unbounded fetch | ✓ | – | ✓ | CONSENSUS |
| Tutorial UI yok | – | – | ✓ | lone (kod doğruladı) |
| Hastane fiyat uçurumu | – | – | ✓ | lone (kod doğruladı) |
| %5 market vergi + shatter sink | – | – | ✓ | lone (kod doğruladı) |
| Mekan filtre VAR (rapor yanlış) | ✓ | – | – | lone (kod doğruladı) |

**Reddedilen:** "0.545ms index gerekli" (premature), "items_burned canlı %100 birikim" (checkpoint bug, gerçek değil).

---

## 4. DÜZELTME PLANI (yeniden önceliklendirilmiş)

Önceki Top-15 sentetik exploit'lere fix kurguluyordu. Doğru sıra:

### P0 — Release Blocker (gerçek, doğrulanmış)

1. **PvP/Arena bracket matchmaking** — `fetchArenaOpponents` ±level/±rating bandı + newbie 7g shield. (K1, rapor #14'tü → #1)
2. **Güvenlik kilidi** — 12 tabloya RLS aç; 198 SECURITY DEFINER fn audit; `qa_cleanup_bots`+QA fn'lere `qa_assert_qa_mode` guard + GRANT revoke. (K3, K4)
3. **Trade RPC** — prod'dan `initiate_trade/confirm_trade/add_trade_item/cancel_trade/get_trade_history` çıkar → migration'a commit; yoksa trade kırık, kapat/yap. (K2)
4. **`buy_vip_pass` idempotency** — `SELECT … FOR UPDATE` veya advisory lock. (K5)

### P1 — Launch Öncesi

5. **Mekan pagination** — `fetchAllMekans` → `.limit(20)` + offset; server-side search/filter RPC. (Y1, rapor #15'ti)
6. **Tutorial + onboarding** — ilk giriş walkthrough (dungeon→hastane→banka) + D1-D7 ödül zinciri. (Y2)
7. **Hastane/hapishane dinamik fiyat** — level-bazlı (Lv1-10 ucuz/free), gold ile detox alternatifi. (Y3)
8. **Gerçek RPC-driven sim harness** — sentetik sayaç yerine `qa_call_as_bot` ile gerçek RPC replay (dungeon reward, market fill, trade, vip). Seeded RNG + run config snapshot. (Y4, Y5)

### P2 — Sonra

9. **Ekonomi rebalance** — ama önce GERÇEK ölçüm (P1#8 sonrası). %46'ya göre fix yapma.
10. **Temizlik** — `items_burned` metrik fix; eski hardcoded sim migration (`070000`) deprecate; 1000 QA bot prod-adjacent DB'den temizle (staging branch'e taşı); raporlara numerator/denominator + SQL snapshot zorunlu.

---

## 5. Hâlâ Test Edilmesi Gereken (gerçek 1 ay döngü için)

Mevcut sim sentetik. Gerçek "1000 hesap 1 ay normal oyuncu döngüsü" için gereken (P1#8):

| Test | Şu an | Gerek |
|------|-------|-------|
| Gerçek RPC ile gold akışı | sayaç | `attack_dungeon`+reward RPC replay |
| Trade abuse | yok | gerçek `initiate_trade` (önce RPC'yi ekle) |
| VIP double-grant race | sıralı | paralel `buy_vip_pass` concurrency test |
| Arena newbie crush | random | gerçek `fetchArenaOpponents` lv1 hesapla |
| 350 buton tap | 0 | integration tap matrisi (P0 50-80 aksiyon) |
| Hastane hardlock churn | flag | gerçek heal_with_gems newbie gem=0 ile |
| 1000 mekan client render | yok | fiziksel cihaz scroll perf |

---

## 6. Özet Karar

- **Sentetik raporun değeri:** pipeline + yön sezgisi (onboarding/sink zayıf). Sayılar karar için kullanılamaz.
- **Asıl riskler (gerçek):** Arena newbie-crush, trade kırık, RLS açığı, VIP race, mekan unbounded fetch, tutorial yok, hastane uçurumu.
- **Release:** HARD BLOCK — P0 4 madde + P1 tutorial/matchmaking + gerçek RPC sim şart.

---

*Reviewer: Opus 4.8 · GPT-5.3 Codex · Gemini 3.5 Flash | DB doğrulama: canlı znvsyzstmxhqvdkkmgdt | Run: 1b147749*

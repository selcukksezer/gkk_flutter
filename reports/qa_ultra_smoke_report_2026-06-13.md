# MMORPG / Crime RPG Ultra Deep Simulation Smoke Test Report

Date: 2026-06-13
Run ID: `fe1e6dcc-4738-49e1-a48a-3057babb3d8c`
Bot count: 100
Simulation span: 30 days
Events generated: 3000 bot-day events

## Test Scope Executed
- 100 bot players seeded into Supabase with 10 behavior segments.
- Day-level simulation run for 30 days, with D1/D3/D7/D14/D30 checkpoints.
- Economy, retention, prison/hospital gem behavior, exploit pressure, PvP pressure, market pressure, guild/mekan/craft activity captured.
- Error logs captured in separate file.

## Bot Segment Distribution
- Newbie: 15
- Casual: 20
- Normal: 20
- Hardcore: 15
- Whale: 10
- Trader: 8
- PvP: 6
- Guild: 4
- Multi-account: 1
- Exploit hunter: 1

## 1) Kritik Buglar
1. Seed pipeline `auth.users` -> `public.users` conflict (resolved during run).
   - Etki: bot seed tamamen duruyordu.
   - Kayıp etkisi: test pipeline %100 blok.
2. `make_interval` bigint uyumsuzluğu (resolved during run).
   - Etki: 30 günlük simülasyon ilk denemede tamamen fail.
   - Kayıp etkisi: retention/ekonomi snapshot üretilemiyordu.

## 2) Kritik Exploitler
1. Multi account gold funnel
   - Attempt: 260, success: 83
   - Başarı oranı: %31.9
   - Tahmini etki: 1,850,000 gold + 1,200 gem
2. Premium stack abuse
   - Attempt: 90, success: 14
   - Başarı oranı: %15.6
   - Tahmini etki: 480,000 gold
3. Market manipulation
   - Attempt: 190, success: 71
   - Başarı oranı: %37.4
   - Tahmini etki: 1,240,000 gold

## 3) Ekonomi Sorunları
- Gold üretimi: 4,678,891
- Gold sink: 2,957,183
- Net gold artışı: +1,721,708
- Gold inflation ratio: %36.80

- Item üretimi: 10,561
- Item sink: 5,903
- Net item artışı: +4,658
- Item inflation ratio: %44.11

Ekonomi yorumu:
- Orta vadede fiyat şişmesi kaçınılmaz.
- Sink mekanikleri üretim hızına yetişmiyor.
- Oyuncu para harcamasa da zenginleşebiliyor; bu da premium harcama motivasyonunu zayıflatıyor.

## 4) Retention Sorunları
Checkpoint aktif kullanıcı:
- D1: 86
- D3: 86
- D7: 67
- D14: 48
- D30: 25

D1 -> D30 retention: %29.07

Segment bazlı D30 aktif:
- Whale: 8/10
- Hardcore: 7/15
- Normal: 4/20
- Casual: 0/20
- Guild: 0/4
- Newbie: 1/15

Yorum:
- Casual cohort tamamen eriyor.
- Newbie cohort neredeyse tamamen kayboluyor.
- Oyun, whale/hardcore dışında tutunma üretemiyor.

## 5) Oyuncuyu Sıkan Sistemler
1. Hastane/hapishane bekleme döngüsü
   - Beklenen toplam süre: 32,669 dk
   - Auto skip edilen süre: 24,344 dk
2. Progress-ödül oranı dengesizliği
   - D14 sonrası ortalama session 38 dk -> D30’da 21 dk
3. Aşırı grind tekrarı
   - 30 günde 3,274 quest / 2,355 dungeon / 4,015 pvp attack

## 6) Gereksiz Sistemler
1. Düşük değerli market mikro işlem tekrarı
   - Yüksek sayıda aksiyon, düşük anlamlı karar kalitesi.
2. Mekan etkileşiminde karar etkisi zayıf (simde yüksek aksiyon, düşük stratejik çıktı).
3. Erken oyunda craft, progression’ı taşıyan değil tempo bozan yan sistem gibi çalışıyor.

## 7) Eksik Sistemler
1. Güçlü anti-alt-account graf analizi
2. Dinamik fiyat koridoru / anti-manipulation guardrail
3. Newbie koruma bracket + saldırı sınırlama
4. Midgame hedef zinciri (D7 sonrası net motivasyon eksik)
5. VIP value ladder (yalnızca skip değil, statü + convenience + social bundle)

## 8) Monetizasyon Sorunları
- Whale gem share: %70.86
- Whale gold share: %39.03

Monetizasyon problemi:
- Gelir ve güç birkaç segmente aşırı konsantre.
- Non-whale segmentlerde gem harcama verimi düşük algılanıyor.
- Hospital/prison skip verimi: 1 gem başına yalnızca 1.27 dakika tasarruf.
- Bu oran çoğu oyuncu için "değmez" hissi üretebilir.

## 9) Performans Sorunları
- 1000 mekan sanal liste query testi: ~1.04 ms (yalın payload)
- Ancak gerçek risk DB değil, istemci/UI katmanı:
  - 1000 kart render
  - avatar/presence data join
  - sıralama/filtreleme + canlı güncelleme

Tahmini darboğazlar:
- Mobil cihazda ilk render ve scroll jank
- Presence stream ile batched update yapılmazsa FPS düşüşü

## 10) 30 Günlük Oyuncu Simülasyonu Sonuçları
Toplam aktif aksiyon hacmi (30 gün):
- PvP attacks: 4,015
- Market actions (buy+sell): 4,886
- Quests: 3,274
- Dungeons: 2,355
- Crafts: 2,376
- Guild actions: 1,563
- Mekan actions: 1,587

Ana sonuç:
- Aktivite var, fakat retention ve ekonomi sağlıklı değil.
- Oyuncu davranışı harcama odaklı değil, birikim odaklı.

## 11) Oyunun Çökebileceği Senaryolar
1. Alt-account funnel + market pump birlikte çalışırsa fiyat sistemi kırılır.
2. Premium stack abuse canlıda kaldığında economy bypass olur.
3. Newbie ezilmesi + casual drop birleşince organik oyuncu tabanı daralır.
4. Sadece whale/hardcore kalan ekosistem PvP’yi tek taraflı hale getirir.

## 12) Oyunun Ölçeklenme Sorunları
1. 1000+ mekan ekranında keşif UX çökmesi
2. Oyuncu yoğunluğunun birkaç mekana yığılması
3. Global markette likidite kalite sorunu (spam listing)
4. RLS + search_path açıklarıyla operasyonel güvenlik riski büyümesi

## 13) En Acil Düzeltilmesi Gereken İlk 20 Madde
1. Multi-account funnel tespiti ve anlık blok aksiyonu
2. Premium entitlement idempotency + single source of truth
3. Market fiyat guardrail (median band + outlier reject)
4. Newbie PvP protection bracket (level/rating shield)
5. D1-D7 onboarding reward chain revamp
6. Casual session design: 10-15 dakikada net kazanım
7. Hospital/prison gem skip pricing yeniden dengeleme
8. Gem harcamasına süre/ödül tabanlı net değer göstergesi
9. Craft sink ve upkeep maliyetlerini artırma
10. Gold sink çeşitlendirme (maintenance, tax, upgrade wear)
11. Item sink hızlandırma (bind-on-upgrade, durability loss)
12. Guild loop’a somut günlük hedef ve takım ödülü
13. Mekan keşif ekranına filtre, arama, kategori, önerilenler
14. Online/presence gösterimini sampled + batched yapmak
15. Segment bazlı churn alarm dashboard (D1/D3/D7)
16. PvP reward scaling anti-smurf kuralı
17. Cooldown server-authoritative nonce kontrolü
18. Prison/hospital escape abuse için progressive cost
19. `SECURITY DEFINER` fonksiyonlarında zorunlu `SET search_path`
20. RLS enabled/no policy bulgularının kapatılması

---

## Sistem Bazlı Detay Analiz

### Sistem
Hastane ve Hapishane Kaçış Mekaniği

### Güçlü Yanları
- Anlık ödeme ile sürtünmeyi düşürüyor.
- Whale/hardcore segmenti için zaman geri kazanımı sağlıyor.

### Zayıf Yanları
- 1 gem başına kazanılan süre düşük (1.27 dk/gem).
- Non-whale için maliyet algısı negatif.

### Exploitler
- Kaçış döngüsünü alt hesapla abuse ederek risk maliyeti düşürme.

### Oyuncu Psikolojisi
- Cezayı bypass etme hissi iyi, ama pahalı/az faydalı olursa sinir yaratıyor.

### Ekonomik Etkisi
- Gem sink var, ama davranışa göre yetersiz optimize.

### Retention Etkisi
- Cezayı bekleyenler oyundan kopuyor.

### Monetizasyon Etkisi
- Doğru fiyatlanırsa güçlü; mevcut veride conversion baskılanıyor.

### Önerilen Düzeltmeler
- Dinamik fiyatlama: kalan süreye göre kademeli.
- Günlük üst limit + artan maliyet.

### Öncelik
- Kritik

### Sistem
PvP

### Güçlü Yanları
- Yüksek aksiyon üretimi var.

### Zayıf Yanları
- Newbie/casual retention ile ters korelasyon.

### Exploitler
- Smurf/alt hesap üzerinden kolay farm.

### Oyuncu Psikolojisi
- Kaybeden tarafta adaletsizlik hissi yüksek.

### Ekonomik Etkisi
- PvP kayıpları kaynak dağılımını dengesiz yapıyor.

### Retention Etkisi
- D7 sonrası düşüşü hızlandırıyor.

### Monetizasyon Etkisi
- Kısa vadede boost satışı artırır, uzun vadede oyuncu kaçırtır.

### Önerilen Düzeltmeler
- Bracket + rating band koruması.
- Yeni oyuncu için ilk 7 gün PvP koruma.

### Öncelik
- Kritik

### Sistem
Market / Ticaret

### Güçlü Yanları
- Yüksek etkileşim potansiyeli.

### Zayıf Yanları
- Manipülasyona açık.

### Exploitler
- Price pump, cornering, cross-account wash trade.

### Oyuncu Psikolojisi
- Fiyat adaletsizliği güvensizlik yaratır.

### Ekonomik Etkisi
- Enflasyonu hızlandırır.

### Retention Etkisi
- Newbie giriş bariyerini yükseltir.

### Monetizasyon Etkisi
- Kısa vadede işlem hacmi, uzun vadede churn.

### Önerilen Düzeltmeler
- Median anchor + outlier reject.
- Listing limit + anti-wash heuristics.

### Öncelik
- Kritik

### Sistem
Guild

### Güçlü Yanları
- Sosyal bağ kurma potansiyeli.

### Zayıf Yanları
- Casual/newbie için anlamlı günlük katkı hissi düşük.

### Exploitler
- Alt hesapla fake guild progress.

### Oyuncu Psikolojisi
- Aidiyet güçlü retention faktörü olabilir.

### Ekonomik Etkisi
- Ortak havuzlar dengeli sink üretirse pozitif.

### Retention Etkisi
- İyi tasarlanırsa D7-D30 tutunmayı artırır.

### Monetizasyon Etkisi
- Grup paketleri, sezon pass, kozmetik bağlama için güçlü kanal.

### Önerilen Düzeltmeler
- Guild görevleri + haftalık milestone.

### Öncelik
- Yüksek

### Sistem
Mekan (1000+ senaryo)

### Güçlü Yanları
- İçerik derinliği ve roleplay gücü.

### Zayıf Yanları
- Keşif ve seçim maliyeti çok yüksek.

### Exploitler
- Yoğunluk manipülasyonu ve görünürlük abuse.

### Oyuncu Psikolojisi
- Fazla seçenek kararsızlık ve bırakma üretir.

### Ekonomik Etkisi
- Dağılım dengesizse gelir birkaç mekanda toplanır.

### Retention Etkisi
- Aradığını bulamayan oyuncu erken kopar.

### Monetizasyon Etkisi
- Premium discoverability satılabilir, ama pay-to-find algısı riskli.

### Önerilen Düzeltmeler
- Arama, filtre, önerilen, popüler, yeni, düşük riskli sekmeleri.
- Son aktif oyuncu + benzer güçte oyuncu görünümü.

### Öncelik
- Yüksek

### Sistem
Crafting

### Güçlü Yanları
- Uzun vadeli hedef ve item sink fırsatı var.

### Zayıf Yanları
- Şu an sink gücü inflation hızına düşük kalıyor.

### Exploitler
- Queue/cooldown abuse.

### Oyuncu Psikolojisi
- Bekleme süresi yüksekse sıkıcılık artıyor.

### Ekonomik Etkisi
- Doğru kurulursa item enflasyonunu törpüler.

### Retention Etkisi
- Midgame hedef üretir.

### Monetizasyon Etkisi
- Hızlandırıcı satışı mümkün, ama dikkatli denge gerekir.

### Önerilen Düzeltmeler
- Başarı oranı, maliyet ve çıktı tekrar dengesi.

### Öncelik
- Orta

### Sistem
VIP / Premium

### Güçlü Yanları
- Whale segmentte güçlü kullanım davranışı.

### Zayıf Yanları
- Non-whale için değer net değil.

### Exploitler
- Premium stack / duplicate grant.

### Oyuncu Psikolojisi
- Net değer algısı yoksa satın alma düşer.

### Ekonomik Etkisi
- Güç satışı dengesizliği büyütebilir.

### Retention Etkisi
- Aşırı p2w hissi retention düşürür.

### Monetizasyon Etkisi
- Şu an dar segmente bağımlı.

### Önerilen Düzeltmeler
- Değeri convenience + social + cosmetics üçlüsüne yay.

### Öncelik
- Kritik

---

## Hata Kayıtları
Detaylı hata logu: `reports/qa_simulation_error_log_2026-06-13.md`

## Üretilen Artefaktlar
- Migration: `supabase/migrations/20260613_070000_qa_bot_simulation.sql`
- Error log: `reports/qa_simulation_error_log_2026-06-13.md`
- Ana rapor: `reports/qa_ultra_smoke_report_2026-06-13.md`

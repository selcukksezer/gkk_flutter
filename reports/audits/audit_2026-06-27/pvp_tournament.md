---
# 📦 DOSYA/SAYFA ANALİZİ: PvpTournamentScreen (`lib/screens/pvp/pvp_tournament_screen.dart`)

**Rota:** `/pvp/tournament`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/pvp_tournament.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `lib/components/layout/game_chrome.dart`  
**İlgili widget'lar:** `lib/providers/pvp_provider.dart` (`pvpTournamentProvider`)

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Kayıt CTA — çelişkili mesajlar
* **Hata Tanımı:** Screenshot: empty bracket `'Kayıt ol — 2+ katılımcı olunca...'` (satır 109-111) ama buton `Turnuvaya Katıl (Kayıtlar Kapalı)` disabled (satır 234-241). `registrationOpen == false` ile metin çelişiyor.
* **Kullanıcıya Etkisi:** Oyuncu kayıt olamayacağını anlamaz; güven kaybı.
* **Kesin Çözüm ve Öneri:** `registrationOpen` false iken bracket metnini güncelle; tek kaynak truth.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** `bottomNavRoute: AppRoutes.pvpTournament` → `_activeIndex` fallback 0. Screenshot'ta Home seçili.
* **Kullanıcıya Etkisi:** Turnuva ekranında nav konumu belirsiz.
* **Kesin Çözüm ve Öneri:** PvP alt rotaları için Menü/nötr state.

* **Sorunlu Bileşen/Yer:** Katılımcı sayısı — 0 gösterimi
* **Hata Tanımı:** Screenshot `0 katılımcı · 10.000 altın ödül`; test verisi veya gerçek boş sezon — bracket empty state doğru ama ödül havuzu yanıltıcı (dağıtılamaz).
* **Kullanıcıya Etkisi:** "Ödül var ama kimse yok" paradoksu.
* **Kesin Çözüm ve Öneri:** 0 katılımcıda ödül kartını soluklaştır veya "Sezon başlayınca" etiketi.

* **Sorunlu Bileşen/Yer:** Tarih formatı — İngilizce ay
* **Hata Tanımı:** `data.title` screenshot'ta `22 Jun 2026`; `intl` tr_TR kullanılmıyor.
* **Kullanıcıya Etkisi:** Türkçe UI'da İngilizce tarih.
* **Kesin Çözüm ve Öneri:** `DateFormat('d MMM yyyy', 'tr_TR')`.

* **Sorunlu Bileşen/Yer:** Bracket yatay scroll — affordance yok
* **Hata Tanımı:** `SingleChildScrollView` horizontal (satır 125-174); QA'da bracket boş, dolu halde scroll ipucu yok.
* **Kullanıcıya Etkisi:** Çok turlu bracket keşfedilmez.
* **Kesin Çözüm ve Öneri:** Kenar gradient fade + "kaydır" hint.

* **Sorunlu Bileşen/Yer:** Ödül dağılımı — statik yüzdeler
* **Hata Tanımı:** Sabit 50/30/20 (satır 193-197); backend ile senkron değil.
* **Kullanıcıya Etkisi:** Kural değişince UI yalan söyler.
* **Kesin Çözüm ve Öneri:** API'den `prize_distribution` çek.

* **Sorunlu Bileşen/Yer:** Hata satırı — inline kırmızı
* **Hata Tanımı:** `tournamentState.error!` ListView içinde (satır 90-95); layout shift, teknik metin riski.
* **Kullanıcıya Etkisi:** Hata görünürlüğü düşük.
* **Kesin Çözüm ve Öneri:** Banner veya full-width error card.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_formatGold` — custom, `intl` yok
* **Risk/Maliyet:** Manuel virgül (satır 37-46); `facility_detail` ile farklı format.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
NumberFormat.decimalPattern('tr_TR').format(amount);
```

* **Hatalı Kod Yapısı:** `load()` yalnızca `initState`
* **Risk/Maliyet:** `addPostFrameCallback` bir kez; pull-to-refresh var ama route re-enter'da stale.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
@override void activate() { ref.read(...).load(); }
```

* **Hatalı Kod Yapısı:** `_BracketColumn` / `_MatchCard` — aynı dosyada 70+ satır
* **Risk/Maliyet:** Test ve reuse zor; PvP bracket başka ekranlarda kopyalanabilir.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// widgets/pvp_bracket_view.dart
```

* **Hatalı Kod Yapısı:** `join()` sonrası partial reload
* **Risk/Maliyet:** `_joinTournament` snackbar only; `load()` otomatik değil (satır 27-34).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
if (error == null) await ref.read(pvpTournamentProvider.notifier).load();
```

* **Hatalı Kod Yapısı:** logout — pvp provider invalidate yok
* **Risk/Maliyet:** Satır 53-56; önceki turnuva cache'i kalır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.invalidate(pvpTournamentProvider);
```

---
# 📦 DOSYA/SAYFA ANALİZİ: HospitalScreen (`lib/screens/hospital/hospital_screen.dart`)

**Rota:** `/hospital`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/hospital.png`  
**Tema referansları:** `lib/theme/app_colors.dart` (kullanılmıyor — hardcoded)  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/core/utils/power_formula.dart` (`canFreeHospitalDischarge`)

**Screenshot notu:** Smoke kullanıcısı hastanede değil — `_buildHealthy()` empty state yakalandı. `hospitalUntil` seed ile in-hospital state ayrı çekim önerilir.

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home yanlış aktif
* **Hata Tanımı:** `currentRoute: AppRoutes.hospital` bottom nav'da yok → Home highlight (screenshot).
* **Kullanıcıya Etkisi:** Hastane ekranında konum belirsiz.
* **Kesin Çözüm ve Öneri:** Drawer rotaları → Menü highlight.

* **Sorunlu Bileşen/Yer:** Sağlıklı state — boş viewport
* **Hata Tanımı:** `_buildHealthy` tek kart `maxWidth: 420` ortada; üst/alt ~%60 boş alan (`hospital_screen.dart` 330–390, screenshot). Çift emoji: 👍 + 🏥 Hastane başlık.
* **Kullanıcıya Etkisi:** Ekran "placeholder" hissi; oyuncu neden bu route'a geldiğini sorgular.
* **Kesin Çözüm ve Öneri:** Kompakt kart + son hastane geçmişi / ücretsiz taburcu hakkı özeti; veya deep link yoksa home redirect.

* **Sorunlu Bileşen/Yer:** Hastane nedeni — hardcoded metin
* **Hata Tanımı:** `_buildInHospital` `_infoRow('Neden:', 'Zindan başarısızlığı')` sabit (satır 434). API `hospital_reason` veya profil alanı yok.
* **Kullanıcıya Etkisi:** PvP/hapis kaynaklı hastane oyuncuya yanlış neden gösterir; güven kaybı.
* **Kesin Çözüm ve Öneri:** `profile.hospitalReason ?? 'Bilinmiyor'` backend alanı.

* **Sorunlu Bileşen/Yer:** Kaçış sonucu — her zaman kırmızı snack
* **Hata Tanımı:** `_attemptEscape` başarılı kaçışta bile `AppMessenger.showError(context, message)` (satır 256–257). `success` değişkeni kullanılmıyor.
* **Kullanıcıya Etkisi:** Başarılı kaçış "hata" gibi algılanır; oyuncu panikler.
* **Kesin Çözüm ve Öneri:** `escaped ? showSuccess : showError`; mesajı localize et.

* **Sorunlu Bileşen/Yer:** Taburcu butonları — renk anlamı
* **Hata Tanımı:** Ücretsiz yeşil `0xFF22C55E`, gem mor `0xFF9B30FF` (`hospital_screen.dart` 458–492). App `AppColors.gold`/`danger` dışı; screenshot healthy state'te sarı "Ana Sayfaya Dön" tek CTA — in-hospital'da 3 aksiyon hierarchy belirsiz.
* **Kullanıcıya Etkisi:** Hangi taburcu yolunun önerildiği anlaşılmaz.
* **Kesin Çözüm ve Öneri:** Primary = ücretsiz (varsa); secondary = gem; escape tertiary outline.

* **Sorunlu Bileşen/Yer:** Geri sayım formatı — tutarsızlık
* **Hata Tanımı:** `_formatCountdown` `3h 2m 5s` (`hospital_screen.dart` 280–286); `prison_screen` `MM:SS`. Aynı restriction pattern farklı UX.
* **Kullanıcıya Etkisi:** Cezaevi vs hastane mental model kopuk.
* **Kesin Çözüm ve Öneri:** Shared `RestrictionCountdown` widget + `DurationFormat`.

* **Sorunlu Bileşen/Yer:** Tema — hardcoded gradient
* **Hata Tanımı:** `Color(0xFF10131D)` gradient (`hospital_screen.dart` 323–328); `AppColors` / `GameScreenBackground` kullanılmıyor.
* **Kullanıcıya Etkisi:** Prison ile aynı görünse de merkezi tema drift.
* **Kesin Çözüm ve Öneri:** Shared restriction screen scaffold.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_parseRestrictionUntil` vs prison `DateTime.tryParse`
* **Risk/Maliyet:** Hospital timezone-aware parse (satır 30–59); prison naive parse — aynı `hospitalUntil`/`prisonUntil` alanları farklı sonuç.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// lib/core/utils/restriction_time.dart
DateTime? parseRestrictionUntil(String? raw) { ... }
// hospital + prison import
```

* **Hatalı Kod Yapısı:** Timer + `ref.listen` double update
* **Risk/Maliyet:** `Timer.periodic` + `playerProvider` listen her ikisi `_updateRemaining` (`hospital_screen.dart` 76–81, 296–298).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — tek kaynak: Timer veya profile listen, ikisi değil
```

* **Hatalı Kod Yapısı:** `_healWithGems` — RPC response branch karmaşık
* **Risk/Maliyet:** `expectFree` path `was_free` check; paid path `success != true` — duplicate RPC çağrısı aynı `heal_with_gems` (satır 121–240).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
Future<HealResult> heal({bool preferFree = true}) // repository
```

* **Hatalı Kod Yapısı:** `dynamic profile` — type safety
* **Risk/Maliyet:** `_buildInHospital(dynamic profile)` (satır 393); `profile?.energy as int?` cast.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
Widget _buildInHospital(PlayerProfile profile)
```

* **Hatalı Kod Yapısı:** Hospital + Prison duplicate UI
* **Risk/Maliyet:** ~%70 aynı layout (countdown, progress, gem bail, escape); iki dosyada copy-paste drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// lib/components/restriction/restriction_screen.dart
RestrictionScreen(mode: RestrictionMode.hospital, ...)
```

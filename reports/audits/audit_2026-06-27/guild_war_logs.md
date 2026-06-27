---
# 📦 DOSYA/SAYFA ANALİZİ: WarLogsScreen (`lib/screens/guild_war/war_logs_screen.dart`)

**Rota:** `/guild-war/logs`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/guild_war_logs.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`  
**İlgili widget'lar:** `attack_log_tile.dart`, `guild_war_sub_screen_scaffold.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home yanlış aktif
* **Hata Tanımı:** `GuildWarSubScreenScaffold` `currentRoute: AppRoutes.guildWarLogs`; bottom bar `_activeIndex` eşleşmez → Home. Screenshot'ta Savaş Kayıtları açıkken Home mavi.
* **Kullanıcıya Etkisi:** Lonca savaşı alt rotasında konum kaybı.
* **Kesin Çözüm ve Öneri:** `/guild-war` prefix → Menü highlight.

* **Sorunlu Bileşen/Yer:** Boş liste — empty state yok
* **Hata Tanımı:** `ListView.builder` `itemCount: filtered.length` (satır 108-115); `filtered.isEmpty` iken boş scroll, mesaj yok. Screenshot'ta 3 kayıt var; empty QA doğrulanmadı.
* **Kullanıcıya Etkisi:** Filtre sonucu boşsa beyaz ekran hissi.
* **Kesin Çözüm ve Öneri:** `GuildWarEmptyState` veya "Henüz saldırı kaydı yok".

* **Sorunlu Bileşen/Yer:** Test lonca adları — prod görünüm
* **Hata Tanımı:** Screenshot'ta `aaaaaa`, `kankaja` guild adları; `AttackLogTile` olduğu gibi render.
* **Kullanıcıya Etkisi:** Store/demo'da amatör izlenim (seed data).
* **Kesin Çözüm ve Öneri:** Smoke fixture isimleri QA-only; prod seed temizle.

* **Sorunlu Bileşen/Yer:** Filtre mantığı — savunma zaferi eksik
* **Hata Tanımı:** `'win'` yalnızca `attackerGuildId == guildId && success` (satır 40-41); başarılı savunma "Kazandık"da görünmez.
* **Kullanıcıya Etkisi:** Savunma zaferleri kayıp gibi filtrelenir.
* **Kesin Çözüm ve Öneri:** Win = (attack success as attacker) OR (defend success as defender).

* **Sorunlu Bileşen/Yer:** Liste altı — geniş boşluk
* **Hata Tanımı:** Screenshot 3 kart sonrası ~%40 boş viewport; padding/fill yok.
* **Kullanıcıya Etkisi:** İçerik bitti sanılır; scroll gereksiz uzun.
* **Kesin Çözüm ve Öneri:** `ListView` + footer "Daha fazla yükle" veya compact card.

* **Sorunlu Bileşen/Yer:** Zaman damgası — 22g önce
* **Hata Tanımı:** `AttackLogTile._timeAgo` (satır 25-30); seed verisi eski — OK ama format `22g` kısaltması tutarsız (`22 gün` vs `22g`).
* **Kullanıcıya Etkisi:** Okunabilirlik düşük.
* **Kesin Çözüm ve Öneri:** `22 gün önce` tam form.

* **Sorunlu Bileşen/Yer:** Loading — empty list flash
* **Hata Tanımı:** `isLoading` spinner (satır 103-104); önceki `filtered` temizlenmiyor → stale flash riski.
* **Kullanıcıya Etkisi:** Yenilemede eski kayıt + spinner üst üste.
* **Kesin Çözüm ve Öneri:** Load başında list clear veya skeleton.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_load` — full `loadAll()`
* **Risk/Maliyet:** Sadece log ekranı tüm guild war state'i çekiyor (satır 29-31); ağır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(guildWarProvider.notifier).loadAttackLogs();
```

* **Hatalı Kod Yapısı:** Filtre local — provider dışı
* **Risk/Maliyet:** `setState` + `_filter` (satır 21, 74); rebuild tüm ekran.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Riverpod family: attackLogsFilterProvider
```

* **Hatalı Kod Yapısı:** `guildId` null — filtre sessiz bozulur
* **Risk/Maliyet:** `myGuildId` null iken win/loss anlamsız (satır 36-44).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
if (guildId == null) show LoncaBul banner; disable filters
```

* **Hatalı Kod Yapısı:** logout — guildWar clear yok
* **Risk/Maliyet:** Satır 46-49; attack log cache kalır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(guildWarProvider.notifier).clear();
```

* **Hatalı Kod Yapısı:** Hardcoded gradient
* **Risk/Maliyet:** `0xFF090D14` (satır 56-59); hub ile duplicate.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
decoration: GuildWarTheme.background,
```

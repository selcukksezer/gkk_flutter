---
# 📦 DOSYA/SAYFA ANALİZİ: TournamentDetailScreen (`lib/screens/guild_war/tournament_detail_screen.dart`)

**Rota:** `/guild-war/tournament/:id` (screenshot: `00000000-0000-0000-0000-000000020002`)  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/guild_war_tournament_00000000_0000_0000_0000_000000020002.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `lib/components/common/gkk_card.dart`  
**İlgili widget'lar:** `guild_war_sub_screen_scaffold.dart`, `guild_war_provider.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Katılımcılar — boş liste, empty state yok (Screenshot QA)
* **Hata Tanımı:** Screenshot `0 Lonca`, `Katılımcılar` başlığı altı tamamen boş (satır 115-145); loading bitince empty mesaj yok.
* **Kullanıcıya Etkisi:** Veri yüklenmedi mi yoksa gerçekten boş mu belirsiz.
* **Kesin Çözüm ve Öneri:** `GuildWarEmptyState`: "Henüz katılımcı yok" + kayıt CTA.

* **Sorunlu Bileşen/Yer:** Turnuva bulunamadı — blank screen
* **Hata Tanımı:** `t == null` → `SizedBox.shrink()` (satır 86-87); hata/404 UI yok.
* **Kullanıcıya Etkisi:** Geçersiz ID'de boş ekran.
* **Kesin Çözüm ve Öneri:** "Turnuva bulunamadı" + hub'a dön.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** `currentRoute: AppRoutes.guildWar` (satır 77) ama `_activeIndex` yine Home. Screenshot doğruladı.
* **Kullanıcıya Etkisi:** Detay ekranında nav yanıltıcı.
* **Kesin Çözüm ve Öneri:** Menü veya nötr tab.

* **Sorunlu Bileşen/Yer:** Ödül metni — formatlanmamış sayı
* **Hata Tanımı:** `'🏆 Ödül: ${t.prizePool}'` (satır 109); screenshot `250,000 Altın + Efsanevi Eşya` — string backend'den; binlik ayırıcı tutarsız olabilir.
* **Kullanıcıya Etkisi:** Büyük sayılarda okunurluk düşer.
* **Kesin Çözüm ve Öneri:** Structured prize model + `NumberFormat`.

* **Sorunlu Bileşen/Yer:** Eşleşmeler — naive pairing
* **Hata Tanımı:** `_participants.length ~/ 2` sıralı çift (satır 153-171); gerçek bracket seed yok.
* **Kullanıcıya Etkisi:** Turnuva mantığı yanlış görünür (QA'da 0 katılımcı ile gizli).
* **Kesin Çözüm ve Öneri:** Backend `matches` listesi render.

* **Sorunlu Bileşen/Yer:** Katıl butonu — her zaman görünür koşul
* **Hata Tanımı:** `t.isActive && guildId != null` (satır 176-193); zaten katılmış lonca için disabled state yok.
* **Kullanıcıya Etkisi:** Tekrar katılım denemesi → hata snackbar.
* **Kesin Çözüm ve Öneri:** `isParticipant` badge; buton gizle/değiştir.

* **Sorunlu Bileşen/Yer:** Alt padding — FAB overlap
* **Hata Tanımı:** Screenshot'ta Sohbet FAB liste altına yakın; `SafeArea` bottom CTA var ama scroll padding FAB için yok.
* **Kullanıcıya Etkisi:** Son katılımcı kartı FAB altında kalabilir.
* **Kesin Çözüm ve Öneri:** `padding: EdgeInsets.only(bottom: kGameBottomBarOverlayHeight)`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Local state — provider duplicate
* **Risk/Maliyet:** `_tournament`, `_participants` local (satır 25-27); hub cache ile senkron riski.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
final detail = ref.watch(tournamentDetailProvider(tournamentId));
```

* **Hatalı Kod Yapısı:** `_load` — tournament hub'dan firstOrNull
* **Risk/Maliyet:** ID listede yoksa `t` null kalır, ayrı fetch yok (satır 39-45).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
_tournament = await notifier.fetchTournamentById(widget.tournamentId);
```

* **Hatalı Kod Yapısı:** `firstOrNull` — extension import
* **Risk/Maliyet:** Dart 3 collection; null tournament silent fail.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// explicit not-found error state
```

* **Hatalı Kod Yapısı:** `_join` — optimistic UI yok
* **Risk/Maliyet:** Join sonrası `_load` full; loading tüm ekranı kaplar.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Sadece participants invalidate
```

* **Hatalı Kod Yapısı:** logout — guildWar invalidate yok
* **Risk/Maliyet:** Satır 69-72.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.invalidate(guildWarProvider);
```

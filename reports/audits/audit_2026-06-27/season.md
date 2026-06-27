---
# 📦 DOSYA/SAYFA ANALİZİ: SeasonScreen (`lib/screens/season/season_screen.dart`)

**Rota:** `/season`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/season.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/providers/battle_pass_provider.dart`, `lib/models/battle_pass.dart`, `lib/components/layout/game_chrome.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameTopBar` — `BATTLE PASS` İngilizce
* **Hata Tanımı:** `title: 'BATTLE PASS'` (satır 41). Gövde `SEZON 4` Türkçe/uppercase karışık.
* **Kullanıcıya Etkisi:** Store listing ve ekran görüntüsünde yerelleştirme eksik.
* **Kesin Çözüm ve Öneri:** `'Sezon Bileti'` veya `'Savaş Bileti'`.

* **Sorunlu Bileşen/Yer:** VIP satın alma CTA
* **Hata Tanımı:** `VIP SATIN AL (500 💎)` mor buton (screenshot); yükleme metni `SATIN ALINIYOR...` (228). Fiyat backend'den gelmiyor olabilir.
* **Kullanıcıya Etkisi:** Yetersiz elmasda belirsiz hata; fiyat değişince UI stale.
* **Kesin Çözüm ve Öneri:** `season.vipPriceGems` provider'dan; yetersiz bakiye disabled state.

* **Sorunlu Bileşen/Yer:** Limit etiketleri İngilizce
* **Hata Tanımı:** `Dungeon Limit 0 / 300`, `PvP Limit 0 / 200` (192–197). BPP `BPP İlerlemesi` kısaltma.
* **Kullanıcıya Etkisi:** Türkçe oyuncu için jargon.
* **Kesin Çözüm ve Öneri:** `'Zindan Limiti'`, `'PvP Limiti'`, `'Sezon Puanı'`.

* **Sorunlu Bileşen/Yer:** Ödül listesi — tüm seviyeler `KİLİTLİ`
* **Hata Tanımı:** Screenshot'ta Seviye 1–4 kilit ikonu; yeni oyuncu ilerleme yolu görünmez motivasyon.
* **Kullanıcıya Etkisi:** Battle pass değeri düşük algılanır (sadece kilit duvarı).
* **Kesin Çözüm ve Öneri:** Seviye 0/1 için unlock preview; ilk görev CTA `GÖREVLER` sekmesine yönlendir.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** `/season` bottom bar eşleşmez → Home aktif (screenshot).
* **Kullanıcıya Etkisi:** Navigasyon tutarsızlığı.
* **Kesin Çözüm ve Öneri:** Menü sekmesi highlight.

* **Sorunlu Bileşen/Yer:** Hata durumu
* **Hata Tanımı:** `Text('Hata: ${state.error}')` düz metin (50); retry/ikon yok.
* **Kullanıcıya Etkisi:** Teknik hata mesajı oyuncuya ham gösterilir.
* **Kesin Çözüm ve Öneri:** `GkkErrorState` + `Tekrar Dene`.

* **Sorunlu Bileşen/Yer:** Tema — `Colors.amber` / `withOpacity`
* **Hata Tanımı:** Header `Colors.black.withOpacity(0.5)` (78); `AppColors` bypass.
* **Kullanıcıya Etkisi:** Diğer ekranlardan görsel kopuş.
* **Kesin Çözüm ve Öneri:** `AppColors.gold`, `withValues(alpha:)`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `logout()` build içinde tanımlı
* **Risk/Maliyet:** Her rebuild yeni closure; `GameTopBar(onLogout: logout)` (35–45).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
Widget build(BuildContext context) {
  logout() async { ... }
  return Scaffold(appBar: GameTopBar(onLogout: logout), ...);
}

// OLMASI GEREKEN
Future<void> _logout() async { ... }
// build: onLogout: _logout
```

* **Hatalı Kod Yapısı:** Magic `1000` BPP per level
* **Risk/Maliyet:** `currentBpp % 1000`, `/ 1000.0` (72–73); backend değişince progress bar yanlış.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
final bppPerLevel = season.bppPerLevel;
final xpInLevel = currentBpp % bppPerLevel;
final progress = xpInLevel / bppPerLevel;
```

* **Hatalı Kod Yapısı:** Manuel tab — `_tabIndex` + custom `_buildTabs`
* **Risk/Maliyet:** Swipe/semantics eksik (275–309).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
DefaultTabController(length: 2, child: TabBarView(...))
```

* **Hatalı Kod Yapısı:** `_buildRewardsList` 90+ satır inline
* **Risk/Maliyet:** Okunabilirlik; reward tile test edilemez (312–401).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — widgets/season_reward_row.dart
SeasonRewardRow(level: level, freeGrant: ..., vipGrant: ...)
```

* **Hatalı Kod Yapısı:** Yenileme yok
* **Risk/Maliyet:** `initState` tek load; claim sonrası stale UI riski.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
RefreshIndicator(onRefresh: () => ref.read(battlePassProvider.notifier).loadAll(), ...)
```

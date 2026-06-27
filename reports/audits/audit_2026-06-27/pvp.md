---
# 📦 DOSYA/SAYFA ANALİZİ: PvpScreen (`lib/screens/pvp/pvp_screen.dart`)

**Rota:** `/pvp`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/pvp.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/providers/pvp_provider.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — yanlış aktif sekme
* **Hata Tanımı:** `currentRoute: AppRoutes.pvp` geçirilse de `_activeIndex` yalnızca home/envanter/zindan/karakter eşler; eşleşmeyince **default 0 (Home)**. Screenshot'ta PvP içeriği görünürken alt nav Home mavi.
* **Kullanıcıya Etkisi:** Oyuncu hangi bölümde olduğunu kaybeder; geri navigasyon beklentisi bozulur.
* **Kesin Çözüm ve Öneri:** Menü rotaları için `_activeIndex` → `_menuTabIndex` veya indicator gizle; `GameChrome` secondary route map.

* **Sorunlu Bileşen/Yer:** `GameTopBar` — İngilizce başlık
* **Hata Tanımı:** `title: 'PvP'` (satır 101). Alt metinler Türkçe (`PvP İstatistikleri`, `Açık Arenalar`).
* **Kullanıcıya Etkisi:** Küçük tutarsızlık; store screenshot'ta İngilizce başlık.
* **Kesin Çözüm ve Öneri:** `'Oyuncu vs Oyuncu'` veya `'Düello'`.

* **Sorunlu Bileşen/Yer:** İstatistik grid — `Rating` İngilizce
* **Hata Tanımı:** `_StatChip` etiketi `'Rating'` (satır ~126). Diğerleri Türkçe: `Kazanma Oranı`, `Galibiyet`.
* **Kullanıcıya Etkisi:** Yeni oyuncu MMR/rating kavramını bağlayamaz.
* **Kesin Çözüm ve Öneri:** `'Derece'` veya `'Sıralama Puanı'`.

* **Sorunlu Bileşen/Yer:** Arena kartı — düşük bilgi yoğunluğu
* **Hata Tanımı:** Screenshot'ta tek arena `test` / `Dövüş Kulübü`; oyuncu sayısı, seviye, giriş ücreti yok. CTA `Arenaya Git` tek aksiyon.
* **Kullanıcıya Etkisi:** Hangi arenanın uygun olduğu belirsiz; boş/test isim güveni düşürür.
* **Kesin Çözüm ve Öneri:** `onlineCount`, `minLevel`, `entryFee` badge'leri; boş isim filtrele.

* **Sorunlu Bileşen/Yer:** Hastane/hapis banner — statik metin
* **Hata Tanımı:** `_isRestricted` boolean; geri sayım yok (dungeon'daki canlı strip ile tutarsız).
* **Kullanıcıya Etkisi:** "Ne zaman dönebilirim?" sorusu cevapsız.
* **Kesin Çözüm ve Öneri:** Paylaşılan `RestrictionCountdownBanner` widget.

* **Sorunlu Bileşen/Yer:** `Son Maçlar` — boş state
* **Hata Tanımı:** `Henüz maç yok.` düz metin; CTA yok (`Geçmişi Aç` üstte ayrı).
* **Kullanıcıya Etkisi:** İlk PvP deneyiminde sonraki adım belirsiz.
* **Kesin Çözüm ve Öneri:** Empty state illustration + `İlk düellonu başlat` → arena listesi.

* **Sorunlu Bileşen/Yer:** Hardcoded gradient arka plan
* **Hata Tanımı:** `Color(0xFF10131D)` / `0xFF171E2C` (105–109); `AppColors.bgDeep` kullanılmıyor.
* **Kullanıcıya Etkisi:** Market/home ile ton farkı.
* **Kesin Çözüm ve Öneri:** `AppColors` gradient sabiti.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `initState` + `activate` çift yükleme
* **Risk/Maliyet:** Her route geri dönüşünde `loadProfile` + `pvpDashboardProvider.load()` tekrar (satır 23–37).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — activate duplicate
@override
void activate() {
  super.activate();
  deferProviderUpdate(() { ... load ... });
}

// OLMASI GEREKEN — activate kaldır; RefreshIndicator + stale TTL
```

* **Hatalı Kod Yapısı:** Hardcoded arena rotası
* **Risk/Maliyet:** `context.go('/mekans/${arena.id}/arena')` (satır ~221); router refactor'da kırılır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
context.go('/mekans/${arena.id}/arena');

// OLMASI GEREKEN
context.go(AppRoutes.mekanArena(arena.id));
```

* **Hatalı Kod Yapısı:** `_isRestricted` basit `DateTime.tryParse`
* **Risk/Maliyet:** UTC/timezone drift; dungeon'daki `_parseRestrictionUntil` ile duplicate logic (satır 40–44).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — core/utils/restriction_time.dart paylaş
bool isActiveRestriction(String? raw) => parseRestrictionUntil(raw)?.isAfter(DateTime.now()) ?? false;
```

* **Hatalı Kod Yapısı:** Inline `_card` / `_StatChip` private helpers
* **Risk/Maliyet:** 550 satırlık screen; yeniden kullanım yok (satır 263+).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
// widgets/pvp_stats_card.dart, widgets/pvp_arena_tile.dart
```

* **Hatalı Kod Yapısı:** `_StatChip` × 5 tek `Row` içinde `Expanded`
* **Risk/Maliyet:** Dar ekranda `0.0%` / `1100` metin sıkışması (satır 124–133).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
Wrap(spacing: 8, runSpacing: 8, children: statChips)
```

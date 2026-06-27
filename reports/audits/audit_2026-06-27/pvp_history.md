---
# 📦 DOSYA/SAYFA ANALİZİ: PvpHistoryScreen (`lib/screens/pvp/pvp_history_screen.dart`)

**Rota:** `/pvp/history`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/pvp_history.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `lib/components/layout/game_chrome.dart`  
**İlgili widget'lar:** `lib/providers/pvp_provider.dart` (`pvpHistoryProvider`)

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home yanlış aktif
* **Hata Tanımı:** `GameSubScreenScaffold` `bottomNavRoute: AppRoutes.pvpHistory` geçiriyor; `_activeIndex` yalnızca 5 ana tab rotasını tanır → eşleşme yok → `0` (Home). Screenshot'ta PvP geçmişi açıkken Home mavi.
* **Kullanıcıya Etkisi:** PvP alt rotasında konum kaybı; geri beklentisi bozulur.
* **Kesin Çözüm ve Öneri:** `/pvp` prefix → Menü veya nötr indicator; `GameSubScreenScaffold` için secondary-route map.

* **Sorunlu Bileşen/Yer:** Boş durum — CTA eksik
* **Hata Tanımı:** Screenshot QA: `Henüz hiç PvP maçınız bulunmuyor.` + emoji + `Yenile` TextButton; arena/düelloya yönlendirme yok (satır 136-151).
* **Kullanıcıya Etkisi:** İlk oyuncu sonraki adımı bilmez; Yenile boş listeyi değiştirmez.
* **Kesin Çözüm ve Öneri:** `İlk düellonu başlat` → `/pvp` veya arena; Yenile ikincil.

* **Sorunlu Bileşen/Yer:** Başlık — emoji + uzun metin
* **Hata Tanımı:** `title: '⚔️ PvP Maç Geçmişi'` (satır 72); AppBar'da emoji + İngilizce kısaltma karışık.
* **Kullanıcıya Etkisi:** Küçük ekranda taşma; PvP ana ekranla tutarsız ton.
* **Kesin Çözüm ve Öneri:** `'Maç Geçmişi'` veya `'Düello Kayıtları'`.

* **Sorunlu Bileşen/Yer:** Filtre chip — kayıp maç mantığı
* **Hata Tanımı:** `_filter == 'loss'` → `m.winnerId != authId` (satır 62-64); beraberlik veya authId boşsa yanlış sınıflandırma.
* **Kullanıcıya Etkisi:** Filtre güvenilmez; QA'da boş liste doğrulandı, dolu liste test edilmedi.
* **Kesin Çözüm ve Öneri:** Explicit `isDraw` / `participantId` karşılaştırması.

* **Sorunlu Bileşen/Yer:** Ödül metni — İngilizce `Gold` / `Rep`
* **Hata Tanımı:** Kart sağ kolon `'${m.goldStolen} Gold'` ve `'Rep'` (satır 228-242); sol metinler Türkçe.
* **Kullanıcıya Etkisi:** Lokalizasyon tutarsızlığı.
* **Kesin Çözüm ve Öneri:** `Altın` / `İtibar` veya `l10n`.

* **Sorunlu Bileşen/Yer:** Hata durumu — ham exception
* **Hata Tanımı:** `history.error!` doğrudan kırmızı metin (satır 125-127).
* **Kullanıcıya Etkisi:** RPC/stack trace sızıntısı.
* **Kesin Çözüm ve Öneri:** User-friendly mesaj + retry (Yenile butonu mevcut).

* **Sorunlu Bileşen/Yer:** Viewport — %70 boş alan
* **Hata Tanımı:** Screenshot'ta filtre bar sonrası geniş boşluk; empty state ortada küçük, illustration yok.
* **Kullanıcıya Etkisi:** "Ekran dondu" algısı.
* **Kesin Çözüm ve Öneri:** Full-height empty illustration + örnek maç mockup (dev).

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `activate()` + `initState()` çift `load()`
* **Risk/Maliyet:** Her route geri dönüşünde duplicate RPC (satır 23-36).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — tek kaynak, stale-while-revalidate
ref.listen(pvpHistoryProvider, ...);
// veya activate'te sadece cache expired ise load
```

* **Hatalı Kod Yapısı:** `authId` çift kaynak
* **Risk/Maliyet:** Supabase `currentUser?.id` vs `playerProvider.profile?.authId` (satır 54-56); senkron kayması filtre bozar.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
final authId = ref.watch(playerProvider).profile?.authId ?? '';
```

* **Hatalı Kod Yapısı:** Hardcoded gradient
* **Risk/Maliyet:** `Color(0xFF10131D)` tekrarı (satır 77-82); `AppColors` drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
decoration: BoxDecoration(gradient: AppColors.screenGradient),
```

* **Hatalı Kod Yapısı:** `logout` — provider clear eksik
* **Risk/Maliyet:** Yalnızca `auth` + `player` (satır 66-69); `pvpHistoryProvider` stale kalır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.invalidate(pvpHistoryProvider);
```

* **Hatalı Kod Yapısı:** Filtre client-side only
* **Risk/Maliyet:** Tüm maçlar çekilip UI'da süzülüyor; büyük geçmişte performans.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// RPC param: p_filter: 'win' | 'loss' | 'all'
```

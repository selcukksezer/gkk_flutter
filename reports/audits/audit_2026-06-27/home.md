---
# 📦 DOSYA/SAYFA ANALİZİ: HomeScreen (`lib/screens/home/home_screen.dart`)

**Rota:** `/home`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/home.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/screens/home/widgets/hero_showcase.dart`, `lib/screens/home/widgets/pantheon_board.dart`, `lib/screens/home/widgets/sticky_action_bar.dart`, `lib/components/layout/game_chrome.dart`

> **QA notu (2026-06-27 güncelleme):** `home.png` harness fix sonrası **yeniden yakalandı** (`QA_SKIP_DAILY_REWARD` + `dismissBlockingOverlays`). Günlük ödül dialogu artık görünmüyor; `KASA AÇ` banner, `HeroShowcase`, `PantheonBoard` screenshot'ta doğrulanabilir. Önceki PNG yalnızca `20 Günlük Ödül Yolu` modalını gösteriyordu.

> **Önceki QA notu:** `home.png` birebir **Günlük Ödül** dialogunu gösteriyordu (`20 Günlük Ödül Yolu`). `HomeScreen._maybeShowDailyReward()` → `showDailyRewardDialog` smoke oturumunda home yüklenir yüklenmez tetiklenmiş. Kasa banner (`KASA AÇ`), `HeroShowcase`, `PantheonBoard` screenshot'ta görünmüyordu. Audit kod + partial UI inference ile yapılmıştır.

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Ekran görüntüsü otomasyonu — daily reward modal home UI'sini maskeliyor
* **Hata Tanımı:** Manifest `home` slug'ı altında yalnızca dialog frame'i; ana dashboard içeriği doğrulanmıyor. Splash/login QA notu ile aynı sınıf hata.
* **Kullanıcıya Etkisi:** Regresyon testi home layout'unu kapsamaz; dialog kapatıldıktan sonraki gerçek UX audit dışı kalır.
* **Kesin Çözüm ve Öneri:** Screenshot harness'te `dailyRewardProvider` override veya dialog dismiss; ikinci pass `home_post_reward.png`.

* **Sorunlu Bileşen/Yer:** `GameTopBar` — AppBar başlık İngilizce
* **Hata Tanımı:** `GameTopBar(title: 'Home')` — kod satır 80. `GameTopBar` aslında custom 196px profil şeridi; `title` parametresi muhtemelen kullanılmıyor veya gizli, ancak semantik/erişilebilirlik etiketi İngilizce kalıyor. Türkçe nav: "Ana Sayfa" / "Krallık".
* **Kullanıcıya Etkisi:** Tutarsız dil; bottom nav ikonları Türkçe label kullanırken üst chrome İngilizce route adı taşır.
* **Kesin Çözüm ve Öneri:** `title: 'Ana Sayfa'` veya `Semantics(header: true, label: 'Ana sayfa')`; `AppStrings.routes.home`.

* **Sorunlu Bileşen/Yer:** `_CratePromoBanner` — sahte geri sayım ve yanıltıcı fiyat
* **Hata Tanımı:** Timer sabit hardcoded: `_buildTimeBlock('06', 'Sa')`, `'32'`, `'12'` — gerçek zamanlı değil. CTA metni `500 ile Aç` + cyan diamond ikon; backend fiyat/stok ile bağlantı yok. Alt metin "Sınırlı bir süre için" süresiz görünür.
* **Kullanıcıya Etkisi:** Yanıltıcı aciliyet (dark pattern); timer sıfırlanmaz → güven kaybı. App Store "misleading UI" riski.
* **Kesin Çözüm ve Öneri:** `loot` API'den `endsAt` + `priceGems` çek; `Stream.periodic` ile gerçek countdown veya timer kaldır. Fiyatı profil `gems` ile karşılaştır (yetersizse disabled CTA).

* **Sorunlu Bileşen/Yer:** Promo banner — tipografi sistemi kopukluğu
* **Hata Tanımı:** `GoogleFonts.urbanist` doğrudan banner içinde (`KASA AÇ`, alt metin, timer); geri kalan home `AppTextStyles` kullanır. Font weight/size (`w900`, 28px) tema `headlineSmall` ile hizalı değil.
* **Kullanıcıya Etkisi:** Banner "başka tasarımcı" hissi; görsel hiyerarşi Pantheon ile uyumsuz.
* **Kesin Çözüm ve Öneri:** `AppTextStyles.h2.copyWith(color: Colors.white)`; Urbanist zaten `app_theme.dart`'ta global.

* **Sorunlu Bileşen/Yer:** `HeroShowcase` — eksik ekipman slotları vs envanter
* **Hata Tanımı:** Home hero 6 slot: weapon, head, chest, gloves, boots, necklace. `InventoryScreen._EquippedPanel` 8 slot: + legs, ring. Oyuncu home'da bacak/yüzük kuşandığını görmez; slot etiketleri de farklı (`Kask` vs `KAFA`, `Ayakkabı` vs `BOT`).
* **Kullanıcıya Etkisi:** Ana sayfa karakter vitrininde eksik build bilgisi; envanter-home bilişsel model kopukluğu.
* **Kesin Çözüm ve Öneri:** Paylaşılan `EquipSlotLayout` constant; home'da 8 slot compact grid veya scrollable ring.

* **Sorunlu Bileşen/Yer:** `PantheonBoard` — ASCII Türkçe ve tier copy
* **Hata Tanımı:** `'Siralama'`, `'Guc liderleri • canli'`, `'Henuz siralama verisi yok.'`, `'Siralama yuklenemedi'` — `ı`, `ü`, `ç` eksik. Alt link `Tumu` → "Tümü".
* **Kullanıcıya Etkisi:** Login/register ile aynı i18n borcu; liderlik prestij metni amatör durur.
* **Kesin Çözüm ve Öneri:** l10n ARB; `'Güç liderleri • canlı'`.

* **Sorunlu Bileşen/Yer:** Günlük ödül dialogu — home içeriğini bloke eden modal
* **Hata Tanımı:** `_maybeShowDailyReward()` profil `ready` olunca otomatik dialog açar; `_dailyRewardShownThisSession` yalnızca session içi. İlk girişte tüm home (kasa, hero, pantheon) görünmez — screenshot'ta kanıtlandı.
* **Kullanıcıya Etkisi:** Yeni/geri dönen oyuncu ana hub'ı göremeden CTA'ya zorlanır; skip/dismiss gecikmesi yoksa frustrasyon.
* **Kesin Çözüm ve Öneri:** Non-blocking banner veya bottom sheet; "Sonra" butonu; dialog `barrierDismissible: true`; screenshot QA'da devre dışı.

* **Sorunlu Bileşen/Yer:** `_WarningStack` — sağ üst pill'ler SafeArea çakışması
* **Hata Tanımı:** `Positioned(top: 0, right: 16)` + `SafeArea` — `GameTopBar` zaten ~196px. Uyarılar (`Kritik Enerji`, `Yüksek Tolerans`) scroll içeriğinin üstüne bindirir; promo banner ile overlap riski. Pill'ler emoji + kısa metin — küçük ekranda yatay taşma yok ama dikey stack 3+ banner olunca ~120pt kaplar.
* **Kullanıcıya Etkisi:** Kasa banner sol metni uyarı pill'leri ile yarışır; kritik durum mesajı kaçırılabilir.
* **Kesin Çözüm ve Öneri:** Uyarıları `GameTopBar` altına inline chip row veya tek birleşik banner; max 1 floating pill.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `ref.listen` build içinde — satır 72-76
* **Risk/Maliyet:** Her `playerProvider` rebuild'inde listener; `ready` geçişinde `_maybeShowDailyReward` build fazında schedule edilir. Home + daily dialog race (screenshot bug kök nedeni).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — home_screen.dart:72-76
ref.listen<PlayerState>(playerProvider, (prev, next) {
  if (next.status == PlayerStatus.ready && prev?.status != PlayerStatus.ready) {
    deferProviderUpdate(_maybeShowDailyReward);
  }
});

// OLMASI GEREKEN — initState / listenManual
@override
void initState() {
  super.initState();
  ref.listenManual(playerProvider, _onPlayerStateChanged);
}
```

* **Hatalı Kod Yapısı:** Ölü kod — ~400 satır kullanılmayan widget sınıfları
* **Risk/Maliyet:** `_StatsGrid`, `_PrimaryActions`, `_QuestSection`, `_PotionAction`, `_SecondaryActions`, `_RecentActivitySection` tanımlı ama `_HomeDashboard.build` içinde **hiç çağrılmıyor**. `_showAllActions` `final false` — toggle imkansız. `_showPotionModal`, `_showComingSoon` dead methods.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT _HomeDashboard children — yalnızca:
const _CratePromoBanner(),
HeroShowcase(...),
const PantheonBoard(),

// OLMASI GEREKEN — ya geri ekle ya sil
// Seçenek A: Stats + PrimaryActions ListView'e ekle
// Seçenek B: dead class'ları ayrı PR'da kaldır (1563 satır → ~900)
```

* **Hatalı Kod Yapısı:** Duplicate logout handler — AppBar + BottomBar
* **Risk/Maliyet:** Aynı 4 satırlık logout+clear bloğu iki yerde (satır 81-85, 91-95); biri güncellenirse diğeri stale kalır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
Future<void> _handleLogout() async {
  await ref.read(authProvider.notifier).logout();
  ref.read(playerProvider.notifier).clear();
  ref.read(inventoryProvider.notifier).clear();
}
// GameTopBar(onLogout: _handleLogout), GameBottomBar(onLogout: _handleLogout)
```

* **Hatalı Kod Yapısı:** `_ActiveStatusPill` — `Stream.periodic` saniyede bir tüm subtree rebuild
* **Risk/Maliyet:** Hastane/hapishane timer pill'i her saniye `AnimatedBuilder` + `BackdropFilter` blur tetikler; home scroll sırasında birden fazla pill = gereksiz GPU yükü.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — TickerMode + ValueNotifier<DateTime> tek listener
class _CountdownText extends StatefulWidget { ... } // yalnızca Text rebuild
```

* **Hatalı Kod Yapısı:** `HeroShowcase` — deprecated `withOpacity` + sabit `height: 450`
* **Risk/Maliyet:** `withOpacity(0.2)` Flutter 3.27+ deprecation; 450pt sabit yükseklik landscape/küçük cihazda ListView overflow veya aşırı boşluk. `SingleTickerProvider` breathing animasyon sürekli repaint.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
.withValues(alpha: 0.2)
LayoutBuilder(builder: (_, c) {
  final h = (c.maxWidth * 1.05).clamp(320.0, 450.0);
  return SizedBox(height: h, child: ...);
})
```

* **Hatalı Kod Yapısı:** `_CratePromoBanner` margin `horizontal: 16` + ListView padding `AppSpacing.base` (16)
* **Risk/Maliyet:** Efektif yatay inset 32px; Pantheon tam genişlik — banner dar görünür, hizalama tutarsız.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — satır 709
margin: const EdgeInsets.symmetric(horizontal: 16),

// OLMASI GEREKEN — margin kaldır, ListView padding yeterli
// veya banner'ı edge-to-edge full bleed yap (negatif margin)
```

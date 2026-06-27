---
# 📦 DOSYA/SAYFA ANALİZİ: CharacterSelectScreen (`lib/screens/auth/character_select_screen.dart`)

**Rota:** `/onboarding/character-select`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/onboarding_character_select.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`

> **QA notu (2026-06-27 güncelleme):** `onboarding_character_select.png` harness fix sonrası **yeniden yakalandı** (`QA_FORCE_CHARACTER_SELECT` + `QA_SKIP_DAILY_REWARD` + `dismissBlockingOverlays`). Screenshot artık **SİMYACI** karakter seçim UI'sini gösteriyor (carousel, `Maceraya Başla` CTA). Önceki PNG günlük ödül modalı veya home redirect içeriyordu.

> **Önceki QA notu:** `onboarding_character_select.png` fiilen **Günlük Ödül** modalını gösteriyordu (`20 Günlük Ödül Yolu`, sarı `Gün 1 Ödülünü Al` CTA). Smoke harness, home'a yönlendirme sırasında `showDailyRewardDialog` açıkken screenshot almış; karakter seçim UI'si görüntüde yoktu. Audit aşağıda **kaynak koda** dayanır.

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Ekran görüntüsü otomasyonu — yanlış katman yakalanmış
* **Hata Tanımı:** Manifest slug `onboarding_character_select` olmasına rağmen PNG tam ekran daily-reward dialogu. Arka planda onboarding ekranı hiç doğrulanmıyor; regresyon (CTA rengi, carousel scroll, seçili border) kaçırılır.
* **Kullanıcıya Etkisi:** Doğrudan oyuncu etkisi yok; tasarım/UX audit'i bu sayfa için geçersiz kalır.
* **Kesin Çözüm ve Öneri:** Screenshot öncesi `dailyRewardProvider` mock (`canClaim: false`) veya dialog `Navigator.pop` + `pumpAndSettle`; character-select rotasına **doğrudan deep link** ile git (home üzerinden değil).

* **Sorunlu Bileşen/Yer:** Başlık alt metinleri — Türkçe/İngilizce dil karışımı
* **Hata Tanımı:** Sınıf adları Türkçe (`Savaşçı`, `Simyacı`, `Gölge`) ancak `titleLine` İngilizce sabit: `Frontline Dominator`, `Arcane Field Engineer`, `Precision Elimination`. `traitSummary` de İngilizce kısaltma: `STR / DEF / AGG`, `INT / CTRL / SUP`, `DEX / SPD / BURST`. Üst etiket `GKK // CHARACTER SELECT` tamamen İngilizce.
* **Kullanıcıya Etkisi:** Onboarding'de ilk karar anında yerelleştirme kopukluğu; login/register'daki ASCII Türkçe sorununa ek olarak "global beta" algısı.
* **Kesin Çözüm ve Öneri:** `titleLine_tr` / `traitSummary_tr` alanları Supabase RPC'den veya `AppStrings.characterSelect.*` sabitlerinden gelsin; header `GKK // KARAKTER SEÇİMİ`.

* **Sorunlu Bileşen/Yer:** Tema sistemi dışı renk/token kullanımı
* **Hata Tanımı:** `Scaffold` arka plan `#08090C`, header altın `#D9AE57`, kart gradyanları `#15171B` / `#0E1014` — hiçbiri `AppColors.bgDeep` (#0F1523), `AppColors.gold` (#F5C842) veya `AppTextStyles` ile hizalı değil. Login/Register `Card` + Urbanist temasından görsel kopuş.
* **Kullanıcıya Etkisi:** Auth funnel sonrası "farklı uygulama" hissi; marka tutarlılığı kırılır.
* **Kesin Çözüm ve Öneri:** `accentColor` sınıf renkleri `AppColors` türevleri; metinler `AppTextStyles.h1/h3/caption`; arka plan `AppColors.bgBase` gradient.

* **Sorunlu Bileşen/Yer:** Alt panel — dikey alan baskısı (küçük ekran)
* **Hata Tanımı:** `_buildBottomSheet` sabit yükseklikler: yatay `ListView` `height: 156`, iç padding `18+18`, `Operasyon Özeti` kutusu + CTA `150px` genişlikte buton. `Column` içinde `Expanded` hero stage ile birlikte iPhone SE (~667pt) SafeArea sonrası alt panel ~280pt — carousel + özet + CTA sıkışır; ekran görüntüsü olmasa da kod layout'u scroll'suz.
* **Kullanıcıya Etkisi:** Alt sınıf kartlarının alt etiketleri (`titleLine`) kesilir; birincil CTA thumb zone'a yakın ama carousel yarım görünür.
* **Kesin Çözüm ve Öneri:** Alt paneli `DraggableScrollableSheet` veya `SingleChildScrollView` yap; carousel yüksekliğini `compact ? 120 : 156` dinamikle.

* **Sorunlu Bileşen/Yer:** Yatay sınıf kartları — erişilebilirlik ve seçim geri bildirimi
* **Hata Tanımı:** `GestureDetector` + `AnimatedContainer`; `Semantics`/`selected` state yok. Seçili kart yalnızca border rengi (`selected ? cls.accentColor : white12`) — ekran okuyucuda "seçili" duyurulmaz. Kart genişliği sabit `188px`; 3 sınıfta 2. kart kısmen viewport dışında kalabilir (scroll ipucu yok).
* **Kullanıcıya Etkisi:** VoiceOver kullanıcısı hangi sınıfın aktif olduğunu anlayamaz; yeni oyuncu 3. sınıfın varlığını fark etmeyebilir.
* **Kesin Çözüm ve Öneri:** `Semantics(selected: selected, label: cls.name, button: true)`; listenin sağına gradient fade + "kaydır" ipucu veya `PageView` ile sayfa göstergesi.

* **Sorunlu Bileşen/Yer:** Birincil CTA — `Maceraya Başla` kontrastı sınıfa göre değişken
* **Hata Tanımı:** `FilledButton` `backgroundColor: activeClass.accentColor`, `foregroundColor: Colors.black`. Simyacı `#63D1C5` (teal) üzerinde siyah metin ~7:1 iyi; Gölge `#8E93FF` (lavanta) üzerinde siyah ~5.5:1 sınırda. Spinner `_submitting` durumunda siyah `CircularProgressIndicator` teal/lavanta üzerinde düşük kontrast.
* **Kullanıcıya Etkisi:** Gölge/Simyacı seçiminde yükleme feedback'i zayıf görünür.
* **Kesin Çözüm ve Öneri:** CTA için sabit `AppColors.gold` arka plan + `AppColors.bgDeep` metin; sınıf rengi yalnızca border/glow'da kalsın.

* **Sorunlu Bileşen/Yer:** Geri navigasyon / iptal yolu yok
* **Hata Tanımı:** `Scaffold` AppBar/back button yok; kullanıcı yanlış hesapla geldiyse logout veya geri dönüş UI'si sunulmuyor. Onboarding ölü uç (dead-end) hissi.
* **Kullanıcıya Etkisi:** Yanlış sınıf seçiminde panik; hesap değiştirmek için uygulamayı kapatmak gerekebilir.
* **Kesin Çözüm ve Öneri:** Sol üst `IconButton(Icons.arrow_back)` → `context.go(login)` veya "Çıkış Yap" text link; seçim sonrası onay sheet'i ("Savaşçı seçildi, emin misin?").

* **Sorunlu Bileşen/Yer:** Spacing — 8pt grid ihlali
* **Hata Tanımı:** Padding `18`, `22`, `10`, `6`, `14`, `16` karışık; `AppSpacing` (`sm=8`, `base=16`, `lg=20`) kullanılmıyor. Header altı `SizedBox(height: 18)` grid dışı.
* **Kullanıcıya Etkisi:** Auth ekranlarıyla ritim uyumsuzluğu; alt panel "elle ölçülmüş" durur.
* **Kesin Çözüm ve Öneri:** Tüm gap'leri `AppSpacing` token'larına sabitle.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Sunucu yanıtı başarı mantığı ters/ gevşek — satır 198
* **Risk/Maliyet:** `response['success'] != false` → `null` veya eksik `success` alanı **başarı** sayılır; RPC hata döndürse bile `persisted = true` olabilir, profil güncellenmeden home'a gidilir.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — character_select_screen.dart:198
if (response is! Map<String, dynamic> || response['success'] != false) {
  persisted = true;
}

// OLMASI GEREKEN
if (response is Map<String, dynamic> && response['success'] == true) {
  persisted = true;
}
```

* **Hatalı Kod Yapısı:** Sınıf tanımları üçlü tekrar — `_classes`, `presentationMap`, `iconMap`
* **Risk/Maliyet:** Yeni sınıf eklemek 3 yeri güncellemeyi gerektirir; drift riski (RPC'den gelen id `presentationMap`'te yoksa fallback `savasci.png`).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — tek registry
const _kClassCatalog = <String, CharacterClassPresentation>{
  'warrior': CharacterClassPresentation(...),
};
// _loadClasses yalnızca name_tr/description_tr merge eder
```

* **Hatalı Kod Yapısı:** `_loadClasses` hata yutma — boş catch, sessiz fallback
* **Risk/Maliyet:** RPC exception'da `_error` set edilir ama `_classes` default liste kalır; `_loadingClasses false` ile kullanıcı fark etmeden stale data görür. `success == false` durumunda `return` ile `_error` set edilmez.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
if (!success || classes == null || classes.isEmpty) {
  if (mounted) setState(() => _error = 'Sınıf listesi boş.');
  return;
}
```

* **Hatalı Kod Yapısı:** `build()` her frame'de `_activeClass` + tam `Stack` rebuild — glow `AnimatedBuilder` tüm stage'i sarmalıyor
* **Risk/Maliyet:** `_glowController.repeat` 2.2s döngüde sürekli repaint; 3× `BoxShadow` + `ShaderMask` + `Hero` — orta segment cihazlarda onboarding jank.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — glow layer RepaintBoundary ile izole
RepaintBoundary(
  child: AnimatedBuilder(
    animation: _glowAnimation,
    builder: (_, __) => _GlowBorder(activeClass: activeClass, t: t),
    child: _CharacterArtwork(activeClass: activeClass), // static child
  ),
)
```

* **Hatalı Kod Yapısı:** `Hero(tag: 'character-card-${activeClass.id}')` — home `HeroShowcase` ile tag çakışma riski
* **Risk/Maliyet:** Home'a `context.go` sonrası aynı tag'li Hero flight exception veya görsel glitch (debug'da turuncu çizgi uyarısı).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
Hero(tag: 'onboarding-character-${activeClass.id}', ...)
// veya onboarding'de Hero kullanma — go() zaten stack sıfırlar
```

* **Hatalı Kod Yapısı:** Monolitik 818 satır tek dosya — UI/logic/RPC karışık
* **Risk/Maliyet:** Test edilebilirlik düşük; `_CharacterClassOption` private, widget test yazılamaz.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN dosya ayrımı
// character_select_screen.dart — state + navigation
// widgets/character_stage.dart, widgets/class_carousel.dart
// data/character_class_catalog.dart
```

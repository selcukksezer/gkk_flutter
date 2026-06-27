---
# 📦 DOSYA/SAYFA ANALİZİ: MekanCreateScreen (`lib/screens/mekans/mekan_create_screen.dart`)

**Rota:** `/mekans/create`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/mekans_create.png`  
**Tema referansları:** `lib/screens/mekans/widgets/mekan_theme.dart`, `mekan_design.dart`  
**İlgili widget'lar:** `mekan_scaffold.dart`, `lib/providers/mekan_provider.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Türkçe karakter — ASCII mesajlar
* **Hata Tanımı:** `_create()` snackbar: `'Once bir tur sec'`, `'Mekan adi gerekli'` (satır 34-38); UI label `'Mekan adi'` (satır 114) — ı/ş/ö yok.
* **Kullanıcıya Etkisi:** Profesyonel olmayan copy; store lokalizasyonu zayıf.
* **Kesin Çözüm ve Öneri:** `'Önce bir tür seç'`, `'Mekan adı gerekli'`, `l10n` ARB.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` / Home — alt nav
* **Hata Tanımı:** `MekanSubScaffold` screenshot'ta Home mavi; mekan alt rotası ana tab ile eşleşmiyor.
* **Kullanıcıya Etkisi:** Mekan oluşturma akışında konum kaybı.
* **Kesin Çözüm ve Öneri:** Mekan hub rotası için Menü highlight.

* **Sorunlu Bileşen/Yer:** Sohbet FAB — kart overlap (Screenshot QA)
* **Hata Tanımı:** Screenshot'ta FAB Kahvehane kartının üzerine bindiriyor; scroll padding bottom yetersiz.
* **Kullanıcıya Etkisi:** Son tür kartı ve CTA kısmen gizlenir.
* **Kesin Çözüm ve Öneri:** `ListView` `padding.bottom: gameBottomContentInset(context)`.

* **Sorunlu Bileşen/Yer:** Kilitli türler — tıklanamaz ama neden belirsiz
* **Hata Tanımı:** `locked` → `onTap: null` (satır 148); kırmızı chip level/gold gösteriyor ama tek satır açıklama yok.
* **Kullanıcıya Etkisi:** Lv6 oyuncu Bar (Lv15, 5M) neden kapalı — chip okunursa anlaşılır; yine de tooltip iyi olur.
* **Kesin Çözüm ve Öneri:** Locked tap → `AppMessenger` ile eksik şart.

* **Sorunlu Bileşen/Yer:** Başlık — tamamen büyük harf
* **Hata Tanımı:** `'IMPARATORLUGUNU KUR'` (satır 94); Türkçe'de `İMPARATORLUĞUNU KUR`.
* **Kullanıcıya Etkisi:** Typo/encoding izlenimi.
* **Kesin Çözüm ve Öneri:** Doğru Unicode veya sentence case.

* **Sorunlu Bileşen/Yer:** Sticky footer CTA — seçim yokken pasif
* **Hata Tanımı:** `canCreate` false iken `NeonButton` disabled, label `'Tur Sec'` (satır 161-166); ad girilse bile tür şart.
* **Kullanıcıya Etkisi:** OK; ancak screenshot'ta tüm türler locked görünüyor — footer sürekli disabled, ilerleme yok.
* **Kesin Çözüm ve Öneri:** En az bir erişilebilir starter tür (düşük level) veya demo unlock.

* **Sorunlu Bileşen/Yer:** Hata — ham `$e`
* **Hata Tanımı:** `AppMessenger.showError(context, '$e')` (satır 63).
* **Kullanıcıya Etkisi:** RPC hata metni sızar.
* **Kesin Çözüm ve Öneri:** Mapped user errors.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_busy` — catch'te reset
* **Risk/Maliyet:** Başarıda `go(myMekan)` öncesi `_busy` true kalır (satır 53-66); route değişince sorun yok ama hata path'te reset var.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// finally { if (mounted) setState(() => _busy = false); }
```

* **Hatalı Kod Yapısı:** `canCreate` — rebuild on name only
* **Risk/Maliyet:** `onChanged: (_) => setState` (satır 112); gold/level provider değişince button state güncellenir (watch var) — OK.
* **Mevcut Durum vs Olması Gereken (Refaktör):** Mevcut yeterli.

* **Hatalı Kod Yapısı:** `_TypeArtCard` — aynı dosyada 115 satır
* **Risk/Maliyet:** Reuse `mekans_screen` ile paylaşılmıyor.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// widgets/mekan_type_card.dart
```

* **Hatalı Kod Yapısı:** Create sonrası mekan list invalidate yok
* **Risk/Maliyet:** `mekanRepository.createMekan` sonra yalnızca profile reload (satır 55-59).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.invalidate(mekanListProvider);
```

* **Hatalı Kod Yapısı:** `MekanTypeInfo.all` — static catalog
* **Risk/Maliyet:** Server-side unlock ile drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// RPC get_mekan_types
```

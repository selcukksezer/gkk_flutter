---
# 📦 DOSYA/SAYFA ANALİZİ: PrisonScreen (`lib/screens/prison/prison_screen.dart`)

**Rota:** `/prison`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/prison.png`  
**Tema referansları:** Hardcoded — `AppColors` kullanılmıyor  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/screens/facilities/facilities_screen.dart` (prison lock banner)

**Screenshot notu:** Smoke kullanıcısı cezaevinde değil — `_buildFree()` yakalandı. `prisonUntil` seed ile in-prison UI ayrı çekim önerilir.

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home yanlış aktif
* **Hata Tanımı:** `currentRoute: AppRoutes.prison` → `_activeIndex` fallback Home (screenshot).
* **Kullanıcıya Etkisi:** Cezaevi ekranında nav yanıltıcı.
* **Kesin Çözüm ve Öneri:** Menü highlight veya restriction route grubu.

* **Sorunlu Bileşen/Yer:** Özgür state — CTA eksik
* **Hata Tanımı:** `_buildFree` yalnızca metin; `Ana Sayfaya Dön` butonu yok (`prison_screen.dart` 233–267). Hospital healthy state'te buton var — tutarsız.
* **Kullanıcıya Etkisi:** Oyuncu çıkış yolu bulamaz; geri gesture'a bağımlı.
* **Kesin Çözüm ve Öneri:** Hospital ile aynı primary CTA; veya otomatik `context.go(home)` bilgi banner.

* **Sorunlu Bileşen/Yer:** Özgür state — thumbs up + cezaevi cognitive dissonance
* **Hata Tanımı:** 👍 emoji + "Cezaevi" başlık + yeşil "Şu anda özgürsünüz!" (`prison_screen.dart` 244–257). Emoji kutlama; bağlam cezaevi.
* **Kullanıcıya Etkisi:** Ton karmaşık; ciddi restriction modülünde casual emoji fazla.
* **Kesin Çözüm ve Öneri:** 🕊️ veya muhafız ikonu; emoji kaldır.

* **Sorunlu Bileşen/Yer:** Kaçış/başarı — `showError` her durumda
* **Hata Tanımı:** `_attemptEscape` `AppMessenger.showError` (satır 154–155); `success` unused. Hospital ile aynı bug.
* **Kullanıcıya Etkisi:** Başarılı kaçış hata olarak gösterilir.
* **Kesin Çözüm ve Öneri:** `showSuccess` / `showError` branch.

* **Sorunlu Bileşen/Yer:** Kefalet butonu — disabled gri belirsiz
* **Hata Tanımı:** `!canAfford` → `backgroundColor: Colors.grey` (satır 347–349); yetersiz gem alt metin 12px kırmızı. Aktif turuncu buton tıklanamaz görünebilir.
* **Kullanıcıya Etkisi:** Gem shop'a yönlendirme yok; hospital'daki "Dükkana Git" pattern eksik.
* **Kesin Çözüm ve Öneri:** Disabled + link "Elmas satın al"; `AppRoutes.shop` deep link.

* **Sorunlu Bileşen/Yer:** Geri sayım — saat yok
* **Hata Tanımı:** `_formatCountdown` yalnızca `MM:SS` (satır 179–182); >60dk hapis `90:00` gibi okunmaz. Hospital `Xh Ym` formatı.
* **Kullanıcıya Etkisi:** Uzun cezada kalan süre yanlış yorumlanır.
* **Kesin Çözüm ve Öneri:** `Duration` adaptive format shared helper.

* **Sorunlu Bileşen/Yer:** Gerekçe metni — facilities ile duplicate
* **Hata Tanımı:** Prison `prisonReason`; facilities kartı aynı metni gösterir (`facilities_screen.dart` 141–156). İki yerde farklı stil — sync riski.
* **Kullanıcıya Etkisi:** Metin güncellenirse biri eski kalır.
* **Kesin Çözüm ve Öneri:** `PrisonStatusBanner` shared widget.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `DateTime.tryParse(prisonUntil)` — timezone blind
* **Risk/Maliyet:** Hospital `_parseRestrictionUntil` ile tutarsız (`prison_screen.dart` 58, 82); UTC suffix olmayan DB değerleri erken/ geç serbest bırakır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
final releaseTime = parseRestrictionUntil(prisonUntil); // shared util
```

* **Hatalı Kod Yapısı:** `_freed` local flag — provider sync
* **Risk/Maliyet:** `_payBail` / escape sonrası `_freed = true` (satır 121, 161); profile reload gecikirse `_inPrison` false olur ama başka ekran hâlâ prison gösterir.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — yalnızca profile.prisonUntil truth source; _freed kaldır
bool get _inPrison => profile?.isInPrison ?? false;
```

* **Hatalı Kod Yapısı:** `_payBail` — yetersiz gem pre-check yok
* **Risk/Maliyet:** Dialog onay → RPC fail; hospital gem dialog shop yönlendirmesi var, prison yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
if (profile.gems < bailCost) {
  await showInsufficientGemsDialog(context, bailCost);
  return;
}
```

* **Hatalı Kod Yapısı:** `rawResponse as Map` — unsafe
* **Risk/Maliyet:** Escape RPC cast (satır 144); type error → boş map → generic message.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
final response = rawResponse is Map<String, dynamic>
    ? rawResponse
    : <String, dynamic>{'error': 'Beklenmeyen yanıt'};
```

* **Hatalı Kod Yapısı:** Duplicate restriction screen
* **Risk/Maliyet:** Prison 418 satır, hospital 546 satır — timer/escape/bail ortak.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// lib/screens/restriction/restriction_screen.dart
enum RestrictionKind { hospital, prison }
```

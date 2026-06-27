---
# 📦 DOSYA/SAYFA ANALİZİ: SettingsScreen (`lib/screens/settings/settings_screen.dart`)

**Rota:** `/settings`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/settings.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Ses ayarları — UI var, işlev yok (false affordance)
* **Hata Tanımı:** `_musicVolume`, `_sfxVolume`, `_muteAll` yalnızca local `setState`; persist (`SharedPreferences`/Supabase) yok. Audio engine/`audioplayers` bağlantısı yok. Slider hareket ettirir ama ses değişmez.
* **Kullanıcıya Etkisi:** Oyuncu ayarı kaydedildi sanır; uygulama yeniden açılınca sıfırlanır — güven kaybı, App Store "non-functional settings" şikayeti.
* **Kesin Çözüm ve Öneri:** `SettingsRepository` + gerçek audio mixin; slider debounce persist; mute master bus.

* **Sorunlu Bileşen/Yer:** Bildirimler & Otomatik Savaş toggle — phantom features
* **Hata Tanımı:** `_notifications`, `_autoBattle` local state; push notification izni (`permission_handler`) veya auto-battle backend hook yok. Otomatik savaş alt metni "PvP ve zindan savaşlarını otomatik yönet" vaat ediyor.
* **Kullanıcıya Etkisi:** Toggle açıkken hiçbir şey olmaz — en kötü UX sınıfı (broken promise).
* **Kesin Çözüm ve Öneri:** Feature flag off + disabled switch + "Yakında"; veya gerçek entegrasyon.

* **Sorunlu Bileşen/Yer:** Dil seçici — English segment fake
* **Hata Tanımı:** `SegmentedButton` EN seçilince `AppMessenger.show(context, 'English desteği yakında eklenecek')` — segment görsel olarak seçilebilir ama `_language` state EN'e geçmiyor (early return). Screenshot'ta TR seçili — OK; kullanıcı EN'e basınca snack + TR'de kalır, segment UI TR'de kalır (confusing flash).
* **Kullanıcıya Etkisi:** Dil değiştirme beklentisi karşılanmaz; uluslararası launch blokör.
* **Kesin Çözüm ve Öneri:** EN segment `enabled: false` veya gizle; `flutter gen-l10n` locale switch.

* **Sorunlu Bileşen/Yer:** Profil isim alanı — geç yüklenen profil senkron değil
* **Hata Tanımı:** `initState` `ref.read(playerProvider).profile` bir kez okunur (satır 34-36). Settings menüden açıldığında profil henüz `loading` ise `_nameController` boş kalır; profil sonra gelince field güncellenmez. Screenshot'ta alt beyaz sheet/username peek — muhtemelen klavye veya overlay artifact; profil kartı `GameTopBar` ile duplicate bilgi.
* **Kullanıcıya Etkisi:** Boş isim alanı → kaydet → validation hatası veya yanlışlıkla username silme.
* **Kesin Çözüm ve Öneri:** `ref.listen(playerProvider, ...)` ile controller sync; `TextEditingController` profile reactive.

* **Sorunlu Bileşen/Yer:** Bottom inset — nav bar + Sohbet FAB overlap
* **Hata Tanımı:** `ListView(padding: EdgeInsets.all(16))` — alt `SizedBox(height: 24)` yetersiz. Screenshot'ta "Hesap" bölümü bottom nav ile yakın; `Hesabı Sil` kırmızı CTA thumb zone/nav bar sınırında. `extendBody: true` scaffold.
* **Kullanıcıya Etkisi:** Destructive action yanlışlıkla tap; scroll sonu içerik gizlenir.
* **Kesin Çözüm ve Öneri:** `gameBottomBarClearance(context) + kGameChatFabSize + 16` alt padding.

* **Sorunlu Bileşen/Yer:** `Hesabı Sil` — tek onay, yeterli friction yok
* **Hata Tanımı:** `_deleteAccount` bir `AlertDialog` — "Emin misiniz?" yeterli değil GDPR/Apple için çoğu uygulama typed confirm veya 2-step. Kırmızı CTA tam genişlik, hemen `Çıkış Yap` altında.
* **Kullanıcıya Etkisi:** Kazara kalıcı veri kaybı; mağaza review/red flag.
* **Kesin Çözüm ve Öneri:** İkinci dialog: kullanıcı adını yaz; 30 gün soft-delete API varsa belirt.

* **Sorunlu Bileşen/Yer:** Section card stili — `AppColors`/`GkkCard` dışı
* **Hata Tanımı:** `_sectionCard` `Colors.black26`, `Border.all(white12)`, manuel `Divider` — envanter `_SectionCard` gradient glass farklı. Settings gradient arka plan `#10131D` → `#171E2C` hardcoded.
* **Kullanıcıya Etkisi:** Menü alt sayfası "prototype" durur; game chrome premium hissi zayıflar.
* **Kesin Çözüm ve Öneri:** Shared `GkkSettingsSection` = `GkkCard` + `AppTextStyles.h3`.

* **Sorunlu Bileşen/Yer:** TextField — düşük kontrast fill
* **Hata Tanımı:** `fillColor: Colors.white.withValues(alpha: 0.05)` + `OutlineInputBorder` — ekran görüntüsünde profil bölümü kısmen görünür; dark tema input sınırları `#253154` login'e göre daha soluk. Error text `_nameError` var ama helper yok (min 3 char kuralı önceden bilinmiyor).
* **Kullanıcıya Etkisi:** Form field sınırları zor seçilir; validation surprise.
* **Kesin Çözüm ve Öneri:** Tema `inputDecorationTheme` reuse; `helperText: 'En az 3 karakter'`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Tüm ayar state local — `ConsumerStatefulWidget` anti-pattern for settings
* **Risk/Maliyet:** 7 adet ephemeral field; widget dispose olunca ayarlar kaybolur; test/mock zor.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
@riverpod
class AppSettings extends _$AppSettings {
  @override
  Future<SettingsModel> build() => ref.read(settingsRepo).load();
  Future<void> setMusicVolume(double v) async { ... }
}
// SettingsScreen ref.watch(appSettingsProvider)
```

* **Hatalı Kod Yapısı:** `initState` içinde `ref.read` — profil race
* **Risk/Maliyet:** Riverpod `ref.read` initState'te OK ama profil async; controller stale.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
@override
Widget build(BuildContext context) {
  ref.listen(playerProvider.select((s) => s.profile?.displayName), (prev, next) {
    if (next != null && next != _nameController.text) {
      _nameController.text = next;
    }
  });
}
```

* **Hatalı Kod Yapısı:** Triple logout path — Settings + GameTopBar + GameBottomBar
* **Risk/Maliyet:** `_logout` confirm dialog + `context.go(login)`; AppBar `onLogout` confirm **yok** — doğrudan logout (satır 122-125). Tutarsız güvenlik UX.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — tek entry
onLogout: _logout, // her yerde confirm'li versiyon
```

* **Hatalı Kod Yapısı:** `_saveName` — RPC sonrası optimistic UI yok, error raw
* **Risk/Maliyet:** `catch (e)` → `'Hata: $e'` snack; Supabase PostgrestException stack trace parçası kullanıcıya gösterilebilir.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
} on PostgrestException catch (e) {
  AppMessenger.showError(context, mapProfileError(e));
}
```

* **Hatalı Kod Yapısı:** `_sliderTile` — mute durumunda slider `onChanged: null` ama value 0 gösterir
* **Risk/Maliyet:** `_muteAll true` iken music/sfx slider 0'da frozen — kullanıcı unmute edince önceki volume kaybolur (state korunuyor ama slider visual 0). UX: unmute → ani eski seviyeye sıçrama.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — display value vs stored value ayrımı
value: _muteAll ? 0.0 : _musicVolume,
onChanged: _muteAll ? null : (v) => setState(() => _musicVolume = v),
// unmute: restore previous volumes
```

* **Hatalı Kod Yapısı:** Settings body `Container` gradient — `GameScreenBackground` reuse edilmemiş
* **Risk/Maliyet:** Character/inventory `GameScreenBackground` veya shared gradient; settings one-off — drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
body: GameScreenBackground(
  child: ListView(...),
),
```

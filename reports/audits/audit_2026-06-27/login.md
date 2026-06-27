---
# 📦 DOSYA/SAYFA ANALİZİ: LoginScreen (`lib/screens/auth/login_screen.dart`)

**Rota:** `/login`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/login.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Metin içerikleri — Türkçe karakter eksikliği (i18n)
* **Hata Tanımı:** UI'da ASCII Türkçe kullanılıyor: "Hesabina", "giris", "Sifre", "Giris Yap", "Giris yapiliyor", "Hesabin yok mu? Kayit Ol". Doğrusu: "Hesabına", "giriş", "Şifre", "Giriş Yap", "Giriş yapılıyor...", "Hesabın yok mu? Kayıt Ol". Urbanist font Türkçe glyph destekliyor; sorun kaynak string'lerde.
* **Kullanıcıya Etkisi:** Profesyonellik algısı düşer; yerel kullanıcıda "beta/placeholder" hissi. App Store inceleme notlarında dil kalitesi sorunu çıkabilir.
* **Kesin Çözüm ve Öneri:** Tüm auth string'lerini `lib/l10n/` veya `AppStrings` sabitlerine taşı; `flutter gen-l10n` ile TR locale zorunlu kıl.

* **Sorunlu Bileşen/Yer:** Alt link — "Hesabin yok mu? Kayit Ol" (`TextButton`)
* **Hata Tanımı:** `textButtonTheme.foregroundColor = AppColors.accentBlue` (#5B8FFF) kart arka planı `AppColors.bgCard` (#1A2238) üzerinde. 14px Urbanist w600 ile kontrast oranı ~4.2:1 — WCAG AA normal metin eşiği 4.5:1'in altında. Ekran görüntüsünde link, başlık beyazına (#F0F4FF) kıyasla belirgin soluk.
* **Kullanıcıya Etkisi:** Düşük görüşlü kullanıcı kayıt yolunu fark etmeyebilir; dönüşüm kaybı.
* **Kesin Çözüm ve Öneri:** Link rengini `AppColors.accentBlue` → `Color(0xFF7AA8FF)` veya `goldLight` tonuna çek; minimum 4.5:1 doğrula. Alternatif: altın underline + `bodyBold` weight.

* **Sorunlu Bileşen/Yer:** Yükleme durumu — `FilledButton.icon` içi spinner
* **Hata Tanımı:** `isLoading` true iken buton içinde `CircularProgressIndicator(strokeWidth: 2)` — `valueColor` belirtilmemiş. Tema `progressIndicatorTheme.color = accentBlue` (#5B8FFF); altın buton (#F5C842) üzerinde mavi spinner + siyah metin "Giris yapiliyor..." — renk uyumsuzluğu ve düşük kontrast (mavi/altın ~2.8:1).
* **Kullanıcıya Etkisi:** Yükleme feedback'i zayıf görünür; buton "bozuk" algısı.
* **Kesin Çözüm ve Öneri:** `CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDeep)` veya `onPrimary` token kullan; ikon yerine sadece spinner + metin hizası `MainAxisAlignment.center`.

* **Sorunlu Bileşen/Yer:** Dikey spacing — 8pt grid ihlali
* **Hata Tanımı:** Kart padding `EdgeInsets.all(20)` (`AppSpacing.lg`) kullanılıyor ancak iç boşluklar karışık: başlık-altı `6px` (grid dışı), alanlar arası `12px` (`AppSpacing.md`), CTA öncesi `18px` (grid dışı), footer `8px` (`AppSpacing.sm`). Ekran görüntüsünde şifre alanı ile altın buton arası (~18px) e-posta-şifre arasından (~12px) geniş — görsel ritim bozuk.
* **Kullanıcıya Etkisi:** Form "amatör" durur; göz FORM→CTA grubunu birincil aksiyon olarak algılamakta gecikir.
* **Kesin Çözüm ve Öneri:** Tüm gap'leri `AppSpacing` token'larına sabitle: `sm(8)` label gap, `base(16)` field gap, `lg(20)` CTA öncesi.

* **Sorunlu Bileşen/Yer:** Auth akış tutarsızlığı — Login vs Register görsel hiyerarşi
* **Hata Tanımı:** Login: gradient arka plan + `Card` (16px radius, `borderDefault` stroke) + ikonlu input + tam genişlik CTA. Register: düz scaffold, kart yok, ikon yok, dar buton. Aynı auth funnel'de iki farklı ürün hissi.
* **Kullanıcıya Etkisi:** Kayıt ekranına geçen kullanıcı "yanlış uygulama" veya eksik sayfa düşüncesi yaşar.
* **Kesin Çözüm ve Öneri:** `AuthFormShell` shared widget: gradient + Card + `maxWidth: 460` + `SafeArea` + `SingleChildScrollView`.

* **Sorunlu Bileşen/Yer:** `TextFormField` — autofill / klavye tipi eksikleri
* **Hata Tanımı:** E-posta alanında `autofillHints: [AutofillHints.email]` yok; şifrede `AutofillHints.password` yok. iOS Password AutoFill ve Android Credential Manager tetiklenmez.
* **Kullanıcıya Etkisi:** Her girişte manuel yazım; churn artışı.
* **Kesin Çözüm ve Öneri:** `autofillHints`, `autocorrect: false`, şifre alanında `enableSuggestions: false` ekle.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `ref.listen` + `ref.watch` aynı `build()` — çift subscription pattern
* **Risk/Maliyet:** Her auth state değişiminde hem widget rebuild hem listener callback; `authenticated` durumunda `context.go` build sırasında çalışır → "setState during build" benzeri navigator uyarıları (debug'da).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — login_screen.dart:43-58
Widget build(BuildContext context) {
  final AuthState authState = ref.watch(authProvider);
  ref.listen<AuthState>(authProvider, (prev, next) { ... });
  // ...
}
```

```dart
// OLMASI GEREKEN
late final ProviderSubscription<AuthState> _authSub;

@override
void initState() {
  super.initState();
  _authSub = ref.listenManual(authProvider, _handleAuthSideEffects);
}

@override
void dispose() {
  _authSub.close();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  final bool isLoading = ref.watch(authProvider.select((s) => s.status == AuthStatus.loading));
  return _LoginView(isLoading: isLoading, onSubmit: _submitLogin);
}
```

* **Hatalı Kod Yapısı:** `Theme.of(context)` tekrarlı çağrılar — gereksiz ancestor lookup
* **Risk/Maliyet:** Gradient `build` içinde 2×, text style 3× `Theme.of(context)`; login tek ekran ama pattern kopyalanırsa jank.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final textTheme = theme.textTheme;
  // tek lookup, aşağıda colorScheme.surface / textTheme.headlineSmall
}
```

* **Hatalı Kod Yapısı:** E-posta validasyonu yetersiz — `contains('@')` only
* **Risk/Maliyet:** `"a@"`, `"@@"` geçerli sayılır; gereksiz API round-trip ve kullanıcıya geç SnackBar hatası.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — satır 108-113
if (!email.contains('@')) return 'Gecerli bir e-posta girin.';

// OLMASI GEREKEN
final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
if (!emailRegex.hasMatch(email)) return 'Geçerli bir e-posta girin.';
```

* **Hatalı Kod Yapısı:** `deviceId: 'flutter-mobile'` hardcoded — satır 38
* **Risk/Maliyet:** Çoklu cihaz oturum yönetimi / fraud analitiği için anlamsız sabit; web/desktop build'lerde de aynı ID.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
import 'package:device_info_plus/device_info_plus.dart';
// veya uuid persisted in secure storage
deviceId: await DeviceIdentityService.currentId(),
```

* **Hatalı Kod Yapısı:** `InputDecoration` kısmen const — suffix `IconButton` her build'de yeni instance
* **Risk/Maliyet:** Şifre toggle `setState` ile tüm form subtree rebuild; büyük sorun değil ama `IconButton` `tooltip`/`semanticLabel` eksik (erişilebilirlik).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
suffixIcon: IconButton(
  tooltip: _obscurePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
),
```

* **Hatalı Kod Yapısı:** Navigasyon tutarsızlığı — `context.push(register)` vs register'da `context.go(login)`
* **Risk/Maliyet:** Login→Register `push` (geri swipe mümkün); Register→Login `go` (stack sıfırlanır). Android predictive back davranışı tutarsız.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Login — tutarlı pop veya go
onPressed: () => context.push(AppRoutes.register), // OK if register uses context.pop()
// Register'da: context.pop() yerine context.go — düzeltilmeli
```

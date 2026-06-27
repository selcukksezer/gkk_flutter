---
# 📦 DOSYA/SAYFA ANALİZİ: RegisterScreen (`lib/screens/auth/register_screen.dart`)

**Rota:** `/register`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/register.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Tüm sayfa — Login ile görsel sistem kopukluğu
* **Hata Tanımı:** Register ekranı Login'in `Card` + gradient + `SafeArea` + `ConstrainedBox(maxWidth: 460)` kabuğunu kullanmıyor. Düz `scaffoldBackgroundColor` (#0F1523) üzerinde ortalanmış `Column`; AppBar yalnızca "Kayit" yazıyor (sol üst, ~17px h3). Login'deki "Krallık Kapısı" marka başlığı ve açıklama metni yok.
* **Kullanıcıya Etkisi:** Kayıt funnel'inde güven kaybı; kullanıcı login kartından "daha az bitmiş" bir sayfaya düşer.
* **Kesin Çözüm ve Öneri:** Login ile aynı `AuthFormShell` wrapper'ı paylaş; başlık "Krallık Kapısı'na Katıl" + alt metin ekle.

* **Sorunlu Bileşen/Yer:** Türkçe karakter eksikliği — tüm label ve CTA'lar
* **Hata Tanımı:** "Kayit", "Kullanici Adi", "Sifre", "Kayit Ol", "Kayit yapiliyor", "Giris Ekranina Don" — doğru: "Kayıt", "Kullanıcı Adı", "Şifre", "Kayıt Ol", "Kayıt yapılıyor...", "Giriş Ekranına Dön". Ekran görüntüsünde AppBar ve placeholder'lar ASCII.
* **Kullanıcıya Etkisi:** Login ile aynı i18n borcu; marka tutarsızlığı iki katına çıkar.
* **Kesin Çözüm ve Öneri:** Merkezi `AppStrings.auth.*` kullan; Register özel metinleri l10n ARB dosyasına.

* **Sorunlu Bileşen/Yer:** Şifre alanı — görünürlük toggle yok
* **Hata Tanımı:** `obscureText: true` sabit; `suffixIcon` yok. Login'de `IconButton` + toggle var; Register'da kullanıcı şifresini doğrulayamaz.
* **Kullanıcıya Etkisi:** Kayıt hataları (yanlış şifre girişi) artar; şifre sıfırlama yükü.
* **Kesin Çözüm ve Öneri:** Login'deki `_obscurePassword` state pattern'ini birebir kopyala veya shared `PasswordField` widget.

* **Sorunlu Bileşen/Yer:** Form validasyonu — istemci tarafı kontrol yok
* **Hata Tanımı:** `_submitRegister()` doğrudan API çağırıyor; boş e-posta/kullanıcı adı/şifre sunucuya gider. `TextField` kullanılıyor (`TextFormField` + `Form` yok); inline hata mesajı alanı yok.
* **Kullanıcıya Etkisi:** Kullanıcı boş forma basınca belirsiz SnackBar veya ağ gecikmesi; form UX guideline (`error-placement`, `inline-validation`) ihlali.
* **Kesin Çözüm ve Öneri:** Login ile aynı `Form` + validator'lar: e-posta regex, kullanıcı adı min 3 / max 20, şifre min 6.

* **Sorunlu Bileşen/Yer:** Layout — klavye açılınca overflow riski
* **Hata Tanımı:** `Center` → `Padding(24)` → `Column(mainAxisSize: min)` — `SingleChildScrollView` yok. 4 input (~52dp each) + gaps + buton ≈ 320dp form; iPhone SE + klavye (~290dp) = **RenderFlex overflow** veya input'lar klavye altında kalır.
* **Kullanıcıya Etkisi:** Küçük cihazlarda kayıt tamamlanamaz; sarı-siyah overflow şeridi (debug) veya gizli alanlar.
* **Kesin Çözüm ve Öneri:** Login pattern: `SafeArea` + `SingleChildScrollView` + `resizeToAvoidBottomInset: true` (Scaffold default).

* **Sorunlu Bileşen/Yer:** Primary CTA — tam genişlik değil
* **Hata Tanımı:** `FilledButton` intrinsic width; Login'de `SizedBox(width: double.infinity)`. Ekran görüntüsünde sarı buton ~120dp genişlikte ortada; touch target yüksekliği ~44dp (padding md×2 + 14px text) ancak genişlik dar — görsel hiyerarşi zayıf.
* **Kullanıcıya Etkisi:** Birincil aksiyon login'e göre daha az belirgin; tap alanı yatayda küçük (thumb zone dışı).
* **Kesin Çözüm ve Öneri:** `SizedBox(width: double.infinity, child: FilledButton(...))` veya `minimumSize: Size.fromHeight(48)`.

* **Sorunlu Bileşen/Yer:** Input alanları — leading icon yok, helper text yok
* **Hata Tanımı:** Login'de `prefixIcon: Icon(Icons.alternate_email_rounded)` vb. var; Register'da yalnızca label. `inputDecorationTheme.contentPadding` vertical `AppSpacing.md` (12px) — efektif field yüksekliği ~48dp; border `AppColors.borderDefault` (#253154) on `bgCard` (#1A2238) kontrastı düşük (~1.8:1), ekran görüntüsünde alan sınırları zor seçiliyor.
* **Kullanıcıya Etkisi:** Form tarama hızı düşer; düşük ışıkta alan sınırları kaybolur.
* **Kesin Çözüm ve Öneri:** Prefix icon'lar ekle; focused border `accentBlue` 1.5px zaten temada — focus testi yap.

* **Sorunlu Bileşen/Yer:** Yasal / güven metni eksik
* **Hata Tanımı:** Kayıt CTA altında KVKK / kullanım şartları onayı yok; referral opsiyonel alan açıklaması yok.
* **Kullanıcıya Etkisi:** Mağaza uyumluluk riski; kullanıcı referral kodunun ne işe yaradığını bilmez.
* **Kesin Çözüm ve Öneri:** CTA üstüne `Text.rich` ile şartlar linki; referral için `helperText: 'Davet kodun varsa gir'`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `TextField` × 4 — `Form`/`TextFormField` yok
* **Risk/Maliyet:** Validasyon logic'i API katmanına kaymış; her submit gereksiz network; hata mesajı field yakınında gösterilemiyor (`AppMessenger.showError` global).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — register_screen.dart:66-100
child: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    TextField(controller: _emailController, ...),
    // ...
    FilledButton(onPressed: isLoading ? null : _submitRegister, ...),
  ],
),
```

```dart
// OLMASI GEREKEN — Login ile hizalı
final _formKey = GlobalKey<FormState>();

body: SafeArea(
  child: SingleChildScrollView(
    padding: AppSpacing.pagePadding,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Kayıt', style: AppTextStyles.h2),
                const SizedBox(height: AppSpacing.base),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: _validateEmail,
                ),
                // ... diğer alanlar
                FilledButton(
                  onPressed: isLoading ? null : () {
                    if (_formKey.currentState?.validate() ?? false) {
                      _submitRegister();
                    }
                  },
                  child: Text(isLoading ? 'Kayıt yapılıyor...' : 'Kayıt Ol'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
),
```

* **Hatalı Kod Yapısı:** `ref.listen` build içinde — Login/Splash ile aynı anti-pattern
* **Risk/Maliyet:** Kayıt başarılı → `context.go(home)` build fazında; Register dispose olmadan Login widget'ı stack'te kalabilir (`push` ile gelindiyse).
* **Mevcut Durum vs Olması Gereken (Refaktör):** Listener'ı `initState`/`listenManual`'a taşı; navigation side-effect'i build'den çıkar.

* **Hatalı Kod Yapısı:** Padding `24` vs Login `20` — `AppSpacing` token ihlali
* **Risk/Maliyet:** Design system 8pt grid: `AppSpacing.xl` (24) vs `AppSpacing.lg` (20) auth ekranları arasında rastgele.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
padding: const EdgeInsets.all(24),

// OLMASI GEREKEN
padding: AppSpacing.pagePadding, // EdgeInsets.all(16) veya auth shell'de lg(20)
```

* **Hatalı Kod Yapısı:** `AppBar` + `Center` çift dikey hizalama — üst dead space
* **Risk/Maliyet:** Ekran görüntüsünde form ~%55 viewport'ta; üst %25 boş (AppBar altı). `Center` widget formu dikey ortalar → klavye kapalıyken bile form aşağı itilir.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — üst hizalı scroll
child: Align(
  alignment: Alignment.topCenter,
  child: SingleChildScrollView(...),
),
// veya AppBar'ı kaldırıp Login gibi in-card başlık
```

* **Hatalı Kod Yapısı:** `_submitRegister` — trim ve boş kontrol eksik
* **Risk/Maliyet:** `username` boşluk-only (`"   "`) API'ye gidebilir; `referralCode` trim ediliyor ama email/username için sadece `.trim()` submit anında, ara boşluklar field'da kalır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
Future<void> _submitRegister() async {
  final form = _formKey.currentState;
  if (form == null || !form.validate()) return;

  await ref.read(authProvider.notifier).register(
    email: _emailController.text.trim(),
    username: _usernameController.text.trim(),
    password: _passwordController.text,
    deviceId: await DeviceIdentityService.currentId(),
    referralCode: _referralController.text.trim().isEmpty
        ? null
        : _referralController.text.trim(),
  );
}
```

* **Hatalı Kod Yapısı:** `const` kullanımı minimal — tüm widget ağacı non-const
* **Risk/Maliyet:** `isLoading` her değişimde 4 `TextField` + 2 buton rebuild; `controller` olduğu için kaçınılmaz ama static `SizedBox(height: 12)` `const` yapılabilir (`const SizedBox(height: AppSpacing.md)`).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
const SizedBox(height: AppSpacing.md), // 12 — const gap'ler
```

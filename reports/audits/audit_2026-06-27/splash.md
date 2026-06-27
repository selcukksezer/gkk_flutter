---
# 📦 DOSYA/SAYFA ANALİZİ: SplashScreen (`lib/screens/auth/splash_screen.dart`)

**Rota:** `/`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/splash.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`

> **QA notu:** `splash.png` ve `login.png` dosyaları birebir aynı boyutta (388.424 byte). Otomasyon, `loadSession()` tamamlanıp `context.go('/login')` tetiklenene kadar splash frame'ini yakalayamamış; ekran görüntüsü fiilen Login ekranını gösteriyor. Splash'in gerçek UI'si kodda tanımlı minimal spinner'dır.

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Tam ekran `Scaffold` — marka/oyun kimliği yok
* **Hata Tanımı:** Splash yalnızca ortada varsayılan `CircularProgressIndicator` gösteriyor; GKK logosu, oyun adı, tagline veya `AppColors.gold` / `AppColors.bgBase` paletine uygun branded arka plan yok. Oyunun geri kalanı (Login kartı, altın CTA, Urbanist tipografi) ile görsel dil tamamen kopuk.
* **Kullanıcıya Etkisi:** İlk izlenim "boş yükleme ekranı"; marka güveni ve premium oyun hissi oluşmuyor. Splash anında login'e geçince kullanıcı hiçbir zaman markayı görmez.
* **Kesin Çözüm ve Öneri:** `Stack` içinde `AppColors.bgBase` gradient + merkezde logo asset (`assets/...`) + `AppTextStyles.h2` ile "Krallık Kapısı" + altta ince `LinearProgressIndicator` (tema: `progressIndicatorTheme.color = AppColors.accentBlue`). Minimum 800ms branded hold süresi ekle.

* **Sorunlu Bileşen/Yer:** `CircularProgressIndicator` — tema token uyumsuzluğu
* **Hata Tanımı:** Spinner `progressIndicatorTheme` ile `AppColors.accentBlue` (#5B8FFF) kullanmalı; ancak `Scaffold` arka planı `scaffoldBackgroundColor` (#0F1523) üzerinde 40×40dp varsayılan spinner, etrafında 200+dp boş alan bırakıyor — görsel ağırlık merkezde ~2% alan kaplıyor, geri kalan %98 dead space.
* **Kullanıcıya Etkisi:** "Uygulama dondu mu?" belirsizliği; yükleme geri bildirimi zayıf, özellikle yavaş ağda.
* **Kesin Çözüm ve Öneri:** Spinner boyutunu 32dp'ye düşürme yerine branded skeleton kullan; `Semantics(label: 'Oturum kontrol ediliyor', liveRegion: true)` ekle.

* **Sorunlu Bileşen/Yer:** Ekran görüntüsü otomasyonu — splash frame yakalanamıyor
* **Hata Tanımı:** QA pipeline `route: "/"` için screenshot alırken `deferProviderUpdate` → `loadSession()` → `unauthenticated` → `go('/login')` zinciri tek frame içinde tamamlanıyor; manifest'te splash ve login PNG'leri özdeş.
* **Kullanıcıya Etkisi:** Doğrudan kullanıcı etkisi yok; audit/regresyon sürecinde splash UI hiç doğrulanmıyor.
* **Kesin Çözüm ve Öneri:** Smoke harness'e `QA_HOLD_SPLASH_MS` flag'i veya `integration_test` binding ile auth provider mock'u (`AuthStatus.initial` dondurma) ekle; screenshot öncesi minimum 1 frame bekle.

* **Sorunlu Bileşen/Yer:** Erişilebilirlik — yükleme durumu duyurulmuyor
* **Hata Tanımı:** `CircularProgressIndicator` etrafında `Semantics` / `ExcludeSemantics` yok; VoiceOver/TalkBack yalnızca "ilerleme göstergesi" der, ne yüklendiği belirsiz.
* **Kullanıcıya Etkisi:** Görme engelli kullanıcı splash'te ne beklediğini anlayamaz.
* **Kesin Çözüm ve Öneri:** `Semantics(label: 'Krallık Kapısı açılıyor, lütfen bekleyin', child: ...)` ve `announceForAccessibility` ile durum geçişi.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `ref.listen` doğrudan `build()` içinde — her rebuild'de yeni listener kaydı riski
* **Risk/Maliyet:** Riverpod `ref.listen` build içinde çalışır ancak auth state her `loading` → `unauthenticated` geçişinde listener tekrar tetiklenir; `mounted` kontrolü var ama navigasyon yan etkisi build fazında kalır. Hot reload / hızlı state flip'te çift `context.go` ve gereksiz route stack manipülasyonu.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — splash_screen.dart:26-38
@override
Widget build(BuildContext context) {
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (!mounted) return;
    if (next.status == AuthStatus.authenticated) {
      context.go(AppRoutes.home);
      return;
    }
    if (next.status == AuthStatus.unauthenticated || next.status == AuthStatus.error) {
      context.go(AppRoutes.login);
    }
  });
  return const Scaffold(...);
}
```

```dart
// OLMASI GEREKEN — listener initState/post-frame, build saf
@override
void initState() {
  super.initState();
  deferProviderUpdate(() => ref.read(authProvider.notifier).loadSession());
  ref.listenManual(authProvider, _onAuthChanged); // veya listen in initState via WidgetsBinding
}

void _onAuthChanged(AuthState? prev, AuthState next) {
  if (!mounted) return;
  switch (next.status) {
    case AuthStatus.authenticated:
      context.go(AppRoutes.home);
    case AuthStatus.unauthenticated:
    case AuthStatus.error:
      context.go(AppRoutes.login);
    default:
      break;
  }
}

@override
Widget build(BuildContext context) {
  return const Scaffold(
    backgroundColor: AppColors.bgBase,
    body: Center(child: _SplashBrandedLoader()),
  );
}
```

* **Hatalı Kod Yapısı:** `const Scaffold` + non-const `CircularProgressIndicator` — kısmi const ihlali
* **Risk/Maliyet:** Scaffold const ama body subtree her build'de yeniden oluşturulur; splash basit olsa da `ref.listen` yüzünden build sayısı artar.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
return const Scaffold(
  body: Center(child: CircularProgressIndicator()),
); // CircularProgressIndicator const DEĞİL — const Scaffold geçersiz optimizasyon

// OLMASI GEREKEN
return Scaffold(
  backgroundColor: AppColors.bgBase,
  body: const Center(
    child: SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator(strokeWidth: 3),
    ),
  ),
);
```

* **Hatalı Kod Yapısı:** `SafeArea` eksik — sistem çubuğu ile spinner çakışma riski
* **Risk/Maliyet:** Notch/Dynamic Island cihazlarda spinner fiziksel olarak merkezde kalsa da gelecekte üst metin eklenirse status bar altına girer.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
body: SafeArea(
  child: Center(child: _SplashContent()),
),
```

* **Hatalı Kod Yapısı:** Hata durumunda login'e sessiz yönlendirme — `AuthStatus.error` mesajı kayboluyor
* **Risk/Maliyet:** `auth_provider.dart:76-78` session load exception'da `errorMessage` set ediliyor; splash doğrudan `/login`'e atıyor, hata snackbar'ı gösterilmiyor (login ekranı error state'i dinlemiyor çünkü status `unauthenticated` değil `error`).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — error ayrı ele alınmalı
if (next.status == AuthStatus.error) {
  context.go('${AppRoutes.login}?error=${Uri.encodeComponent(next.errorMessage ?? '')}');
  // veya login'de ref.watch ile errorMessage göster
}
```

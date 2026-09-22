# GKK Flutter — App Store + Google Play Release Readiness Audit

| Alan | Değer |
|------|--------|
| **Tarih** | 2026-07-31 |
| **Workspace** | `/Users/selcuk/Documents/gkk-web/gkk_flutter` |
| **Flutter** | 3.41.8 (stable) / Dart 3.11.5 |
| **pubspec version** | `1.0.0+1` |
| **Kapsam** | Kod, platform config, legal, assets, CI, test kanıtı (kaynak değiştirilmedi) |
| **Yöntem** | Statik repo taraması + config/okuma + grep (TODO/debug/secrets/IAP/ads/permissions) |

---

## 1. Executive summary

### Verdict: **NO-GO** (submit etme)

**Genel hazırlık: ~38%**

Oyun özelliği ve backend tarafı (Supabase, tutorial, hesap silme RPC, uygulama içi legal metinler, smoke/integration test suite) görece olgun. Buna karşılık **mağaza paketleme / imzalama / listing / monetization / branding** katmanı hâlâ Flutter şablon + stub seviyesinde. Bu haliyle hem App Store hem Play Console’a yükleme **teknik olarak riskli**, review’da **red / incomplete binary** olasılığı yüksek.

| Boyut | Skor (kabaca) | Not |
|-------|---------------|-----|
| Store listing / legal URL | 25% | In-app legal ✅; public Privacy Policy URL ❌ |
| Build & signing | 15% | Release = debug signing; AAB/CI/exportOptions yok |
| Product / monetization | 45% | Oynanabilir; IAP stub + mock ads |
| Privacy / permissions | 40% | Exact alarm + INTERNET gap + Privacy Manifest app-level yok |
| Branding / assets | 30% | Android default icon; isim tutarsız |
| Backend / secrets hygiene | 55% | Anon key client’ta (beklenen); QA env gitignore eksik |
| Testing evidence | 70% | Çok smoke/integration; store CI yok; golden yok |
| Rejection-risk polish | 40% | Broken gem shop, bahis/loot disclosure Console’da doldurulmalı |

---

## 2. Critical blockers (submit öncesi zorunlu)

Bunlar düzelmeden **binary yükleme veya review geçişi** beklenmemeli.

### C1. Android release imzası hâlâ **debug keystore**

**Kanıt:** `android/app/build.gradle.kts` L38–43:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

- `key.properties` / `.jks` / `.keystore` **yok**.
- Play Console, debug-signed AAB kabul etmez (veya production track’e çıkmaz).
- **Aksiyon:** Upload key + Play App Signing; `signingConfigs.release` + `key.properties` (gitignore); `flutter build appbundle --release`.

### C2. `INTERNET` izni **main** manifest’te yok → release ağ kırığı riski

**Kanıt:**

| Manifest | INTERNET |
|----------|----------|
| `android/app/src/main/AndroidManifest.xml` | ❌ yok |
| `android/app/src/debug/AndroidManifest.xml` | ✅ var |
| `android/app/src/profile/AndroidManifest.xml` | ✅ var |

Supabase’e bağlı online oyun. Release/APK/AAB `main` merge kullanır → **release build’te network permission eksik kalabilir**. Debug’ta “çalışıyor” yanıltır.

**Aksiyon:** `main/AndroidManifest.xml` içine `<uses-permission android:name="android.permission.INTERNET"/>` (+ genelde `ACCESS_NETWORK_STATE`).

### C3. Mağaza listing için **public Privacy Policy URL** yok

- Gizlilik metni uygulama içinde var: `lib/core/legal/legal_document_content.dart` (`_privacyTr`), register consent, Settings → Legal.
- Repo’da **https://…** privacy/terms/marketing/support URL **yok** (yalnız `support@gkk.game` e-posta).
- **App Store Connect** ve **Play Console Data safety / Privacy policy** alanı **erişilebilir URL** ister; in-app markdown yeterli değil.

**Aksiyon:** `https://…` üzerinde Privacy + Terms yayınla; Console’a yapıştır; Settings’ten de link aç (opsiyonel ama iyi).

### C4. Uygulama görünen adı hâlâ şablon / tutarsız

| Kaynak | Değer |
|--------|--------|
| Android `android:label` | `gkk_flutter` |
| iOS `CFBundleDisplayName` | `Gkk Flutter` |
| iOS `CFBundleName` | `GkkFlutter` |
| `AppConstants.appName` | `GKK Mobile` |
| Legal metin | Gölge Krallığı Klansı / GKK |

Reviewer + kullanıcı home screen’de **gkk_flutter** görür → marka/red riski.

**Aksiyon:** Tek nihai display name (ör. `Gölge Krallığı` / `GKK`) → Android label + iOS display name + store listing senkron.

### C5. Android launcher icon = Flutter default (küçük/şablon PNG)

**Kanıt:** `android/app/src/main/res/mipmap-*/ic_launcher.png` dosya boyutları ~442–1443 byte; mdpi 48×48 colormap. `mipmap-anydpi-v26` **adaptive icon yok**.

iOS tarafında 1024 set var (`ios/Runner/Assets.xcassets/AppIcon.appiconset/`, alpha yok ✅) — Android geride.

**Aksiyon:** Marka adaptive icon + tüm density; Play feature graphic + store icon 512.

### C6. IAP UI canlı fiyat gösteriyor ama **StoreKit / Play Billing yok**

**Kanıt:**

- `pubspec.yaml`: `in_app_purchase` / `purchases_flutter` **yok**.
- `lib/screens/shop/shop_screen.dart` `_buyGemPackage` → snackbar: *"Elmas satın alma yakında (IAP). Şimdilik kullanılamıyor."*
- Katalog + sahte fiyatlar: `lib/core/constants/economy_constants.dart` (`gem_starter` … `gem_legend`, `storeProductId: com.gkk.gems.*`, ₺ / $ fiyatları).

Reviewer “Elmas” sekmesine basar → **kırık satın alma**. Guideline 2.1 (App Completeness) / Play broken functionality.

**Aksiyon (ikiden biri):**

1. IAP’yi tamamen gizle / “yakında” sekmesini kaldır **veya**
2. Gerçek Billing + server receipt validation + **Restore purchases** (Apple zorunlu) ekle.

### C7. Reklam SDK yok; mock ad sözleşmesi release’te fail-closed

**Kanıt:** `lib/core/services/ad_service.dart` — yalnız `MockAdService`; `google_mobile_ads` yok. Release’te mock reward kapalı (iyi) ama UI “reklam izle → ödül” akışları **kalıcı fail** eder.

Legal metin IAP + reklam izlemeyi anlatıyor (`legal_document_content.dart`) → questionnaire ile çelişki riski.

**Aksiyon:** Rewarded ad feature’ı gizle **veya** AdMob + ATT (iOS) + Data safety “Ads” beyanı.

### C8. iOS / Android paket kimliği + imza / export hazırlığı eksik

| Platform | Identifier | Not |
|----------|------------|-----|
| Android `applicationId` | `com.gkk.gkk_flutter` | TODO yorumu hâlâ duruyor (`build.gradle.kts` L23) |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.gkk.gkkFlutter` | Android ile **farklı** (store’lar ayrı OK; marka karışıklığı) |
| iOS entitlements | **Yok** | Associated Domains / Push yok |
| `exportOptions.plist` | **Yok** | Archive/CI export tanımsız |
| `PrivacyInfo.xcprivacy` (app source) | **Yok** | Yalnız plugin bundle’larında (build çıktısı) |
| CI store pipeline | **Yok** | `.github/` yok; Codemagic/Fastlane yok |

---

## 3. High priority (red / crash / compliance olasılığı yüksek)

### H1. `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` + `exactAllowWhileIdle`

**Kanıt:** `android/app/src/main/AndroidManifest.xml` L1–5; `lib/core/services/local_notification_service.dart` `AndroidScheduleMode.exactAllowWhileIdle`.

Play, exact alarm’ı takvim/alarm uygulaması dışı için sıkı sorar; `USE_EXACT_ALARM` özellikle hassas. Oyun reminder’ı için **inexact** veya kullanıcıdan `SCHEDULE_EXACT_ALARM` izni + Console beyanı tercih edilmeli.

### H2. Release’e sızan debug logger (mutlak path + `print`)

**Kanıt:** `lib/core/debug/staff_hub_debug_log.dart`

- Hardcoded path: `/Users/selcuk/Documents/gkk-web/gkk_flutter/.cursor/debug-a3bc69.log`
- `kDebugMode` yok → `print('[DEBUG-a3bc69]...')` release’te de çalışır
- Staff hub / liveops / player sheet çağırıyor

PII / staff aksiyon log’u logcat’e sızabilir. **Aksiyon:** `assert`/`kDebugMode` gate veya tamamen kaldır.

### H3. Simulated gambling / loot box — Console age rating + disclosure

Özellikler (kodda canlı):

- At yarışı bahis (altın **ve elmas**): `lib/screens/horse_race/`
- Loot box + drop oranı UI: `lib/screens/loot/loot_chest_widgets.dart` (`DROP ORANI`, `%…`)
- Enhancement RNG, çark asset’leri (`assets/wheel/`)

**İyi:** Loot drop rate oyuncuya gösteriliyor.  
**Eksik:** Store age questionnaire’da *Simulated Gambling*, *Loot Boxes*, violence (PvP/zindan), user-generated chat beyanı; gerekirse odds URL / in-app odds linki listing’de.

Legal metinde “şans oyunu / simulated gambling” ayrı açık madde **zayıf** — eklenmesi önerilir.

### H4. Hesap silme — UI + RPC var; mağaza meta + web yolu kontrol

**Kanıt (olumlu):**

- UI: `lib/screens/settings/settings_screen.dart` `_deleteAccount` → RPC `delete_account`
- SQL: `supabase/migrations/20260729_010000_delete_account.sql` (username confirm, staff blok, `auth.users` delete)

**Eksik:** Apple, hesaplı app’te silmeyi **uygulama içinde** + genelde **web’den de** talep edebiliyor; Play de account deletion URL isteyebilir. Public web deletion / support sayfası yok.

### H5. Restore purchases yok

IAP açılacaksa Apple 3.1.1 → Restore zorunlu. Şu an IAP stub → C6 ile birlikte ele al.

### H6. EN localization fiilen TR kopyası

- `app_tr.arb` / `app_en.arb`: ~888 key; EN değerlerinin **~398’i Türkçe karakter** içeriyor.
- Key drift: TR-only `tut_onboarding_welcome_title`; EN-only `detail`.
- Store’da EN locale açılırsa yarım çeviri → polish/rejection değil ama kötü ilk izlenim.

### H7. Supabase anon key + proje URL hardcoded (tek ortam)

**Kanıt:** `lib/core/constants/app_constants.dart` (+ `scripts/create_qa_integration_accounts.sh` aynı key).

- Anon key client’ta normal; **RLS + Edge security** production’da zorunlu doğrulanmalı.
- Staging/prod flavor / `--dart-define` yok → QA seed / wipe script’leri yanlışlıkla prod’a işaret ederse felaket (`reports/*/WIPE_CHECKLIST.md` uyarıyor).
- TODO hâlâ: *"Replace with real values from secure config."*

### H8. QA credential dosyası gitignore eksik

- `.gitignore` yalnız `.env.qa.local`
- `.env.qa.accounts` **gitignore’da değil** (şu an untracked; commit riski yüksek — test şifreleri)

### H9. Bildirim / deep link yarım

- Local notifications init var; tap handler boş (“ileride deep-link”).
- `app_links` plugin iOS build’de görünüyor; **Associated Domains / intent-filter app links** repo’da yok.
- iOS `Info.plist`: notification usage string yok (local notif için çoğu zaman OK); **remote push** yok.

### H10. Analytics / crash reporting yok

`RetentionAnalytics` = `debugPrint` stub (`lib/core/services/retention_analytics.dart`). Crashlytics/Sentry yok → production crash körlüğü.

### H11. ABI filtresi dar

`build.gradle.kts`: yalnız `arm64-v8a` + `x86_64`. `armeabi-v7a` yok → bazı 32-bit cihazlar dışarıda. Bilinçliyse OK; değilse Play cihaz kapsamı düşer.

---

## 4. Medium (should fix)

| ID | Bulgu | Kanıt |
|----|--------|--------|
| M1 | `pubspec.yaml` description: *"A new Flutter project."* | `pubspec.yaml` L2 |
| M2 | README hâlâ Flutter starter + arm64 debug odaklı; store checklist yok | `README.md` |
| M3 | Version `1.0.0+1` — ilk submit OK; iOS `MARKETING_VERSION = 1.0` pbxproj ile hizalı tutulmalı | `pubspec.yaml`, `project.pbxproj` |
| M4 | minSdk 24 / targetSdk 36 / compileSdk 36 (Flutter default) — OK; bilinçli pin yok | FlutterExtension |
| M5 | iOS deployment 13.0 — OK; Podfile `platform :ios` yorum satırı | `Podfile`, `project.pbxproj` |
| M6 | R8/ProGuard/minify **yok**; obfuscation CI yok | `build.gradle.kts` |
| M7 | Orientation: iOS phone portrait+landscape; tablet tüm yönler — oyun UX kararı netleştirilmeli | `Info.plist` |
| M8 | Splash: beyaz LaunchScreen + küçük LaunchImage; markalı splash zayıf | `LaunchScreen.storyboard` |
| M9 | Staff hub release’te route guard’lı ✅ ama debug log H2 | `staff_route_guard.dart` |
| M10 | Mock ads / QA flags `--dart-define` ile — release’te default kapalı ✅; store script’lerinde `QA_ALLOW_MOCK_ADS=1` yalnız test | `lib/qa/qa_flags.dart`, `scripts/*` |
| M11 | Audit backlog: `reports/audits/audit_2026-06-27/TODO.md` — 258/455; P0 çoğunluk kapanmış görünüyor ama ürün polish bitmemiş | audit TODO |
| M12 | Ekonomi/tasarım açıklar tarihsel raporlarda (enerji regen vb.) — store red değil, soft-launch churn | `reports/oyun eksikleri.md` |
| M13 | `support@gkk.game` — domain/MX/inbox canlı mı repo’dan doğrulanamaz; Console support URL/email tutarlı olmalı | settings + legal |
| M14 | Data Safety / App Privacy Nutrition Labels: e-posta, gameplay, chat, purchase (IAP açılırsa), diagnostics — form doldurulmalı; IDFA iddiası legal’de “toplamıyoruz” → ATT gerekmez **şu an** | legal §2 |
| M15 | NDK pin `27.0.12077973` vs Flutter default `28.2…` — bilinçli mi kontrol | `build.gradle.kts` L11 |

---

## 5. Low / polish

- Hardcoded Türkçe snackbar’lar (shop confirm “satin almak…”) l10n dışı.
- `Staff Hub` / `LiveOps` EN label.
- Golden test yok; unit test ~53 dosya; integration_test ~29 — coverage tool raporu yok.
- Accessibility: `Semantics` / `reduceMotion` kısmen var; sistematik a11y audit yok.
- Tablet layout özel optimize yok (iPad orientation açık).
- Store screenshot klasörü: `reports/screenshots/` tutorial/audit amaçlı — **store listing asset paketi değil**.
- Feature graphic / promo video / localized store description repo’da yok.
- `connectivity_gate` var — offline UX düşünülmüş (artı).

---

## 6. Per-platform checklist

### 6.1 iOS App Store

| Madde | Durum | Kanıt |
|-------|--------|--------|
| Bundle ID belirlenmiş | ⚠️ | `com.gkk.gkkFlutter` — final marka kararı? |
| Display name markalı | ❌ | `Gkk Flutter` |
| Version/build | ⚠️ | `1.0.0+1` / FLUTTER_BUILD_* — ASC ile senkron planı yok |
| Signing / Archive / exportOptions | ❌ | entitlements yok; exportOptions yok |
| Privacy Policy URL (ASC) | ❌ | yalnız in-app |
| Support URL | ❌ | yalnız e-posta kopyalama |
| Privacy Manifest (app) | ⚠️ | plugin-level var; app `PrivacyInfo.xcprivacy` yok |
| ATT / IDFA | ✅ (şimdilik N/A) | AdMob/IDFA yok; legal IDFA toplamıyor |
| NS*UsageDescription | ✅/⚠️ | Kamera/lokasyon yok; bildirim runtime; ek string gerekmedikçe OK |
| Account deletion | ⚠️ | In-app ✅; web ❌ |
| IAP + Restore | ❌ | Stub |
| Age rating questionnaire hazırlığı | ⚠️ | Violence/chat/gambling/loot — Console’da doldurulacak |
| Screenshots / App Preview | ❌ | Store-ready set yok |
| Push / Background modes | ✅ | Background modes suiistimali yok (plist’te UIBackgroundModes yok) |
| Universal Links | ❌ | yapılandırılmamış |

### 6.2 Google Play

| Madde | Durum | Kanıt |
|-------|--------|--------|
| applicationId | ⚠️ | `com.gkk.gkk_flutter` + TODO yorumu |
| App label | ❌ | `gkk_flutter` |
| Release signing | ❌ | debug signing |
| AAB build pipeline | ❌ | dokümante/CI yok (`README` APK arm64 debug odaklı) |
| INTERNET in main | ❌ | yalnız debug/profile |
| targetSdk / minSdk | ✅ | 36 / 24 (Flutter 3.41 default) |
| Adaptive icon | ❌ | yok |
| Data safety form | ⚠️ | sinyaller kodda; form doldurulmamış |
| Privacy policy URL | ❌ | |
| Exact alarm permissions | ❌/⚠️ | beyan + gerekçe veya kaldır |
| Ads declaration | ⚠️ | SDK yok; UI reklam vaat edebilir |
| Families / age | ⚠️ | 13+ legal; Play target audience seçimi |
| Account deletion | ⚠️ | in-app ✅ |
| Billing | ❌ | yok |
| Deobfuscation mapping upload | ❌ | minify kapalı |

---

## 7. Legal / compliance matrix

| Konu | In-app / kod | Store Console | Gap |
|------|--------------|---------------|-----|
| Terms of Service | ✅ canonical TR MD | ❌ public URL | Host + link |
| Privacy Policy | ✅ canonical TR MD + KVKK | ❌ public URL | Host + link |
| Community guidelines | ✅ | — | OK in-app |
| Register consent checkboxes | ✅ `register_legal_consent.dart` | — | OK |
| Age 13+ | ✅ legal | ⚠️ questionnaire | ASC/Play age rating |
| Account deletion | ✅ RPC+UI | ⚠️ web URL | Apple/Play meta |
| IAP disclosure | ✅ metin var | ❌ ürün yok | Metin ↔ ürün çelişkisi |
| Ads disclosure | ✅ metin/reklam akışı | ❌ SDK yok | Feature gizle veya entegre |
| IDFA / ATT | ✅ “toplamıyoruz” | N/A | AdMob gelirse ATT |
| Loot box odds | ✅ UI drop rate | ⚠️ labeling | Play/Apple loot beyanı |
| Simulated gambling (at yarışı) | ⚠️ oyun içi | ⚠️ rating | Questionnaire + legal madde |
| UGC / chat moderation | ✅ community + staff/report | ⚠️ | Safety form |
| Bug-report-for-rating abuse | ✅ legal yasak | — | İyi (Guideline 5.6) |
| Children’s privacy | ✅ 13-altı ret | — | COPPA/KVKK uyumu iddiası |
| Data controller contact | ⚠️ `support@gkk.game` | ⚠️ | Inbox/domain doğrula |
| Export compliance / encryption | — | ⚠️ | ASC standart HTTPS beyanı |

---

## 8. Suggested submit sequence (sıralı aksiyonlar)

1. **Karar:** Soft-launch scope — IAP/ads **kapalı** mı (önerilen v1), yoksa tam entegrasyon mu?
2. **Android INTERNET** (+ network state) → `main` manifest.
3. **Release signing** + Play App Signing; debug signing’i kaldır.
4. **Display name + ikonlar** (Android adaptive + Play 512; iOS set doğrula).
5. **Gem IAP sekmesi / reklam ödül CTA:** gizle veya gerçek SDK.
6. **Public Privacy + Terms URL** yayınla; ASC + Play’e gir; support e-posta doğrula.
7. **StaffHubDebugLog** ve benzeri unconditional `print` temizliği.
8. **Exact alarm** stratejisini Play policy’ye çek.
9. **Age rating / Data safety / App Privacy** formlarını özellik envanteriyle doldur (chat, bahis, loot, hesap, bildirim).
10. `flutter build appbundle --release` + iOS Archive (exportOptions + Distribution cert).
11. Store screenshot set (telefon; iPad isteniyorsa ayrı).
12. Internal/closed testing track → smoke (login, tutorial, dungeon, shop non-IAP, delete account sandbox).
13. Production submit.

**Önerilmez:** IAP stub + fiyatlı paketler + default icon + `gkk_flutter` label ile ilk review.

---

## 9. Evidence appendix — taranan ana yollar

### Config / platform
- `pubspec.yaml`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/profile/AndroidManifest.xml`
- `android/local.properties` (SDK path; imza secret değil)
- `ios/Runner/Info.plist`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Podfile` / `ios/Podfile.lock`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `.gitignore`

### App / legal / monetization
- `lib/core/constants/app_constants.dart`
- `lib/core/constants/economy_constants.dart`
- `lib/core/legal/legal_document_content.dart`
- `lib/core/services/ad_service.dart`
- `lib/core/services/supabase_service.dart`
- `lib/core/services/local_notification_service.dart`
- `lib/core/services/retention_analytics.dart`
- `lib/core/debug/staff_hub_debug_log.dart`
- `lib/screens/shop/shop_screen.dart`
- `lib/screens/settings/settings_screen.dart`
- `lib/screens/auth/widgets/register_legal_consent.dart`
- `lib/screens/staff/staff_route_guard.dart`
- `lib/qa/qa_flags.dart`
- `lib/main.dart`
- `lib/l10n/app_tr.arb`, `app_en.arb`
- `supabase/migrations/20260729_010000_delete_account.sql`
- `supabase/migrations/20260727_300000_legal_documents_and_acceptance.sql`

### Tests / ops / reports
- `test/` (~53 dart), `integration_test/` (~29 dart)
- `scripts/run_*`, `scripts/create_qa_integration_accounts.sh`
- `reports/audits/audit_2026-06-27/TODO.md`
- `reports/oyun eksikleri.md`
- `reports/ai_swarm_*` (ekonomi/QA; store checklist değil)
- `README.md`
- `.env.qa.local` (gitignore’da), `.env.qa.accounts` (gitignore’da değil)

### Bilinçli olarak bulunamayanlar
- `key.properties`, `*.jks`, `exportOptions.plist`
- App-level `PrivacyInfo.xcprivacy`
- `.github/workflows`, Fastlane, Codemagic
- `google-services.json` / `GoogleService-Info.plist`
- `in_app_purchase` / `google_mobile_ads`
- Store listing metadata klasörü (description/screenshots/feature graphic)
- Hosted privacy/terms URL

---

## 10. Bloklayıcı özet sayımı

| Seviye | Adet (bu raporda) |
|--------|-------------------|
| Critical (C1–C8) | **8** |
| High (H1–H11) | **11** |
| Medium | **15** |
| Low | birkaç polish maddesi |

**Verdict tekrar:** **NO-GO** — tahmini hazırlık **~38%**. En kısa yol: C1–C5 + C3 URL + C6/C7 feature gizleme → conditional soft-launch adayı (~60%+); tam IAP/ads ile production go için ek sprint gerekir.

---

*Bu rapor yalnızca gözlem ve kanıt listeler; uygulama kaynağı değiştirilmedi.*

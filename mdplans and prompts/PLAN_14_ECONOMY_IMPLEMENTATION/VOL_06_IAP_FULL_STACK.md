# PLAN 14 — Cilt 6: Uygulama İçi Satın Alma (IAP) Uçtan Uca

> **Öncelik:** P0 — Sim kapıları geçtikten sonra  
> **Migration:** `20260722_050000`, `20260722_060000`  
> **Flutter:** `in_app_purchase` paketi + yeni servis katmanı

---

## 1. Mevcut Durum

| Bileşen | Durum |
|---------|-------|
| `gem_iap_packages` tablosu | Hazır (4 paket) |
| `get_gem_iap_packages()` | Hazır |
| `EconomyConstants.gemIapPackages` | Hazır |
| `in_app_purchase` pubspec | **Yok** |
| `verify_and_grant_gems` RPC | **Yok** |
| `_buyGemPackage` | Toast — mint yok ✅ |

---

## 2. Hedef Mimari

```
[Kullanıcı] → [ShopScreen] → [IapService]
    → [Apple/Google Store]
    → [PurchaseDetails callback]
    → [IapRepository.verifyAndGrant]
    → [Supabase Edge Function: verify_receipt]
        → Apple App Store Server API / Google Play Developer API
    → [verify_and_grant_gems RPC]
    → [users.gems += package.gems]
    → [iap_transactions log]
    → [playerProvider.loadProfile()]
```

**Altın kural:** Elmas yalnızca sunucu doğrulaması sonrası verilir.

---

## 3. Veritabanı

### 3.1 `iap_transactions` tablosu

```sql
CREATE TABLE public.iap_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  package_id TEXT NOT NULL REFERENCES gem_iap_packages(id),
  store_product_id TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  transaction_id TEXT NOT NULL,
  receipt_hash TEXT NOT NULL,
  gems_granted INTEGER NOT NULL,
  price_usd_cents INTEGER,
  verified_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (platform, transaction_id),
  UNIQUE (receipt_hash)
);
```

### 3.2 `verify_and_grant_gems` RPC

Parametreler:
- `p_package_id TEXT`
- `p_platform TEXT`
- `p_receipt_data TEXT`
- `p_transaction_id TEXT`
- `p_edge_verify_token TEXT` — Edge Function imzalı JWT (anti-spoof)

Akış:
1. Auth kontrol
2. Paket aktif mi
3. receipt_hash duplicate kontrol
4. Edge verify token doğrula (shared secret)
5. gems += package.gems (SECURITY DEFINER)
6. iap_transactions insert
7. Return `{ success, gems_granted, gems }`

---

## 4. Supabase Edge Function

**Dosya:** `supabase/functions/verify-iap-receipt/index.ts`

### iOS (StoreKit 2)

- JWT: App Store Connect API Key
- `GET /inApps/v1/transactions/{transactionId}`
- Doğrula: bundleId, productId, environment (Sandbox/Production)

### Android

- Google Play Developer API service account
- `purchases.products.get`
- `purchaseState == 0`, consume if needed

**Çıktı:** `{ valid: true, productId, transactionId, environment }` imzalı token

---

## 5. Flutter Katmanı

### 5.1 Bağımlılık

```yaml
# pubspec.yaml
dependencies:
  in_app_purchase: ^3.2.0
```

### 5.2 Yeni dosyalar

| Dosya | Sorumluluk |
|-------|------------|
| `lib/services/iap_service.dart` | Store bağlantı, product query, purchase stream |
| `lib/repositories/iap_repository.dart` | Edge + RPC orchestration |
| `lib/providers/iap_provider.dart` | Riverpod — loading, error, pending |
| `lib/models/iap_purchase_result.dart` | Freezed model |

### 5.3 `shop_screen.dart` güncelleme

`_buyGemPackage`:
1. Loading state
2. `IapService.purchase(productId)`
3. Stream listener → verify
4. Success → snackbar + profile reload
5. Error → user-friendly message
6. `completePurchase` always

### 5.4 Feature flag

```dart
const kIapEnabled = bool.fromEnvironment('IAP_ENABLED', defaultValue: false);
const kMockIap = bool.fromEnvironment('MOCK_IAP', defaultValue: false);
```

Staging: `MOCK_IAP=true` — test receipt kabul  
Production: `IAP_ENABLED=true`

---

## 6. Store Console Yapılandırması

| store_product_id | iOS | Android |
|------------------|-----|---------|
| com.gkk.gems.starter | Consumable 100 gems | Managed product |
| com.gkk.gems.standard | 500 gems | |
| com.gkk.gems.best_value | 1200 gems | |
| com.gkk.gems.mega | 2600 gems | |

Fiyat: EconomyConstants ile eşleşmeli (USD/TRY display).

---

## 7. Güvenlik Kontrol Listesi

- [ ] receipt_hash UNIQUE — double spend
- [ ] transaction_id UNIQUE per platform
- [ ] Client gems mint yok
- [ ] Edge Function secret rotation planı
- [ ] Sandbox/Production ayrımı
- [ ] Rate limit: max 10 verify/dk/user
- [ ] Refund webhook (Faz 2 — opsiyonel)

---

## 8. Test Planı

| Aşama | Test |
|-------|------|
| Unit | IapRepository mock RPC |
| Integration | Sandbox 1 satın alma / paket |
| Regression | shop buy_shop_item hâlâ gold |
| Security | Aynı receipt 2 kez → reject |
| Load | 100 concurrent verify |

---

## 9. Kabul Kriterleri

- [ ] Sandbox'ta 4 paketin tamamı elmas veriyor
- [ ] iap_transactions log doluyor
- [ ] Çift harcama engelleniyor
- [ ] App Store / Play review guidelines uyum
- [ ] Production canary %10 — 48 saat hata yok

---

## 10. Alt Görev Kataloğu (100+ sayfa eşdeğeri)

| ID | Görev |
|----|-------|
| 6.1 | Apple App Store Connect kurulum |
| 6.2 | Google Play Console kurulum |
| 6.3 | Edge Function iOS verify |
| 6.4 | Edge Function Android verify |
| 6.5 | RPC verify_and_grant_gems |
| 6.6 | IapService Flutter |
| 6.7 | Shop UI entegrasyon |
| 6.8 | Sandbox test script |
| 6.9 | Production rollout runbook |
| 6.10 | Refund/chargeback prosedürü |

Her biri: adım adım ekran görüntüsü, API örnekleri, hata kodları tablosu.

---

## 11. Ekonomi Etkisi

IAP devreye girince elmas açığı kapanır:

| Kaynak | Yıllık elmas |
|--------|--------------|
| F2P (günlük+quest) | ~4700 |
| Sink (kasa+VIP+hastane) | ~5000+ |
| IAP | Değişken — hedef gelir |

Paket başına elmas/dolar: starter ~101, mega ~130 — Battle Pass VIP (500 elmas) rekabetçi.

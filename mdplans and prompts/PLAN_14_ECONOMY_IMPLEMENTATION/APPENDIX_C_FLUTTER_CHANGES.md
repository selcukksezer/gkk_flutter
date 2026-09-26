# PLAN 14 — Ek C: Flutter Dosya Değişiklik Matrisi

---

## Yeni Dosyalar

| Dosya | Cilt | Açıklama |
|-------|------|----------|
| `lib/core/utils/currency_format.dart` | VOL_11 | Altın/elmas format |
| `lib/services/iap_service.dart` | VOL_06 | StoreKit/Play |
| `lib/repositories/iap_repository.dart` | VOL_06 | RPC orchestration |
| `lib/providers/iap_provider.dart` | VOL_06 | Riverpod state |
| `lib/models/iap_purchase_result.dart` | VOL_06 | Sonuç modeli |
| `lib/screens/shop/widgets/gem_packages_tab.dart` | VOL_11 | Shop refactor |
| `lib/screens/shop/widgets/gold_packages_tab.dart` | VOL_11 | Shop refactor |
| `lib/screens/shop/widgets/items_tab.dart` | VOL_11 | Shop refactor |
| `supabase/functions/verify-iap-receipt/index.ts` | VOL_06 | Receipt verify |

---

## Değiştirilecek Dosyalar

| Dosya | Cilt | Değişiklik özeti |
|-------|------|------------------|
| `pubspec.yaml` | VOL_06 | in_app_purchase ^3.2.0 |
| `lib/screens/shop/shop_screen.dart` | VOL_06, 11 | IAP + format + refactor |
| `lib/core/constants/economy_constants.dart` | VOL_03 | goldSources metin |
| `lib/screens/inventory/inventory_screen.dart` | VOL_03 | Satış preview %35 |
| `lib/screens/loot/loot_hub_screen.dart` | VOL_11 | Route, preview, l10n |
| `lib/screens/loot/loot_chest_widgets.dart` | VOL_11 | Chip Wrap |
| `lib/components/layout/game_chrome.dart` | VOL_11 | _activeIndex map |
| `lib/components/layout/game_top_bar.dart` | VOL_11 | CurrencyFormat |
| `lib/repositories/inventory_repository.dart` | VOL_03 | sell response sell_rate |
| `lib/screens/market/widgets/market_sell_tab.dart` | VOL_09 | Fiyat band UI |
| `lib/models/player_model.dart` | VOL_11 | gems int? (opsiyonel — breaking) |

---

## Test Dosyaları

| Dosya | Cilt |
|-------|------|
| `test/core/utils/currency_format_test.dart` | VOL_11 |
| `test/services/iap_service_test.dart` | VOL_06 |
| `test/repositories/iap_repository_test.dart` | VOL_06 |
| `integration_test/smoke/iap_sandbox_test.dart` | VOL_06 |

---

## Grep Komutları (Etki Analizi)

```bash
rg "profile\?\.gems|'\\$gems'|_fmtGold" lib/
rg "vendor_sell|sell_inventory" lib/
rg "AppRoutes\.shop" lib/screens/loot/
rg "_buyGemPackage|IAP" lib/
```

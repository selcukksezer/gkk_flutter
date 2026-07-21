# PLAN 14 — Cilt 11: Ekonomi Arayüzü ve Kullanıcı Deneyimi

> **Öncelik:** P1  
> **Kaynak audit:** `reports/audits/audit_2026-06-27/shop.md`, `loot.md`

---

## 1. Cüzdan Format Tutarlılığı

### Problem

- Header: gems `500` (integer)
- Mağaza şeridi: `'$gems'` → **500.0** görünür (`PlayerProfile.gems` double)
- Altın: `_fmtGold` → `50K` vs header `50.0k`

### Çözüm

**Yeni dosya:** `lib/core/utils/currency_format.dart`

```dart
abstract final class CurrencyFormat {
  static String gems(num value) => value.round().toString();
  static String gold(int value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toString();
  }
}
```

**Değiştirilecek dosyalar:**
- `lib/components/layout/game_top_bar.dart`
- `lib/screens/shop/shop_screen.dart`
- Tüm gold/gems display noktaları (grep: `profile?.gems`, `_fmtGold`)

---

## 2. Mağaza (ShopScreen)

| Sorun | Düzeltme |
|-------|----------|
| Tab `'💎 Gem'` İngilizce | `'💎 Elmas'` |
| Battle Pass teaser | Feature flag ile gizle veya ComingSoonBadge |
| `_GemPackagesTab` IAP | VOL_06 sonrası gerçek satın alma |
| Monolitik 1137 satır | `lib/screens/shop/widgets/` altına böl |

---

## 3. Loot Hub

| Sorun | Düzeltme |
|-------|----------|
| `currentRoute: AppRoutes.shop` | `AppRoutes.loot` |
| Drop Preview gizli | Varsayılan açık veya top-5 otomatik |
| `'Drop Preview'` İngilizce | `'Önizleme'` |
| Çarpan chip kesik | `Wrap` veya 2 satır |
| 9 sn spin kilit | Skip butonu (ayarlardan) |

---

## 4. Bottom Navigation

Mağaza, loot, pazar menü rotalarında Home highlight yanlış — `game_chrome.dart` `_activeIndex` prefix map:

```dart
// Bilinmeyen route → Menü tab (index 4)
if (route.startsWith('/shop') || route.startsWith('/loot') || route.startsWith('/market')) {
  return 4; // Menü
}
```

---

## 5. Lokalizasyon

Merkezi `AppStrings` veya l10n ARB:
- `shop.tabs.gems` = "Elmas"
- `loot.preview` = "Önizleme"
- `market.empty` = "Henüz ilan yok"

---

## 6. Kabul Kriterleri

- [ ] Gems asla ondalık gösterilmez
- [ ] Altın format tüm ekranlarda aynı
- [ ] Loot odds görünür
- [ ] Screenshot audit PASS (42 rota)

---

## 7. Alt Görevler (UI)

- 11.1 currency_format.dart + unit test
- 11.2 shop refactor widgets
- 11.3 loot_hub route + preview fix
- 11.4 game_chrome nav map
- 11.5 l10n migration batch
- 11.6 integration_test screenshot regresyon

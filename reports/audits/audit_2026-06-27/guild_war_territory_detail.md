---
# 📦 DOSYA/SAYFA ANALİZİ: TerritoryDetailScreen (`lib/screens/guild_war/territory_detail_screen.dart`)

**Rota:** `/guild-war/territory/:id` (screenshot: `00000000-0000-0000-0000-000000030001` — Demir Kalesi)  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/guild_war_territory_00000000_0000_0000_0000_000000030001.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `defense_power_bar.dart`  
**İlgili widget'lar:** `attack_log_tile.dart`, `guild_war_defense_sheet.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `_StatTile` — label kontrastı düşük (Screenshot QA)
* **Hata Tanımı:** `fontSize: 10`, `AppColors.textTertiary` (satır 233); screenshot'ta "Savunma", "Trade Geliri" koyu mavi üzerinde okunmuyor.
* **Kullanıcıya Etkisi:** İstatistik etiketleri ayırt edilemez.
* **Kesin Çözüm ve Öneri:** Min 11px + `textSecondary`; veya label üstte icon altında value.

* **Sorunlu Bileşen/Yer:** Savunma bar — max değer tutarsızlığı
* **Hata Tanımı:** Screenshot footer `Savunma: 2600 / 1000` kırmızı bar; `DefensePowerBar` `max: t.baseDefensePower` (satır 169-173) — current > max görsel bug.
* **Kullanıcıya Etkisi:** Progress bar anlamsız (>100%).
* **Kesin Çözüm ve Öneri:** `max(current, baseDefense)` veya ayrı "bonus savunma" göstergesi.

* **Sorunlu Bileşen/Yer:** Hero banner — sadece isim
* **Hata Tanımı:** 120px gradient kutu yalnızca `t.name` (satır 122-142); harita/harita pini yok.
* **Kullanıcıya Etkisi:** Bölge kimliği zayıf; hub haritayla bağ kopuk.
* **Kesin Çözüm ve Öneri:** Territory icon, koordinat, bonus özeti.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home aktif
* **Hata Tanımı:** `currentRoute: AppRoutes.guildWar` → fallback Home. Screenshot doğruladı.
* **Kullanıcıya Etkisi:** Bölge detayında konum kaybı.
* **Kesin Çözüm ve Öneri:** Guild-war secondary nav map.

* **Sorunlu Bileşen/Yer:** Bölge yok — blank screen
* **Hata Tanımı:** `t == null` → `SizedBox.shrink()` (satır 114-115); loading sonrası boş.
* **Kullanıcıya Etkisi:** Geçersiz territory ID'de 404 yok.
* **Kesin Çözüm ve Öneri:** Error empty + geri.

* **Sorunlu Bileşen/Yer:** Saldır/Savunma CTA — lonca yok gizlenir
* **Hata Tanımı:** `if (guildId != null)` (satır 191); loncasız oyuncu CTA görmez, açıklama da yok.
* **Kullanıcıya Etkisi:** Salt okunur ekran; neden aksiyon yok belli değil.
* **Kesin Çözüm ve Öneri:** `Lonca üyeliği gerekli` banner.

* **Sorunlu Bileşen/Yer:** Son saldırılar — screenshot'ta görünmüyor
* **Hata Tanımı:** `recentAttacks.isNotEmpty` koşulu (satır 177); screenshot fold altında veya boş — scroll ipucu yok.
* **Kullanıcıya Etkisi:** Saldırı geçmişi keşfedilmez.
* **Kesin Çözüm ve Öneri:** Hub'daki son 3 saldırı özeti header'da.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Local `_detail` state
* **Risk/Maliyet:** `TerritoryDetail?` local (satır 29-48); provider pattern yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.watch(territoryDetailProvider(territoryId))
```

* **Hatalı Kod Yapısı:** `_attack` — `context.push` extra
* **Risk/Maliyet:** `AppRoutes.guildWarBattleResult` + `extra: result` (satır 77); deep link kırılgan.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
context.push('/guild-war/battle-result?id=${result.id}');
```

* **Hatalı Kod Yapısı:** `GridView.count` shrinkWrap
* **Risk/Maliyet:** Nested scroll ListView içinde (satır 145-158); performans OK ama `childAspectRatio: 1.6` dar metin.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Wrap veya 2-column intrinsic height
```

* **Hatalı Kod Yapısı:** `_addDefense` — sheet sonrası full reload
* **Risk/Maliyet:** `_load()` tüm detail (satır 80-90).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Optimistic defensePower update
```

* **Hatalı Kod Yapısı:** logout — guildWar clear eksik
* **Risk/Maliyet:** Satır 99-102.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(guildWarProvider.notifier).clear();
```

* **Hatalı Kod Yapısı:** `isOwner` — null owner edge case
* **Risk/Maliyet:** `isUnclaimed` bölgede owner null; `isOwner` false → Saldır gösterilir (OK) ama `ownerGuildName` boş string riski.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Sahipsiz bölge için özel CTA copy
```

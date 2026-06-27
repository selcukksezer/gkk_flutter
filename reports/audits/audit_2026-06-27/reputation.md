---
# 📦 DOSYA/SAYFA ANALİZİ: ReputationScreen (`lib/screens/reputation/reputation_screen.dart`)

**Rota:** `/reputation`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/reputation.png` *(partial capture 2026-06-27 — manifest'e eklendi)*  
**Tema referansları:** Hardcoded `Color(0xFF111827)` — `AppColors` minimal  
**İlgili widget'lar:** `lib/screens/home/home_screen.dart` (`_getReputationTier` global rep), `lib/components/layout/game_chrome.dart`

**Screenshot notu:** İlk tam audit koşusunda `/reputation` manifest'te yoktu; `AUDIT_ROUTES=/reputation` ile partial screenshot alındı.

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home yanlış aktif
* **Hata Tanımı:** `currentRoute: AppRoutes.reputation` → Home highlight (screenshot).
* **Kullanıcıya Etkisi:** İtibar ekranında nav konumu belirsiz.
* **Kesin Çözüm ve Öneri:** Menü highlight; reputation drawer item ile sync.

* **Sorunlu Bileşen/Yer:** Mock veri — prod'da yanıltıcı defaults
* **Hata Tanımı:** `_defaultFactions()` hardcoded rep/tasks (`reputation_screen.dart` 81–137); RPC fail `catch (_) {}` → defaults gösterilir (satır 191–193). Screenshot: Tüccarlar 45, Suç Örgütü 80 — smoke'ta gerçek server verisi mi mock mu belirsiz.
* **Kullanıcıya Etkisi:** Oyuncu sahte ilerleme görür; bağış/görev sonrası sürpriz reset.
* **Kesin Çözüm ve Öneri:** RPC fail → empty/error state; mock yalnızca `kDebugMode`.

* **Sorunlu Bileşen/Yer:** İki itibar sistemi — home vs faction
* **Hata Tanımı:** Home global `reputation` (0–356K+, `_getReputationTier` farklı eşikler); bu ekran faction rep 0–100 `_tierLabel`. Aynı "itibar" kelimesi iki ekonomi (`home_screen.dart` 1511+, `reputation_screen.dart` 47–53).
* **Kullanıcıya Etkisi:** Oyuncu home'daki İmparator tier ile faction Dostane'yi ilişkilendiremez; sistem çelişkisi.
* **Kesin Çözüm ve Öneri:** UI copy: "Fraksiyon İtibarı" vs "Şöhret"; home link tooltip.

* **Sorunlu Bileşen/Yer:** `_tierRewards` — faction id mismatch
* **Hata Tanımı:** Rewards map keys: `tuccarlar`, `gizli`, `tapınak`, `hapisane`, `hastane` (satır 73–78); faction ids: `zanaatkarlar`, `maceracilar`, `muhafizlar`, `suc_orgutu`. Expand'de `rewards[i] ?? '—'` → çoğu fraksiyonda ödül satırı "—".
* **Kullanıcıya Etkisi:** Kademe ödülleri boş; progression anlamsız.
* **Kesin Çözüm ve Öneri:** Key'leri faction id ile hizala; server-driven rewards.

* **Sorunlu Bileşen/Yer:** Görevler — salt okunur, tamamlanmış görünüm
* **Hata Tanımı:** `_buildTask` progress bar + `current/target` (`reputation_screen.dart` 451–492); tamamlanan görev (20/20) için claim CTA yok. Screenshot expand olmadan görevler gizli.
* **Kullanıcıya Etkisi:** Oyuncu görev bitince ödül alamaz; UI dekoratif.
* **Kesin Çözüm ve Öneri:** `claim_faction_task` RPC + "Ödülü Al" butonu.

* **Sorunlu Bileşen/Yer:** Bağış dialog — `TextEditingController` leak
* **Hata Tanımı:** `TextField(controller: TextEditingController(text: '$repAmount')..selection=...)` her build'de yeni controller (`reputation_screen.dart` 247–253); dispose yok.
* **Kullanıcıya Etkisi:** Dialog açıkken memory leak; klavye girişi zıplar.
* **Kesin Çözüm ve Öneri:** Stateful dialog widget; tek controller `initState`/`dispose`.

* **Sorunlu Bileşen/Yer:** Liste bottom clearance
* **Hata Tanımı:** `ListView` padding `vertical: 12` (satır 527); 5. kart (Suç Örgütü) screenshot'ta FAB/nav'a yakın; expand açılınca kesilir.
* **Kullanıcıya Etkisi:** Bağış butonu nav altında kalır.
* **Kesin Çözüm ve Öneri:** `gameBottomBarClearance` alt padding.

* **Sorunlu Bileşen/Yer:** Tier badge — "Onurlu" suç örgütünde
* **Hata Tanımı:** 80/100 rep → `_tierLabel` "Onurlu" altın badge (`reputation_screen.dart` 47–52). Suç örgütü için pozitif kelime; faction fantasy zayıf.
* **Kullanıcıya Etkisi:** Ton kopukluğu; muhafızlar "Düşman" kırmızı ile asimetri.
* **Kesin Çözüm ve Öneri:** Faction-specific tier labels map.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_donate` — optimistic local update
* **Risk/Maliyet:** RPC sonrası `setState(() => faction.rep += repGain)` (satır 318–319); server reject veya farklı gain → client drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
final result = await repo.donate(faction.id, goldAmount);
await _load(); // server truth
```

* **Hatalı Kod Yapısı:** `_Faction` / `_FactionTask` — private mutable models
* **Risk/Maliyet:** `int rep` ve `int current` mutable (satır 24, 41); list state copy yok — side effect risk.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
@freezed
class Faction with _$Faction {
  const factory Faction({required int rep, ...}) = _Faction;
}
```

* **Hatalı Kod Yapısı:** Tek dosya — data + UI + dialog
* **Risk/Maliyet:** 540 satır; test isolation zor.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// reputation_provider.dart, faction_card.dart, donate_dialog.dart
```

* **Hatalı Kod Yapısı:** `get_reputation` RPC — silent partial merge
* **Risk/Maliyet:** Server list boş item veya unknown faction → skip; defaults kalır (satır 163–189).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — server authoritative list; client defs yalnızca display metadata
```

* **Hatalı Kod Yapısı:** Global rep tier utility yok
* **Risk/Maliyet:** `_tierLabel`/`_tierColor` duplicate home/character logic.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// lib/core/utils/faction_reputation_tier.dart
// lib/core/utils/player_reputation_tier.dart — ayrı dosyalar
```

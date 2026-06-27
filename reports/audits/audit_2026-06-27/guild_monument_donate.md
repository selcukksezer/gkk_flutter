---
# 📦 DOSYA/SAYFA ANALİZİ: GuildMonumentDonateScreen (`lib/screens/guild/guild_monument_donate_screen.dart`)

**Rota:** `/guild/monument/donate`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/guild_monument_donate.png`  
**Tema referansları:** `lib/theme/app_colors.dart`, `lib/components/layout/game_chrome.dart`  
**İlgili widget'lar:** `lib/providers/guild_provider.dart`, `guild_monument_screen.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Lonca yok — kırık empty state (Screenshot QA)
* **Hata Tanımı:** Screenshot: `Lonca bulunamadı.` tek satır, ortada (satır 173-177); AppBar bile minimal, bottom nav yok, CTA yok (`Lonca Bul` / `Geri`).
* **Kullanıcıya Etkisi:** QA smoke hesabı loncasız — form hiç görünmedi; özellik test edilemedi.
* **Kesin Çözüm ve Öneri:** Empty illustration + `context.go(AppRoutes.guild)` CTA; monument donate smoke için guild fixture.

* **Sorunlu Bileşen/Yer:** Başlık duplicate
* **Hata Tanımı:** `GameTopBar` `'Anıta Bağış Yap'` + body içi aynı başlık mavi (satır 181, 192).
* **Kullanıcıya Etkisi:** Dikey alan israfı; hiyerarşi karışık.
* **Kesin Çözüm ve Öneri:** Body'den H1 kaldır; sadece AppBar.

* **Sorunlu Bileşen/Yer:** Input default — `'0'` her alan
* **Hata Tanımı:** Controller `text: '0'` (satır 21-24); kullanıcı silmeden bağış yapamaz veya yanlışlıkla 0 gönderir.
* **Kullanıcıya Etkisi:** Form friction; sıfır bağış hatası snackbar (satır 85-88).
* **Kesin Çözüm ve Öneri:** Boş placeholder; `hintText: '0'`.

* **Sorunlu Bileşen/Yer:** `suffixText: 'max $remaining'` — İngilizce
* **Hata Tanımı:** `_resourceInput` suffix (satır 148); label Türkçe.
* **Kullanıcıya Etkisi:** Küçük l10n kopukluğu.
* **Kesin Çözüm ve Öneri:** `'en fazla $remaining'`.

* **Sorunlu Bileşen/Yer:** Envanter/stok önizlemesi yok
* **Hata Tanımı:** Yapısal/mistik/kritik kaynak input var ama oyuncunun elinde ne kadar olduğu gösterilmiyor.
* **Kullanıcıya Etkisi:** Bağış denemesi → RPC fail; trial-and-error.
* **Kesin Çözüm ve Öneri:** `inventoryProvider` ile `Sahip: X` satırı.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — donate route tanınmıyor
* **Hata Tanımı:** `currentRoute: AppRoutes.guildMonumentDonate` (satır 183) → Home fallback.
* **Kullanıcıya Etkisi:** Lonca alt rotasında nav yanlış (form görünseydi).
* **Kesin Çözüm ve Öneri:** `/guild` prefix → Menü.

* **Sorunlu Bileşen/Yer:** Başarı sonrası — hard `go` monument
* **Hata Tanımı:** `context.go(AppRoutes.guildMonument)` (satır 107); geri stack silinir.
* **Kullanıcıya Etkisi:** Çoklu bağış akışı kesilir.
* **Kesin Çözüm ve Öneri:** `pop` + refresh veya "Başka bağış" CTA.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_loadDailyDonations` — silent catch
* **Risk/Maliyet:** `catch (_) {}` (satır 76); limit bar yanlış kalır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Hata banner + retry; veya provider'a taşı
```

* **Hatalı Kod Yapısı:** RPC `p_user_id` client'tan
* **Risk/Maliyet:** `donate_to_monument` user.id gönderiyor (satır 95-100); güvenlik: server auth.uid kullanmalı.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// params yalnızca miktarlar; RLS auth
```

* **Hatalı Kod Yapısı:** `onChanged` limit clamp — cursor jump
* **Risk/Maliyet:** `ctrl.text = '$remaining'` (satır 152-154); TextField imleç sona atlar.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// TextInputFormatter ile MaxValueFormatter
```

* **Hatalı Kod Yapısı:** İki farklı Scaffold yapısı
* **Risk/Maliyet:** `!hasGuild` vs normal (satır 173-223); chrome tutarsız.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
GameSubScreenScaffold + conditional body
```

* **Hatalı Kod Yapısı:** Static daily limits
* **Risk/Maliyet:** `_maxStructural` vb. kodda sabit (satır 29-33); backend değişince drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Config RPC veya remote config
```

* **Hatalı Kod Yapısı:** Bağış sonrası guild/player refresh yok
* **Risk/Maliyet:** Monument ekranına dönünce stale anıt seviyesi.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(guildProvider.notifier).loadMonument();
```

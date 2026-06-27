---
# 📦 DOSYA/SAYFA ANALİZİ: GuildMonumentScreen (`lib/screens/guild/guild_monument_screen.dart`)

**Rota:** `/guild/monument`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/guild_monument.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/models/guild_model.dart` (`kMonumentBonuses`)  
**İlgili widget'lar:** `lib/providers/guild_provider.dart`, `lib/components/layout/game_chrome.dart`

**Screenshot notu:** Smoke kullanıcısı lonca üyesi değil — ekran empty state (`Bir Loncaya Üye Değilsiniz`) yakalandı; üye state için `guild.png` veya QA seed ile yeniden çekim önerilir.

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Empty state — minimal bilgi
* **Hata Tanımı:** `!hasGuild` → kırmızı metin + `Lonca Bul` (`guild_monument_screen.dart` 165–170). Screenshot merkezde tek satır; anıt sistemi ne işe yarar açıklanmıyor, görsel/ikon yok.
* **Kullanıcıya Etkisi:** Menüden "Lonca Anıtı"na gelen oyuncu neden boş ekran gördüğünü ve motivasyonu anlamaz.
* **Kesin Çözüm ve Öneri:** `MekanEmpty` tarzı illüstrasyon + "Loncaya katılarak anıt yükselt" + birincil/ikincil CTA.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** `currentRoute: AppRoutes.guildMonument` bottom nav'da eşleşmez → Home aktif (screenshot). `game_chrome.dart` `_activeIndex` fallback `0`.
* **Kullanıcıya Etkisi:** Lonca alt ekranında konum kaybı.
* **Kesin Çözüm ve Öneri:** `/guild` prefix → Menü veya Lonca hub highlight.

* **Sorunlu Bileşen/Yer:** Tema tutarsızlığı — hardcoded renkler
* **Hata Tanımı:** `Color(0xFF1A2030)`, `Colors.blue`, `Color(0xFFFBBF24)`, `Color(0xFF6366F1)` doğrudan (`guild_monument_screen.dart` 195–351); `AppColors` / `AppTextStyles` kullanılmıyor. Guild ekranı ve guild war farklı palette.
* **Kullanıcıya Etkisi:** Anıt ekranı "ayrı uygulama" hissi; marka bütünlüğü kırılır.
* **Kesin Çözüm ve Öneri:** `AppColors.bgCard`, `AppColors.gold`, `AppTextStyles.title`.

* **Sorunlu Bileşen/Yer:** Başlık duplicate — AppBar + içerik
* **Hata Tanımı:** `GameTopBar(title: '🏛️ Lonca Anıtı')` + ListView içinde `Text('Lonca Anıtı', fontSize: 24, color: Colors.blue)` (satır 195). Üye state'te çift başlık dikey alan israfı.
* **Kullanıcıya Etkisi:** İçerik fold altında kalır; görsel gürültü.
* **Kesin Çözüm ve Öneri:** İç başlığı kaldır; hero kart yeterli.

* **Sorunlu Bileşen/Yer:** Aksiyon satırı — küçük ekran taşma
* **Hata Tanımı:** `Row` içinde `Bağış Yap` + `Yükselt` yan yana (`guild_monument_screen.dart` 196–211). Dar genişlikte butonlar sıkışır veya overflow.
* **Kullanıcıya Etkisi:** Yükseltme CTA kesilir; lider yetkisi olan oyuncu aksiyonu göremez.
* **Kesin Çözüm ve Öneri:** `Wrap` veya `Column` + full-width butonlar; `canUpgrade` için FAB.

* **Sorunlu Bileşen/Yer:** `_ResourceTile` — `childAspectRatio: 3` sıkışıklık
* **Hata Tanımı:** Grid 2×2, label `fontSize: 10`, value `14` (`guild_monument_screen.dart` 292–304, 428). "Yapısal Kaynak" uzun label tek satırda sıkışır.
* **Kullanıcıya Etkisi:** Kaynak tarama zor; sayılar birbirine yakın görünür.
* **Kesin Çözüm ve Öneri:** `childAspectRatio: 2.2`; kısa label ("Yapısal") + tooltip.

* **Sorunlu Bileşen/Yer:** Bonus grid — `childAspectRatio: 2.2` overflow
* **Hata Tanımı:** `kMonumentBonuses` 5+ satır, her hücrede Lv + title + effect 3 satır (`guild_monument_screen.dart` 316–342). `mainAxisSize: min` ama aspect ratio düşük → metin clip.
* **Kullanıcıya Etkisi:** Kilitli bonus açıklamaları okunamaz.
* **Kesin Çözüm ve Öneri:** `ListView` satır bazlı; unlocked/locked accordion.

* **Sorunlu Bileşen/Yer:** Hata mesajı — teknik exception
* **Hata Tanımı:** `_loadError = 'Anıt verileri yüklenemedi: $e'` (satır 112). RLS/Postgrest hatası kullanıcıya ham dump.
* **Kullanıcıya Etkisi:** Güven kaybı; destek talebi olmadan çözüm yok hissi.
* **Kesin Çözüm ve Öneri:** User-friendly map + "Tekrar Dene"; log'a `$e`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Monolith screen — 434 satır + inline widget
* **Risk/Maliyet:** `_load` 4 paralel Supabase sorgusu + username join ekranda; test/mock zor.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
// guild_monument_repository.dart
class GuildMonumentRepository {
  Future<MonumentSnapshot> fetch(String guildId);
}
// guild_monument_provider.dart
```

* **Hatalı Kod Yapısı:** `_load` — N+1 username fetch pattern
* **Risk/Maliyet:** Contributors çek → ayrı `users.inFilter` (satır 73–76); doğru ama ekran içinde 90 satır veri katmanı.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — RPC get_monument_dashboard(guild_id) tek round-trip
final data = await client.rpc('get_monument_dashboard', params: {'p_guild_id': guildId});
```

* **Hatalı Kod Yapısı:** `_upgrade` — `as Map` unsafe cast
* **Risk/Maliyet:** `rpc('upgrade_monument') as Map` (satır 126); wrong type runtime crash.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
if (data is! Map<String, dynamic>) { ... return; }
final result = data;
```

* **Hatalı Kod Yapısı:** State duplication — `guildProvider` vs `_guild` map
* **Risk/Maliyet:** `_guild` local `Map<String,dynamic>` provider'daki `Guild` modelinden ayrı; sync drift.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
final guild = ref.watch(guildProvider).guild;
// monument fields guild model'e extend veya MonumentViewModel
```

* **Hatalı Kod Yapısı:** `context.go` donate — stack replace
* **Risk/Maliyet:** `Bağış Yap` → `context.go(AppRoutes.guildMonumentDonate)` (satır 199); geri tuşu monument'e dönmez (go vs push).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
context.push(AppRoutes.guildMonumentDonate);
```

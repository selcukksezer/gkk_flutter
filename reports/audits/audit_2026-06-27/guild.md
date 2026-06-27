---
# 📦 DOSYA/SAYFA ANALİZİ: GuildScreen (`lib/screens/guild/guild_screen.dart`)

**Rota:** `/guild`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/guild.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/providers/guild_provider.dart`, `lib/models/guild_model.dart`, `lib/components/layout/game_chrome.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** Lonca menü ekranı; `currentRoute: AppRoutes.guild` bottom bar'da eşleşmez → Home mavi (screenshot).
* **Kullanıcıya Etkisi:** Oyuncu lonca hub'ında olduğunu nav'dan anlayamaz.
* **Kesin Çözüm ve Öneri:** Menü aktif göstergesi.

* **Sorunlu Bileşen/Yer:** Lonca üyesi değil görünümü — bilgi yoğunluğu
* **Hata Tanımı:** `Henüz bir loncaya üye değilsiniz.` + arama + `Önerilen Loncalar` listesi. Kartlarda `Lv.4 · Anıt Lv.8 · 41/50 üye · 2828063 güç` tek satır — küçük ekranda taşma riski.
* **Kullanıcıya Etkisi:** Lonca seçimi karşılaştırması zor.
* **Kesin Çözüm ve Öneri:** Chip satırı: seviye | üye | güç ayrı satırlar; `2828063` → `2.8M`.

* **Sorunlu Bileşen/Yer:** `Lv.` kısaltması
* **Hata Tanımı:** Önerilen lonca satırlarında `Lv.` (721+). Türkçe tam kelime yok.
* **Kullanıcıya Etkisi:** Küçük tutarsızlık.
* **Kesin Çözüm ve Öneri:** `'Sv.4'` veya `'Seviye 4'`.

* **Sorunlu Bileşen/Yer:** `AlertDialog` varsayılan tema
* **Hata Tanımı:** Ayrıl/oluştur/dağıt dialogları (116–258) açık Material tema; koyu oyun UI'sine uymuyor.
* **Kullanıcıya Etkisi:** Modal "sistem dialogu" hissi; immersion kırılır.
* **Kesin Çözüm ve Öneri:** `backgroundColor: AppColors.bgCard`, `AppTextStyles.title`.

* **Sorunlu Bileşen/Yer:** Arama CTA hizası
* **Hata Tanımı:** `Lonca ara...` + sarı `Ara` butonu; klavye açılınca liste scroll davranışı belirsiz.
* **Kullanıcıya Etkisi:** Arama sonucu boşsa feedback gecikmeli olabilir.
* **Kesin Çözüm ve Öneri:** Loading/empty state inline; `TextField.onSubmitted`.

* **Sorunlu Bileşen/Yer:** Hitap tonu karışımı
* **Hata Tanımı:** `Loncaya katıldınız!` (siz formu) vs dungeon `yapilamaz` (sen/ASCII).
* **Kullanıcıya Etkisi:** Marka sesi tutarsız.
* **Kesin Çözüm ve Öneri:** Tek hitap politikası (`sen` informal oyun tonu).

* **Sorunlu Bileşen/Yer:** Yenileme eksik
* **Hata Tanımı:** Üye listesi / önerilen loncalar pull-to-refresh yok.
* **Kullanıcıya Etkisi:** Katılım sonrası manuel geri çıkış gerekir.
* **Kesin Çözüm ve Öneri:** `RefreshIndicator` on `_NoGuildView` / `_GuildView`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Monolith ~1055 satır
* **Risk/Maliyet:** `_NoGuildView`, `_GuildView`, `_MemberTile`, 4 dialog tek dosyada.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
// guild_no_guild_view.dart, guild_member_tile.dart, guild_dialogs.dart
```

* **Hatalı Kod Yapısı:** RPC doğrudan ekranda — `_memberAction`
* **Risk/Maliyet:** `SupabaseService.client.rpc` screen içinde (414+); provider bypass.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
final response = await SupabaseService.client.rpc(rpcName, params: ...);

// OLMASI GEREKEN
await ref.read(guildProvider.notifier).promoteMember(memberId);
```

* **Hatalı Kod Yapısı:** `_myRole` karma fallback
* **Risk/Maliyet:** Birden fazla kaynaktan rol çözümü (501–516); edge case bug.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
GuildRole get myRole => ref.watch(guildProvider).myMembership?.role ?? GuildRole.member;
```

* **Hatalı Kod Yapısı:** `createCost = 10000000` hardcoded
* **Risk/Maliyet:** Ekonomi değişince UI/backend uyumsuz (180).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
final createCost = ref.watch(guildConfigProvider).createCostGold;
```

* **Hatalı Kod Yapısı:** `postFrameCallback` init load
* **Risk/Maliyet:** `deferProviderUpdate` pattern ile tutarsız (70–76).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
deferProviderUpdate(() async {
  await ref.read(guildProvider.notifier).loadGuild();
});
```

* **Hatalı Kod Yapısı:** `_StatChip` isim çakışması (pvp ile)
* **Risk/Maliyet:** Aynı private isim farklı dosyalarda; arama/refactor zor (1037).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
class GuildStatChip extends StatelessWidget { ... }
```

---
# 📦 DOSYA/SAYFA ANALİZİ: ChatScreen (`lib/screens/chat/chat_screen.dart`)

**Rota:** `/chat`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/chat.png`  
**Tema referansları:** Inline `_ChatDesignSystem` (App theme bypass)  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart` (kullanılmıyor), `chat_screen.dart.bak`, `chat_screen_new.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Chrome tutarsızlığı — `AppBar` vs `GameTopBar`
* **Hata Tanımı:** Full-screen route `Scaffold` + default `AppBar(title: 'Sohbet')` (`chat_screen.dart` 1272–1277); `GameTopBar` / `GameBottomBar` yok. Screenshot'ta profil/level/kaynak header eksik; diğer tüm hub ekranlarından kopuk.
* **Kullanıcıya Etkisi:** Sohbet "ayrı uygulama"; altın/gem/enerji bağlamı kaybolur; geri navigasyon belirsiz.
* **Kesin Çözüm ve Öneri:** `GameScreenScaffold` wrap; veya `asPanel` FAB modal pattern tutarlılığı.

* **Sorunlu Bileşen/Yer:** Mesaj hizalama — sender ID eşleşmesi
* **Hata Tanımı:** `_isOwnSender` `senderId == gameUserId || authUserId` (satır 431–433); history RPC `sender_user_id` auth vs game id mismatch ise tüm balonlar sola hizalanır. Screenshot'ta tüm mesajlar solda, dar bubble (~%35 genişlik).
* **Kullanıcıya Etkisi:** Kendi mesajını ayırt edemez; DM/global okuma yavaş.
* **Kesin Çözüm ve Öneri:** RPC normalize game `users.id`; fallback username match; QA assert own-message right-align.

* **Sorunlu Bileşen/Yer:** Kanal chip + moderasyon — 5. chip kalabalık
* **Hata Tanımı:** `_buildChannelBar` 4 kanal + `Susturulanlar` aynı satır (`chat_screen.dart` 1281–1344). Screenshot'ta 5 chip; "Susturulanlar" kanal değil — mental model karışır.
* **Kullanıcıya Etkisi:** Yeni oyuncu susturma listesini sohbet kanalı sanır.
* **Kesin Çözüm ve Öneri:** Susturulanlar AppBar action veya composer menü.

* **Sorunlu Bileşen/Yer:** Kullanıcı etiketi — solid mavi tag
* **Hata Tanımı:** Mesaj başlığında username `Container` solid accent background (`chat_screen.dart` 1892–1895). Screenshot'ta mavi blok isimden büyük; mesaj gövdesi ikincil.
* **Kullanıcıya Etkisi:** Görsel gürültü; uzun isimler tag'i şişirir.
* **Kesin Çözüm ve Öneri:** İnce text-only username; renk kanal accent.

* **Sorunlu Bileşen/Yer:** `maxWidth: 380` — dar bubble
* **Hata Tanımı:** `ConstrainedBox(maxWidth: 380)` telefon genişliğinin ~%50'si (`chat_screen.dart` 1869–1870). Screenshot sağda boş alan; kısa mesajlar bile dar sütun.
* **Kullanıcıya Etkisi:** Mesaj başına satır sayısı artar; chat verimsiz.
* **Kesin Çözüm ve Öneri:** `maxWidth: min(520, width * 0.78)`.

* **Sorunlu Bileşen/Yer:** Gradient typo — panel arka plan
* **Hata Tanımı:** `gradientBgPanel` colors `0xfff0141b26`, `0xfff0090d15` (`chat_screen.dart` 61–64) — fazla `f` prefix; alpha/channel şüpheli parse.
* **Kullanıcıya Etkisi:** Bazı cihazlarda panel düz renk veya banding.
* **Kesin Çözüm ve Öneri:** `Color(0xFF141B26)`, `Color(0xFF090D15)`.

* **Sorunlu Bileşen/Yer:** Bottom inset — composer + sistem gesture
* **Hata Tanımı:** `_buildComposer` `SafeArea` kısmi; full-screen chat'te home indicator overlap riski; FAB modal (`asPanel`) vs route farklı padding.
* **Kullanıcıya Etkisi:** Son mesaj composer altında kalır.
* **Kesin Çözüm ve Öneri:** `MediaQuery.padding.bottom` + `viewInsets` keyboard aware scroll.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** God file — ~1986 satır tek dosya
* **Risk/Maliyet:** Design system, models, moderation, realtime, UI hep `chat_screen.dart`; `.bak` / `_new` duplicate dosyalar repo'da.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// lib/screens/chat/
//   chat_design_system.dart
//   chat_models.dart
//   chat_repository.dart
//   widgets/chat_message_list.dart
//   widgets/chat_composer.dart
//   chat_screen.dart (<200 lines)
```

* **Hatalı Kod Yapısı:** In-memory message store — restart loss
* **Risk/Maliyet:** `_messages` map state (satır 395–400); realtime append local; pagination yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
@riverpod
class ChatChannelMessages extends _$ChatChannelMessages {
  Future<List<ChatMessage>> build(ChatChannel channel) => repo.history(channel);
}
```

* **Hatalı Kod Yapısı:** `_mutedPlayers` ≡ `_blockedPlayers`
* **Risk/Maliyet:** `_syncBlockedUsers` her ikisini aynı key set (satır 615–620); mute vs block ayrımı yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — ayrı Set mute; block RPC ayrı
```

* **Hatalı Kod Yapısı:** Realtime channel — lifecycle
* **Risk/Maliyet:** `_subscribeRealtime` init'te; kanal değişiminde re-subscribe belirsiz; dispose unsubscribe var ama reconnect yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.listen(activeChannelProvider, (_, next) => _resubscribe(next));
```

* **Hatalı Kod Yapısı:** `_showSnack` vs `AppMessenger`
* **Risk/Maliyet:** Karışık feedback kanalları; bazı path `AppMessenger`, çoğu local snack.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// Tek AppMessenger — chat_screen içi _showSnack kaldır
```

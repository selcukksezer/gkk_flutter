---
# 📦 DOSYA/SAYFA ANALİZİ: TradeScreen (`lib/screens/trade/trade_screen.dart`)

**Rota:** `/trade`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/trade.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`, `lib/providers/inventory_provider.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Karşı teklif paneli — bilinçli ama kırıcı placeholder
* **Hata Tanımı:** `_buildActiveState` sağ kolon (satır 571-588): `'Gerçek zamanlı senkronizasyon henüz desteklenmiyor.'` + `Icons.sync_disabled`. P2P ticaretin yarısı çalışmıyor ama Onayla aktif.
* **Kullanıcıya Etkisi:** Oyuncu tek taraflı onaylayıp dolandırılma/eksik takas riski sanır; prod'da feature incomplete sinyali.
* **Kesin Çözüm ve Öneri:** Realtime channel (Supabase Realtime) veya polling; tamamlanana kadar Onayla disabled + `Beta` banner.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home aktif (menü rotası)
* **Hata Tanımı:** `AppRoutes.trade` bottom bar'da yok → Home highlight. Screenshot idle arama ekranı + Home seçili.
* **Kullanıcıya Etkisi:** Ticaret ekranında konum kaybı.
* **Kesin Çözüm ve Öneri:** Menü tab indicator veya trade-specific mini nav.

* **Sorunlu Bileşen/Yer:** Boş durum — viewport %60 boş
* **Hata Tanımı:** Idle state tek kart (arama + input); screenshot'ta header sonrası geniş boş alan — görsel ağırlık üstte, CTA zayıf.
* **Kullanıcıya Etkisi:** "Uygulama dondu" algısı; ticaret sosyal özellik keşfi düşük.
* **Kesin Çözüm ve Öneri:** Illustration + "Yakındaki oyuncular" / son işlem özeti; idle'da geçmiş snippet.

* **Sorunlu Bileşen/Yer:** Eşya seçici — görsel yoksunluk
* **Hata Tanımı:** `_showItemPicker` ListTile `leading`: 10×10 renk noktası (satır 251-256) — `ItemIconView` yok; isim + qty only.
* **Kullanıcıya Etkisi:** Aynı isimli/stack eşyalar ayırt edilemez; ticaret hatası.
* **Kesin Çözüm ve Öneri:** 40dp `ItemIconView` + rarity border; enhancement level badge.

* **Sorunlu Bileşen/Yer:** Oturum ID — debug metni prod'da
* **Hata Tanımı:** `'Oturum: ${_sessionId!.substring(0, 8)}...'` (satır 495-497) 10px `white38` — oyuncu için anlamsız.
* **Kullanıcıya Etkisi:** Destek ticket'ında işe yarar ama UI clutter; hacker-ish.
* **Kesin Çözüm ve Öneri:** Dev-only `kDebugMode` veya destek menüsüne taşı.

* **Sorunlu Bileşen/Yer:** Miktar — her zaman 1
* **Hata Tanımı:** `_addItemToOffer` `'quantity': 1` sabit (satır 130); stackable eşyada partial trade yok.
* **Kullanıcıya Etkisi:** 99 potion'dan 5 veremez; KO trade beklentisi karşılanmaz.
* **Kesin Çözüm ve Öneri:** Bank/shop pattern `_askQuantity` dialog.

* **Sorunlu Bileşen/Yer:** Durum makinesi — gelen istek UI yok
* **Hata Tanımı:** Yalnızca outbound search (`initiate_trade`); pending/active inbound trade listesi, push/badge yok.
* **Kullanıcıya Etkisi:** Karşı taraf uygulamada değilse trade ölür; idle ekranda kalır.
* **Kesin Çözüm ve Öneri:** `get_pending_trades` banner + notification.

* **Sorunlu Bileşen/Yer:** Geçmiş sekmesi — hata/empty aynı ağırlık
* **Hata Tanımı:** `_historyError` kırmızı `$e` (satır 697); empty `'Henüz ticaret geçmişi yok.'` — screenshot trade tab idle; geçmiş QA'da doğrulanmadı.
* **Kullanıcıya Etkisi:** RPC fail → teknik metin.
* **Kesin Çözüm ve Öneri:** User-friendly error + retry (mevcut buton OK).

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** RPC param adı tutarsızlığı
* **Risk/Maliyet:** `add_trade_item`: `session_id`; `confirm_trade`/`cancel_trade`: `p_session_id` (satır 136, 162, 186) — overload/migration riski.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — tek convention
params: {'p_session_id': _sessionId}
```

* **Hatalı Kod Yapısı:** Local state — sunucu sync yok
* **Risk/Maliyet:** `_myOffer`, `_tradeStatus` yalnızca client; app kill → stale session; `_confirmTrade` session null ise yine `done` (satır 160-168).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
class TradeSessionNotifier extends AsyncNotifier<TradeSession> {
  StreamSubscription? _realtime;
}
```

* **Hatalı Kod Yapısı:** `_addToHistory` — optimistic + immediate reload
* **Risk/Maliyet:** Satır 201-211 fake id `th${timestamp}` insert sonra `_loadHistory()` — duplicate flash.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
await _loadHistory(); // optimistic skip veya merge by id
```

* **Hatalı Kod Yapısı:** `_removeFromOffer` — sunucu sync yok
* **Risk/Maliyet:** Local remove only; backend offer stale kalır.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
await client.rpc('remove_trade_item', params: {...});
```

* **Hatalı Kod Yapısı:** `SingleChildScrollView` + `Column` trade tab — unbounded height risk
* **Risk/Maliyet:** Active state büyük; nested scroll yok; çok eşyada overflow (screenshot idle OK).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — offer listesi ListView.builder maxHeight
ConstrainedBox(constraints: BoxConstraints(maxHeight: 200), child: ListView(...))
```

* **Hatalı Kod Yapısı:** logout — inventory clear yok
* **Risk/Maliyet:** Satır 291-294 character/shop ile aynı gap.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(inventoryProvider.notifier).clear();
```

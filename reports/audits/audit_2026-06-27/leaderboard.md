---
# 📦 DOSYA/SAYFA ANALİZİ: LeaderboardScreen (`lib/screens/leaderboard/leaderboard_screen.dart`)

**Rota:** `/leaderboard`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/leaderboard.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Sahte liderlik verisi (prod riski)
* **Hata Tanımı:** RPC hata/boş dönerse `_defaultEntries()` 30 uydurma oyuncu (`GölgeKral`, `DemirKılıç`…) gösterilir (satır 35–66, 155–164).
* **Kullanıcıya Etkisi:** Gerçek sıralama ile karışır; QA dışı prod'da yanıltıcı liderlik — ciddi güven ihlali.
* **Kesin Çözüm ve Öneri:** Mock yalnızca `kDebugMode`; prod'da error/empty state UI.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** Menüden açılan `/leaderboard` rotası bottom bar'da eşleşmez → Home seçili görünür (screenshot doğruladı).
* **Kullanıcıya Etkisi:** Navigasyon bilişsel model kopukluğu.
* **Kesin Çözüm ve Öneri:** Menü aktif state veya indicator suppress.

* **Sorunlu Bileşen/Yer:** Podyum değer formatı — tutarsız ikon
* **Hata Tanımı:** Screenshot'ta servet kategorisinde `1802.2M` yanında gri ay ikonu; alt listede aynı. `🪙` emoji `_formatValue` içinde tanımlı ama podyumda farklı render olabilir.
* **Kullanıcıya Etkisi:** Servet vs güç birimleri karışır.
* **Kesin Çözüm ve Öneri:** Kategori başına sabit `LeaderboardValueFormatter`.

* **Sorunlu Bileşen/Yer:** Arama + podyum etkileşimi
* **Hata Tanımı:** Arama aktifken podyum gizlenir (satır ~481); boş arama sonrası podyum geri gelir ama geçiş animasyonsuz.
* **Kullanıcıya Etkisi:** "Top 3 nereye gitti?" şaşkınlığı.
* **Kesin Çözüm ve Öneri:** Podyumu dim + filtre; veya arama sonuçlarında rank badge.

* **Sorunlu Bileşen/Yer:** `N/A` / `Lv.` İngilizce kısaltmalar
* **Hata Tanımı:** `_formatValue` level için `Lv.$value` (81); oyuncu kendi sırası yoksa `N/A` (342).
* **Kullanıcıya Etkisi:** Türkçe UI'da yabancı fragment.
* **Kesin Çözüm ve Öneri:** `'Sv.$value'` / `'Bilinmiyor'` veya `'—'`.

* **Sorunlu Bileşen/Yer:** Yenileme pattern
* **Hata Tanımı:** Yalnızca küçük refresh `IconButton` (420+); `RefreshIndicator` yok.
* **Kullanıcıya Etkisi:** Mobil kullanıcı pull-to-refresh bekler.
* **Kesin Çözüm ve Öneri:** `RefreshIndicator` + mevcut ikon.

* **Sorunlu Bileşen/Yer:** Kategori `Görev` etiketi
* **Hata Tanımı:** `level` anahtarı label `'Görev'` (30) — aslında seviye sıralaması; semantik yanlış.
* **Kullanıcıya Etkisi:** Görev sistemi ile karışır.
* **Kesin Çözüm ve Öneri:** Label `'Seviye'`.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Supabase RPC doğrudan StatefulWidget'ta
* **Risk/Maliyet:** Provider/cache yok; test mock zor; `setState` yoğun (satır 125–209).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — screen içinde RPC
final data = await SupabaseService.client.rpc('get_leaderboard', ...);

// OLMASI GEREKEN
final state = ref.watch(leaderboardProvider(category, period));
```

* **Hatalı Kod Yapısı:** `_defaultEntries` prod fallback
* **Risk/Maliyet:** Catch bloğu sessiz; fake data set (satır 155–164).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
} catch (_) {}
setState(() { _entries = _defaultEntries(); });

// OLMASI GEREKEN
} catch (e) {
  setState(() { _entries = []; _error = 'Sıralama yüklenemedi'; });
}
```

* **Hatalı Kod Yapısı:** `_LeaderboardEntry` local class
* **Risk/Maliyet:** Model tekrarı; JSON mapping screen'de (satır 12–25).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — models/leaderboard_entry.dart + fromJson
```

* **Hatalı Kod Yapısı:** `_applyFilter` her keystroke `setState`
* **Risk/Maliyet:** 30+ entry listesinde her tuş rebuild (satır 212–222).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
Timer? _debounce;
void _onSearchChanged(String q) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 250), () => _applyFilter(q));
}
```

* **Hatalı Kod Yapısı:** Hardcoded gradient body
* **Risk/Maliyet:** `0xFF10131D` tekrar; tema dışı (pvp/guild ile aynı kopya).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
decoration: BoxDecoration(gradient: AppGradients.screenBackground),
```

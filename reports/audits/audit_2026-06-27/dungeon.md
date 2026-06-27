---
# 📦 DOSYA/SAYFA ANALİZİ: DungeonScreen (`lib/screens/dungeon/dungeon_screen.dart`)

**Rota:** `/dungeon`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/dungeon.png`  
**Tema referansları:** `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart`, `lib/theme/app_spacing.dart`, `lib/theme/app_text_styles.dart`  
**İlgili widget'lar:** `lib/screens/dungeon/widgets/featured_cave_dungeon_card.dart`, `lib/screens/dungeon/widgets/dungeon_progress_row.dart`, `lib/components/layout/game_chrome.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Bölge sekmeleri — Latince bölge adları
* **Hata Tanımı:** Tab etiketleri `Silva Obscura`, `Caverna Profunda`, `Desertum Ignis` vb. (satır 67–73). Oyuncu dili Türkçe; bölge numarası `B1`–`B5` anlaşılır ama alt isimler RPG lore değil, çevrilmemiş placeholder.
* **Kullanıcıya Etkisi:** Zindan hub'ında yabancı dil hissi; login/register ASCII Türkçe borcuyla birleşince i18n tutarsızlığı.
* **Kesin Çözüm ve Öneri:** `AppStrings.dungeon.zones` veya Supabase `zone_display_name`; en azından `Silva` → `Orman`.

* **Sorunlu Bileşen/Yer:** Zindan kartı CTA — `Loot` İngilizce
* **Hata Tanımı:** `_LootButton` metni `'Loot'` (satır 1141). Ana CTA `Zindana Gir` Türkçe; yan düğme İngilizce.
* **Kullanıcıya Etkisi:** Ödül önizleme butonu anlaşılmaz veya "beta" algısı.
* **Kesin Çözüm ve Öneri:** `'Ganimet'` veya `'Ödül Tablosu'`.

* **Sorunlu Bileşen/Yer:** ASCII Türkçe hata/snackbar metinleri
* **Hata Tanımı:** `yuklenemedi` (176, 1265), `giris yapilamaz`, `Baglanti`, `ptal` (1399 onay dialogu — **İptal** yerine bozuk string), `YETERSZ`/`YETERL` güç etiketleri.
* **Kullanıcıya Etkisi:** Hata anında güven kaybı; onay dialogunda `ptal` tıklanabilir ama profesyonel değil.
* **Kesin Çözüm ve Öneri:** l10n ARB; `ptal` acil düzeltme → `'İptal'`.

* **Sorunlu Bileşen/Yer:** `_HospitalMiniStrip` — saniyede bir rebuild
* **Hata Tanımı:** `Stream.periodic(Duration(seconds: 1))` ile hastane geri sayımı (satır ~526). Tüm strip subtree her saniye repaint.
* **Kullanıcıya Etkisi:** Uzun zindan oturumunda gereksiz pil/GPU; scroll jank riski.
* **Kesin Çözüm ve Öneri:** Yalnızca `Text` widget'ını `Ticker` veya `CountdownText` ile izole et.

* **Sorunlu Bileşen/Yer:** Zindan kartları — CTA renk tutarsızlığı
* **Hata Tanımı:** Screenshot'ta ilk kart mavi `Zindana Gir`, ikinci turuncu; güç yeterliliği `GÜÇ YETERLİ` bar'ı bazı kartlarda var bazılarında yok.
* **Kullanıcıya Etkisi:** Hangi zindanın "önerilen" olduğu belirsiz; görsel hiyerarşi kopuk.
* **Kesin Çözüm ve Öneri:** Tek `DungeonCtaStyle` enum: ready=primary, locked=muted, insufficient=warning.

* **Sorunlu Bileşen/Yer:** Hapis durumu görünürlüğü
* **Hata Tanımı:** Hastane için mini strip var; hapiste iken yalnızca buton `Hapis Kilidi` metni — üst şerit yok.
* **Kullanıcıya Etkisi:** Oyuncu neden giremediğini geç fark eder.
* **Kesin Çözüm ve Öneri:** `_PrisonMiniStrip` veya birleşik `_RestrictionBanner`.

* **Sorunlu Bileşen/Yer:** Alt nav highlight
* **Hata Tanımı:** `GameBottomBar(currentRoute: AppRoutes.dungeon)` doğru; screenshot'ta Zindan sekmesi mavi glow — **bu ekranda doğru**. (Menü ekranlarından farklı.)
* **Kullanıcıya Etkisi:** Yok (olumlu).
* **Kesin Çözüm ve Öneri:** Diğer menü rotalarına örnek al.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** Monolith dosya (~1854 satır, 15+ private widget)
* **Risk/Maliyet:** `_DungeonCard`, `_LootDialog`, `_ConfirmEntryDialog`, victory/defeat dialogları tek dosyada; test ve hot-reload yavaş.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT — dungeon_screen.dart tek dosya
class _DungeonCard extends StatelessWidget { ... }
class _LootDialog extends StatelessWidget { ... }

// OLMASI GEREKEN
// widgets/dungeon_card.dart, dialogs/dungeon_loot_dialog.dart
```

* **Hatalı Kod Yapısı:** Ölü kod — kullanılmayan dialog/overlay sınıfları
* **Risk/Maliyet:** `_EntryOverlay`, `_ResultDialog`, `_DefeatResultDialog`, `_kVictoryBg*` sabitleri (24–47) hiç referanslanmıyor; binary şişkinliği.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — dead class'ları kaldır veya dungeon_battle_screen'e taşı
// grep ile 0 referans → sil
```

* **Hatalı Kod Yapısı:** Çift zone state — `_selectedZone` + `TabController`
* **Risk/Maliyet:** İki kaynak gerçek; listener senkron hatası riski (satır 87–101, 308).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
int _selectedZone = 0;
_tabController.addListener(() => setState(() => _selectedZone = ...));

// OLMASI GEREKEN
int get _selectedZone => _tabController.index == 0 ? 0 : _kZones[_tabController.index - 1].number;
```

* **Hatalı Kod Yapısı:** Onay dialog — typo `ptal`
* **Risk/Maliyet:** UX bug; muhtemelen kopyala-yapıştır hatası (satır 1399).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
child: const Text('ptal', style: TextStyle(color: Color(0xFF4A5880))),

// OLMASI GEREKEN
child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
```

* **Hatalı Kod Yapısı:** `initState` içinde doğrudan `ref.read` async
* **Risk/Maliyet:** Post-frame callback pattern pvp/guild ile tutarsız; build sırasında race (satır 103–107).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
@override
void initState() {
  super.initState();
  deferProviderUpdate(() async {
    await ref.read(dungeonProvider.notifier).loadDungeons();
  });
}
```

* **Hatalı Kod Yapısı:** Tema token bypass — `Color(0xFF080B12)`, `withOpacity` (29 kullanım)
* **Risk/Maliyet:** Dark mode / tema değişiminde kırılır; Flutter 3.27 `withOpacity` deprecation.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// MEVCUT
color: Colors.white.withOpacity(0.08)

// OLMASI GEREKEN
color: AppColors.textPrimary.withValues(alpha: 0.08)
```

---
# 📦 DOSYA/SAYFA ANALİZİ: QuestsScreen (`lib/screens/quests/quests_screen.dart`)

**Rota:** `/quests`  
**Ekran görüntüsü:** `reports/screenshots/audit_2026-06-27/quests.png`  
**Tema referansları:** `lib/models/quest_model.dart`  
**İlgili widget'lar:** `lib/components/layout/game_chrome.dart`

---

## 1. 🚨 KRİTİK UI/UX VE GÖRSEL TASARIM HATALARI

* **Sorunlu Bileşen/Yer:** Tab filtre — listener ters mantık (bug)
* **Hata Tanımı:** Satır 54-57: `if (!_tabCtrl.indexIsChanging) return` — kategori **yalnızca animasyon sırasında** güncellenir; settle olunca atlanır. `_filtered` eski tab ile kalabilir.
* **Kullanıcıya Etkisi:** Günlük/Haftalık/Ana sekmesi yanlış liste; görev "kayboldu" sanılır.
* **Kesin Çözüm ve Öneri:** `if (_tabCtrl.indexIsChanging) return;` → settle sonrası update.

* **Sorunlu Bileşen/Yer:** Kategori heuristics — kırılgan filtre
* **Hata Tanımı:** `_filtered` (satır 157-180): `q_d` prefix, `QuestDifficulty.easy` → daily proxy. Elite görev "Elit Avcısı" Ana tab'da; daily easy questler weekly'ye kaçabilir.
* **Kullanıcıya Etkisi:** Screenshot: Tümü'nde 17 görev; tab değişince beklenmedik boşluk.
* **Kesin Çözüm ve Öneri:** RPC `quest_type` alanı; client prefix tahmini kaldır.

* **Sorunlu Bileşen/Yer:** Sezon görevi — otomatik redirect
* **Hata Tanımı:** `_loadQuests` completed season quest → `context.go(AppRoutes.season)` (satır 99-102) + snack. Oyuncu Görevler'e giremez.
* **Kullanıcıya Etkisi:** Aggressive UX; claim önce quests'te görmek isteyen oyuncu frustrasyon.
* **Kesin Çözüm ve Öneri:** In-app banner; redirect optional veya bir kez.

* **Sorunlu Bileşen/Yer:** Enerji — ödül chip'i gibi gösteriliyor
* **Hata Tanımı:** `_RewardChip(Icons.flash_on_rounded, '${widget.quest.energyCost}', orange)` (satır 758-763) — maliyet ama reward row'da.
* **Kullanıcıya Etkisi:** "+20 enerji" sanılır; aslında harcama — screenshot Elit Avcısı kartında yanıltıcı.
* **Kesin Çözüm ve Öneri:** `'⚡ -20 Enerji'` ayrı maliyet satırı; kırmızı/gri.

* **Sorunlu Bileşen/Yer:** `_actionLoading` — global kilitleme
* **Hata Tanımı:** Tek `bool _actionLoading` tüm kart butonlarını disable (satır 821-835).
* **Kullanıcıya Etkisi:** Bir görev claim ederken diğer completed görevler bekler.
* **Kesin Çözüm ve Öneri:** Per-quest `Set<String> _loadingQuestIds`.

* **Sorunlu Bileşen/Yer:** Bottom clearance — nav/FAB
* **Hata Tanımı:** `ListView.builder(padding: fromLTRB(16, 4, 16, 24))` — `gameBottomBarClearance` yok. Screenshot son kart + Sohbet FAB yakın.
* **Kullanıcıya Etkisi:** Son görev CTA nav altında.
* **Kesin Çözüm ve Öneri:** `padding.bottom: gameBottomBarClearance(context) + 16`.

* **Sorunlu Bileşen/Yer:** `GameBottomBar` — Home highlight
* **Hata Tanımı:** `/quests` menü rotası; screenshot Home aktif.
* **Kullanıcıya Etkisi:** Cross-cutting.
* **Kesin Çözüm ve Öneri:** Menü map.

* **Sorunlu Bileşen/Yer:** Tamamlanma header — claim edilmemiş completed sayılır
* **Hata Tanımı:** `_completionRate` `QuestStatus.completed` (satır 201-204); claim edilmemiş görevler %100 sayılıp yeşil/shimmer — screenshot 0/17 ama kartlarda active görevler var (completed yok header'da doğru).
* **Kullanıcıya Etkisi:** İleride completed birikince bar dolu ama ödül alınmamış — "Bitti" yanıltıcı alt metin.
* **Kesin Çözüm ve Öneri:** `'Ödül Bekliyor'` ayrı stat; rate = claimed/total.

---

## 2. 🏗️ FLUTTER WIDGET AĞACI VE REFAKTÖR (KOD) HATALARI

* **Hatalı Kod Yapısı:** `_QColors` — tema duplicate (~1287 satır dosya)
* **Risk/Maliyet:** Satır 18-30 inline palette; `_QuestCard` shimmer AnimationController per card — 17 görev = 17 ticker!
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — shimmer yalnızca completed + visible cards
// veya static gradient overlay
class _QuestCardState {
  @override
  void initState() {
    if (widget.quest.status == QuestStatus.completed) _shimmerCtrl.repeat();
  }
}
```

* **Hatalı Kod Yapısı:** `_claimReward` — optimistic remove
* **Risk/Maliyet:** Satır 121 `_quests.removeWhere` RPC öncesi değil sonra ama fail olursa geri alma yok.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN
await rpc(...);
if (mounted) setState(() => _quests.removeWhere(...));
```

* **Hatalı Kod Yapısı:** `_completeQuest` — full reload
* **Risk/Maliyet:** Her complete `_loadQuests()` — season redirect tetiklenebilir tekrar.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
// OLMASI GEREKEN — single quest patch from RPC response
```

* **Hatalı Kod Yapısı:** `_QuestDetailSheet` — duplicate action logic
* **Risk/Maliyet:** `_QuestCard._buildActionButton` ile mirror kod (~200 satır duplicate).
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
Widget QuestActionButton({required QuestData quest, ...})
```

* **Hatalı Kod Yapısı:** `QuestData.fromJson` — RPC shape tek nokta değil
* **Risk/Maliyet:** `_loadQuests` cast `(res as List)` — hata mesajı raw.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
final list = QuestRepository.parseAvailableQuests(res);
```

* **Hatalı Kod Yapısı:** Logout — inventory clear eksik
* **Risk/Maliyet:** Satır 207-210.
* **Mevcut Durum vs Olması Gereken (Refaktör):**

```dart
ref.read(inventoryProvider.notifier).clear();
```

# Bug Audit — Equip Level Gate / Stat Bonus / Dungeon XP UI / Upgrade Scroll / Chat Hit-Test

**Tarih:** 2026-07-31  
**Workspace:** `/Users/selcuk/Documents/gkk-web/gkk_flutter`  
**Kapsam:** Araştırma + kök neden + fix önerisi (implementasyon yok)  
**Kanıt:** Flutter client + migration geçmişi + canlı DB `pg_get_functiondef` (Supabase MCP)

---

## 1. Executive summary

| # | Issue | Severity | Root cause (tek satır) | Effort | Status |
|---|--------|----------|------------------------|--------|--------|
| 1 | Level gate kırık — Lv10 oyuncu Lv55 item kuşabilir | **P0 / Critical** | Canlı `equip_item` + client: `required_level` hiç kontrol edilmiyor | M | **FIXED** |
| 2 | Kuşanılan item HP/ATK/DEF karakter ekranına yansımıyor | **P0 / Critical** | Equip sadece `users.power` günceller; `attack`/`defense`/`max_health` base kolon; UI base okur | L | **FIXED** |
| 3 | Zindan sonuç ekranında XP bonus kırılımları yok | **P1 / High** | Bonuslar `enter_dungeon` içinde bake edilir; response’ta breakdown yok; UI sadece toplam XP | M | **FIXED** |
| 4 | Güçlendirme (upgrade) sayfası aşağı kaymıyor | **P1 / High** | Örs paneli sabit `Column` çocuğu; sayfa scroll yok; alt inset yetersiz + bottom overlay | M | **FIXED** |
| 5 | Chat butonu hizasındaki alanlar tıklanamıyor | **P1 / High** | `GameBottomBar` tam genişlik × `kGameBottomBarStackHeight` hit-test yutar (`ColoredBox` + Scaffold slot) | S | **FIXED** |

### Fix notes (2026-07-31)

- Migrations (applied linked remote):
  - `20261016_100000_equip_level_gate_stat_sync.sql`
  - `20261016_110000_enter_dungeon_xp_breakdown.sql`
  - `20261016_111000_attack_dungeon_xp_breakdown_passthrough.sql`
- Model A: `equip_bonus_*` + `sync_user_equipment_stats` on equip/unequip/swap/enhance.
- Client: level gate UX, enhancement bottom inset + anvil scroll, chat hit-test (`ColoredBox` removed), dungeon XP banner.

---

## 2. Issue 1 — Level gate broken

### Symptom
Level 10 oyuncu, `required_level = 55` ekipmanı (ör. mythic chest/legs) kuşanabiliyor. UI “SEVIYE Lv. 55” gösteriyor ama kuşanmayı engellemiyor.

### Repro hypothesis
1. Envanterde `required_level > player.level` bir item aç.
2. **KUSAN** bas.
3. Beklenen: red / hata. Gerçek: kuşanma başarılı, slot dolar, `power` artar.

### Root cause (file:line evidence)

**A) Server — canlı `equip_item` level kontrolü yok**

Canlı DB tanımı (MCP `execute_sql` / `pg_get_functiondef`):

- Ownership + slot swap + `is_equipped=true`
- `calculate_user_total_power` → `users.power` update
- **`required_level` / `users.level` karşılaştırması yok**
- Consumable / slot-match validasyonu da yok (eski migration’lardaki kontroller son overwrite’ta düşmüş)

Son overwrite migration:

```4:61:supabase/migrations/20260721_230000_gameplay_fixes_batch.sql
CREATE OR REPLACE FUNCTION public.equip_item(p_row_id uuid, p_slot text)
...
  SELECT row_id, item_id INTO v_item_record
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = v_user_id
...
  UPDATE public.users SET power = v_new_power::integer WHERE auth_id = v_user_id;
  RETURN jsonb_build_object('success', true, 'row_id', p_row_id, 'slot', p_slot);
```

Önceki `20260224_180000_fix_equip_validation.sql` consumable + slot match eklemişti; **level gate yine yoktu**. `20260721` ise o validasyonları da sildi → sadece collision/power kaldı.

**B) Client — gate yok**

- `InventoryNotifier.equipItem` → direkt RPC (`lib/providers/inventory_provider.dart:135-152`)
- `SupabaseInventoryRepository.equipItem` → `rpc('equip_item')` (`lib/repositories/inventory_repository.dart:140-158`)
- Detail panel `requiredLevel` **sadece display**:

```189:189:lib/screens/inventory/widgets/inventory_item_detail_panel.dart
      ('SEVIYE', 'Lv. ${item.requiredLevel}'),
```

- Equip enable koşulu sadece slot:

```315:360:lib/screens/inventory/widgets/inventory_item_detail_panel.dart
    final bool canEquip = item.equipSlot != EquipSlot.none;
    ...
    } else if (canEquip && actions.onEquip != null) {
      primaryLabel = 'KUSAN (${item.equipSlot.name.toUpperCase()})';
```

- `_handleEquip` level okumuyor (`lib/screens/inventory/inventory_screen.dart:191-204`)

**C) Data doğrulama**

Canlı `items` örnekleri: `chest_robe_mythic` → `required_level=55`, `health=35333`; `legs_leggings_mythic` → `required_level=55`, `health=25500`. Kolon dolu; gate kodu yok → “req_level ignored”.

**D) RLS**

Equip path `SECURITY DEFINER` RPC. Table RLS level gate sağlamaz. RLS bu bug’ın nedeni değil.

### Fix recommendation (concrete)

1. **Server (zorunlu):** `equip_item` içine:
   - `items` join → `required_level`, `equip_slot`, `type`
   - `users.level` (auth) ile karşılaştır
   - `IF v_player.level < COALESCE(v_item.required_level, 1) THEN RETURN jsonb_build_object('success', false, 'error', 'Level yetersiz. Gereken: N');`
   - Eski slot/consumable check’leri geri getir (regression)
2. **Client (UX):** Equip öncesi `profile.level < item.requiredLevel` → buton disable + mesaj; RPC error’ı göster.
3. **Opsiyonel:** Mevcut illegal equip’ler için one-shot audit SQL (unequip / warn).

### Effort
**M** (RPC rewrite + client gate + smoke)

### Test plan
- [ ] Lv10 + Lv55 item → RPC `success:false`, error level mesajı
- [ ] Lv55 + Lv55 item → başarı
- [ ] Slot mismatch / potion → reject
- [ ] Client: KUSAN disabled + snack
- [ ] QA: `inventory_equip_item` bot step illegal level ile FAIL bekler

---

## 3. Issue 2 — Stat bonuses not on character screen

### Symptom
HP (can) veren item kuşanılıyor; karakter ekranında Can Kapasitesi ~300 civarı kalıyor. ATK/DEF de item bonusunu yansıtmıyor. Power artıyor gibi (combat power formülü equip kullanıyor).

### Repro hypothesis
1. Base `max_health ≈ 300` karakter.
2. Yüksek `items.health` armor kuşan (ör. mythic chest `health=28000+`).
3. Karakter → Gelişim & Savaş: Can/ATK/DEF değişmez; Güç artabilir.

### Root cause (file:line evidence)

**A) Equip → sadece power cache**

Canlı / migration `equip_item`:

```58:59:supabase/migrations/20260721_230000_gameplay_fixes_batch.sql
    v_new_power := public.calculate_user_total_power(v_user_id);
  UPDATE public.users SET power = v_new_power::integer WHERE auth_id = v_user_id;
```

`attack`, `defense`, `health`, `max_health`, `luck` **güncellenmiyor**.

**B) Power formülü item.health’i “power’a” çevirir, max HP’ye değil**

```262:303:supabase/migrations/20260724_240000_monument_bonus_rpc_wiring.sql
CREATE OR REPLACE FUNCTION public.calculate_user_total_power(p_user_id UUID)
...
  SELECT COALESCE(SUM(public.calculate_item_power(...)), 0) INTO v_equipment_power
  FROM public.inventory i WHERE ... is_equipped = true;
...
  v_total_power := (v_equipment_power * v_stat_mult) + (level * 500) + ...
```

Client mirror:

```20:22:lib/core/utils/enhancement_stats.dart
  final double base =
      item.attack + item.defense + (item.health / 10.0) + (item.luck * 2.0);
```

Yani item `health=25500` → power’a `+2550` katkı; `users.max_health`’e **0**.

**C) Karakter UI base kolon okur**

```849:868:lib/screens/character/character_screen.dart
  Widget _buildCombatStats(...) {
    ...
      CharacterCombatStatsPanel(
        power: _fmtCompact(profile?.power ?? 0),
        health: profile?.health ?? 0,
        maxHealth: profile?.maxHealth ?? 0,
        attack: '${profile?.attack ?? 0}',
        defense: '${profile?.defense ?? 0}',
        luck: '${profile?.luck ?? 0}',
```

`profile.*` ← `users` satırı (`PlayerProfile.fromJson`). Equipped inventory aggregate **yok** (`character_screen` içinde `equippedItems` kullanımı yok).

**D) `max_health` nereden geliyor?**

- Class level-up: `health_per_level` (backup schema pattern)
- Stat allocation: `allocate_stat_points` → `max_health += health_gain` (`supabase/migrations/20260730_040000_stat_points_health_allocation.sql:73-81`)
- **Equipped item.health path yok**

**E) Cache?**

`loadProfile()` equip sonrası çağrılıyor (`inventory_provider.dart:130`) — stale cache ana sebep değil. Server hiç yazmıyor → refresh de base gösterir.

### Mimari boşluk (tasarım kararı)

İki tutarlı model mümkün; şu an **hiçbiri tamamlanmamış**:

| Model | Equip etkisi | Character UI |
|-------|--------------|--------------|
| **A. Materialize** | Equip/unequip `users.attack/defense/max_health` güncelle | Mevcut UI doğru çalışır |
| **B. Derived display** | `users` base kalsın; UI/RPC effective = base + Σ equipped (+enh) | UI + combat HP okuma değişmeli |

Bug: item kartı “CAN” gösteriyor (`inventory_item_detail_panel.dart:185`) ama effective combat/character pool’a bağlanmıyor.

### Fix recommendation (concrete)

Tercih önerisi: **Model A (server authoritative)** — dungeon/PvP zaten `users.max_health` / `users.attack` kullanıyor.

1. `sync_user_equipment_stats(p_auth_id)` helper:
   - base = class+level+allocated (veya `stat_allocated_*` + class baseline)
   - + Σ `enhancedStat(item.attack/defense/health/luck)` equipped
   - `UPDATE users SET attack=..., defense=..., max_health=..., luck=..., power=calculate_user_total_power(...)`
   - current `health` clamp `<= max_health`
2. `equip_item` / `unequip_item` / `swapEquip` / enhance-on-equipped sonunda `PERFORM sync_...`
3. Character panel: isteğe bağlı “base + ekipman” breakdown satırı
4. One-shot backfill: tüm kullanıcılar için sync

Alternatif B: UI’da aggregate; ama combat RPC’ler de effective okumalı — aksi halde display-only yalan.

### Effort
**L** (stat sync tasarımı + tüm equip path + backfill + combat regression)

### Test plan
- [ ] Equip HP item → `max_health` artar; unequip → geri
- [ ] Enhance equipped → stats/power sync
- [ ] Character Can Kapasitesi = DB `max_health`
- [ ] Dungeon/PvP damage floor yeni max ile
- [ ] Level gate (Issue 1) ile birlikte: illegal equip stats vermemeli

---

## 4. Issue 3 — Dungeon result XP bonuses visibility

### Symptom
Zindan zafer ekranında toplam XP var; “lonca XP bonusu +X”, karakter/sınıf XP kırılımı vb. görünmüyor.

### Repro hypothesis
1. Lonca anıtı seviye ≥5 oyuncu ile zindan kazan.
2. Sonuç: `TECRÜBE +N` tek sayı.
3. Lonca %XP satırı yok.

### Root cause (file:line evidence)

**A) Live battle path**

```192:215:lib/screens/dungeon/dungeon_battle_screen.dart
      final dynamic raw = await SupabaseService.client.rpc(
        'attack_dungeon',
        params: <String, dynamic>{'p_dungeon_id': _dungeonId},
      );
...
        final DungeonResult parsed =
            DungeonResult.fromJson(Map<String, dynamic>.from(raw));
```

`attack_dungeon` → `attack_dungeon_rl_inner` → **`enter_dungeon`**.

**B) Server bonus’ları bake ediyor, breakdown dönmüyor**

Canlı `enter_dungeon`:
- `_monument_xp_multiplier(p_player_id)` / `_monument_gold_multiplier` uygulanıyor (`[GKK_MONUMENT_BEGIN/END]`)
- Return keys: `xp_earned`, `gold_earned`, `reward_multiplier`, `is_critical`, `is_first_clear`, …  
- **Yok:** `xp_bonus_pct`, `monument_xp_bonus`, `bonus_breakdown`, `base_xp`, `class_xp_bonus`

Monument formül (`20260724_240000_monument_bonus_rpc_wiring.sql:8-39`):

- Lv≥5: +5%
- Lv≥50: +5%
- Lv≥75: +8%
- her 5 seviyede +0.2%

Örnek: anıt 25 → `_monument_xp_bonus_pct = 6.0` (canlı SQL doğrulandı).

Diğer XP çarpanları (enter_dungeon gövdesi / `20260614_010000_...`):
- Kritik zafer: ×1.5
- Luck: `1 + luck * 0.001`
- Farm `reward_multiplier` (`_dungeon_farm_reward_multiplier`)
- First clear ayrı flag (ödül çarpanı farm formülünde)

**C) Class “XP bonus” yok**

Canlı `character_classes.passive_bonuses`:
- warrior: `dungeon_success_bonus`, PvP/boss — **XP key yok**
- alchemist / shadow: craft/loot/pvp — **XP key yok**

“Karakter bonusu” UI beklentisi varsa: ya luck satırı, ya yok-ürün; class XP passive tanımlı değil.

**D) Result UI ne gösteriyor / ne eksik**

Gösterilen (`dungeon_battle_screen.dart` `_VictoryView` + `dungeon_result_widgets.dart`):
- Toplam XP / altın (`_RewardTile`)
- Kritik / ilk geçiş banner
- Kuşatma (siege) loot/gold banner
- Reputation buff banner
- Milestone
- Farm cezası (`reward_multiplier < 0.99`) — `DungeonResultBalanceNotes`

Eksik:
- Lonca anıtı XP % / mutlak +X
- Base XP vs final XP
- Luck XP katkısı
- (Varsa ileride) class XP

Model de breakdown alanı taşımıyor:

```417:451:lib/models/dungeon_model.dart
class DungeonResult {
  ...
  final int xpEarned;
  final double? rewardMultiplier;
  // no xpBonuses / monumentXp / baseXp
```

### Fix recommendation (concrete)

1. **`enter_dungeon` return genişlet:**
   ```json
   "xp_breakdown": {
     "base": 1000,
     "critical_mult": 1.5,
     "luck_mult": 1.02,
     "farm_mult": 1.0,
     "monument_pct": 6.0,
     "monument_xp": 92,
     "final": 1615
   }
   ```
2. `DungeonResult` + `DungeonXpBonusBanner` (TR: “Lonca anıtı XP +%6 (+92)”)
3. Kritik/ilk geçiş zaten var — breakdown ile çakışmayı netleştir
4. Class XP isteniyorsa önce `passive_bonuses` + RPC wiring (şu an data yok)

### Effort
**M** (RPC JSON + model + 1 widget)

### Test plan
- [ ] Anıt 0 → breakdown `monument_pct=0`, satır gizle
- [ ] Anıt 25 → UI “Lonca XP +%6” + final = bake
- [ ] Kritik + monument stack doğru
- [ ] Farm cezası notu + bonus satırları birlikte

---

## 5. Issue 4 — Upgrade page scroll broken

### Symptom
Güçlendirme (`/enhancement`) ekranında aşağı kaydırma çalışmıyor / içerik kesiliyor; alt envanter veya örs CTA’ya ulaşılamıyor.

### Repro hypothesis
1. `/enhancement` aç (özellikle küçük yükseklik / büyük safe-area).
2. Örs paneli + seçili eşya preview + indirim satırı → dikey dolu.
3. Sayfa scroll yok; sadece alt GridView scroll — örs kesilirse kurtarma yok.
4. Envanter son satırlar bottom nav/FAB altında kalır (inset kısa).

### Root cause (file:line evidence)

**Layout: sabit örs + Expanded envanter — sayfa scroll yok**

```618:634:lib/screens/enhancement/enhancement_screen.dart
        body: GameScreenBackground(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: <Widget>[
                _buildAnvilPanel(...),  // NOT scrollable
                const SizedBox(height: 10),
                Expanded(child: _buildInventoryPanel()),
              ],
            ),
          ),
        ),
```

Yorum da bunu söylüyor (`:569`): “üst sabit örs paneli + alt kaydırılabilir envanter”.

**Bottom clearance yetersiz**

```1251:1300:lib/screens/enhancement/enhancement_screen.dart
    final double bottomPad = MediaQuery.of(context).padding.bottom + 96;
...
                : GridView.builder(
                    padding: EdgeInsets.only(bottom: bottomPad),
```

Standart clearance:

```25:26:lib/components/layout/game_screen_background.dart
  static double bottomInset(BuildContext context) => gameBottomBarClearance(context);
```

```627:663:lib/components/layout/game_chrome.dart
const double kGameBottomBarStackHeight =
    kGameChatFabStackBottom + kGameChatFabSize; // 74+64 = 138
...
double gameBottomBarClearance(BuildContext context) {
  return gameBottomSafeInset(context) + kGameBottomBarOverlayHeight;
}
```

Enhancement: `padding.bottom + 96`  
Gerekli: `gameBottomSafeInset + 138` (≥ `padding.bottom + 138` genelde)  
→ **~42px+ kısa** → son satırlar FAB/nav altında; “kaymıyor” hissi + Issue 5 ile birleşince dokunulamaz.

**Overlay**

```613:617:lib/screens/enhancement/enhancement_screen.dart
        extendBody: true,
        bottomNavigationBar: GameBottomBar(
          currentRoute: AppRoutes.enhancement,
```

`extendBody: true` body’yi bar altına uzatır; yeterli padding yoksa içerik örtülür.

### Fix recommendation (concrete)

1. Body’yi `CustomScrollView` / tek `ListView` yap: örs `SliverToBoxAdapter`, envanter `SliverGrid` — **tüm sayfa scroll**.
2. Veya örs `Flexible`/`ConstrainedBox(maxHeight:)` + her iki bölge bağımsız scroll.
3. `bottomPad = GameScrollLayout.bottomInset(context)` (96 hardcode sil).
4. Küçük ekranda örs overflow → `SingleChildScrollView` fallback.

### Effort
**M**

### Test plan
- [ ] iPhone SE / küçük Android: örs CTA + envanter son hücre görünür & tıklanır
- [ ] Büyük ekran: layout bozulmaz
- [ ] Tutorial anchor (`enhanceForgeBtn`, inventory tile) scroll sonrası hit

---

## 6. Issue 5 — Click-through / hit-test near chat button

### Symptom
Chat FAB ile aynı yatay/dikey banttaki UI (envanter hücreleri, butonlar, liste sonu) tıklanamıyor. “Görünür ama ölü” alan.

### Repro hypothesis
1. Herhangi bir `GameBottomBar` + `extendBody: true` ekran.
2. Sağ alt FAB bandının **solunda** (görünür boşluk) veya FAB üstündeki içerikte tap.
3. Hit chat/nav katmanına gider veya yutulur; body aksiyonu tetiklenmez.

### Root cause (file:line evidence)

```833:1084:lib/components/layout/game_chrome.dart
    return ColoredBox(
      // alpha 0 → empty FAB band passes hits to body under extendBody.
      color: Colors.transparent,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: SizedBox(
          height: kGameBottomBarStackHeight, // full-width × 138
          child: Stack(
            children: <Widget>[
              Positioned( /* gradient IgnorePointer — OK */ ),
              Positioned( /* nav pill full width bottom */ ),
              ...
              Positioned(
                right: 6,
                bottom: kGameChatFabStackBottom,
                child: GameChatFab(), // 64×64 only on the right
              ),
```

Sorunlar:

1. **Yorum yanlış:** Flutter’da `ColoredBox(color: Colors.transparent)` hit-test’e katılır (alpha 0 “pass-through” değil).
2. **Scaffold `bottomNavigationBar` slot** çocuğun istediği yüksekliği (SafeArea + 138) tam genişlikte ayırır; body `extendBody` ile altta kalsa da pointer önce bar’a gider.
3. FAB sadece sağda 64×64; **üst bantta sol/orta boşluk** da aynı hit bölgesinde → “invisible overlay”.
4. Gradient `IgnorePointer` — doğru; ama parent `ColoredBox` / bar slot yine yer.

`GameChatFab` kendisi 64×64 (`game_chrome.dart:1272-1274`) — oversized FAB değil; **oversized parent stack**.

Home’da `StickyActionBar` sol FAB ayrı; sağ chat ile aynı stack yüksekliğini paylaşıyor → orta şerit de riskli.

### Fix recommendation (concrete)

1. `ColoredBox` kaldır; root’u `Stack` + `clipBehavior: Clip.none` yap.
2. Nav pill / FAB / leading’i **yalnızca kendi `Positioned` widget’ları** hit alsın; boş alan hit etmesin (`HitTestBehavior.deferToChild` / wrap yok).
3. İsteğe bağlı: FAB bandını `IgnorePointer(ignoring: true)` ile sar, çocuklarda `IgnorePointer(ignoring: false)`.
4. Smoke: enhancement/inventory alt-sağ hücre tap → item seçilir, chat açılmaz.

### Effort
**S**

### Test plan
- [ ] FAB sağ: chat açılır
- [ ] FAB solundaki boş bant: alttaki liste/item tap çalışır
- [ ] Nav pill tab’ları çalışır
- [ ] Tutorial nav spotlight bozulmaz

---

## 7. Shared / cross-cutting notes

### Equip ↔ Stats (Issue 1 + 2)
Aynı RPC yüzeyi: `equip_item` hem level gate hem stat sync eksik. Fix sırası:
1. Level gate (güvenlik/ekonomi)
2. Stat sync (progression fairness)
Aksi halde illegal high-level gear + (ileride) inflated HP/ATK stack’lenir.

### Power vs displayed stats
Power zaten equipment-aware; character ATK/DEF/HP değil. Oyuncu “güç arttı ama can aynı” → kafa karışıklığı beklenen semptom.

### Chat overlay ↔ Upgrade scroll (Issue 4 + 5)
İkisi de `GameBottomBar` / `kGameBottomBarStackHeight` / `extendBody`. Scroll inset fix tek başına yetmez; hit-test fix olmadan alt-sağ hâlâ ölü kalır.

### Dungeon XP path
Battle UI `attack_dungeon` kullanır ama XP hesabı `enter_dungeon` içinde. Breakdown eklerken **`enter_dungeon` return**’ü genişlet; `attack_dungeon_rl_inner` passthrough keys’i koru.

### Class XP
`passive_bonuses` içinde dungeon XP yok. UI’da “karakter XP bonusu” için önce design/seed gerekir; luck/monument/crit mevcut kaynaklar.

---

## 8. Suggested fix order

| Sıra | Issue | Neden |
|------|-------|--------|
| 1 | **#5 Chat hit-test** | S / global UX; scroll testlerini bozuyor |
| 2 | **#1 Level gate** | P0 ekonomi exploit; server-side zorunlu |
| 3 | **#4 Upgrade scroll** | #5 sonrası inset + sayfa scroll; aynı chrome |
| 4 | **#2 Stat sync** | P0 ama L; gate sonrası güvenli |
| 5 | **#3 XP breakdown UI** | P1; RPC JSON + banner; bağımsız |

---

## 9. Kanıt özeti (hızlı indeks)

| Konu | Kanıt |
|------|--------|
| Live `equip_item` no level | MCP `pg_get_functiondef('equip_item')` |
| Migration overwrite | `supabase/migrations/20260721_230000_gameplay_fixes_batch.sql` |
| Client no gate | `inventory_item_detail_panel.dart:315`, `inventory_provider.dart:135` |
| Item health not → max_health | `equip_item` only updates `power`; `enhancement_stats.dart:21` |
| Character UI base | `character_screen.dart:849-868` |
| Monument XP applied, no breakdown | live `enter_dungeon` + `20260724_240000_monument_bonus_rpc_wiring.sql` |
| Result UI totals only | `dungeon_battle_screen.dart:2098-2120`, `dungeon_model.dart:417+` |
| Enhancement non-page-scroll | `enhancement_screen.dart:621-633`, bottomPad `:1251` |
| Chat bar swallows hits | `game_chrome.dart:833-839`, `627-629`, FAB `:1080-1083` |

---

*Rapor sonu — implementasyon bu görevde yapılmadı.*

# Karmaşık Ekranlar — UI Yoğunluk Denetimi

**Tarih:** 2026-07-31  
**Workspace:** `/Users/selcuk/Documents/gkk-web/gkk_flutter`  
**Kapsam:** System2-era restriction UI + lonca klinik/anıt + envanter + zindan hub/battle + lonca savaş/kasa  
**Yöntem:** kaynak satır sayısı + birincil eylem / sekme / nested panel sayımı (kod okuma; canlı UX testi yok)  
**Kod değişikliği:** yok — sadece bu rapor

---

## 1. Özet

System2 sonrası **hastane / hapishane** tek “çıkış” ekranı olmaktan çıktı: birincil ödeme + 3–4 yan eylem + ward pano/sohbet footer. Lonca tarafında **klinik kartı** (donate / upgrade / band / service) + **üye görünümü** (savaş / anıt / kasa / klinik / üye listesi) aynı scroll’da birikiyor. Envanter + zindan battle dosya boyutu ve etkileşim çeşitliliğiyle ayrıca yüksek yük.

| Severity | Ekran | Kısa neden |
|----------|--------|------------|
| **HIGH** | Hastane / Hapishane (+ WardPanel) | 1 primary + 4 secondary + nested tabs footer |
| **HIGH** | Lonca üye görünümü + Klinik kart | Hub + klinik full dashboard aynı ListView |
| **HIGH** | Envanter (+ detail flow) | Drag/drop, filter, equip grid, çok aksiyonlu detail |
| **HIGH** | Zindan battle | Dev state machine / faz panelleri (~2.3k satır) |
| **MED** | Lonca anıt | Multi-resource donate + upgrade + contributor |
| **MED** | Lonca kasa | 3 tab (altın / eşya / geçmiş) + dağıtım diyaloğları |
| **MED** | Zindan hub | Zone tabs + siege meta + confirm + level gate |
| **MED** | Kuşatma hub | Slot / hold / prime / bonus yığını |
| **MED** | Lonca savaş hub | Tab + territory + defense sheet |

---

## 2. Detay tablosu

| # | Ekran | Path | ~LOC | Neden karmaşık | Severity | Sadeleştirme fikri (1 satır) |
|---|--------|------|-----:|----------------|----------|------------------------------|
| 1 | **Hastane** | `lib/screens/hospital/hospital_screen.dart` (+ `restriction_screen_ui.dart`, `ward_panel.dart`) | 490 + 943 + 687 | Aktifken: primary (ücretsiz/elmas taburcu) + doktor ziyareti + lonca doktor + reklam (−30dk) + gizli kaçış; footer **WardPanel** (PANO / SOHBET tabs, visibility chip’ler). Cognitive load = “nasıl çıkarım?” → 5 paralel cevap. | **HIGH** | Yan eylemleri “Daha fazla seçenek” sheet’e al; ward’ı ayrı route veya collapsed accordion. |
| 2 | **Hapishane** | `lib/screens/prison/prison_screen.dart` (+ aynı restriction/ward) | 516 | Aynı iskelet: primary kefalet (elmas) + gardiyan rüşvet (altın) + lonca avukat + reklam + kaçış + WardPanel. Tutorial anchor’lar ek gürültü. | **HIGH** | Hastane ile aynı: 1 net primary, riskli/şanslı yollar secondary sheet’te. |
| 3 | **Ward pano/sohbet** | `lib/components/restriction/ward_panel.dart` | 687 | Restriction footer içinde nested `TabBar` (PANO+SOHBET), board RPC + chat RPC, visibility toggles, scroll chat. Restriction zaten yoğun → footer ikinci uygulama gibi. | **HIGH** | Restriction ekranından ayır: “Koğuş” bottom sheet / kendi sayfası. |
| 4 | **Lonca klinik kartı** | `lib/screens/guild/widgets/guild_clinic_card.dart` | 969 | Full mode: seviye, soft %, band chip’ler, doktor/avukat service tile’lar, 3 pool bar, shared donate limit, 3 kaynak donate, upgrade CTA + role gate. Compact mode var ama guild’de full açılıyor. | **HIGH** | Guild’de sadece compact özet + “Klinik” detay ekranı; donate/upgrade orada. |
| 5 | **Lonca üye görünümü** | `lib/screens/guild/widgets/guild_member_view.dart` | 998 | Tek scroll hub: hero + command grid (savaş/anıt/kasa) + anıt progress teaser + kasa paneli + **GuildClinicCard full** + üye listesi + staff aksiyonlar. Bilgi + navigasyon + ekonomi aynı yüzeyde. | **HIGH** | Klinik + kasa özetini pill/CTA’ya indir; detayları mevcut alt ekranlara bırak. |
| 6 | **Lonca anıt** | `lib/screens/guild/guild_monument_screen.dart` + `widgets/guild_monument_ui.dart` | 541 + 551 | Çok kaynak donate (kind loop), miktar diyaloğu, upgrade progress panel, contributor satırları, vault-only gold kuralları UI’da açıklama yığını. | **MED** | Donate’i tek “Kaynak bağışla” picker’a indir; upgrade ayrı sticky CTA. |
| 7 | **Envanter** | `lib/screens/inventory/inventory_screen.dart` + `inventory_item_detail_flow.dart` + `inventory_item_detail_panel.dart` | 1378 + 800 + 560 | Filtre, equipped strip, drag-drop slot swap/unequip, tutorial bypass, box opening provider, detail: equip/use/sell/BOL/COP + name scroll. Bir item → çok dal. | **HIGH** | Detail’de context’e göre 1 primary + overflow menü; drag-drop’u advanced mode. |
| 8 | **Zindan hub** | `lib/screens/dungeon/dungeon_screen.dart` (+ zone tab bar, siege panel, confirm dialog) | 642 (+widgets) | Zone tabs, level gate, power, restriction blok, siege slot/hold/prime hints, featured cave, confirm entry diyaloğu. Liste + meta + event overlay. | **MED** | Siege bilgisini kart badge + ayrı hub’a taşı; confirm’de sadece cost/risk. |
| 9 | **Zindan battle** | `lib/screens/dungeon/dungeon_battle_screen.dart` | 2326 | Faz state machine, header, success/fail, stat duel panel, loot/result UI — tek dosyada aşırı yoğun. LOC tek başına cognitive + bakım yükü. | **HIGH** | Faz widget’larını dosyalara böl; oyuncu yüzünde tek “Saldır / sonuç” odağı. |
| 10 | **Kuşatma hub** | `lib/screens/dungeon/dungeon_siege_hub_screen.dart` | 888 | Slot occupancy, hold break, prime window, farm/defense bonus, leaderboard satırları — çok kavram aynı ekranda. | **MED** | “Durum / Slotlar / Sıralama” 3 sekme; prime dışı UI’ı sadeleştir. |
| 11 | **Lonca kasa** | `lib/screens/guild/guild_vault_screen.dart` | 1229 | Tab: Altın / Eşyalar / Geçmiş; equal + targeted gold dağıt; item dağıt; tax/ledger filtre. Rol + ekonomi + envanter köprüsü. | **MED** | Üye için read-only özet; dağıtımı leader-only alt akış. |
| 12 | **Lonca savaş hub** | `lib/screens/guild_war/guild_war_hub_screen.dart` (+ attack / defense sheet) | 579 (+248 +205) | Turnuva/territory tab’lar, attack push, defense sheet — savaş dili + ekonomi bonusları. | **MED** | Hub’da sadece aktif savaş + 1 CTA; detay attack ekranında kalsın. |

---

## 3. System2 restriction — eylem yığını (referans)

Aktif restriction panel (`RestrictionActivePanel`):

| Katman | Hastane | Hapishane |
|--------|---------|-----------|
| Primary | Ücretsiz taburcu **veya** elmas taburcu | Elmas kefalet |
| Secondary grid | Doktor · Lonca doktor · Reklam · Kaçış | Rüşvet · Lonca avukat · Reklam · Kaçış |
| Footer | `WardPanel` (PANO / SOHBET) | aynı |
| Paylaşılan UI | `restriction_screen_ui.dart` (~943 LOC) | aynı |

**Not:** Reklam tile `MockAdService.allowMockReward` ile koşullu; prod’da da reklam açıksa grid 4 tile kalır.

---

## 4. Lonca hub yığılımı

`GuildMemberView` scroll sırası (yoğunluk kaynağı):

1. Hero (rol, online, min power)
2. Command grid → Savaş / Anıt / Kasa
3. Anıt upgrade teaser (tekrar anıt’a gider)
4. Kasa özet paneli (+ eşya pill)
5. **Klinik full card** (donate + upgrade + bands)
6. Üye listesi + staff aksiyonlar

→ Oyuncu “loncaya bakayım” derken ekonomi dashboard’una düşüyor.

---

## 5. Öncelik önerisi (sadeleştirme sırası)

1. **P0 — Restriction:** Hastane/Hapishane secondary + Ward ayır (en yüksek “çok karmaşık” hissi).  
2. **P0 — Lonca hub:** `GuildClinicCard` full’ü guild scroll’dan çıkar.  
3. **P1 — Envanter detail:** aksiyon overflow.  
4. **P1 — Battle dosya parçalama** (UX + maintainability).  
5. **P2 — Anıt / Kasa / Siege / Guild war** sekme veya progressive disclosure.

---

## 6. Bilinçli dışarıda bırakılanlar

- Auth / tutorial tek CTA ekranları — yoğun değil.  
- `guild_screen.dart` ince router (~265 LOC) — karmaşıklık child view’da.  
- Shop / horse race / BP — bu turda System2 + guild/dungeon/inventory odaklı; ayrı audit gerekirse eklenebilir.

---

## 7. Kanıt (dosya boyutları)

```
490   hospital_screen.dart
516   prison_screen.dart
687   ward_panel.dart
943   restriction_screen_ui.dart
969   guild_clinic_card.dart
998   guild_member_view.dart
541   guild_monument_screen.dart
551   guild_monument_ui.dart
1378  inventory_screen.dart
800   inventory_item_detail_flow.dart
560   inventory_item_detail_panel.dart
642   dungeon_screen.dart
2326  dungeon_battle_screen.dart
888   dungeon_siege_hub_screen.dart
1229  guild_vault_screen.dart
579   guild_war_hub_screen.dart
```

*(wc -l, 2026-07-31)*

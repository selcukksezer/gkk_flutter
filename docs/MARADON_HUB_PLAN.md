# GKK Moradon Hub — Knight Online Tarzı Canlı Ana Meydan Planı

Login ve karakter seçimi (`savasci`, `golge`, `simyaci`) sonrasında açılan `/home` (`lib/screens/home/home_screen.dart`) ekranını statik bir menü olmaktan çıkarıp, **Knight Online — Moradon** ruhuna sahip; oyuncuların birbirini canlı gördüğü, pazar kurabildiği, NPC'lerle ve diğer oyuncularla etkileşime geçtiği **2.5D İzometrik Canlı Şehir Meydanı** haline getirme planıdır.

---

## 1. Mimari Genel Bakış

1. **Blender MCP + CC0 Asset Hattı (`assets/moradon/`)**:
   - Computer Use / PowerShell ile Blender 5.0 başlatılır, `blender_mcp` (`localhost:9876`) aktif edilir.
   - Poly Haven & Poly Pizza (CC0 ticari lisanslı) dokular/modeller + Blender Python (`bpy`/`bmesh`) prosedürel modelleme ile Moradon meydanı, Magic Anvil, Teleport Gate, Inn/Banka, Pazar Tezgahı, Arena Sancağı ve karakter auraları üretilir.
   - İzometrik (60°/45°) kameradan yüksek kaliteli şeffaf PNG render'lar doğrudan `assets/moradon/` dizinine alınır.
2. **Çok Oyunculu Katman (`Supabase Realtime — moradon_town_1`)**:
   - **Presence**: Meydandaki oyuncuların anlık konumu (`x, y`), sınıfı (`savasci`, `golge`, `simyaci`), kullanıcı adı, loncası, gücü (`totalPower`), silah parlama seviyesi ve pazar durumu (`isMerchant`, `merchantTitle`).
   - **Broadcast**: `player_move` (yumuşak `lerp` yürüyüş), `chat_bubble` (5 saniyelik baş üstü konuşma balonu), `emote`.
   - **Canlı Meydan Simülasyonu**: Gerçek oyuncularla birlikte meydanda devriye gezen muhafızlar ve ortam pazar tezgahları.
3. **Flutter 2.5D Sahne Motoru (`lib/screens/home/moradon/`)**:
   - Y-Sorting (derinlik sıralamalı) 60 FPS sahne, kamera takibi, Tap-to-Move + Virtual Joystick.
   - NPC'lere tıklayınca yürüme ve Knight Online tarzı NPC diyalog/işlem menüsü.
   - Diğer oyunculara tıklayınca **Hedef Halkası (Target Ring)** ve **Etkileşim Menüsü** (Profil, PvP Düello, Ticaret, Pazar Tezgahı, Mesaj, Arkadaş Ekle).
   - Sağ üstte **Mini-Map (Radar)**, **Town (Merkeze Işınlan)** ve **Klasik HUD Görünümü** geçiş anahtarı.
   - Mevcut `TutorialAnchorId.homePromo`, `TutorialAnchorId.homeHero`, `DailyRewardDialog`, `ComebackSummaryDialog` ve `_WarningStack` (Hastane/Hapis) yapılarını %100 korur.

---

## 2. Üretilecek Moradon Yapıları ve Oyun İçi Rotaları

| Yapı / NPC | Oyun İçi İşlevi & Bağlı Rotalar | Çıktı Dosyası |
| :--- | :--- | :--- |
| **Meydan Zemini & Çevre** | Moradon taş avlusu, merdivenler, meşaleler | `assets/moradon/map_ground.png` |
| **Merkez Moradon Anıtı** | Spawn noktası (Town) & Pantheon Sıralaması (`AppRoutes.leaderboard`) | `assets/moradon/monument_center.png` |
| **Magic Anvil (Demirci Kael)** | Eşya Geliştirme (+Basma) & Üretim (`AppRoutes.enhancement`, `AppRoutes.crafting`) | `assets/moradon/npc_anvil.png` |
| **Teleport Gate (Boyut Kapısı)** | Zindan, Kuşatma & Boss (`AppRoutes.dungeon`, `AppRoutes.dungeonSiegeHub`) | `assets/moradon/npc_teleport_gate.png` |
| **Grand Inn (Bankacı & Kasa)** | Banka, Envanter & Tesisler (`AppRoutes.bank`, `AppRoutes.inventory`, `AppRoutes.facilities`) | `assets/moradon/npc_inn_bank.png` |
| **Moradon Pazarı (Tüccar)** | Oyuncu Pazarı, Ticaret & Dükkan (`AppRoutes.market`, `AppRoutes.trade`, `AppRoutes.shop`) | `assets/moradon/npc_market_hub.png` |
| **Oyuncu Pazar Tezgahı** | "Pazar Kur" moduna geçen oyuncuların tezgah görünümü | `assets/moradon/merchant_stall.png` |
| **Arena & Klan Sancağı** | PvP Arena, Lonca & Lonca Savaşı (`AppRoutes.pvp`, `AppRoutes.guild`, `AppRoutes.guildWar`) | `assets/moradon/npc_arena_clan.png` |
| **Muhafız Yüzbaşı (Görev)** | Görevler, Kodeks, Hastane & Hapis (`AppRoutes.quests`, `AppRoutes.codex`, `AppRoutes.hospital`, `AppRoutes.prison`) | `assets/moradon/npc_captain.png` |
| **Gece Kulübü & Hipodrom** | Mekanlar, At Yarışı & Ganimet (`AppRoutes.mekans`, `AppRoutes.horseRace`, `AppRoutes.loot`) | `assets/moradon/npc_entertainment.png` |

---

## 3. Uygulama Fazları

- **Faz 1**: Blender 5.0'ı başlatıp MCP (`port 9876`) bağlantısını kurma ve Python + CC0 kütüphaneleriyle tüm izometrik Moradon asset'lerini `assets/moradon/` dizinine render etme.
- **Faz 2**: `lib/models/moradon_models.dart` ve `lib/providers/moradon_hub_provider.dart` (Supabase Realtime Presence/Broadcast + yerel ortam nüfusu) kodlama.
- **Faz 3**: `lib/screens/home/moradon/moradon_world_view.dart` ve `moradon_hud_overlay.dart` (2.5D Y-sorted sahne, Tap-to-Move, Joystick, Mini-Map, NPC & Oyuncu menüleri, Pazar Kurma, Baş üstü sohbet balonları) kodlama.
- **Faz 4**: `lib/screens/home/home_screen.dart` entegrasyonu, `pubspec.yaml` asset kaydı ve `flutter analyze` / test doğrulaması.

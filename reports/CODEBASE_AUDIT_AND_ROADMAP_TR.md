# GKK Flutter Oyun Kod Tabanı Analizi, Yapı, Eksikler ve Öneri Raporu

## 1. Kod Tabanı Mimarisi (Architectural Overview)

Proje, Flutter (Dart SDK ^3.8.0) kullanılarak geliştirilmiş, backend tarafında Supabase RPC ve PostgreSQL mimarisiyle çalışan kapsamlı bir MMORPG / Rol Yapma (RPG) oyunudur.

### Klasör / Katman Yapısı:
- **`lib/core/`**: Uygulama sabitleri (`constants`), hata yönetimi (`errors`), matchmaking, Supabase servis katmanı (`services`), öğretici (`tutorial`) ve genel araçlar (`utils`).
- **`lib/models/`**: Oyundaki tüm veri modelleri (`InventoryItem`, `PlayerModel`, `DungeonModel`, `MekanModel`, `GuildModel`, `DungeonSiegeModel`, `CraftingModel`, `PvPModel`, vb.). Modeller `freezed` ve `json_serializable` kullanılarak immutability prensibine uygun tanımlanmıştır.
- **`lib/providers/`**: Riverpod state management sağlayıcıları (StateNotifierProvider / Provider). Kullanıcı profilinden (PlayerProvider) loncaya, pazara, zindan kuşatmasına kadar tüm durumlar Riverpod ile reaktiftir.
- **`lib/repositories/`**: Supabase veritabanı / RPC çağrılarını sarmalayan repository sınıfları. Sunucu güvenliğini korumak amacıyla doğrudan veritabanı yazma işlemleri yerine RPC (Remote Procedure Calls) kullanılır.
- **`lib/screens/`**: UI ekranları. Modüler olarak ayrılmıştır:
  - `home/`, `character/`, `inventory/`, `dungeon/`, `pvp/`, `guild/`, `guild_war/`, `mekans/`, `crafting/`, `enhancement/`, `facilities/`, `market/`, `shop/`, `loot/`, `bank/`, `trade/`, `quests/`, `hospital/`, `prison/`, `chat/`, `settings/`, `staff/`, `support/`.
- **`lib/routing/`**: `go_router` bazlı sayfa geçiş ve yönlendirme yönetimi (`app_router.dart`).
- **`mdplans and prompts/`**: Oyunun 13 aşamalı master planlarını ve ekonomi/mekanik dokümantasyonlarını barındıran strateji rehberleri (`MASTER_GAMEPLAN.md`, `PLAN_01` ile `PLAN_13` arası).

---

## 2. Mevcut Sistemlerin Durumu (Current Feature Map)

1. **Envanter ve Eşya Yönetimi**:
   - 30 slotlu çanta yapısı, sürükle-bırak (drag-drop) slot değişimi, eşya kuşanma/çıkarma.
   - Stat sıfırlama parşömeni, isim değiştirme parşömeni, detoks iksirleri, loot box açma.
2. **Karakter ve Kodex**:
   - Karakter sınıfı seçimi, stat dağıtımı (Güç, Çeviklik, Dayanıklılık, Şans vb.).
   - Kodex (Koleksiyon) sistemi: Toplanan itemlerle unvan ve kalıcı bonus kazanma.
3. **Zindan & Zindan Kuşatması (Dungeon Siege)**:
   - PvE zindan savaşları (Normal & Boss).
   - Zindan Kuşatması: Loncaya veya bireysel bölge kontrolüne dayalı süre sınırlı PvPvE kuşatma mekaniği ve pasif altın/stat geliri.
4. **Mekan (İşletme) & Tesisler (Facilities)**:
   - Mekan kurma/yönetme, mekan arenası savaşları, müşteri çekme ve seviye atlatma.
   - Tesis üretimi (Çiftlik, Maden vb.) ve üretim kuyruğu.
5. **Lonca & Lonca Savaşları & Lonca Anıtı**:
   - Lonca kurma/katılma, Lonca kasası, Lonca turnuvaları ve Lonca Anıtı bağış/bafer mekanizması.
6. **Ekonomi & Pazar & Gece Pazarı**:
   - Pazarda eşya alım-satım emirleri, Pazar Kutsamaları.
   - Rastgele zamanlarda açılan Gece Pazarı ve özel ürün indirimleri.
7. **Diğer Aktiviteler**:
   - At Yarışı (Adil şans algoritmaları ve bahis).
   - Hastane / Hapishane (Detoks ve kaçış mekanizmaları).
   - Görevler, Savaş Geçidi (Battle Pass), Günlük Ödüller, İtibar Mağazası.

---

## 3. Tespit Edilen Eksikler ve Geliştirilmesi Gereken Alanlar (Gaps & Areas of Improvement)

### A. Kod & Test Seviyesindeki Eksikler (Düzeltildi)
- `FakeInventoryRepository` içinde `useNameChangeScroll` metodu eksikti, bu durum test derleme hatasına yol açıyordu (Düzeltildi).
- `test/rpc_test.dart` giriş noktası eksik `main()` fonksiyonu nedeniyle hata veriyordu (Düzeltildi).
- `SmokeRouteRegistry` içindeki hızlı menü rota sayısı ile test iddiası arasındaki uyuşmazlık güncellendi.

### B. Oyun İçi Yapısal ve Deneyim Eksikleri
1. **Dinamik Ses ve VFX Geri Bildirimleri**:
   - `audioplayers` paketi eklenmiş ancak zindan darbeleri, eşya yükseltme (enhancement) başarı/başarısızlık ses efektleri ve mekanik UI dokunuşlarında ses geri bildirimleri eksik veya sınırlı.
2. **Kuşatma (Dungeon Siege) Canlı Ticker ve Anlık Bildirimler**:
   - Zindan kuşatması sırasında bölge el değiştirdiğinde oyunculara anlık (Realtime Push/WebSocket) uyarı gönderimi zenginleştirilebilir.
3. **Pazar (Market) Grafikleri ve Fiyat Trendleri**:
   - Pazar nesnelerinin fiyat geçmişini gösteren basit çizgi grafikleri (Price Trend Charts) oyuncuların ticaret deneyimini artıracaktır.
4. **Offline Progress / Afk Gelir Toplama Görselleştirmesi**:
   - Oyuncu geri döndüğünde gösterilen "Comeback Summary" diyaloğuna daha detaylı tesis ve mekan kazancı görsel özeti eklenebilir.

---

## 4. Önerilen Yeni Özellikler ve Yol Haritası (What Can Be Added)

1. **Dünya Boss'u (World Boss / Raids)**:
   - Belirli gün ve saatlerde ortaya çıkan, tüm sunucunun ortak canlı puf (HP) havuzuna saldırdığı devasa boss savaşları. Toplam verilen hasara göre ödül dağıtımı.
2. **Ateşli Ticaret / Kervan Sistemi (Trade Caravans)**:
   - Mekanlar ve şehirler arası mal taşıma kervanları. Başka oyuncuların kervanlara saldırması (PvP Yağma) veya koruma olarak kiralık asker verilmesi.
3. **Ekipman Set Bonusları (Set Effects)**:
   - Aynı setten 2/4/6 parça giyildiğinde aktif olan özel aura veya pasif yetenekler (örneğin: Ejderha Seti -> %10 Ateş Hasarı + %5 Kritik).
4. **Simya & Büyüleme (Enchanting / Gem Socketing)**:
   - Yüksek seviye eşyalara soket açıp mücevher (Gem) takma veya özel rünlerle ek özellikler yükleme.
5. **Dostluk Seviyeleri ve İttifak Görevleri (Co-op Quests)**:
   - İki oyuncunun ortaklaşa tamamlayabileceği günlük Zindan Co-Op modları.

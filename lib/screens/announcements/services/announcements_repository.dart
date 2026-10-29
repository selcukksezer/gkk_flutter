import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/live_ticker_model.dart';
import '../../../providers/live_ticker_provider.dart';
import '../../../theme/app_colors.dart';
import '../models/announcement_models.dart';

/// Repository managing curated announcements, live ticker feeds,
/// read-status tracking, and event gift claims with SharedPreferences persistence.
class AnnouncementsRepository {
  AnnouncementsRepository({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const String _readKey = 'aion2_announcements_read_set';
  static const String _claimedKey = 'aion2_announcements_claimed_gifts';

  Set<String> _readIds = <String>{};
  Set<String> _claimedGiftIds = <String>{};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final SharedPreferences prefs = _prefs ?? await SharedPreferences.getInstance();
    final List<String>? storedRead = prefs.getStringList(_readKey);
    if (storedRead != null) {
      _readIds = storedRead.toSet();
    }
    final List<String>? storedClaimed = prefs.getStringList(_claimedKey);
    if (storedClaimed != null) {
      _claimedGiftIds = storedClaimed.toSet();
    }
    _initialized = true;
  }

  bool isRead(String id) => _readIds.contains(id);

  bool isGiftClaimed(String announcementId) => _claimedGiftIds.contains(announcementId);

  Future<void> markAsRead(String id) async {
    if (_readIds.contains(id)) return;
    _readIds.add(id);
    final SharedPreferences prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey, _readIds.toList());
  }

  Future<void> markAllAsRead(List<String> ids) async {
    _readIds.addAll(ids);
    final SharedPreferences prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey, _readIds.toList());
  }

  Future<bool> claimGift(String announcementId) async {
    if (_claimedGiftIds.contains(announcementId)) return false;
    _claimedGiftIds.add(announcementId);
    final SharedPreferences prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setStringList(_claimedKey, _claimedGiftIds.toList());
    return true;
  }

  /// Official Curated 2027 Aion 2 Events & Patch Notes.
  static final List<AnnouncementItem> curatedAnnouncements = <AnnouncementItem>[
    AnnouncementItem(
      id: 'patch_2_4_0',
      title: 'Aion 2: Uçurumun Hükümdarları (v2.4.0)',
      subtitle: '3D Impeller shader motoru, Uçurum Zindanı ve devrimsel sınıf dengeleri yayında!',
      versionTag: 'v2.4.0',
      type: AnnouncementType.patchNotes,
      isHeroBanner: true,
      accentColor: AppColors.liquidGold,
      badgeLabel: 'BÜYÜK GÜNCELLEME',
      bannerGradient: const <Color>[
        Color(0xFF2E1C0C),
        Color(0xFF1B2A4A),
        Color(0xFF080B12),
      ],
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
      eventStartTime: DateTime.now().subtract(const Duration(hours: 3)),
      eventEndTime: DateTime.now().add(const Duration(days: 7)),
      isClaimable: true,
      rewards: const <EventRewardItem>[
        EventRewardItem(
          id: 'reward_abyss_chest',
          name: 'Uçurum Kaşif Sandığı',
          icon: '🎁',
          quantity: 1,
          rarity: 'epic',
          description: 'Nadir ekipman geliştirme kristalleri ve kadim cevherler barındırır.',
        ),
        EventRewardItem(
          id: 'reward_gold_5000',
          name: '5.000 Saf Altın',
          icon: '🪙',
          quantity: 5000,
          rarity: 'rare',
          description: 'Demirci ve pazaryeri takaslarında geçerli kraliyet sikkesi.',
        ),
        EventRewardItem(
          id: 'reward_gems_100',
          name: '100 Yıldız Elması',
          icon: '💎',
          quantity: 100,
          rarity: 'legendary',
          description: 'Astra ve kozmetik parşömenlerde kullanılan ilahi para birimi.',
        ),
      ],
      contentMarkdown: '''
# ⚔️ Aion 2: Uçurumun Hükümdarları v2.4.0

Değerli Daevalar,
Atreia dünyası yepyeni bir boyuta ulaşıyor! Modern **3D Impeller motoru** ve **10.000 oyuncu Spatial Hash Grid** mimarimizle mobil MMO standartlarını yeniden yazıyoruz.

---

### 🌟 Öne Çıkan Başlıklar

* **[YENİ] Uçurum Yarığı Zindanı:** 5 katmanlı dinamik boss mücadeleleri ve kadim Dragon Emperor relikleri.
* **[GÖRSEL] 2027 AAA Shader Hattı:** ACES Tonemapping, Volümetrik Sis ve PBR zemin ıslaklık yansımaları.
* **[SAVAŞ] Vuruş Hissi 2.0:** 40ms Mikro Hit-Stop, Yönlü Ekran Sarsıntısı ve Dokunsal Geri Bildirim (Haptics).
* **[PERFORMANS] Akıllı Ön Yükleyici:** 2ms/kare bütçeli arka plan varlık akışı; düşük sistemli cihazlarda 60 FPS garantisi.

---

### 🛡️ Sınıf Dengeleri & Değişiklikler

* **Gladiator:** *Dönen Kılıç Fırtınası* hasar çarpanı **%18 artırıldı**.
* **Sorcerer:** *Alev Küresi* mana tüketimi **%12 azaltıldı**, patlama yarıçapı genişletildi.
* **Templar:** *Demir Kalkan Duruşu* sırasında alınan kritik hasar **%25 düşürüldü**.
* **Assassin:** Gölge Adımı bekleme süresi **14sn'den 12sn'ye** çekildi.

---

### 🎁 Etkinlik Hediyesi
Bu yama kutlaması adına tüm oyuncularımıza **Uçurum Kaşif Sandığı** ve **100 Yıldız Elması** hediye ediyoruz. Sayfanın altındaki veya bannerdaki butona tıklayarak hemen talep edebilirsiniz!
''',
    ),
    AnnouncementItem(
      id: 'event_solorius_festival',
      title: 'Karanlık Solorius Şenliği & Ejderha Tapınağı',
      subtitle: 'Kuşatma bosslarına karşı birleşin; çifte EXP ve efsanevi kanat kozmetikleri kazanın!',
      versionTag: 'ETKİNLİK',
      type: AnnouncementType.event,
      isHeroBanner: true,
      accentColor: AppColors.cyberFuchsia,
      badgeLabel: 'CANLI ETKİNLİK',
      bannerGradient: const <Color>[
        Color(0xFF380826),
        Color(0xFF161538),
        Color(0xFF080B12),
      ],
      publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
      eventStartTime: DateTime.now().subtract(const Duration(hours: 12)),
      eventEndTime: DateTime.now().add(const Duration(days: 2, hours: 14, minutes: 30)),
      isClaimable: true,
      rewards: const <EventRewardItem>[
        EventRewardItem(
          id: 'reward_wings_skin',
          name: 'Solorius Yıldız Kanatları',
          icon: '🪽',
          quantity: 1,
          rarity: 'mythic',
          description: 'Karanlık göklerde ışıldayan efsanevi festival kanat kozmetiği.',
        ),
        EventRewardItem(
          id: 'reward_exp_potion',
          name: 'Büyük Tecrübe İksiri x5',
          icon: '🧪',
          quantity: 5,
          rarity: 'rare',
          description: '2 saat boyunca zindan ve canavar tecrübesini %50 artırır.',
        ),
      ],
      contentMarkdown: '''
# ❄️ Karanlık Solorius Şenliği Başladı!

Atreia kış gökleri kadim ejderha auralarıyla kaplandı. 3 gün sürecek şenlik boyunca tüm Daevalar özel etkinlik görevlerini tamamlayarak eşsiz ganimetler kazanabilir.

---

### 🕒 Etkinlik Takvimi & Kurallar

* **Tarih:** 28 Ekim - 31 Ekim 2026
* **Çifte EXP Saatleri:** Her gün 18:00 - 22:00 (Sunucu Saati)
* **Tapınak Akınları:** Günde 2 kez Ejderha Lordu Tapınağı kapıları açılır.

---

### 🏆 Ödül Detayları
Etkinliğe giriş yapan her savaşçı tek dokunuşla **Solorius Yıldız Kanatları** parşömenini alabilir.
''',
    ),
    AnnouncementItem(
      id: 'event_night_market_frenzy',
      title: 'Gece Pazarı: Gizemli Tüccar İndirimleri',
      subtitle: 'Gezgin tüccar kamp meydanında! Efsanevi taşlarda %40 kupon indirimi.',
      versionTag: 'FLAS ETKİNLİK',
      type: AnnouncementType.event,
      isHeroBanner: true,
      accentColor: AppColors.accentCyan,
      badgeLabel: 'SON SAATLER',
      bannerGradient: const <Color>[
        Color(0xFF0A2B35),
        Color(0xFF131B32),
        Color(0xFF080B12),
      ],
      publishedAt: DateTime.now().subtract(const Duration(hours: 18)),
      eventStartTime: DateTime.now().subtract(const Duration(hours: 18)),
      eventEndTime: DateTime.now().add(const Duration(hours: 5, minutes: 42)),
      isClaimable: false,
      contentMarkdown: '''
# 🌙 Gece Pazarı Gezgin Tüccarı Meydanda!

Yıldızların en parlak olduğu bu gecede, gizemli karavan kamp merkezine yanaştı.

### 💰 Fırsatlar:
* Tüm geliştirme taşlarında **%40 indirim**.
* Nadir zırh kalıpları sınırlı stokla satışta.
* Etkinlik sona ermeden Gece Pazarı sekmesini ziyaret etmeyi unutmayın.
''',
    ),
    AnnouncementItem(
      id: 'notice_fair_play_siege',
      title: 'Kuşatma Savaşları & Adil Oyun İlkeleri',
      subtitle: 'Lonca kuşatmalarında makro ve üçüncü parti araçlara karşı sıfır tolerans politikası.',
      versionTag: 'DUYURU',
      type: AnnouncementType.broadcast,
      isHeroBanner: false,
      accentColor: AppColors.toxicNeon,
      badgeLabel: 'GÜVENLİK',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      contentMarkdown: '''
# 🛡️ Adil Oyun & Kuşatma Kuralları

Sunucumuzda rekabetin dürüstlüğünü korumak adına otomatik tespit sistemimiz 7/24 devrededir.

* Makro ve yetkisiz istemci müdahaleleri anında kalıcı yasaklama ile sonuçlanır.
* Kuşatma bölgelerindeki şüpheli durumları ekran görüntüsü veya video ile moderatör ekibimize iletebilirsiniz.
''',
    ),
  ];

  /// Merges curated announcements with live server ticker archive items.
  List<AnnouncementItem> getMergedAnnouncements({
    required List<LiveTickerItem> tickerArchive,
    String filter = 'all',
  }) {
    final List<AnnouncementItem> all = <AnnouncementItem>[
      ...curatedAnnouncements,
      ...tickerArchive.map((LiveTickerItem ticker) => AnnouncementItem.fromLiveTickerItem(ticker)),
    ];

    switch (filter) {
      case 'unread':
        return all.where((AnnouncementItem item) => !isRead(item.id)).toList();
      case 'event':
        return all.where((AnnouncementItem item) => item.type == AnnouncementType.event).toList();
      case 'patchNotes':
        return all.where((AnnouncementItem item) => item.type == AnnouncementType.patchNotes).toList();
      case 'server':
        return all.where((AnnouncementItem item) => item.type == AnnouncementType.liveTicker).toList();
      case 'all':
      default:
        return all;
    }
  }

  int getUnreadCount(List<AnnouncementItem> items) {
    return items.where((AnnouncementItem item) => !isRead(item.id)).length;
  }
}

/// Riverpod Provider for AnnouncementsRepository.
final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  final AnnouncementsRepository repo = AnnouncementsRepository();
  repo.init();
  return repo;
});

/// State for the Announcements portal.
class AnnouncementsScreenState {
  const AnnouncementsScreenState({
    this.filter = 'all',
    this.unreadCount = 0,
    this.claimedIds = const <String>{},
    this.readIds = const <String>{},
    this.lastUpdated,
  });

  final String filter;
  final int unreadCount;
  final Set<String> claimedIds;
  final Set<String> readIds;
  final DateTime? lastUpdated;

  AnnouncementsScreenState copyWith({
    String? filter,
    int? unreadCount,
    Set<String>? claimedIds,
    Set<String>? readIds,
    DateTime? lastUpdated,
  }) {
    return AnnouncementsScreenState(
      filter: filter ?? this.filter,
      unreadCount: unreadCount ?? this.unreadCount,
      claimedIds: claimedIds ?? this.claimedIds,
      readIds: readIds ?? this.readIds,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Controller managing portal interactive state.
class AnnouncementsController extends Notifier<AnnouncementsScreenState> {
  late AnnouncementsRepository _repo;

  @override
  AnnouncementsScreenState build() {
    _repo = ref.watch(announcementsRepositoryProvider);
    _syncState();
    return const AnnouncementsScreenState();
  }

  Future<void> _syncState() async {
    await _repo.init();
    final LiveTickerState tickerState = ref.read(liveTickerProvider);
    final List<AnnouncementItem> items = _repo.getMergedAnnouncements(
      tickerArchive: tickerState.feedArchive,
      filter: state.filter,
    );
    state = state.copyWith(
      unreadCount: _repo.getUnreadCount(items),
      claimedIds: _repo._claimedGiftIds,
      readIds: _repo._readIds,
      lastUpdated: DateTime.now(),
    );
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
    _syncState();
  }

  Future<void> markAsRead(String id) async {
    await _repo.markAsRead(id);
    await _syncState();
  }

  Future<void> markAllAsRead(List<String> ids) async {
    await _repo.markAllAsRead(ids);
    await _syncState();
  }

  Future<bool> claimGift(String announcementId) async {
    final bool claimed = await _repo.claimGift(announcementId);
    if (claimed) {
      await _syncState();
    }
    return claimed;
  }
}

final announcementsControllerProvider =
    NotifierProvider<AnnouncementsController, AnnouncementsScreenState>(
  AnnouncementsController.new,
);

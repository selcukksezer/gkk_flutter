import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/notification_inbox_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../utils/logout_helper.dart';
import 'blacklist_management_view.dart';
import 'friend_requests_view.dart';
import 'friend_search_bar.dart';
import 'friends_models.dart';
import 'widgets/friend_card_view.dart';
import 'widgets/friend_party_invite_cta.dart';
import 'widgets/friend_presence_orb.dart';
import 'widgets/friend_quick_whisper_dialog.dart';

export 'blacklist_management_view.dart';
export 'friend_requests_view.dart';
export 'friend_search_bar.dart';
export 'friends_models.dart';
export 'widgets/friend_card_view.dart';
export 'widgets/friend_class_crest.dart';
export 'widgets/friend_party_invite_cta.dart';
export 'widgets/friend_presence_orb.dart';
export 'widgets/friend_quick_whisper_dialog.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _usernameCtrl = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  bool _claiming = false;

  List<FriendEntry> _friends = const <FriendEntry>[];
  List<FriendEntry> _incoming = const <FriendEntry>[];
  List<FriendEntry> _outgoing = const <FriendEntry>[];
  List<BlockedPlayerEntry> _blockedUsers = const <BlockedPlayerEntry>[];

  String _referralCode = '';
  int _claimableGems = 0;
  List<Map<String, dynamic>> _referred = const <Map<String, dynamic>>[];
  bool _referralListExpanded = false;
  bool _filterOnlineOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void didUpdateWidget(covariant FriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final int target = widget.initialTabIndex.clamp(0, 2);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  List<FriendEntry> _parseList(dynamic raw) {
    if (raw is! List) return const <FriendEntry>[];
    return raw
        .whereType<Map>()
        .map((Map e) => FriendEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  List<FriendEntry> _sortFriends(List<FriendEntry> list) {
    final List<FriendEntry> sorted = List<FriendEntry>.from(list);
    sorted.sort((FriendEntry a, FriendEntry b) {
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }
      if (a.level != b.level) {
        return b.level.compareTo(a.level);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  Future<void> _load() async {
    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        SupabaseService.client.rpc('get_friends'),
        SupabaseService.client.rpc('get_referral_info'),
        _loadBlockedSilently(),
      ]);
      if (!mounted) return;
      final dynamic res = results[0];
      final dynamic refInfo = results[1];
      setState(() {
        _loading = false;
        if (res is Map) {
          _friends = _sortFriends(_parseList(res['friends']));
          _incoming = _parseList(res['incoming']);
          _outgoing = _parseList(res['outgoing']);
        }
        if (refInfo is Map && refInfo['success'] == true) {
          _referralCode = (refInfo['referral_code'] ?? '').toString();
          _claimableGems = (refInfo['claimable_gems'] as num?)?.toInt() ?? 0;
          _referred = refInfo['referred'] is List
              ? (refInfo['referred'] as List)
                  .whereType<Map>()
                  .map((Map e) => Map<String, dynamic>.from(e))
                  .toList(growable: false)
              : const <Map<String, dynamic>>[];
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<BlockedPlayerEntry>> _loadBlockedSilently() async {
    try {
      final dynamic res =
          await SupabaseService.client.rpc('get_blocked_chat_users');
      if (res is List) {
        final List<BlockedPlayerEntry> list = res
            .whereType<Map>()
            .map((Map m) =>
                BlockedPlayerEntry.fromJson(Map<String, dynamic>.from(m)))
            .where((BlockedPlayerEntry b) => b.id.isNotEmpty)
            .toList(growable: false);
        _blockedUsers = list;
        return list;
      }
    } catch (_) {
      // Non-blocking fallback
    }
    return const <BlockedPlayerEntry>[];
  }

  Future<void> _claimReferralRewards() async {
    setState(() => _claiming = true);
    try {
      final dynamic res =
          await SupabaseService.client.rpc('claim_referral_rewards');
      if (!mounted) return;
      final bool ok = res is Map && res['success'] == true;
      if (ok) {
        final int gems = (res['gems_earned'] as num?)?.toInt() ?? 0;
        AppMessenger.showSuccess(
          context,
          gems > 0 ? '💎 $gems gem kazandın!' : 'Tahsil edilecek ödül yok.',
        );
        await _load();
        unawaited(ref.read(playerProvider.notifier).loadProfile());
        unawaited(ref.read(notificationInboxProvider.notifier).refresh());
      } else {
        AppMessenger.showError(context, 'Ödül alınamadı.');
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Ödül alınamadı.');
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<bool> _sendRequestDirect(String username) async {
    final String trimmed = username.trim();
    if (trimmed.isEmpty) return false;

    setState(() => _sending = true);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'send_friend_request',
        params: <String, dynamic>{'p_username': trimmed},
      );
      if (!mounted) return false;
      final bool ok = res is Map && res['success'] == true;
      if (ok) {
        final bool auto = res['auto_accepted'] == true;
        _usernameCtrl.clear();
        FocusScope.of(context).unfocus();
        AppMessenger.showSuccess(
          context,
          auto ? '🎉 Artık arkadaşsınız!' : 'İstek gönderildi.',
        );
        await _load();
        unawaited(ref.read(notificationInboxProvider.notifier).refresh());
        return true;
      } else {
        AppMessenger.showError(
          context,
          res is Map
              ? (res['error']?.toString() ?? 'İstek gönderilemedi.')
              : 'İstek gönderilemedi.',
        );
        return false;
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'İstek gönderilemedi.');
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendRequestFromInput() async {
    await _sendRequestDirect(_usernameCtrl.text);
  }

  Future<void> _respond(FriendEntry entry, bool accept) async {
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'respond_friend_request',
        params: <String, dynamic>{
          'p_friendship_id': entry.friendshipId,
          'p_accept': accept,
        },
      );
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        AppMessenger.show(
          context,
          accept ? '${entry.name} artık arkadaşın!' : 'İstek reddedildi.',
        );
        await _load();
        unawaited(ref.read(notificationInboxProvider.notifier).refresh());
      } else {
        AppMessenger.showError(context, 'İşlem başarısız.');
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'İşlem başarısız.');
    }
  }

  Future<void> _cancelOutgoing(FriendEntry entry) async {
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'remove_friend',
        params: <String, dynamic>{'p_friendship_id': entry.friendshipId},
      );
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        AppMessenger.show(context, 'İstek iptal edildi.');
        await _load();
      } else {
        AppMessenger.showError(context, 'İptal edilemedi.');
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'İptal edilemedi.');
    }
  }

  Future<void> _remove(FriendEntry entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        title: const Row(
          children: <Widget>[
            Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text(
              'Arkadaşlıktan Çıkar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          '${entry.name} arkadaş listenden silinsin mi?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final dynamic res = await SupabaseService.client.rpc(
        'remove_friend',
        params: <String, dynamic>{'p_friendship_id': entry.friendshipId},
      );
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        AppMessenger.show(context, '${entry.name} silindi.');
        await _load();
      } else {
        AppMessenger.showError(context, 'Silme başarısız.');
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Silme başarısız.');
    }
  }

  void _openBlacklistModal() {
    HapticFeedback.lightImpact();
    BlacklistManagementView.showModal(
      context,
      initialBlockedUsers: _blockedUsers,
      onUnblocked: (String unblockedId) {
        setState(() {
          _blockedUsers = _blockedUsers
              .where((BlockedPlayerEntry b) => b.id != unblockedId)
              .toList(growable: false);
        });
      },
    );
  }

  Future<bool> _handlePartyInvite({
    required String targetUser,
    required PartyRole role,
    required String activity,
  }) async {
    try {
      await SupabaseService.client.rpc(
        'send_notification',
        params: <String, dynamic>{
          'p_username': targetUser,
          'p_type': 'party_invite',
          'p_message': 'Partiye davet edildin: $activity (${role.name})',
        },
      ).catchError((_) => null);
    } catch (_) {}

    if (mounted) {
      AppMessenger.showSuccess(
        context,
        '⚔️ $targetUser partiye davet edildi! [${role.name} · $activity]',
      );
    }
    return true;
  }

  Future<bool> _handleDirectWhisper({
    required FriendEntry friend,
    required String message,
  }) async {
    try {
      await SupabaseService.client.rpc(
        'send_notification',
        params: <String, dynamic>{
          'p_username': friend.username,
          'p_type': 'whisper',
          'p_message': message,
        },
      ).catchError((_) => null);
    } catch (_) {}

    if (mounted) {
      AppMessenger.showSuccess(
        context,
        '💬 ${friend.name} kişisine fısıldandı: "$message"',
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final int requestBadgeCount = _incoming.length;

    return Scaffold(
      appBar: GameTopBar(
        title: 'Arkadaşlar & Sosyal',
        trailingActions: <Widget>[
          IconButton(
            icon: const Icon(Icons.block_rounded, color: Colors.white70),
            tooltip: 'Engellenenler (Kara Liste)',
            onPressed: _openBlacklistModal,
          ),
        ],
        onLogout: () async {
          await performLogout(ref);
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.friends,
        onLogout: () async {
          await performLogout(ref);
        },
      ),
      body: Stack(
        children: <Widget>[
          // Deep cosmos ambient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFF070A12),
                    Color(0xFF0F172A),
                    Color(0xFF05070B),
                  ],
                ),
              ),
            ),
          ),
          // Subtle celestial violet glow orb at top right
          Positioned(
            top: -60,
            right: -60,
            width: 260,
            height: 260,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Subtle cyan glow orb at bottom left
          Positioned(
            bottom: 80,
            left: -60,
            width: 240,
            height: 240,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      const Color(0xFF06B6D4).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _buildTopTabBar(requestBadgeCount),
                Expanded(
                  child: _loading
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF8B5CF6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Arkadaşlar yükleniyor...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: <Widget>[
                            _buildFriendsTab(),
                            _buildRequestsTab(),
                            _buildSearchTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabBar(int requestBadgeCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B111E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => HapticFeedback.selectionClick(),
              indicator: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: <Widget>[
                Tab(
                  height: 42,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.people_alt_rounded, size: 16),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Arkadaşlar (${_friends.length})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  height: 42,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.mail_rounded, size: 16),
                      const SizedBox(width: 5),
                      const Flexible(
                        child: Text(
                          'İstekler',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (requestBadgeCount > 0) ...<Widget>[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[
                                Color(0xFF22C55E),
                                Color(0xFF16A34A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '$requestBadgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  height: 42,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.person_search_rounded, size: 17),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Oyuncu Ara',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    final int onlineCount = _friends.where((FriendEntry f) => f.isOnline).length;
    final List<FriendEntry> displayFriends = _filterOnlineOnly
        ? _friends.where((FriendEntry f) => f.isOnline).toList(growable: false)
        : _friends;

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF38BDF8),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: <Widget>[
          _buildPresenceOverviewBanner(onlineCount: onlineCount),
          const SizedBox(height: 12),
          _buildQuickAddCard(),
          const SizedBox(height: 14),
          _buildReferralCard(),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _sectionTitle(
                  _filterOnlineOnly
                      ? '🟢 ÇEVRİMİÇİ ARKADAŞLAR ($onlineCount)'
                      : '👥 ARKADAŞ LİSTESİ (${_friends.length})',
                ),
              ),
              if (_friends.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _filterOnlineOnly = !_filterOnlineOnly);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _filterOnlineOnly
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _filterOnlineOnly
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _filterOnlineOnly
                              ? Icons.filter_alt_rounded
                              : Icons.filter_alt_outlined,
                          size: 13,
                          color: _filterOnlineOnly
                              ? const Color(0xFF10B981)
                              : Colors.white60,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _filterOnlineOnly ? 'Sadece Çevrimiçi' : 'Tümü',
                          style: TextStyle(
                            color: _filterOnlineOnly
                                ? const Color(0xFF10B981)
                                : Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (displayFriends.isEmpty)
            _buildEmptyFriendsCard(
              isFiltered: _filterOnlineOnly && _friends.isNotEmpty,
            )
          else
            ...displayFriends.map(_buildFriendTile),
        ],
      ),
    );
  }

  Widget _buildPresenceOverviewBanner({required int onlineCount}) {
    final int totalCount = _friends.length;
    final int offlineCount = (totalCount - onlineCount).clamp(0, totalCount);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: onlineCount > 0
                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                  : const Color(0xFF38BDF8).withValues(alpha: 0.25),
              width: 1.1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (onlineCount > 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFF38BDF8))
                    .withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              FriendPresenceOrb(
                status: onlineCount > 0
                    ? FriendPresenceStatus.online
                    : FriendPresenceStatus.offline,
                size: 11,
              ),
              const SizedBox(width: 8),
              Text(
                '$onlineCount Çevrimiçi',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const Text(
                '  ·  ',
                style: TextStyle(color: Colors.white24),
              ),
              Text(
                '$offlineCount Çevrimdışı',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalCount Toplam',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFriendsCard({bool isFiltered = false}) {
    if (isFiltered) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.nights_stay_rounded,
                size: 34,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Şu anda çevrimiçi arkadaşın yok',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Listendeki ${_friends.length} arkadaşının tümü şu an dinleniyor. Tüm arkadaşlarını görmek için filtreyi kapatabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _filterOnlineOnly = false);
              },
              icon: const Icon(Icons.people_outline_rounded, size: 16),
              label: const Text('Tüm Arkadaşları Göster'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 36,
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Henüz arkadaşın yok!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Birlikte zindanlara girmek ve ödüller kazanmak için diğer oyuncuları ekleyebilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _tabController.animateTo(2);
            },
            icon: const Icon(Icons.person_search_rounded, size: 16),
            label: const Text('Oyuncu Ara'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: FriendRequestsView(
        incomingRequests: _incoming,
        outgoingRequests: _outgoing,
        onAcceptRequest: (FriendEntry entry) => _respond(entry, true),
        onDeclineRequest: (FriendEntry entry) => _respond(entry, false),
        onCancelOutgoing: _cancelOutgoing,
        onRefresh: _load,
      ),
    );
  }

  Widget _buildSearchTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF8B5CF6),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: <Widget>[
          const SizedBox(height: 4),
          _sectionTitle('🔍 CANLI OYUNCU ARAMA'),
          const SizedBox(height: 4),
          FriendSearchBar(
            onSendRequest: _sendRequestDirect,
            existingFriends: _friends,
            outgoingRequests: _outgoing,
            incomingRequests: _incoming,
            blockedUsers: _blockedUsers,
            hintText: 'Kullanıcı adı veya takma ad ile ara...',
          ),
          const SizedBox(height: 24),
          _buildSearchTipsCard(),
        ],
      ),
    );
  }

  Widget _buildSearchTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.tips_and_updates_rounded,
                  color: Color(0xFFF5C842), size: 18),
              SizedBox(width: 8),
              Text(
                'Arkadaş Edinme İpuçları',
                style: TextStyle(
                  color: Color(0xFFF5C842),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _tipItem('En az 2 karakter yazarak canlı önerileri görebilirsin.'),
          _tipItem('Zindan ve parti çağrıları için arkadaşlarınla eşleş.'),
          _tipItem('Davet kodunla gelen arkadaşlarından ekstra Elmas kazan!'),
        ],
      ),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('• ', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildQuickAddCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _usernameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textInputAction: TextInputAction.send,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    hintText: 'Hızlı kullanıcı adı ekle...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 18,
                      color: Color(0xFF8B5CF6),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendRequestFromInput(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _sendRequestFromInput,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.add_rounded, size: 16),
                          SizedBox(width: 4),
                          Text('Ekle',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralCard() {
    final int eligibleCount = _referred
        .where((Map<String, dynamic> r) => r['eligible'] == true)
        .length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1330).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFC34BFF).withValues(alpha: 0.4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFC34BFF).withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFFDDA8FF),
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ARKADAŞINI DAVET ET',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Color(0xFFDDA8FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Davet ettiğin oyuncu Seviye 5\'e ulaşınca sen 50 💎, o 25 💎 kazanır!',
                style:
                    TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFC34BFF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _referralCode.isEmpty ? '...' : _referralCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _referralCode.isEmpty
                        ? null
                        : () async {
                            HapticFeedback.lightImpact();
                            await Clipboard.setData(
                                ClipboardData(text: _referralCode));
                            if (mounted) {
                              AppMessenger.show(
                                  context, 'Davet kodu kopyalandı!');
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFC34BFF).withValues(alpha: 0.22),
                      foregroundColor: const Color(0xFFDDA8FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: const Color(0xFFC34BFF).withValues(alpha: 0.4),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.copy_rounded, size: 14),
                        SizedBox(width: 4),
                        Text('Kopyala',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Davet edilen: ${_referred.length}  ·  Seviye 5+: $eligibleCount',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                  if (_claimableGems > 0)
                    FilledButton(
                      onPressed: _claiming ? null : _claimReferralRewards,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC34BFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _claiming
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('💎 $_claimableGems Gem Al',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _referralListExpanded = !_referralListExpanded,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'DAVET LİSTESİ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Color(0xFFDDA8FF),
                            ),
                          ),
                        ),
                        Text(
                          '${_referred.length}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: _referralListExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white54,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _referralListExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _referred.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Henüz senin kodunla kayıt olan yok. Kodunu paylaş!',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                                ),
                              )
                            : Column(
                                children: _referred
                                    .map(_buildReferredTile)
                                    .toList(growable: false),
                              ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferredTile(Map<String, dynamic> row) {
    final String rawDisplay = (row['display_name'] ?? '').toString().trim();
    final String rawUser = (row['username'] ?? '').toString().trim();
    final String name = rawDisplay.isNotEmpty
        ? rawDisplay
        : (rawUser.isNotEmpty ? rawUser : 'Bilinmeyen Oyuncu');
    final int level = (row['level'] as num?)?.toInt() ?? 1;
    final int power = (row['power'] as num?)?.toInt() ?? 0;
    final int progressPct = (row['progress_pct'] as num?)?.toInt() ??
        ((level * 100) / 5).floor().clamp(0, 100);
    final bool claimed = row['claimed'] == true;
    final bool eligible = row['eligible'] == true;
    final bool rewardReady =
        row['reward_ready'] == true || (eligible && !claimed);
    final String cls = (row['character_class'] ?? '—').toString();
    final Color accent = claimed
        ? const Color(0xFF22C55E)
        : rewardReady
            ? const Color(0xFFC34BFF)
            : const Color(0xFFF5C842);

    String statusLabel;
    if (claimed) {
      statusLabel = 'Ödül alındı';
    } else if (rewardReady) {
      statusLabel = '50 💎 hazır — yukarıdan topla';
    } else {
      statusLabel = 'Lv.$level / 5  ·  ilerleme %$progressPct';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                claimed
                    ? '✓'
                    : rewardReady
                        ? '💎'
                        : '⏳',
                style: TextStyle(color: accent, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Lv.$level  ·  ⚡ $power  ·  $cls',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (progressPct / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white10,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusLabel,
            style:
                TextStyle(color: accent.withValues(alpha: 0.9), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(FriendEntry entry) {
    return FriendCardView(
      key: ValueKey<String>('friend_${entry.friendshipId}'),
      friendshipId: entry.friendshipId,
      username: entry.username,
      displayName: entry.displayName,
      avatarUrl: entry.avatarUrl,
      level: entry.level,
      power: entry.power,
      isOnline: entry.isOnline,
      characterClass: entry.characterClass,
      location: entry.location,
      guildName: entry.guildName,
      activityStatus: entry.activityStatus,
      onTapCard: () {
        HapticFeedback.lightImpact();
        FriendQuickWhisperDialog.show(
          context: context,
          friendshipId: entry.friendshipId,
          recipientName: entry.name,
          avatarUrl: entry.avatarUrl,
          level: entry.level,
          characterClass: entry.characterClass,
          isOnline: entry.isOnline,
          onSendWhisper: (String msg) => _handleDirectWhisper(
            friend: entry,
            message: msg,
          ),
        );
      },
      onPartyInvite: ({
        required String targetUser,
        required PartyRole role,
        required String activity,
      }) =>
          _handlePartyInvite(
        targetUser: targetUser,
        role: role,
        activity: activity,
      ),
      onDirectWhisper: (String msg) => _handleDirectWhisper(
        friend: entry,
        message: msg,
      ),
      onRemove: () => _remove(entry),
    );
  }
}

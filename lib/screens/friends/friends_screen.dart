import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/profile_avatar.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/notification_inbox_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../utils/logout_helper.dart';

class FriendEntry {
  const FriendEntry({
    required this.friendshipId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.level = 1,
    this.power = 0,
    this.isOnline = false,
  });

  final String friendshipId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int level;
  final int power;
  final bool isOnline;

  String get name =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : username;

  factory FriendEntry.fromJson(Map<String, dynamic> json) {
    return FriendEntry(
      friendshipId: (json['friendship_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      displayName: json['display_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      power: (json['power'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] == true,
    );
  }
}

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _usernameCtrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  bool _claiming = false;
  List<FriendEntry> _friends = const <FriendEntry>[];
  List<FriendEntry> _incoming = const <FriendEntry>[];
  List<FriendEntry> _outgoing = const <FriendEntry>[];

  String _referralCode = '';
  int _claimableGems = 0;
  List<Map<String, dynamic>> _referred = const <Map<String, dynamic>>[];
  bool _referralListExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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

  Future<void> _load() async {
    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        SupabaseService.client.rpc('get_friends'),
        SupabaseService.client.rpc('get_referral_info'),
      ]);
      if (!mounted) return;
      final dynamic res = results[0];
      final dynamic refInfo = results[1];
      setState(() {
        _loading = false;
        if (res is Map) {
          _friends = _parseList(res['friends']);
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

  Future<void> _sendRequest() async {
    final String username = _usernameCtrl.text.trim();
    if (username.isEmpty) return;

    setState(() => _sending = true);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'send_friend_request',
        params: <String, dynamic>{'p_username': username},
      );
      if (!mounted) return;
      final bool ok = res is Map && res['success'] == true;
      if (ok) {
        final bool auto = res['auto_accepted'] == true;
        _usernameCtrl.clear();
        AppMessenger.showSuccess(
          context,
          auto ? '🎉 Artık arkadaşsınız!' : 'İstek gönderildi.',
        );
        await _load();
        unawaited(ref.read(notificationInboxProvider.notifier).refresh());
      } else {
        AppMessenger.showError(
          context,
          res is Map
              ? (res['error']?.toString() ?? 'İstek gönderilemedi.')
              : 'İstek gönderilemedi.',
        );
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'İstek gönderilemedi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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

  Future<void> _remove(FriendEntry entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Arkadaşlıktan Çıkar'),
        content: Text('${entry.name} arkadaş listenden silinsin mi?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GameTopBar(
        title: 'Arkadaşlar',
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF090D14),
              Color(0xFF101722),
              Color(0xFF090D14),
            ],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: <Widget>[
                    _buildAddCard(),
                    const SizedBox(height: 16),
                    _buildReferralCard(),
                    if (_incoming.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      _sectionTitle('📬 GELEN İSTEKLER (${_incoming.length})'),
                      ..._incoming.map(_buildIncomingTile),
                    ],
                    if (_outgoing.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      _sectionTitle('📤 GÖNDERİLEN (${_outgoing.length})'),
                      ..._outgoing.map(_buildOutgoingTile),
                    ],
                    const SizedBox(height: 16),
                    _sectionTitle('👥 ARKADAŞLAR (${_friends.length})'),
                    if (_friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Henüz arkadaşın yok. Yukarıdan kullanıcı adıyla ekle!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      )
                    else
                      ..._friends.map(_buildFriendTile),
                  ],
                ),
              ),
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

  Widget _buildAddCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _usernameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Kullanıcı adı...',
                hintStyle: const TextStyle(color: Colors.white38),
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendRequest(),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _sending ? null : _sendRequest,
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('➕ Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard() {
    final int eligibleCount = _referred
        .where((Map<String, dynamic> r) => r['eligible'] == true)
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1330).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFC34BFF).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '🎁 ARKADAŞINI DAVET ET',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Color(0xFFDDA8FF),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Davet ettiğin oyuncu Level 5\'e ulaşınca sen 50 💎, o 25 💎 kazanır!',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
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
                        await Clipboard.setData(
                            ClipboardData(text: _referralCode));
                        if (mounted) {
                          AppMessenger.show(context, 'Kod kopyalandı!');
                        }
                      },
                child: const Text('📋 Kopyala'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Davet edilen: ${_referred.length}  ·  Level 5+: $eligibleCount',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              if (_claimableGems > 0)
                FilledButton(
                  onPressed: _claiming ? null : _claimReferralRewards,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC34BFF),
                  ),
                  child: _claiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('💎 $_claimableGems Gem Al',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(
                () => _referralListExpanded = !_referralListExpanded,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                        ? const Text(
                            'Henüz senin kodunla kayıt olan yok. Kodunu paylaş!',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11),
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
    );
  }

  Widget _buildReferredTile(Map<String, dynamic> row) {
    final String name = (row['display_name'] ?? row['username'] ?? '?').toString();
    final int level = (row['level'] as num?)?.toInt() ?? 1;
    final int power = (row['power'] as num?)?.toInt() ?? 0;
    final int progressPct = (row['progress_pct'] as num?)?.toInt() ??
        ((level * 100) / 5).floor().clamp(0, 100);
    final bool claimed = row['claimed'] == true;
    final bool eligible = row['eligible'] == true;
    final bool rewardReady = row['reward_ready'] == true || (eligible && !claimed);
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
            style: TextStyle(color: accent.withValues(alpha: 0.9), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _tileShell({required Widget child, Color? borderColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Colors.white12),
      ),
      child: child,
    );
  }

  Widget _buildIncomingTile(FriendEntry entry) {
    return _tileShell(
      borderColor: const Color(0xFFF5C842).withValues(alpha: 0.4),
      child: Row(
        children: <Widget>[
          ProfileAvatar(size: 38, avatarUrl: entry.avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${entry.name}  ·  Lv.${entry.level}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _respond(entry, true),
            icon: const Icon(Icons.check_circle,
                color: Color(0xFF22C55E), size: 26),
            tooltip: 'Kabul Et',
          ),
          IconButton(
            onPressed: () => _respond(entry, false),
            icon:
                const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 26),
            tooltip: 'Reddet',
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingTile(FriendEntry entry) {
    return _tileShell(
      child: Row(
        children: <Widget>[
          ProfileAvatar(size: 38, avatarUrl: entry.avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${entry.name}  ·  Lv.${entry.level}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const Text(
            'Bekliyor...',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(FriendEntry entry) {
    return _tileShell(
      child: Row(
        children: <Widget>[
          Stack(
            children: <Widget>[
              ProfileAvatar(size: 42, avatarUrl: entry.avatarUrl),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: entry.isOnline
                        ? const Color(0xFF22C55E)
                        : Colors.grey.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF090D14), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Lv.${entry.level}  ·  ⚡ ${entry.power}  ·  ${entry.isOnline ? '🟢 Çevrimiçi' : '⚫ Çevrimdışı'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _remove(entry),
            icon: const Icon(Icons.person_remove_outlined,
                color: Colors.white38, size: 20),
            tooltip: 'Arkadaşlıktan çıkar',
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/profile_avatar.dart';
import '../../core/services/supabase_service.dart';
import '../../theme/app_colors.dart';
import 'friends_models.dart';

class BlacklistManagementView extends StatefulWidget {
  const BlacklistManagementView({
    super.key,
    this.initialBlockedUsers = const <BlockedPlayerEntry>[],
    this.onUnblocked,
    this.isModal = false,
  });

  final List<BlockedPlayerEntry> initialBlockedUsers;
  final void Function(String unblockedUserId)? onUnblocked;
  final bool isModal;

  static Future<void> showModal(
    BuildContext context, {
    List<BlockedPlayerEntry> initialBlockedUsers = const <BlockedPlayerEntry>[],
    void Function(String unblockedUserId)? onUnblocked,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF090D14).withValues(alpha: 0.88),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black87,
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: BlacklistManagementView(
                  initialBlockedUsers: initialBlockedUsers,
                  onUnblocked: onUnblocked,
                  isModal: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  @override
  State<BlacklistManagementView> createState() => _BlacklistManagementViewState();
}

class _BlacklistManagementViewState extends State<BlacklistManagementView> {
  final TextEditingController _blockInputCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isBlocking = false;
  List<BlockedPlayerEntry> _blockedList = <BlockedPlayerEntry>[];
  final Set<String> _animatingUnblockIds = <String>{};

  @override
  void initState() {
    super.initState();
    _blockedList = List<BlockedPlayerEntry>.from(widget.initialBlockedUsers);
    _loadBlockedUsers();
  }

  @override
  void dispose() {
    _blockInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('get_blocked_chat_users');
      if (!mounted) return;

      if (raw is List) {
        final List<BlockedPlayerEntry> list = raw
            .whereType<Map>()
            .map((Map m) =>
                BlockedPlayerEntry.fromJson(Map<String, dynamic>.from(m)))
            .where((BlockedPlayerEntry b) => b.id.isNotEmpty)
            .toList(growable: false);

        setState(() {
          _blockedList = list;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _promptUnblock(BlockedPlayerEntry player) async {
    HapticFeedback.mediumImpact();

    final bool? confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Engeli Kaldır',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (
        BuildContext ctx,
        Animation<double> anim,
        Animation<double> secondary,
        Widget? child,
      ) {
        final double scale = Curves.easeOutBack.transform(anim.value);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: FadeTransition(
            opacity: anim,
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            AppColors.spaceNavy.withValues(alpha: 0.95),
                            AppColors.carbonVoid.withValues(alpha: 0.98),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.danger.withValues(alpha: 0.25),
                            blurRadius: 28,
                            spreadRadius: -4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.danger.withValues(alpha: 0.15),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.danger.withValues(alpha: 0.2),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_open_rounded,
                              color: AppColors.danger,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Engeli Kaldır',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                ProfileAvatar(
                                  size: 40,
                                  avatarUrl: player.avatarUrl,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        player.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '@${player.username}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (player.level > 1)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.gold.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      'Lv. ${player.level}',
                                      style: const TextStyle(
                                        color: AppColors.gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '@${player.name} adlı oyuncunun engelini kaldırmak istediğinden emin misin?\n\nBu oyuncu yeniden sana özel mesaj ve arkadaşlık isteği gönderebilecek.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.15),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text(
                                    'Vazgeç',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    Navigator.of(ctx).pop(true);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: <Color>[
                                          Color(0xFFEF4444),
                                          Color(0xFFDC2626),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Icon(
                                            Icons.lock_open_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Engeli Kaldır',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;
    await _executeUnblock(player);
  }

  Future<void> _executeUnblock(BlockedPlayerEntry player) async {
    final String playerId = player.id;
    if (_animatingUnblockIds.contains(playerId)) return;

    setState(() {
      _animatingUnblockIds.add(playerId);
    });

    try {
      await SupabaseService.client.rpc(
        'unblock_chat_user',
        params: <String, dynamic>{'p_blocked_user_id': playerId},
      );
    } catch (_) {
      // Defensive fallback for offline / mock testing
    }

    if (!mounted) return;

    AppMessenger.show(context, '@${player.name} için engel kaldırıldı.');
    widget.onUnblocked?.call(playerId);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      setState(() {
        _animatingUnblockIds.remove(playerId);
        _blockedList.removeWhere((BlockedPlayerEntry b) => b.id == playerId);
      });
    }
  }

  Future<void> _handleDirectBlock() async {
    final String rawQuery = _blockInputCtrl.text.trim();
    if (rawQuery.isEmpty) return;

    // Sanitize query if prepended with @
    final String query = rawQuery.startsWith('@') ? rawQuery.substring(1).trim() : rawQuery;
    if (query.isEmpty) return;

    // Check if already in blocked list
    final bool alreadyBlocked = _blockedList.any((BlockedPlayerEntry b) =>
        b.username.toLowerCase() == query.toLowerCase() ||
        b.name.toLowerCase() == query.toLowerCase() ||
        b.id == query);

    if (alreadyBlocked) {
      AppMessenger.show(context, '@$query zaten engelli listesinde.');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isBlocking = true);

    try {
      String targetUserId = query;
      String targetUsername = query;

      try {
        final dynamic searchRes = await SupabaseService.client.rpc(
          'search_chat_users',
          params: <String, dynamic>{'p_query': query, 'p_limit': 1},
        );
        if (searchRes is List && searchRes.isNotEmpty) {
          final Map<String, dynamic> first =
              Map<String, dynamic>.from(searchRes.first as Map);
          targetUserId = (first['id'] ?? query).toString();
          targetUsername = (first['username'] ?? query).toString();
        }
      } catch (_) {
        // Fallback to direct query
      }

      // Check again with resolved user ID
      if (_blockedList.any((BlockedPlayerEntry b) => b.id == targetUserId)) {
        if (!mounted) return;
        AppMessenger.show(context, '@$targetUsername zaten engelli listesinde.');
        return;
      }

      await SupabaseService.client.rpc(
        'block_chat_user',
        params: <String, dynamic>{'p_blocked_user_id': targetUserId},
      );

      if (!mounted) return;
      _blockInputCtrl.clear();
      AppMessenger.show(context, '@$targetUsername engellendi.');

      setState(() {
        _blockedList.insert(
          0,
          BlockedPlayerEntry(
            id: targetUserId,
            username: targetUsername,
            blockedAt: DateTime.now(),
          ),
        );
      });
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Oyuncu engellenemedi.');
      }
    } finally {
      if (mounted) setState(() => _isBlocking = false);
    }
  }

  static String _formatDate(DateTime dt) {
    const List<String> months = <String>[
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    final int monthIdx = (dt.month >= 1 && dt.month <= 12) ? dt.month - 1 : 0;
    return '${dt.day} ${months[monthIdx]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.block_rounded,
                color: AppColors.danger,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Engellenen Oyuncular',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (widget.isModal)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildInfoBanner(),
          _buildBlockInput(),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.danger),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBlockedUsers,
                    color: AppColors.danger,
                    backgroundColor: AppColors.spaceNavy,
                    child: _buildBlockedList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.danger.withValues(alpha: 0.12),
            AppColors.spaceNavy.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.danger,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Engellediğin oyuncular sana özel mesaj gönderemez ve arkadaşlık isteği iletemez.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
          if (_blockedList.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                '${_blockedList.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockInput() {
    final bool hasText = _blockInputCtrl.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _blockInputCtrl,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Kullanıcı adı ile engelle...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_remove_rounded,
                    color: AppColors.danger,
                    size: 19,
                  ),
                  suffixIcon: hasText
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                          onPressed: () {
                            _blockInputCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.spaceNavy.withValues(alpha: 0.7),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.8),
                      width: 1.2,
                    ),
                  ),
                ),
                onSubmitted: (_) => _handleDirectBlock(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isBlocking ? null : _handleDirectBlock,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[
                      Color(0xFFEF4444),
                      Color(0xFFDC2626),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _isBlocking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Engelle',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AppColors.success.withValues(alpha: 0.25),
                    AppColors.success.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const <double>[0.3, 0.7, 1.0],
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.spaceNavy.withValues(alpha: 0.9),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.success,
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.shield_outlined,
                    size: 12,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'TERTEMİZ İLETİŞİM',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Engellenen Oyuncu Yok',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Kara listeniz tamamen temiz. Huzurlu ve dostane bir oyun deneyimi!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12.5,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedList() {
    if (_blockedList.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _blockedList.length,
      itemBuilder: (BuildContext context, int index) {
        final BlockedPlayerEntry player = _blockedList[index];
        final bool isAnimating = _animatingUnblockIds.contains(player.id);

        return AnimatedSlide(
          offset: isAnimating ? const Offset(0.3, 0) : Offset.zero,
          duration: const Duration(milliseconds: 250),
          child: AnimatedOpacity(
            opacity: isAnimating ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 250),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool isNarrow = constraints.maxWidth < 340;
                  final String? formattedDate = player.blockedAt != null
                      ? _formatDate(player.blockedAt!)
                      : null;

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 10 : 14,
                          vertical: 12,
                        ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.spaceNavy.withValues(alpha: 0.85),
                          AppColors.carbonVoid.withValues(alpha: 0.95),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.22),
                        width: 1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            ProfileAvatar(
                              size: 42,
                              avatarUrl: player.avatarUrl,
                            ),
                            if (player.level > 1)
                              Positioned(
                                bottom: -3,
                                right: -3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.spaceNavy,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '${player.level}',
                                    style: const TextStyle(
                                      color: AppColors.goldLight,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                player.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      '@${player.username}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.45),
                                        fontSize: 11.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (formattedDate != null) ...<Widget>[
                                    Text(
                                      ' • ',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      formattedDate,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (player.reason != null &&
                                  player.reason!.trim().isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.danger.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    player.reason!,
                                    style: TextStyle(
                                      color: AppColors.danger.withValues(alpha: 0.85),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed:
                              isAnimating ? null : () => _promptUnblock(player),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.5),
                            ),
                            backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isNarrow ? 8 : 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.lock_open_rounded, size: 14),
                          label: Text(
                            isNarrow ? 'Kaldır' : 'Engeli Kaldır',
                            style: const TextStyle(
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
            },
              ),
            ),
          ),
        );
      },
    );
  }
}

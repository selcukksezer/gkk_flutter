import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/common/profile_avatar.dart';
import 'friends_models.dart';
import 'widgets/friend_class_crest.dart';
import 'widgets/friend_presence_orb.dart';

enum RequestTabType {
  incoming,
  outgoing,
}

/// AAA Luxury Glassmorphic Friend Requests View for Aion 2 Mobile.
class FriendRequestsView extends StatefulWidget {
  const FriendRequestsView({
    super.key,
    required this.incomingRequests,
    required this.outgoingRequests,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    this.onCancelOutgoing,
    this.onRefresh,
  });

  final List<FriendEntry> incomingRequests;
  final List<FriendEntry> outgoingRequests;
  final Future<void> Function(FriendEntry entry) onAcceptRequest;
  final Future<void> Function(FriendEntry entry) onDeclineRequest;
  final Future<void> Function(FriendEntry entry)? onCancelOutgoing;
  final Future<void> Function()? onRefresh;

  @override
  State<FriendRequestsView> createState() => _FriendRequestsViewState();
}

class _FriendRequestsViewState extends State<FriendRequestsView> {
  RequestTabType _activeSubTab = RequestTabType.incoming;
  final Set<String> _animatingItemIds = <String>{};
  final Map<String, String> _actionStatuses = <String, String>{}; // 'accepted', 'declined', 'cancelled', 'error'
  bool _isProcessingBatch = false;

  String? _formatTimeAgo(DateTime? time) {
    if (time == null) return null;
    final Duration diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} g';
    return '${time.day}.${time.month.toString().padLeft(2, '0')}';
  }

  Future<void> _handleAccept(FriendEntry entry) async {
    final String id = entry.friendshipId;
    if (_animatingItemIds.contains(id)) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _animatingItemIds.add(id);
      _actionStatuses[id] = 'accepted';
    });

    // Brief delay to showcase the smooth accept animation
    await Future<void>.delayed(const Duration(milliseconds: 280));
    try {
      await widget.onAcceptRequest(entry);
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionStatuses[id] = 'error';
        });
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    } finally {
      if (mounted) {
        setState(() {
          _animatingItemIds.remove(id);
          _actionStatuses.remove(id);
        });
      }
    }
  }

  Future<void> _handleDecline(FriendEntry entry) async {
    final String id = entry.friendshipId;
    if (_animatingItemIds.contains(id)) return;

    HapticFeedback.lightImpact();
    setState(() {
      _animatingItemIds.add(id);
      _actionStatuses[id] = 'declined';
    });

    // Brief delay to showcase the decline animation
    await Future<void>.delayed(const Duration(milliseconds: 280));
    try {
      await widget.onDeclineRequest(entry);
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionStatuses[id] = 'error';
        });
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    } finally {
      if (mounted) {
        setState(() {
          _animatingItemIds.remove(id);
          _actionStatuses.remove(id);
        });
      }
    }
  }

  Future<void> _handleCancel(FriendEntry entry) async {
    final String id = entry.friendshipId;
    if (_animatingItemIds.contains(id)) return;

    HapticFeedback.lightImpact();
    setState(() {
      _animatingItemIds.add(id);
      _actionStatuses[id] = 'cancelled';
    });

    await Future<void>.delayed(const Duration(milliseconds: 260));
    try {
      await widget.onCancelOutgoing?.call(entry);
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionStatuses[id] = 'error';
        });
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    } finally {
      if (mounted) {
        setState(() {
          _animatingItemIds.remove(id);
          _actionStatuses.remove(id);
        });
      }
    }
  }

  Future<void> _handleAcceptAll() async {
    if (_isProcessingBatch || widget.incomingRequests.isEmpty) return;

    final List<FriendEntry> targets = List<FriendEntry>.from(widget.incomingRequests);
    HapticFeedback.mediumImpact();
    setState(() => _isProcessingBatch = true);

    try {
      for (final FriendEntry entry in targets) {
        if (!mounted) break;
        await _handleAccept(entry);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingBatch = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildSegmentedControl(),
        if (_activeSubTab == RequestTabType.incoming &&
            widget.incomingRequests.length >= 2) ...<Widget>[
          const SizedBox(height: 10),
          _buildBatchActionBar(),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: widget.onRefresh != null
              ? RefreshIndicator(
                  onRefresh: widget.onRefresh!,
                  color: const Color(0xFFC34BFF),
                  backgroundColor: const Color(0xFF0F172A),
                  child: _buildListContent(),
                )
              : _buildListContent(),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    final int incomingCount = widget.incomingRequests.length;
    final int outgoingCount = widget.outgoingRequests.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _buildSubTabButton(
                  title: 'Gelen İstekler',
                  count: incomingCount,
                  badgeColor: const Color(0xFF22C55E),
                  isActive: _activeSubTab == RequestTabType.incoming,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _activeSubTab = RequestTabType.incoming);
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSubTabButton(
                  title: 'Gönderilen',
                  count: outgoingCount,
                  badgeColor: const Color(0xFF8B5CF6),
                  isActive: _activeSubTab == RequestTabType.outgoing,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _activeSubTab = RequestTabType.outgoing);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabButton({
    required String title,
    required int count,
    required Color badgeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: <Color>[
                      Color(0xFF2A1F4D),
                      Color(0xFF1E293B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                  : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: isActive
                ? <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              if (count > 0) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
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
      ),
    );
  }

  Widget _buildBatchActionBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF22C55E).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.mark_email_unread_rounded,
                    size: 16,
                    color: Color(0xFF22C55E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.incomingRequests.length} oyuncu bekliyor',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isProcessingBatch ? null : _handleAcceptAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF22C55E), Color(0xFF16A34A)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isProcessingBatch
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.done_all_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Tümünü Kabul Et',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListContent() {
    final bool isIncoming = _activeSubTab == RequestTabType.incoming;
    final List<FriendEntry> list =
        isIncoming ? widget.incomingRequests : widget.outgoingRequests;

    if (list.isEmpty) {
      return _buildEmptyState(isIncoming);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: list.length,
      itemBuilder: (BuildContext context, int index) {
        final FriendEntry entry = list[index];
        return _buildAnimatedRequestCard(entry, isIncoming);
      },
    );
  }

  Widget _buildEmptyState(bool isIncoming) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 36),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isIncoming
                      ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                      : const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (isIncoming
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF8B5CF6))
                        .withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: <Color>[
                          const Color(0xFF1E293B),
                          (isIncoming
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF8B5CF6))
                              .withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: (isIncoming
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF8B5CF6))
                            .withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (isIncoming
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF8B5CF6))
                              .withValues(alpha: 0.25),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Icon(
                      isIncoming
                          ? Icons.mark_email_read_rounded
                          : Icons.send_rounded,
                      color: isIncoming
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFC34BFF),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isIncoming
                        ? 'Bekleyen Gelen İstek Yok'
                        : 'Bekleyen Gönderilen İstek Yok',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isIncoming
                        ? 'Yeni yol arkadaşları sana istek gönderdiğinde burada listelenecek.'
                        : 'Arama sekmesinden diğer savaşçıların kullanıcı adını aratarak davet gönderebilirsin.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedRequestCard(FriendEntry entry, bool isIncoming) {
    final String id = entry.friendshipId;
    final bool isAnimating = _animatingItemIds.contains(id);
    final String? status = _actionStatuses[id];

    final double targetScale = isAnimating ? 0.94 : 1.0;
    final double targetOpacity = isAnimating ? 0.2 : 1.0;
    final Offset targetSlide = isAnimating
        ? (status == 'accepted' ? const Offset(0.35, 0) : const Offset(-0.35, 0))
        : Offset.zero;

    Color borderColor;
    Color shadowColor;
    if (status == 'accepted') {
      borderColor = const Color(0xFF22C55E);
      shadowColor = const Color(0xFF22C55E).withValues(alpha: 0.35);
    } else if (status == 'declined') {
      borderColor = const Color(0xFFEF4444);
      shadowColor = const Color(0xFFEF4444).withValues(alpha: 0.35);
    } else if (status == 'cancelled') {
      borderColor = const Color(0xFFF59E0B);
      shadowColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
    } else if (status == 'error') {
      borderColor = const Color(0xFFEF4444);
      shadowColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
    } else {
      borderColor = isIncoming
          ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.12);
      shadowColor = Colors.black.withValues(alpha: 0.3);
    }

    return AnimatedSlide(
      offset: targetSlide,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: targetOpacity,
        duration: const Duration(milliseconds: 280),
        child: AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 280),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: isAnimating ? 1.5 : 1.1,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: isAnimating ? 14 : 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: status != null
                        ? _buildStatusFeedback(status)
                        : (isIncoming
                            ? _buildIncomingCardContent(entry, isAnimating)
                            : _buildOutgoingCardContent(entry, isAnimating)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFeedback(String status) {
    IconData icon;
    Color color;
    String text;

    switch (status) {
      case 'accepted':
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF22C55E);
        text = 'Arkadaşlık Kabul Edildi!';
        break;
      case 'declined':
        icon = Icons.cancel_rounded;
        color = const Color(0xFFEF4444);
        text = 'İstek Reddedildi';
        break;
      case 'cancelled':
        icon = Icons.remove_circle_outline_rounded;
        color = const Color(0xFFF59E0B);
        text = 'İstek İptal Edildi';
        break;
      default:
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFEF4444);
        text = 'İşlem Başarısız';
        break;
    }

    return Container(
      key: ValueKey<String>('status_$status'),
      constraints: const BoxConstraints(minHeight: 62),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingCardContent(FriendEntry entry, bool isAnimating) {
    final String? timeAgo = _formatTimeAgo(entry.createdAt);
    final FriendPresenceStatus status = FriendPresenceStatus.fromOnline(
      isOnline: entry.isOnline,
      activity: entry.activityStatus,
    );

    return Row(
      key: ValueKey<String>('content_${entry.friendshipId}'),
      children: <Widget>[
        // Avatar with Live Presence Orb
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            ProfileAvatar(
              size: 44,
              avatarUrl: entry.avatarUrl,
              glowFrame: entry.isOnline,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: FriendPresenceOrb(
                status: status,
                size: 11,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Player Identity & Badges
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (timeAgo != null) ...<Widget>[
                    const SizedBox(width: 6),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Text(
                    '@${entry.username}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (entry.guildName != null && entry.guildName!.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '<${entry.guildName}>',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              // Class Crest, Level, Combat Power Chips
              Wrap(
                spacing: 5,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  // Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5C842).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFF5C842).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Lv.${entry.level}',
                      style: const TextStyle(
                        color: Color(0xFFF5C842),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  // Character Class Crest
                  if (entry.characterClass != null && entry.characterClass!.isNotEmpty)
                    ClassCrestBadge(
                      className: entry.characterClass!,
                      compact: true,
                    ),
                  // Combat Power Badge
                  if (entry.power > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.bolt_rounded,
                            size: 10,
                            color: Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            FriendClassCrest.formatCp(entry.power),
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Accept Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isAnimating ? null : () => _handleAccept(entry),
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF22C55E), Color(0xFF16A34A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Decline Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isAnimating ? null : () => _handleDecline(entry),
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutgoingCardContent(FriendEntry entry, bool isAnimating) {
    final String? timeAgo = _formatTimeAgo(entry.createdAt);
    final FriendPresenceStatus status = FriendPresenceStatus.fromOnline(
      isOnline: entry.isOnline,
      activity: entry.activityStatus,
    );

    return Row(
      key: ValueKey<String>('content_${entry.friendshipId}'),
      children: <Widget>[
        // Avatar with Presence Orb
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            ProfileAvatar(
              size: 42,
              avatarUrl: entry.avatarUrl,
              glowFrame: entry.isOnline,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: FriendPresenceOrb(
                status: status,
                size: 11,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Outgoing Player Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (timeAgo != null) ...<Widget>[
                    const SizedBox(width: 6),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Text(
                    '@${entry.username}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                  if (entry.guildName != null && entry.guildName!.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '<${entry.guildName}>',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              // Class Crest, Level, Combat Power Chips
              Wrap(
                spacing: 5,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5C842).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFF5C842).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Lv.${entry.level}',
                      style: const TextStyle(
                        color: Color(0xFFF5C842),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (entry.characterClass != null && entry.characterClass!.isNotEmpty)
                    ClassCrestBadge(
                      className: entry.characterClass!,
                      compact: true,
                    ),
                  if (entry.power > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.bolt_rounded,
                            size: 10,
                            color: Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            FriendClassCrest.formatCp(entry.power),
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Pending Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC34BFF)),
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Bekliyor',
                style: TextStyle(
                  color: Color(0xFFDDA8FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Cancel Outgoing Button
        if (widget.onCancelOutgoing != null) ...<Widget>[
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isAnimating ? null : () => _handleCancel(entry),
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.9,
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white60,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}


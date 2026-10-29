import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/common/profile_avatar.dart';
import '../../core/services/supabase_service.dart';
import 'friends_models.dart';

class FriendSearchBar extends StatefulWidget {
  const FriendSearchBar({
    super.key,
    required this.onSendRequest,
    this.existingFriends = const <FriendEntry>[],
    this.outgoingRequests = const <FriendEntry>[],
    this.incomingRequests = const <FriendEntry>[],
    this.blockedUsers = const <BlockedPlayerEntry>[],
    this.onPlayerSelected,
    this.hintText = 'Kullanıcı adı ile ara...',
  });

  final Future<bool> Function(String username) onSendRequest;
  final List<FriendEntry> existingFriends;
  final List<FriendEntry> outgoingRequests;
  final List<FriendEntry> incomingRequests;
  final List<BlockedPlayerEntry> blockedUsers;
  final void Function(PlayerSearchResult player)? onPlayerSelected;
  final String hintText;

  @override
  State<FriendSearchBar> createState() => _FriendSearchBarState();
}

class _FriendSearchBarState extends State<FriendSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _isLoading = false;
  String _lastQuery = '';
  int _searchRequestId = 0;
  List<PlayerSearchResult> _results = <PlayerSearchResult>[];
  final Set<String> _pendingSendUsernames = <String>{};
  final Set<String> _sentSuccessUsernames = <String>{};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(FriendSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_results.isNotEmpty) {
      _refreshResultsStatuses();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTextChanged() {
    final String query = _controller.text.trim();
    if (query == _lastQuery) return;
    _debounce?.cancel();

    if (query.length < 2) {
      _searchRequestId++;
      setState(() {
        _lastQuery = query;
        _isLoading = false;
        _results = <PlayerSearchResult>[];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  void _clearSearch() {
    HapticFeedback.selectionClick();
    _debounce?.cancel();
    _searchRequestId++;
    _controller.clear();
    setState(() {
      _lastQuery = '';
      _isLoading = false;
      _results = <PlayerSearchResult>[];
    });
  }

  Future<void> _executeSearch(String query) async {
    final int currentRequestId = ++_searchRequestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lastQuery = query;
    });

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'search_chat_users',
        params: <String, dynamic>{
          'p_query': query,
          'p_limit': 12,
        },
      );

      if (!mounted || currentRequestId != _searchRequestId) return;
      if (_controller.text.trim().toLowerCase() != query.toLowerCase()) return;

      final List<PlayerSearchResult> list = <PlayerSearchResult>[];
      if (raw is List) {
        final Set<String> friendNames = widget.existingFriends
            .map((FriendEntry f) => f.username.toLowerCase())
            .toSet();
        final Set<String> outgoingNames = widget.outgoingRequests
            .map((FriendEntry f) => f.username.toLowerCase())
            .toSet();
        final Set<String> incomingNames = widget.incomingRequests
            .map((FriendEntry f) => f.username.toLowerCase())
            .toSet();
        final Set<String> blockedIds =
            widget.blockedUsers.map((BlockedPlayerEntry b) => b.id).toSet();

        for (final dynamic item in raw) {
          if (item is! Map) continue;
          final Map<String, dynamic> map = Map<String, dynamic>.from(item);
          final String uName = (map['username'] ?? '').toString().trim();
          if (uName.isEmpty) continue;

          final String uid = (map['id'] ?? map['user_id'] ?? '').toString();
          final String lowerName = uName.toLowerCase();

          final bool isFriend = friendNames.contains(lowerName);
          final bool hasPendingOut = outgoingNames.contains(lowerName) ||
              _sentSuccessUsernames.contains(lowerName);
          final bool hasPendingIn = incomingNames.contains(lowerName);
          final bool isBlocked = blockedIds.contains(uid);

          list.add(
            PlayerSearchResult.fromJson(map).copyWith(
              id: uid,
              username: uName,
              isFriend: isFriend,
              hasPendingOutgoing: hasPendingOut,
              hasPendingIncoming: hasPendingIn,
              isBlocked: isBlocked,
            ),
          );
        }
      }

      setState(() {
        _results = list;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && currentRequestId == _searchRequestId) {
        setState(() {
          _isLoading = false;
          _results = <PlayerSearchResult>[];
        });
      }
    }
  }

  void _refreshResultsStatuses() {
    final Set<String> friendNames = widget.existingFriends
        .map((FriendEntry f) => f.username.toLowerCase())
        .toSet();
    final Set<String> outgoingNames = widget.outgoingRequests
        .map((FriendEntry f) => f.username.toLowerCase())
        .toSet();
    final Set<String> incomingNames = widget.incomingRequests
        .map((FriendEntry f) => f.username.toLowerCase())
        .toSet();
    final Set<String> blockedIds =
        widget.blockedUsers.map((BlockedPlayerEntry b) => b.id).toSet();

    setState(() {
      _results = _results.map((PlayerSearchResult p) {
        final String lowerName = p.username.toLowerCase();
        return p.copyWith(
          isFriend: friendNames.contains(lowerName),
          hasPendingOutgoing: outgoingNames.contains(lowerName) ||
              _sentSuccessUsernames.contains(lowerName),
          hasPendingIncoming: incomingNames.contains(lowerName),
          isBlocked: blockedIds.contains(p.id),
        );
      }).toList();
    });
  }

  Future<void> _handleSendRequest(PlayerSearchResult player) async {
    final String uName = player.username.trim();
    if (uName.isEmpty || _pendingSendUsernames.contains(uName)) return;

    HapticFeedback.lightImpact();

    setState(() {
      _pendingSendUsernames.add(uName);
    });

    try {
      final bool success = await widget.onSendRequest(uName);
      if (!mounted) return;
      if (success) {
        _sentSuccessUsernames.add(uName.toLowerCase());
        _results = _results.map((PlayerSearchResult p) {
          if (p.username.toLowerCase() == uName.toLowerCase()) {
            return p.copyWith(hasPendingOutgoing: true);
          }
          return p;
        }).toList();
      }
    } catch (_) {
      // Prevent stuck spinner if network or future throws
    } finally {
      if (mounted) {
        setState(() {
          _pendingSendUsernames.remove(uName);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _controller.text.trim().isNotEmpty;
    final bool showResults = hasQuery && _controller.text.trim().length >= 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSearchField(hasQuery),
        if (showResults) ...<Widget>[
          const SizedBox(height: 10),
          _buildResultsContainer(),
        ],
      ],
    );
  }

  Widget _buildSearchField(bool hasQuery) {
    final bool isFocused = _focusNode.hasFocus;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isFocused
                  ? <Color>[
                      const Color(0xFF1E1738).withValues(alpha: 0.88),
                      const Color(0xFF0F172A).withValues(alpha: 0.94),
                    ]
                  : <Color>[
                      const Color(0xFF0E1324).withValues(alpha: 0.82),
                      const Color(0xFF090D1A).withValues(alpha: 0.88),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFF9333EA).withValues(alpha: 0.9)
                  : const Color(0xFF8B5CF6).withValues(alpha: 0.25),
              width: isFocused ? 1.5 : 1.0,
            ),
            boxShadow: <BoxShadow>[
              if (isFocused)
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.32),
                  blurRadius: 16,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 2),
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isFocused ? 0.45 : 0.32),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            textInputAction: TextInputAction.search,
            cursorColor: const Color(0xFFC084FC),
            onSubmitted: (String val) {
              final String trimmed = val.trim();
              if (trimmed.length >= 2) {
                _debounce?.cancel();
                _executeSearch(trimmed);
              }
            },
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFC084FC),
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Icon(
                        Icons.search_rounded,
                        color: isFocused
                            ? const Color(0xFFC084FC)
                            : const Color(0xFF8B5CF6).withValues(alpha: 0.85),
                        size: 22,
                      ),
                    ),
              suffixIcon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: hasQuery
                    ? IconButton(
                        key: const ValueKey<String>('clear_search_btn'),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 19,
                        ),
                        tooltip: 'Aramayı Temizle',
                        splashRadius: 18,
                        onPressed: _clearSearch,
                      )
                    : const SizedBox.shrink(
                        key: ValueKey<String>('empty_suffix'),
                      ),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsContainer() {
    Widget content;
    if (_isLoading && _results.isEmpty) {
      content = _buildLoadingCard();
    } else if (_results.isEmpty) {
      content = _buildEmptyCard();
    } else {
      content = _buildResultsList();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: _resultsBoxDecoration(),
          child: content,
        ),
      ),
    );
  }

  BoxDecoration _resultsBoxDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF10172B).withValues(alpha: 0.95),
          const Color(0xFF090D1A).withValues(alpha: 0.98),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        width: 1.1,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC084FC)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Oyuncular taranıyor...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    final bool isDirectPending = _pendingSendUsernames.contains(_lastQuery);
    final bool isDirectSent =
        _sentSuccessUsernames.contains(_lastQuery.toLowerCase());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.person_search_rounded,
              color: Color(0xFFC084FC),
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '"$_lastQuery" ile eşleşen oyuncu bulunamadı.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Doğrudan bu kullanıcı adına arkadaşlık daveti iletebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          if (isDirectSent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.45),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.check_circle_rounded,
                      size: 15, color: Color(0xFF34D399)),
                  SizedBox(width: 6),
                  Text(
                    'İstek İletildi',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            FilledButton.icon(
              onPressed: isDirectPending
                  ? null
                  : () {
                      _handleSendRequest(
                        PlayerSearchResult(
                          id: '',
                          username: _lastQuery,
                        ),
                      );
                    },
              icon: isDirectPending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 14),
              label: Text('$_lastQuery Kullanıcısına Gönder'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: Color(0xFFC084FC),
              ),
              const SizedBox(width: 6),
              const Text(
                'BULUNAN OYUNCULAR',
                style: TextStyle(
                  color: Color(0xFFC084FC),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                '${_results.length} sonuç',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _results.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
              indent: 14,
              endIndent: 14,
            ),
            itemBuilder: (BuildContext context, int index) {
              final PlayerSearchResult player = _results[index];
              return _buildResultTile(player);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultTile(PlayerSearchResult player) {
    final bool isPending = _pendingSendUsernames.contains(player.username);
    final bool hasPendingOut = player.hasPendingOutgoing ||
        _sentSuccessUsernames.contains(player.username.toLowerCase());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onPlayerSelected?.call(player);
        },
        splashColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
        highlightColor: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  ProfileAvatar(
                    size: 40,
                    avatarUrl: player.avatarUrl,
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: player.isOnline
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF64748B),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0F172A),
                          width: 2,
                        ),
                        boxShadow: player.isOnline
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFF22C55E)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      player.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (player.level > 1) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  const Color(0xFFFFD700)
                                      .withValues(alpha: 0.22),
                                  const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFF5C842)
                                    .withValues(alpha: 0.55),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'Lv.${player.level}',
                              style: const TextStyle(
                                color: Color(0xFFF5C842),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                        if (player.power > 0) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '⚡${player.power}',
                              style: const TextStyle(
                                color: Color(0xFFD8B4FE),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildActionStatus(player, isPending, hasPendingOut),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionStatus(
    PlayerSearchResult player,
    bool isPending,
    bool hasPendingOut,
  ) {
    if (player.isBlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.block_rounded, size: 12, color: Color(0xFFEF4444)),
            SizedBox(width: 4),
            Text(
              'Engellendi',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (player.isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_rounded,
                size: 12, color: Color(0xFF22C55E)),
            SizedBox(width: 4),
            Text(
              'Arkadaş',
              style: TextStyle(
                color: Color(0xFF22C55E),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (hasPendingOut) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.hourglass_top_rounded,
                size: 12, color: Color(0xFFDDA8FF)),
            SizedBox(width: 4),
            Text(
              'Bekliyor',
              style: TextStyle(
                color: Color(0xFFDDA8FF),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (player.hasPendingIncoming) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF5C842).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFF5C842).withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.mark_email_unread_rounded,
                size: 12, color: Color(0xFFF5C842)),
            SizedBox(width: 4),
            Text(
              'İstek Var',
              style: TextStyle(
                color: Color(0xFFF5C842),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton(
      onPressed: isPending ? null : () => _handleSendRequest(player),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: isPending
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.person_add_alt_1_rounded, size: 14),
                SizedBox(width: 4),
                Text(
                  'Ekle',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../common/app_messenger.dart';

/// Ward board + chat for Hospital/Prison — game-flavored, not bare list.
class WardPanel extends StatefulWidget {
  const WardPanel({
    super.key,
    required this.wardType,
    required this.accent,
  });

  /// `hospital` or `prison`
  final String wardType;
  final Color accent;

  @override
  State<WardPanel> createState() => _WardPanelState();
}

class _WardPanelState extends State<WardPanel>
    with SingleTickerProviderStateMixin {
  static const Duration _pollInterval = Duration(seconds: 8);

  late final TabController _tabs;
  bool _loading = false;
  bool _chatBusy = false;
  bool _showOnCity = false;
  bool _friendsOptIn = false;
  String? _boardError;
  String? _chatError;
  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];
  Map<String, dynamic>? _self;
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  RealtimeChannel? _realtimeChannel;
  Timer? _pollTimer;
  String? _lastMessageId;

  String get _channelKey =>
      widget.wardType == 'hospital' ? 'ward_hospital' : 'ward_prison';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _refresh();
    _subscribeRealtime();
    _startPollFallback();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_realtimeChannel?.unsubscribe() ?? Future<void>.value());
    _tabs.dispose();
    _msgCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _startPollFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted || _chatBusy || _loading) return;
      unawaited(_loadChat(silent: true));
    });
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isInitialized) return;
    unawaited(_realtimeChannel?.unsubscribe() ?? Future<void>.value());

    _realtimeChannel = SupabaseService.client
        .channel('ward_chat_${_channelKey}_${widget.wardType}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel',
            value: _channelKey,
          ),
          callback: (PostgresChangePayload payload) {
            final Map<String, dynamic> row =
                Map<String, dynamic>.from(payload.newRecord);
            if (row.isEmpty || row['deleted_at'] != null) return;
            _appendRealtimeRow(row);
          },
        )
        .subscribe();
  }

  void _appendRealtimeRow(Map<String, dynamic> row) {
    final String id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (_messages.any((Map<String, dynamic> m) => m['id']?.toString() == id)) {
      return;
    }

    final Map<String, dynamic> msg = <String, dynamic>{
      'id': id,
      'channel': row['channel'] ?? _channelKey,
      'sender_id': row['sender_user_id'],
      'sender_name': row['sender_name'] ?? '?',
      'content': row['content'] ?? '',
      'created_at': row['created_at'],
    };

    if (!mounted) return;
    setState(() {
      _messages = <Map<String, dynamic>>[..._messages, msg];
      _lastMessageId = id;
      _chatError = null;
    });
    _scrollChatToEnd();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    // Parallel so chat failure cannot block board hydrate.
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _safeRpc('get_ward_board', <String, dynamic>{
        'p_ward_type': widget.wardType,
      }),
      _safeRpc('get_ward_chat_history', <String, dynamic>{
        'p_ward_type': widget.wardType,
        'p_limit': 40,
      }),
    ]);
    if (!mounted) return;

    final Object? board = results[0];
    final Object? chat = results[1];

    String? boardError;
    String? chatError;
    List<Map<String, dynamic>> entries = _entries;
    Map<String, dynamic>? self = _self;
    bool showCity = _showOnCity;
    bool friends = _friendsOptIn;
    List<Map<String, dynamic>> messages = _messages;

    if (board is Map && board['success'] == true) {
      final dynamic raw = board['entries'];
      entries = raw is List
          ? raw
              .whereType<Map>()
              .map((Map e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      self = board['self'] is Map
          ? Map<String, dynamic>.from(board['self'] as Map)
          : null;
      showCity = board['show_on_city'] == true;
      friends = board['friends_opt_in'] == true;
      boardError = null;
    } else if (board is Map) {
      boardError = (board['message'] ?? board['error'] ?? 'Pano yüklenemedi')
          .toString();
    } else if (board is String) {
      boardError = board;
    }

    if (chat is Map && chat['success'] == true) {
      messages = _parseMessages(chat['messages']);
      chatError = null;
      if (messages.isNotEmpty) {
        _lastMessageId = messages.last['id']?.toString();
      }
    } else if (chat is Map) {
      chatError = (chat['message'] ?? chat['error'] ?? 'Sohbet yüklenemedi')
          .toString();
    } else if (chat is String) {
      chatError = chat;
    }

    setState(() {
      _entries = entries;
      _self = self;
      _showOnCity = showCity;
      _friendsOptIn = friends;
      _messages = messages;
      _boardError = boardError;
      _chatError = chatError;
      _loading = false;
    });

    _scrollChatToEnd();
  }

  Future<void> _loadChat({bool silent = false}) async {
    if (_chatBusy) return;
    _chatBusy = true;
    try {
      final Object? chat = await _safeRpc('get_ward_chat_history', <String, dynamic>{
        'p_ward_type': widget.wardType,
        'p_limit': 40,
      });
      if (!mounted) return;

      if (chat is Map && chat['success'] == true) {
        final List<Map<String, dynamic>> messages =
            _parseMessages(chat['messages']);
        final String? newest =
            messages.isEmpty ? null : messages.last['id']?.toString();
        final bool changed = newest != _lastMessageId;
        if (silent && !changed) {
          return;
        }
        setState(() {
          _messages = messages;
          _chatError = null;
          _lastMessageId = newest;
        });
        if (changed) {
          _scrollChatToEnd();
        }
      } else if (!silent) {
        final String err = chat is Map
            ? (chat['message'] ?? chat['error'] ?? 'Sohbet yüklenemedi')
                .toString()
            : chat is String
                ? chat
                : 'Sohbet yüklenemedi';
        setState(() => _chatError = err);
      }
    } finally {
      _chatBusy = false;
    }
  }

  List<Map<String, dynamic>> _parseMessages(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((Map e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _scrollChatToEnd() {
    if (_messages.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_chatScroll.hasClients ||
          !_chatScroll.position.hasContentDimensions) {
        return;
      }
      // reverse:true → offset 0 = newest, pinned above composer.
      _chatScroll.jumpTo(0);
    });
  }

  Future<Object?> _safeRpc(String name, Map<String, dynamic> params) async {
    try {
      return await SupabaseService.client.rpc(name, params: params);
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _send() async {
    final String text = _msgCtrl.text.trim();
    if (text.isEmpty || _loading || _chatBusy) return;
    setState(() => _loading = true);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'send_ward_message',
        params: <String, dynamic>{
          'p_ward_type': widget.wardType,
          'p_content': text,
        },
      );
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        _msgCtrl.clear();
        final String id = res['message_id']?.toString() ?? '';
        final String content = (res['content'] ?? text).toString();
        final String senderName = (_self?['display_name'] ?? 'Sen').toString();
        if (id.isNotEmpty &&
            !_messages.any((Map<String, dynamic> m) => m['id']?.toString() == id)) {
          setState(() {
            _messages = <Map<String, dynamic>>[
              ..._messages,
              <String, dynamic>{
                'id': id,
                'channel': res['channel'] ?? _channelKey,
                'sender_name': senderName,
                'content': content,
                'created_at': DateTime.now().toIso8601String(),
              },
            ];
            _lastMessageId = id;
            _loading = false;
          });
          _scrollChatToEnd();
        } else {
          setState(() => _loading = false);
        }
        // Confirm + catch peers if realtime delayed.
        unawaited(_loadChat(silent: true));
      } else {
        final String msg = res is Map
            ? (res['message'] ?? res['error'] ?? 'Gönderilemedi').toString()
            : 'Gönderilemedi';
        AppMessenger.showError(context, msg);
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Gönderilemedi');
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveVisibility({bool? city, bool? friends}) async {
    final bool prevCity = _showOnCity;
    final bool prevFriends = _friendsOptIn;
    setState(() {
      if (city != null) _showOnCity = city;
      if (friends != null) _friendsOptIn = friends;
    });
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'set_ward_board_visibility',
        params: <String, dynamic>{
          'p_show_on_city': city,
          'p_friends_opt_in': friends,
        },
      );
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        setState(() {
          _showOnCity = res['show_on_city'] == true;
          _friendsOptIn = res['friends_opt_in'] == true;
        });
        await _refresh();
      } else {
        setState(() {
          _showOnCity = prevCity;
          _friendsOptIn = prevFriends;
        });
        AppMessenger.showError(context, 'Ayar kaydedilemedi');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _showOnCity = prevCity;
          _friendsOptIn = prevFriends;
        });
        AppMessenger.showError(context, 'Ayar kaydedilemedi');
      }
    }
  }

  String _scopeLabel(String? scope) => switch (scope) {
        'guild' => 'Lonca',
        'friends' => 'Arkadaş',
        'city' => 'Şehir',
        'self' => 'Sen',
        _ => 'Koğuş',
      };

  String _classLabel(String? raw) {
    final String c = (raw ?? '').trim();
    if (c.isEmpty) return '—';
    return c[0].toUpperCase() + c.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final bool hospital = widget.wardType == 'hospital';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.accent.withValues(alpha: 0.42)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.spaceNavy.withValues(alpha: 0.92),
            AppColors.carbonVoid.withValues(alpha: 0.96),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: widget.accent.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: <Widget>[
                Icon(
                  hospital ? Icons.hotel_rounded : Icons.lock_rounded,
                  size: 18,
                  color: widget.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hospital ? 'Koğuş · Hastane' : 'Koğuş · Hapishane',
                    style: TextStyle(
                      color: widget.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(widget.accent),
                      ),
                    ),
                  )
                else
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Yenile',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    color: AppColors.mutedTitanium,
                  ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicatorColor: widget.accent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 2,
            labelColor: widget.accent,
            unselectedLabelColor: AppColors.mutedTitanium,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            overlayColor:
                const WidgetStatePropertyAll<Color>(Colors.transparent),
            tabs: const <Widget>[
              Tab(text: 'PANO'),
              Tab(text: 'SOHBET'),
            ],
          ),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _buildBoard(),
                _buildChat(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    if (_loading && _entries.isEmpty && _self == null) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
        ),
      );
    }
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
      ?_self,
      ..._entries,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        children: <Widget>[
          if (_boardError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _boardError!,
                style: const TextStyle(
                  color: AppColors.coralFlare,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 26,
                            color: widget.accent.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Koğuş loş… Lonca arkadaşların varsayılan görünür.\n'
                            'Şehir / arkadaş panosu için opt-in aç.',
                            style: TextStyle(
                              color: AppColors.mutedTitanium
                                  .withValues(alpha: 0.95),
                              fontSize: 12,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (BuildContext context, int i) {
                      final Map<String, dynamic> e = rows[i];
                      final bool self = e['is_self'] == true;
                      return _WardMemberRow(
                        name: (e['display_name'] ?? '?').toString(),
                        self: self,
                        scope: _scopeLabel(e['scope']?.toString()),
                        timeBand: (e['time_band'] ?? '?').toString(),
                        classLabel: _classLabel(
                          e['character_class']?.toString(),
                        ),
                        accent: widget.accent,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.darkObsidian.withValues(alpha: 0.65),
              border: Border.all(
                color: widget.accent.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.group_outlined,
                  size: 14,
                  color: widget.accent.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Arkadaş',
                  style: TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Switch.adaptive(
                  value: _friendsOptIn,
                  activeTrackColor: widget.accent.withValues(alpha: 0.45),
                  thumbColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) =>
                        states.contains(WidgetState.selected)
                            ? widget.accent
                            : null,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (bool v) => _saveVisibility(friends: v),
                ),
                const Spacer(),
                Icon(
                  Icons.location_city_rounded,
                  size: 14,
                  color: widget.accent.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Şehir',
                  style: TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Switch.adaptive(
                  value: _showOnCity,
                  activeTrackColor: widget.accent.withValues(alpha: 0.45),
                  thumbColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) =>
                        states.contains(WidgetState.selected)
                            ? widget.accent
                            : null,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (bool v) => _saveVisibility(city: v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        children: <Widget>[
          if (_chatError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _chatError!,
                style: const TextStyle(
                  color: AppColors.coralFlare,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          // Messenger layout: newest hugs composer; empty void stays ABOVE.
          // Align+shrinkWrap → few msgs never leave gap under last bubble.
          // reverse:true → scroll up = older history; offset 0 = latest.
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 26,
                            color: widget.accent.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Koğuş fısıltıları henüz yok.\n'
                            'Aynı koğuştaki oyunculara 80 karakter.',
                            style: TextStyle(
                              color: AppColors.mutedTitanium
                                  .withValues(alpha: 0.95),
                              fontSize: 12,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: ListView.builder(
                      key: const ValueKey<String>('ward_chat_list'),
                      controller: _chatScroll,
                      reverse: true,
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _messages.length,
                      itemBuilder: (BuildContext context, int i) {
                        // reverse:true → index 0 at bottom (near input).
                        // _messages ASC (oldest→newest) → flip for display.
                        final Map<String, dynamic> m =
                            _messages[_messages.length - 1 - i];
                        return _ChatBubble(
                          name: (m['sender_name'] ?? '?').toString(),
                          content: (m['content'] ?? '').toString(),
                          accent: widget.accent,
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  maxLength: 80,
                  cursorColor: widget.accent,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'Koğuş mesajı…',
                    hintStyle: const TextStyle(color: AppColors.mutedTitanium),
                    filled: true,
                    fillColor: AppColors.darkObsidian.withValues(alpha: 0.65),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: widget.accent.withValues(alpha: 0.25),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: widget.accent.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: widget.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: widget.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                child: IconButton(
                  tooltip: 'Gönder',
                  onPressed: (_loading || _chatBusy) ? null : _send,
                  icon: Icon(Icons.send_rounded, color: widget.accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WardMemberRow extends StatelessWidget {
  const _WardMemberRow({
    required this.name,
    required this.self,
    required this.scope,
    required this.timeBand,
    required this.classLabel,
    required this.accent,
  });

  final String name;
  final bool self;
  final String scope;
  final String timeBand;
  final String classLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: self
            ? AppColors.liquidGold.withValues(alpha: 0.08)
            : AppColors.darkObsidian.withValues(alpha: 0.45),
        border: Border.all(
          color: self
              ? AppColors.liquidGold.withValues(alpha: 0.35)
              : accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (self ? AppColors.liquidGold : accent)
                  .withValues(alpha: 0.15),
              border: Border.all(
                color: (self ? AppColors.liquidGold : accent)
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              self
                  ? '★'
                  : (name.isNotEmpty ? name[0].toUpperCase() : '?'),
              style: TextStyle(
                color: self ? AppColors.liquidGold : accent,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: self ? AppColors.liquidGold : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: <Widget>[
                    _MiniChip(label: scope, color: accent),
                    _MiniChip(label: classLabel, color: AppColors.mutedTitanium),
                    _MiniChip(
                      label: timeBand,
                      color: AppColors.warningSolar,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        color: color.withValues(alpha: 0.1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.name,
    required this.content,
    required this.accent,
  });

  final String name;
  final String content;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // reverse ListView lays out bottom→top; top padding = gap toward older msgs.
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.darkObsidian.withValues(alpha: 0.82),
                AppColors.spaceNavy.withValues(alpha: 0.72),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                name,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

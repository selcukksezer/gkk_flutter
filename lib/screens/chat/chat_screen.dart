import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../core/staff/staff_player_entry.dart';
import '../../core/utils/keyboard_dismiss.dart';
import '../../providers/player_provider.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff_model.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'chat_design_system.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import 'widgets/chat_ban_banner.dart';
import 'widgets/chat_channel_bar.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_dm_panel.dart';
import 'widgets/chat_message_list.dart';
import 'widgets/chat_moderation_panel.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.asPanel = false});

  final bool asPanel;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const int _maxMessageLength = 200;
  static const Duration _rateLimitDuration = Duration(seconds: 2);

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _dmSearchController = TextEditingController();
  final TextEditingController _filterTermController = TextEditingController();
  final TextEditingController _filterReplacementController = TextEditingController(text: '***');
  final ScrollController _scrollController = ScrollController();

  final Map<ChatChannel, List<ChatMessage>> _messages = <ChatChannel, List<ChatMessage>>{
    ChatChannel.global: <ChatMessage>[],
    ChatChannel.guild: <ChatMessage>[],
    ChatChannel.trade: <ChatMessage>[],
    ChatChannel.dm: <ChatMessage>[],
  };

  final Set<String> _mutedPlayers = <String>{};
  final Set<String> _blockedPlayers = <String>{};
  final Map<String, BlockedChatUser> _blockedUsers = <String, BlockedChatUser>{};

  ChatChannel _activeChannel = ChatChannel.global;
  ChatModerationState _moderationState = ChatModerationState.empty(ChatChannel.global);
  List<ChatDmConversation> _dmConversations = <ChatDmConversation>[];
  List<ChatUserSummary> _dmSearchResults = <ChatUserSummary>[];

  ChatUserSummary? _activeDmPeer;

  bool _isLoading = false;
  bool _isSending = false;
  bool _isDmLoading = false;
  bool _isDmSearchLoading = false;
  bool _isModerationLoading = false;

  int _guildUnreadCount = 0;
  DateTime _lastMessageSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  RealtimeChannel? _realtimeChannel;
  final Map<String, bool> _presenceByUserId = <String, bool>{};
  Timer? _presenceTimer;

  String get _currentAuthUserId => SupabaseService.client.auth.currentUser?.id ?? '';

  String get _currentGameUserId => ref.read(playerProvider).profile?.id ?? '';

  String get _currentUserId =>
      _currentGameUserId.isNotEmpty ? _currentGameUserId : _currentAuthUserId;

  bool _isOwnSender(String senderId) {
    if (senderId.isEmpty) return false;
    return senderId == _currentGameUserId || senderId == _currentAuthUserId;
  }

  bool _isUserOnline(String userId, {bool? fallback}) {
    if (userId.isEmpty) return false;
    if (_presenceByUserId.containsKey(userId)) {
      return _presenceByUserId[userId]!;
    }
    return fallback ?? false;
  }

  void _seedPresence(String userId, bool? online) {
    if (userId.isEmpty || online == null) return;
    _presenceByUserId[userId] = online;
  }

  void _seedPresenceFromMessages(Iterable<ChatMessage> messages) {
    for (final ChatMessage message in messages) {
      _seedPresence(message.senderId, message.senderIsOnline);
    }
  }

  List<String> _collectPresenceUserIds() {
    final Set<String> ids = <String>{};
    for (final ChatDmConversation conversation in _dmConversations) {
      if (conversation.peerUserId.isNotEmpty) ids.add(conversation.peerUserId);
    }
    if (_activeDmPeer != null && _activeDmPeer!.id.isNotEmpty) {
      ids.add(_activeDmPeer!.id);
    }
    for (final ChatUserSummary user in _dmSearchResults) {
      if (user.id.isNotEmpty) ids.add(user.id);
    }
    for (final ChatMessage message in _currentMessages) {
      if (!message.isSystem && message.senderId.isNotEmpty && !_isOwnSender(message.senderId)) {
        ids.add(message.senderId);
      }
    }
    return ids.toList();
  }

  void _startPresencePolling() {
    _presenceTimer?.cancel();
    unawaited(_refreshPresence());
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(_refreshPresence()));
  }

  void _stopPresencePolling() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  Future<void> _refreshPresence() async {
    final List<String> userIds = _collectPresenceUserIds();
    if (userIds.isEmpty || !mounted) return;

    try {
      final dynamic res = await ChatRepository.rpc(
        'get_chat_presence',
        params: <String, dynamic>{'p_user_ids': userIds},
      );
      if (!mounted) return;
      if (res is List) {
        setState(() {
          for (final dynamic row in res) {
            if (row is! Map) continue;
            final String id = row['user_id']?.toString() ?? '';
            if (id.isEmpty) continue;
            _presenceByUserId[id] = row['is_online'] == true;
          }
        });
      }
    } catch (_) {
      // Non-blocking.
    }
  }


  bool? _peerPresenceFallback(String peerUserId) {
    for (final ChatDmConversation conversation in _dmConversations) {
      if (conversation.peerUserId == peerUserId) return conversation.peerIsOnline;
    }
    if (_activeDmPeer?.id == peerUserId) return _activeDmPeer?.isOnline;
    for (final ChatUserSummary user in _dmSearchResults) {
      if (user.id == peerUserId) return user.isOnline;
    }
    return null;
  }

  int get _dmUnreadCount => _dmConversations.fold<int>(0, (int total, ChatDmConversation item) => total + item.unreadCount);

  List<ChatMessage> get _currentMessages => _messages[_activeChannel] ?? const <ChatMessage>[];

  String get _topBarTitle {
    if (_activeChannel == ChatChannel.dm) {
      if (_activeDmPeer != null) {
        return '@${_activeDmPeer!.username}';
      }
      return 'Özel Mesajlar';
    }
    return switch (_activeChannel) {
      ChatChannel.global => 'Genel Sohbet',
      ChatChannel.guild => 'Lonca Sohbeti',
      ChatChannel.trade => 'Pazar Sohbeti',
      ChatChannel.dm => 'Özel Mesajlar',
    };
  }

  Future<void> _logoutHandler() => performLogout(ref);

  ChatBan? get _activeBan {
    for (final ChatBan ban in _moderationState.activeBans) {
      if (ban.scope == 'global') return ban;
      if (ban.channel == _activeChannel.key) return ban;
      if (_activeChannel == ChatChannel.guild && ban.scope == 'guild') return ban;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleComposerChanged);
    unawaited(_syncBlockedUsers());
    _subscribeRealtime();
    _startPresencePolling();
    unawaited(_loadForChannel(_activeChannel));
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerChanged);
    _messageController.dispose();
    _dmSearchController.dispose();
    _filterTermController.dispose();
    _filterReplacementController.dispose();
    _scrollController.dispose();
    _realtimeChannel?.unsubscribe();
    _stopPresencePolling();
    super.dispose();
  }


  Future<void> _loadForChannel(ChatChannel channel) async {
    setState(() {
      _isLoading = true;
      _activeChannel = channel;
      if (channel == ChatChannel.guild) {
        _guildUnreadCount = 0;
      }
      if (channel != ChatChannel.dm) {
        _activeDmPeer = null;
      }
    });

    try {
      if (channel == ChatChannel.dm) {
        await Future.wait(<Future<void>>[
          _loadModerationState(channel),
          _loadDmConversations(),
        ]);
      } else {
        await Future.wait(<Future<void>>[
          _loadHistory(channel),
          _loadModerationState(channel),
        ]);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadHistory(ChatChannel channel, {int limit = 50}) async {
    final dynamic res = await ChatRepository.rpc('get_chat_history', params: <String, dynamic>{'p_channel': channel.key, 'p_limit': limit});

    final List<ChatMessage> parsed = ((res as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => !_blockedPlayers.contains(m.senderId) && !_mutedPlayers.contains(m.senderId))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (!mounted) return;
    setState(() {
      _messages[channel] = parsed;
      _seedPresenceFromMessages(parsed);
    });
    unawaited(_refreshPresence());
    _scheduleScrollToBottom(immediate: true);
  }

  Future<void> _loadDmConversations() async {
    setState(() => _isDmLoading = true);
    try {
      final dynamic res = await ChatRepository.rpc('get_dm_conversations');
      final List<ChatDmConversation> items = ((res as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((Map m) => ChatDmConversation.fromJson(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      if (!mounted) return;
      setState(() {
        _dmConversations = items;
        for (final ChatDmConversation conversation in items) {
          _seedPresence(conversation.peerUserId, conversation.peerIsOnline);
        }
      });
      unawaited(_refreshPresence());
    } finally {
      if (mounted) setState(() => _isDmLoading = false);
    }
  }

  Future<void> _loadDmMessages(String peerUserId, {int limit = 50}) async {
    final dynamic res = await ChatRepository.rpc('get_dm_messages', params: <String, dynamic>{'p_peer_user_id': peerUserId, 'p_limit': limit});

    final List<ChatMessage> parsed = ((res as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => !_blockedPlayers.contains(m.senderId) && !_mutedPlayers.contains(m.senderId))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (!mounted) return;
    setState(() {
      _messages[ChatChannel.dm] = parsed;
      _seedPresenceFromMessages(parsed);
    });
    unawaited(_refreshPresence());
    _scheduleScrollToBottom(immediate: true);
  }

  Future<void> _markDmRead(String peerUserId) async {
    await ChatRepository.rpc('mark_dm_conversation_read', params: <String, dynamic>{'p_peer_user_id': peerUserId});
  }

  Future<void> _searchDmUsers(String query, {int limit = 8}) async {
    final String trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() => _dmSearchResults = <ChatUserSummary>[]);
      return;
    }

    setState(() => _isDmSearchLoading = true);
    try {
      final dynamic res = await ChatRepository.rpc('search_chat_users', params: <String, dynamic>{'p_query': trimmed, 'p_limit': limit});

      final List<ChatUserSummary> users = ((res as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((Map m) => ChatUserSummary.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _dmSearchResults = users;
        for (final ChatUserSummary user in users) {
          _seedPresence(user.id, user.isOnline);
        }
      });
      unawaited(_refreshPresence());
    } finally {
      if (mounted) setState(() => _isDmSearchLoading = false);
    }
  }

  Future<void> _loadModerationState(ChatChannel channel) async {
    setState(() => _isModerationLoading = true);
    try {
      final dynamic res = await ChatRepository.rpc('get_chat_moderation_state', params: <String, dynamic>{'p_channel': channel.key});

      if (!mounted) return;
      setState(() {
        _moderationState = ChatModerationState.fromJson(channel, (res as Map?)?.cast<String, dynamic>());
      });
    } catch (_) {
      if (mounted) {
        setState(() => _moderationState = ChatModerationState.empty(channel));
      }
    } finally {
      if (mounted) setState(() => _isModerationLoading = false);
    }
  }

  Future<void> _syncBlockedUsers() async {
    try {
      final dynamic res = await ChatRepository.rpc('get_blocked_chat_users');
      final List<BlockedChatUser> users = ((res as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((Map m) => BlockedChatUser.fromJson(Map<String, dynamic>.from(m)))
          .where((u) => u.id.isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _blockedUsers
          ..clear()
          ..addEntries(users.map((u) => MapEntry<String, BlockedChatUser>(u.id, u)));
        _blockedPlayers
          ..clear()
          ..addAll(_blockedUsers.keys);
        _mutedPlayers
          ..clear()
          ..addAll(_blockedUsers.keys);
      });
    } catch (_) {
      // Backward compatible: old DB may not have this RPC yet.
    }
  }

  Future<void> _unmutePlayer(
    String playerId, {
    String? playerName,
    bool showToast = true,
  }) async {
    if (playerId.isEmpty) return;

    bool serverUnblocked = false;

    try {
      final dynamic res = await ChatRepository.rpc('unblock_chat_user', params: <String, dynamic>{'p_blocked_user_id': playerId});
      final Map<String, dynamic>? data = res is Map ? Map<String, dynamic>.from(res) : null;
      serverUnblocked = data?['success'] == true;
    } catch (_) {
      serverUnblocked = false;
    }

    if (!mounted) return;

    setState(() {
      _mutedPlayers.remove(playerId);
      _blockedPlayers.remove(playerId);
      _blockedUsers.remove(playerId);
    });

    if (serverUnblocked) {
      await _loadForChannel(_activeChannel);
      await _loadDmConversations();
      if (showToast) {
        _showSnack('@${playerName ?? 'oyuncu'} için susturma kaldırıldı.');
      }
    } else if (showToast) {
      _showSnack('Yerel susturma kaldırıldı. Kalıcı kaldırma için migration gerekli olabilir.');
    }
  }

  Future<void> _openBlockedUsersSheet() async {
    await _syncBlockedUsers();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        final List<BlockedChatUser> users = _blockedUsers.values.toList(growable: false);
        if (users.isEmpty) {
          return const SafeArea(
            child: SizedBox(
              height: 180,
              child: Center(
                child: Text('Susturulan kullanıcı yok.', style: TextStyle(color: Colors.white70)),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Susturulanlar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final BlockedChatUser u = users[index];
                      final String label = u.displayName?.isNotEmpty == true ? u.displayName! : u.username;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text('@$label', style: const TextStyle(color: Colors.white)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                unawaited(_unmutePlayer(u.id, playerName: label));
                              },
                              child: const Text('Susturmayı Kaldır'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDmConversation(ChatUserSummary peer) async {
    setState(() {
      _activeChannel = ChatChannel.dm;
      _activeDmPeer = peer;
      _isLoading = true;
    });

    try {
      await _loadDmMessages(peer.id);
      await _markDmRead(peer.id);
      await _loadDmConversations();
      await _loadModerationState(ChatChannel.dm);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _leaveDmConversation() {
    setState(() {
      _activeDmPeer = null;
      _messages[ChatChannel.dm] = <ChatMessage>[];
    });
  }

  Future<void> _sendMessage() async {
    final String raw = _messageController.text;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    final Duration diff = DateTime.now().difference(_lastMessageSentAt);
    if (diff < _rateLimitDuration) {
      _showSnack('Çok hızlı yazıyorsunuz!');
      return;
    }

    if (trimmed.length > _maxMessageLength) {
      _showSnack('Mesaj çok uzun (max $_maxMessageLength karakter)');
      return;
    }

    ChatChannel targetChannel = _activeChannel;
    String targetContent = trimmed;
    String? recipientId = _activeDmPeer?.id;

    if (_activeChannel != ChatChannel.dm) {
      final RegExpMatch? mention = RegExp(r'^@([a-zA-Z0-9_.-]+)\s+([\s\S]+)$').firstMatch(trimmed);
      if (mention != null) {
        final String username = mention.group(1) ?? '';
        final String rest = (mention.group(2) ?? '').trim();
        if (rest.isEmpty) {
          _showSnack('Özel mesaj içeriği boş olamaz.');
          return;
        }
        final ChatUserSummary? peer = await _resolveDmUserByUsername(username);
        if (peer == null) {
          _showSnack('Bu kullanıcı adına ait oyuncu bulunamadı.');
          return;
        }
        targetChannel = ChatChannel.dm;
        recipientId = peer.id;
        targetContent = rest;
      }
    }

    if (targetChannel == ChatChannel.dm && (recipientId == null || recipientId.isEmpty)) {
      _showSnack('Özel mesaj için önce bir oyuncu seçin.');
      return;
    }

    if (recipientId != null && (_mutedPlayers.contains(recipientId) || _blockedPlayers.contains(recipientId))) {
      _showSnack('Bu oyuncu susturuldu/engellendiği için özel mesaj gönderemezsiniz.');
      return;
    }

    setState(() => _isSending = true);
    try {
      final dynamic result = await ChatRepository.rpc('send_chat_message', params: <String, dynamic>{
        'p_channel': targetChannel.key,
        'p_content': targetContent,
        'p_recipient_user_id': recipientId,
      });
      final Map<String, dynamic>? response = result is Map ? Map<String, dynamic>.from(result) : null;

      if (response?['success'] == true) {
        _lastMessageSentAt = DateTime.now();
        final dynamic messagePayload = response?['message'];
        if (messagePayload is Map) {
          final ChatMessage serverMessage = ChatMessage.fromJson(Map<String, dynamic>.from(messagePayload));
          _appendIfAbsent(targetChannel, serverMessage);
        } else {
          _appendLocalMessage(
            channel: targetChannel,
            content: targetContent,
            recipientUserId: recipientId,
          );
        }
        _messageController.clear();
        dismissKeyboard(context);
        _scheduleScrollToBottom(immediate: true);

        // Server state ile hizalamak için hızlı bir yenileme yap.
        if (targetChannel == ChatChannel.dm && recipientId != null && recipientId.isNotEmpty) {
          await _loadDmMessages(recipientId);
          await _loadDmConversations();
        } else {
          await _loadHistory(targetChannel);
        }

        if (targetChannel == ChatChannel.dm) {
          await _loadDmConversations();
        }
      } else {
        _showSnack(response?['error']?.toString() ?? 'Mesaj gönderilemedi');
      }
    } catch (e) {
      _showSnack('Mesaj gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<ChatUserSummary?> _resolveDmUserByUsername(String username) async {
    final String normalized = username.replaceFirst('@', '').trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final dynamic res = await ChatRepository.rpc('search_chat_users', params: <String, dynamic>{'p_query': normalized, 'p_limit': 10});

    final List<ChatUserSummary> users = ((res as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map m) => ChatUserSummary.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);

    for (final ChatUserSummary u in users) {
      if (u.username.toLowerCase() == normalized) {
        return u;
      }
    }
    return null;
  }

  Future<void> _hideDmConversation(ChatDmConversation conv) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        title: const Text('Konuşmayı sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '@${conv.peerUsername} ile konuşma listenizden kaldırılsın mı?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final dynamic res = await ChatRepository.rpc(
        'hide_dm_conversation',
        params: <String, dynamic>{'p_peer_user_id': conv.peerUserId},
      );
      final Map<String, dynamic>? data = res is Map ? Map<String, dynamic>.from(res) : null;
      if (data?['success'] != true) {
        _showSnack(data?['error']?.toString() ?? 'Konuşma silinemedi');
        return;
      }
      if (_activeDmPeer?.id == conv.peerUserId) {
        _leaveDmConversation();
      }
      await _loadDmConversations();
      _showSnack('Konuşma silindi');
    } catch (_) {
      _showSnack('Konuşma silinemedi');
    }
  }

  void _showDmConversationActions(ChatDmConversation conv) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Konuşmayı sil', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_hideDmConversation(conv));
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_rounded, color: Colors.white70),
              title: const Text('Oyuncuyu sustur', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_promptMutePlayer(
                  conv.peerUserId,
                  playerName: conv.peerUsername,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptMutePlayer(
    String playerId, {
    String? playerName,
    String? staffBadge,
  }) async {
    if (playerId.isEmpty) {
      _showSnack('Geçersiz kullanıcı.');
      return;
    }
    if (staffBadge == 'admin' || staffBadge == 'gm') {
      _showSnack('Yetkili oyuncular susturulamaz.');
      return;
    }

    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: const Text('Sustur'),
              subtitle: Text(playerName ?? 'oyuncu'),
              onTap: () => Navigator.pop(ctx, 'mute'),
            ),
          ],
        ),
      ),
    );
    if (action == 'mute') {
      await _mutePlayer(playerId, playerName: playerName);
    }
  }

  Future<void> _mutePlayer(String playerId, {String? playerName}) async {
    if (playerId.isEmpty) {
      _showSnack('Geçersiz kullanıcı.');
      return;
    }

    try {
      final dynamic res = await ChatRepository.rpc(
        'block_chat_user',
        params: <String, dynamic>{'p_blocked_user_id': playerId},
      );
      if (res is Map && res['success'] != true) {
        _showSnack(res['error']?.toString() ?? 'Oyuncu susturulamadı.');
        return;
      }
    } catch (e) {
      _showSnack(userFacingErrorMessage(e, fallback: 'Oyuncu susturulamadı.'));
      return;
    }

    setState(() {
      _mutedPlayers.add(playerId);
      _blockedPlayers.add(playerId);
      _blockedUsers[playerId] = BlockedChatUser(
        id: playerId,
        username: playerName ?? 'oyuncu',
        displayName: playerName,
      );
      _messages.updateAll(
        (_, List<ChatMessage> list) =>
            list.where((m) => m.senderId != playerId).toList(growable: false),
      );
      if (_activeDmPeer?.id == playerId) {
        _activeDmPeer = null;
      }
    });

    try {
      if (mounted) {
        final String label = playerName ?? _blockedUsers[playerId]?.username ?? 'oyuncu';
        AppMessenger.show(context, '@$label susturuldu.');
      }
      await _loadForChannel(_activeChannel);
    } catch (_) {
      _showSnack('Mesajlar yenilenemedi.');
    }
  }

  Future<void> _showReportSheet(ChatMessage msg) async {
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ListTile(title: Text('Rapor nedeni', style: TextStyle(fontWeight: FontWeight.w700))),
            ListTile(title: const Text('Spam'), onTap: () => Navigator.pop(ctx, 'spam')),
            ListTile(title: const Text('Taciz'), onTap: () => Navigator.pop(ctx, 'harassment')),
            ListTile(title: const Text('Dolandırıcılık'), onTap: () => Navigator.pop(ctx, 'scam')),
            ListTile(title: const Text('Diğer'), onTap: () => Navigator.pop(ctx, 'other')),
          ],
        ),
      ),
    );
    if (reason == null) return;
    await _reportMessage(msg.id, reason);
  }

  Future<void> _reportMessage(String messageId, String reason) async {
    try {
      final dynamic res = await ChatRepository.rpc('report_chat_message', params: <String, dynamic>{'p_message_id': messageId, 'p_reason': reason, 'p_details': null});
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _showSnack('Rapor gönderildi.');
      } else {
        _showSnack(response?['error']?.toString() ?? 'Rapor gönderilemedi.');
      }
    } catch (e) {
      _showSnack('Rapor gönderilemedi: $e');
    }
  }

  Future<void> _moderateChatMessage(ChatMessage msg, String action) async {
    final int? muteMinutes = switch (action) {
      'mod_delete' => null,
      'mod_delete_mute_15' => 15,
      'mod_delete_mute_60' => 60,
      'mod_delete_mute_4320' => 4320,
      'mod_delete_mute_7200' => 7200,
      _ => null,
    };
    if (action.startsWith('mod_') && action != 'mod_delete' && muteMinutes == null) {
      return;
    }

    try {
      final StaffProfile staff = ref.read(staffProvider).profile;
      Map<String, dynamic>? response;

      if (staff.has('chat.delete_message')) {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_message_id': msg.id,
          'p_reason': 'moderator_delete',
        };
        if (muteMinutes != null) {
          params['p_mute_minutes'] = muteMinutes;
        }
        final dynamic res = await ChatRepository.rpc('staff_moderate_chat_message', params: params);
        response = res is Map ? Map<String, dynamic>.from(res) : null;
      } else {
        final dynamic deleteRes = await ChatRepository.rpc(
          'delete_chat_message',
          params: <String, dynamic>{'p_message_id': msg.id, 'p_reason': 'moderator_delete'},
        );
        response = deleteRes is Map ? Map<String, dynamic>.from(deleteRes) : null;
        if (response?['success'] == true && muteMinutes != null && _moderationState.permissions.canBan) {
          final dynamic banRes = await ChatRepository.rpc('ban_chat_user', params: <String, dynamic>{
            'p_target_user_id': msg.senderId,
            'p_channel': msg.channel.key,
            'p_duration_minutes': muteMinutes,
            'p_reason': 'moderator_delete',
          });
          final Map<String, dynamic>? banResponse = banRes is Map ? Map<String, dynamic>.from(banRes) : null;
          if (banResponse?['success'] != true) {
            response = <String, dynamic>{
              'success': true,
              'notice': response?['notice'],
              'warning': banResponse?['error']?.toString() ?? 'Mesaj silindi ancak susturma uygulanamadi.',
            };
          } else {
            response = <String, dynamic>{
              'success': true,
              'notice': response?['notice'],
              'muted_minutes': muteMinutes,
            };
          }
        }
      }

      if (response?['success'] == true) {
        final String notice = response?['notice']?.toString() ?? 'Mesaj silindi.';
        _applyDeletedMessage(msg.id, msg.channel, notice);
        if (response?['muted_minutes'] != null) {
          _showSnack('Mesaj silindi · ${response!['muted_minutes']} dk susturma');
        } else if (response?['warning'] != null) {
          _showSnack('${response!['warning']}');
        } else {
          _showSnack('Mesaj silindi.');
        }
      } else {
        _showSnack(response?['error']?.toString() ?? 'İşlem başarısız.');
      }
    } catch (e) {
      _showSnack('İşlem başarısız: $e');
    }
  }

  void _applyDeletedMessage(String id, ChatChannel channel, String notice) {
    if (!mounted || id.isEmpty) return;
    setState(() {
      final List<ChatMessage> prev = List<ChatMessage>.from(_messages[channel] ?? const <ChatMessage>[]);
      final int idx = prev.indexWhere((ChatMessage m) => m.id == id);
      if (idx < 0) return;
      final ChatMessage old = prev[idx];
      prev[idx] = ChatMessage(
        id: old.id,
        channel: old.channel,
        senderId: old.senderId,
        senderName: old.senderName,
        content: notice,
        timestamp: old.timestamp,
        isSystem: old.isSystem,
        recipientUserId: old.recipientUserId,
        guildId: old.guildId,
        deletedAt: DateTime.now().toIso8601String(),
        senderIsOnline: old.senderIsOnline,
        senderStaffBadge: old.senderStaffBadge,
        senderKingBadge: old.senderKingBadge,
        senderGuildName: old.senderGuildName,
        senderAuthId: old.senderAuthId,
        systemTone: old.systemTone,
      );
      _messages[channel] = prev;
    });
  }

  Future<void> _banPlayer(ChatMessage msg) async {
    final TextEditingController minuteCtrl = TextEditingController(text: '30');
    final TextEditingController reasonCtrl = TextEditingController(text: 'kural ihlali');

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${msg.senderName} için ban'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: minuteCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Süre (dakika)'),
              ),
              const SizedBox(height: ChatDesignSystem.spaceMd),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Sebep'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Uygula')),
          ],
        );
      },
    );

    if (ok != true) return;

    final int duration = int.tryParse(minuteCtrl.text.trim()) ?? 0;
    final String reason = reasonCtrl.text.trim().isEmpty ? 'kural ihlali' : reasonCtrl.text.trim();
    if (duration <= 0) {
      _showSnack('Geçerli bir süre girin.');
      return;
    }

    try {
      final dynamic res = await ChatRepository.rpc('ban_chat_user', params: <String, dynamic>{
        'p_target_user_id': msg.senderId,
        'p_channel': _activeChannel.key,
        'p_duration_minutes': duration,
        'p_reason': reason,
      });
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _showSnack('Oyuncu geçici olarak sohbetten uzaklaştırıldı.');
      } else {
        _showSnack(response?['error']?.toString() ?? 'Ban uygulanamadı.');
      }
    } catch (e) {
      _showSnack('Ban uygulanamadı: $e');
    }
  }

  Future<void> _assignModerator(ChatMessage msg) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Moderator Atama'),
        content: Text('${msg.senderName} bu kanal için moderator yapılsın mı?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Onayla')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final dynamic res = await ChatRepository.rpc('assign_chat_moderator', params: <String, dynamic>{'p_target_user_id': msg.senderId, 'p_channel': _activeChannel.key});
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _showSnack('Moderator atandı.');
        await _loadModerationState(_activeChannel);
      } else {
        _showSnack(response?['error']?.toString() ?? 'Moderator atanamadı.');
      }
    } catch (e) {
      _showSnack('Moderator atanamadı: $e');
    }
  }

  Future<void> _createFilter() async {
    final String term = _filterTermController.text.trim();
    final String replacement = _filterReplacementController.text.trim().isEmpty ? '***' : _filterReplacementController.text.trim();

    if (term.isEmpty) {
      _showSnack('Filtre kelimesi boş olamaz.');
      return;
    }

    try {
      final dynamic res = await ChatRepository.rpc('create_chat_filter', params: <String, dynamic>{
        'p_term': term,
        'p_replacement': replacement,
        'p_channel': _activeChannel.key,
      });
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _filterTermController.clear();
        _filterReplacementController.text = '***';
        _showSnack('Filtre eklendi.');
        await _loadModerationState(_activeChannel);
      } else {
        _showSnack(response?['error']?.toString() ?? 'Filtre eklenemedi.');
      }
    } catch (e) {
      _showSnack('Filtre eklenemedi: $e');
    }
  }

  Future<void> _deleteFilter(String filterId) async {
    try {
      final dynamic res = await ChatRepository.rpc('delete_chat_filter', params: <String, dynamic>{'p_filter_id': filterId});
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _showSnack('Filtre silindi.');
        await _loadModerationState(_activeChannel);
      } else {
        _showSnack(response?['error']?.toString() ?? 'Filtre silinemedi.');
      }
    } catch (e) {
      _showSnack('Filtre silinemedi: $e');
    }
  }

  void _subscribeRealtime() {
    _realtimeChannel?.unsubscribe();

    _realtimeChannel = SupabaseService.client
        .channel('chat_messages_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (PostgresChangePayload payload) {
            final Map<String, dynamic> newRow = Map<String, dynamic>.from(payload.newRecord);
            final Map<String, dynamic> oldRow = Map<String, dynamic>.from(payload.oldRecord);

            if (newRow.isNotEmpty && newRow['deleted_at'] != null) {
              final String id = newRow['id']?.toString() ?? '';
              final ChatChannel channel = ChatChannelX.fromKey(newRow['channel']?.toString() ?? 'global');
              final String notice = newRow['content']?.toString() ?? 'Mesaj silindi.';
              _applyDeletedMessage(id, channel, notice);
              return;
            }

            if (newRow.isEmpty && oldRow.isNotEmpty) {
              _removeMessage(oldRow['id']?.toString() ?? '', oldRow['channel']?.toString());
              return;
            }

            if (newRow.isEmpty) return;

            final ChatMessage msg = ChatMessage.fromJson(newRow);
            if (_blockedPlayers.contains(msg.senderId) || _mutedPlayers.contains(msg.senderId)) {
              return;
            }

            if (msg.channel == ChatChannel.dm) {
              _handleIncomingDm(msg);
              return;
            }

            if (msg.channel == ChatChannel.guild && msg.senderId != _currentUserId && _activeChannel != ChatChannel.guild) {
              setState(() => _guildUnreadCount = (_guildUnreadCount + 1).clamp(0, 99));
            }

            _appendIfAbsent(msg.channel, msg);
          },
        )
        .subscribe();
  }

  void _handleIncomingDm(ChatMessage msg) {
    if (_currentUserId.isEmpty) return;

    final bool isOwn = _isOwnSender(msg.senderId);
    final String peerId = isOwn ? (msg.recipientUserId ?? '') : msg.senderId;
    if (peerId.isEmpty) return;

    final bool isActiveThread = _activeChannel == ChatChannel.dm && _activeDmPeer?.id == peerId;
    if (isActiveThread) {
      _appendIfAbsent(ChatChannel.dm, msg);
      if (!isOwn) {
        unawaited(_markDmRead(peerId));
      }
    }

    unawaited(_loadDmConversations());
  }

  void _appendIfAbsent(ChatChannel channel, ChatMessage message) {
    if (!mounted) return;
    setState(() {
      final List<ChatMessage> prev = List<ChatMessage>.from(_messages[channel] ?? const <ChatMessage>[]);
      if (prev.any((m) => m.id == message.id)) return;
      prev.add(message);
      prev.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (prev.length > 100) {
        prev.removeRange(0, prev.length - 100);
      }
      _messages[channel] = prev;
    });
    _scheduleScrollToBottom();
  }

  void _appendLocalMessage({
    required ChatChannel channel,
    required String content,
    required String? recipientUserId,
  }) {
    final String senderId = _currentUserId;
    final String nowIso = DateTime.now().toIso8601String();
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': 'local_${DateTime.now().microsecondsSinceEpoch}',
      'channel': channel.key,
      'sender_user_id': senderId,
      'sender_name': 'Sen',
      'content': content,
      'created_at': nowIso,
      'is_system': false,
      'recipient_user_id': recipientUserId,
    };
    _appendIfAbsent(channel, ChatMessage.fromJson(payload));
  }

  void _handleComposerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _scheduleScrollToBottom({bool immediate = false, int retries = 4}) {
    void attempt(int remaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (!_scrollController.hasClients) {
          if (remaining > 0) {
            Future<void>.delayed(const Duration(milliseconds: 80), () {
              attempt(remaining - 1);
            });
          }
          return;
        }

        final double target = _scrollController.position.maxScrollExtent;

        if (immediate) {
          _scrollController.jumpTo(target);
        } else {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }

        if (remaining > 0 && (_scrollController.position.maxScrollExtent - _scrollController.offset) > 8) {
          Future<void>.delayed(const Duration(milliseconds: 80), () {
            attempt(remaining - 1);
          });
        }
      });
    }

    attempt(retries);
  }

  void _removeMessage(String id, String? channelKey) {
    if (!mounted || id.isEmpty) return;
    final ChatChannel channel = ChatChannelX.fromKey(channelKey ?? 'global');
    setState(() {
      _messages[channel] = (_messages[channel] ?? const <ChatMessage>[]).where((m) => m.id != id).toList(growable: false);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppMessenger.show(context, message);
  }


  @override
  Widget build(BuildContext context) {
    final bool showDmPanel = _activeChannel == ChatChannel.dm;
    final bool showComposer = _activeChannel != ChatChannel.dm || _activeDmPeer != null;
    final StaffProfile staff = ref.watch(staffProvider).profile;
    final bool canStaffPlayer = canOpenStaffPlayerActions(staff);
    final bool canModerateMessages =
        staff.has('chat.delete_message') || _moderationState.permissions.canDelete;

    final Widget body = Column(
      children: <Widget>[
        if (widget.asPanel)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ChatChannelBar(
          activeChannel: _activeChannel,
          guildUnreadCount: _guildUnreadCount,
          dmUnreadCount: _dmUnreadCount,
          onChannelSelected: _loadForChannel,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
            child: Column(
              children: <Widget>[
                if (_activeBan != null) ChatBanBanner(ban: _activeBan!),
                ChatModerationPanel(
                  moderationState: _moderationState,
                  isLoading: _isModerationLoading,
                  filterTermController: _filterTermController,
                  filterReplacementController: _filterReplacementController,
                  onCreateFilter: _createFilter,
                  onDeleteFilter: _deleteFilter,
                ),
                Expanded(
                  child: showDmPanel
                      ? ChatDmPanel(
                          activePeer: _activeDmPeer,
                          dmSearchController: _dmSearchController,
                          isDmSearchLoading: _isDmSearchLoading,
                          isDmLoading: _isDmLoading,
                          dmSearchResults: _dmSearchResults,
                          dmConversations: _dmConversations,
                          isLoadingMessages: _isLoading,
                          messages: _currentMessages,
                          scrollController: _scrollController,
                          isOwnSender: _isOwnSender,
                          isUserOnline: _isUserOnline,
                          peerPresenceFallback: _peerPresenceFallback,
                          onSearchChanged: (String value) => unawaited(_searchDmUsers(value)),
                          onOpenConversation: _openDmConversation,
                          onConversationLongPress: _showDmConversationActions,
                          onMutePeer: () => _promptMutePlayer(
                            _activeDmPeer!.id,
                            playerName: _activeDmPeer!.username,
                          ),
                          onLeaveConversation: _leaveDmConversation,
                          onMuteSender: (String senderId, String senderName) => _mutePlayer(senderId, playerName: senderName),
                          canModerateMessages: canModerateMessages,
                          onModerateMessage: canModerateMessages
                              ? (ChatMessage m, String action) => unawaited(_moderateChatMessage(m, action))
                              : null,
                        )
                      : ChatMessageList(
                          isLoading: _isLoading,
                          messages: _currentMessages,
                          activeChannel: _activeChannel,
                          scrollController: _scrollController,
                          isOwnSender: _isOwnSender,
                          isUserOnline: _isUserOnline,
                          onMuteSender: (String senderId, String senderName) => _mutePlayer(senderId, playerName: senderName),
                          onStaffPlayerAction: canStaffPlayer
                              ? (ChatMessage m) {
                                  if (m.senderAuthId == null || m.senderAuthId!.isEmpty) return;
                                  unawaited(openStaffPlayerActions(
                                    context,
                                    ref,
                                    authId: m.senderAuthId!,
                                    username: m.senderName,
                                    displayName: m.senderName,
                                    staffBadge: m.senderStaffBadge,
                                    kingBadge: m.senderKingBadge,
                                  ));
                                }
                              : null,
                          onReportMessage: (ChatMessage m) => unawaited(_showReportSheet(m)),
                          canModerateMessages: canModerateMessages,
                          onModerateMessage: canModerateMessages
                              ? (ChatMessage m, String action) => unawaited(_moderateChatMessage(m, action))
                              : null,
                        ),
                ),
              ],
            ),
          ),
        ),
        if (showComposer)
          ChatComposer(
            asPanel: widget.asPanel,
            activeChannel: _activeChannel,
            activeBan: _activeBan,
            messageController: _messageController,
            isSending: _isSending,
            maxMessageLength: _maxMessageLength,
            blockedUserCount: _blockedUsers.length,
            onSend: _sendMessage,
            onOpenBlockedUsers: _openBlockedUsersSheet,
          ),
      ],
    );

    if (widget.asPanel) {
      return DismissKeyboard(child: body);
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      appBar: GameTopBar(title: _topBarTitle, onLogout: _logoutHandler),
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.chat,
        onLogout: _logoutHandler,
      ),
      body: DismissKeyboard(child: body),
    );
  }
}

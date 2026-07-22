import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../models/dungeon_siege_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dungeon_siege_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';

class DungeonSiegeHubScreen extends ConsumerStatefulWidget {
  const DungeonSiegeHubScreen({super.key});

  @override
  ConsumerState<DungeonSiegeHubScreen> createState() => _DungeonSiegeHubScreenState();
}

class _DungeonSiegeHubScreenState extends ConsumerState<DungeonSiegeHubScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      unawaited(ref.read(dungeonSiegeProvider.notifier).loadHub());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait<void>(<Future<void>>[
      ref.read(dungeonSiegeProvider.notifier).loadHub(),
      ref.read(dungeonSiegeProvider.notifier).loadNotifications(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final DungeonSiegeState siegeState = ref.watch(dungeonSiegeProvider);
    final DungeonSiegeHub hub = siegeState.hub ?? DungeonSiegeHub.empty();
    final DungeonSiegeStatus status = hub.status;

    return Scaffold(
      backgroundColor: AppColors.carbonVoid,
      appBar: GameTopBar(
        title: 'Kuşatma Merkezi',
        onLogout: () async => performLogout(ref),
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.dungeonSiegeHub,
        onLogout: () async => performLogout(ref),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFEF4444),
        onRefresh: _refresh,
        child: siegeState.hubLoading && siegeState.hub == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                children: <Widget>[
                  _HubStatusCard(status: status, weekKey: hub.weekKey),
                  if (siegeState.unreadNotificationCount > 0) ...<Widget>[
                    const SizedBox(height: 12),
                    _NotificationsBanner(
                      count: siegeState.unreadNotificationCount,
                      onTap: () async {
                        await ref.read(dungeonSiegeProvider.notifier).markAllNotificationsRead();
                        if (!context.mounted) return;
                        AppMessenger.showSuccess(context, 'Bildirimler okundu.');
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'Aktif Kuşatmalar'),
                  const SizedBox(height: 8),
                  if (status.sessions.isEmpty)
                    const _EmptyCard(text: 'Prime time\'da oturumlar burada görünür.')
                  else
                    ...status.sessions.map(
                      (DungeonSiegeSession session) => _SessionCard(session: session),
                    ),
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'Bölge Bağlantısı'),
                  const SizedBox(height: 8),
                  if (hub.territories.isEmpty)
                    const _EmptyCard(text: 'Lonca savaşı bölgeleri henüz eşlenmedi.')
                  else
                    ...hub.territories.map(
                      (DungeonSiegeTerritoryLink link) => _TerritoryRow(link: link),
                    ),
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'Haftalık Sıralama'),
                  const SizedBox(height: 8),
                  if (hub.leaderboard.isEmpty)
                    const _EmptyCard(text: 'Bu hafta henüz puan yok.')
                  else
                    ...hub.leaderboard.take(10).map(
                          (DungeonSiegeLeaderboardEntry entry) => _LeaderboardRow(entry: entry),
                        ),
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'Son Düellolar (24s)'),
                  const SizedBox(height: 8),
                  if (hub.recentChallenges.isEmpty)
                    const _EmptyCard(text: 'Henüz meydan okuma yok.')
                  else
                    ...hub.recentChallenges.take(12).map(
                          (DungeonSiegeRecentChallenge row) => _ChallengeRow(challenge: row),
                        ),
                ],
              ),
      ),
    );
  }
}

class _HubStatusCard extends StatelessWidget {
  const _HubStatusCard({required this.status, required this.weekKey});

  final DungeonSiegeStatus status;
  final String weekKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFFEF4444).withValues(alpha: 0.18),
            const Color(0xFF111827),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'KUŞATMA MERKEZİ',
                style: TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (weekKey.isNotEmpty)
                Text(
                  weekKey,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.siegeActive ? 'Prime time AKTİF' : 'Prime time kapalı',
            style: TextStyle(
              color: status.siegeActive ? const Color(0xFF86EFAC) : Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status.enabled
                ? '${status.sessions.length} aktif oturum · hold + bölge bonusları'
                : 'Sistem DB\'de kapalı (is_enabled=false)',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _NotificationsBanner extends StatelessWidget {
  const _NotificationsBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.notifications_active_outlined, color: Color(0xFFFBBF24), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count okunmamış kuşatma bildirimi',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const Text('Okundu', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 12)),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final DungeonSiegeSession session;

  @override
  Widget build(BuildContext context) {
    final int occupied = session.slots.where((DungeonSiegeSlot s) => s.isOccupied).length;
    final DungeonSiegeHold? hold = session.hold;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hold != null && hold.holdId.isNotEmpty
              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
              : const Color(0xFF1F2937),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                session.dungeonId.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Z${session.zoneNumber}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '$occupied/${session.slots.length}',
                style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12),
              ),
            ],
          ),
          if (session.territoryOwnerGuildName != null &&
              session.territoryOwnerGuildName!.isNotEmpty &&
              session.territoryOwnerGuildName != 'Sahipsiz') ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Bölge: ${session.territoryOwnerGuildName}',
              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11),
            ),
          ],
          if (hold != null && hold.holdId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'HOLD · ${hold.guildName ?? 'Lonca'} · kırılma ${hold.breakProgress}/${hold.breakRequired}',
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ] else if (session.guildSlots > 0) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Lonca slot: ${session.guildSlots}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _TerritoryRow extends StatelessWidget {
  const _TerritoryRow({required this.link});

  final DungeonSiegeTerritoryLink link;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${link.zoneNumber}',
              style: const TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(link.territoryName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                Text(
                  link.ownerGuildName ?? 'Sahipsiz',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final DungeonSiegeLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: entry.rank <= 3 ? const Color(0xFFFBBF24) : Colors.white38,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.playerName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                if (entry.guildName != null)
                  Text(entry.guildName!, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          Text(
            '${entry.points}p',
            style: const TextStyle(color: Color(0xFF86EFAC), fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.challenge});

  final DungeonSiegeRecentChallenge challenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: challenge.youWereInvolved
              ? const Color(0xFFEF4444).withValues(alpha: 0.35)
              : const Color(0xFF1E293B),
        ),
      ),
      child: Text(
        '${challenge.challengerName} vs ${challenge.defenderName} · ${challenge.dungeonId} · kazanan: ${challenge.winnerName}',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}

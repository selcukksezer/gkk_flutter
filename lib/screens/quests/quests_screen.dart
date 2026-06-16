import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/quest_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

// ── Category tabs ─────────────────────────────────────────────────────────────
enum _QuestCategory { all, daily, weekly, main }

// ── Premium color palette ─────────────────────────────────────────────────────
class _QColors {
  static const bg = Color(0xFF0B0F1A);
  static const surface = Color(0xFF131826);
  static const border = Color(0x18FFFFFF);
  static const gold = Color(0xFFFBBF24);
  static const purple = Color(0xFF8B5CF6);
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF97316);
  static const text = Color(0xFFE2E8F0);
  static const textMuted = Color(0xFF64748B);
}

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen>
    with TickerProviderStateMixin {
  List<QuestData> _quests = [];
  bool _loading = true;
  String? _error;
  _QuestCategory _category = _QuestCategory.all;
  bool _actionLoading = false;
  final Set<String> _knownCompletedSeasonQuests = {};

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() => _category = _QuestCategory.values[_tabCtrl.index]);
    });
    _loadQuests();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuests() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final level = ref.read(playerProvider).profile?.level ?? 1;
      final res = await SupabaseService.client.rpc(
        'get_available_quests',
        params: {'p_player_level': level},
      );
      final list = (res as List)
          .map((e) => QuestData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      String? redirectSeasonQuestId;
      for (final quest in list) {
        if (!quest.isSeasonQuest || quest.status != QuestStatus.completed)
          continue;
        final key = quest.bpPlayerQuestId ?? quest.questId;
        if (!_knownCompletedSeasonQuests.contains(key)) {
          _knownCompletedSeasonQuests.add(key);
          redirectSeasonQuestId ??= key;
        }
      }

      if (mounted) {
        setState(() {
          _quests = list;
          _loading = false;
        });
        if (redirectSeasonQuestId != null) {
          _snack('🏆 Sezon görevi tamamlandı! Ödülü sezon sayfasından al.');
          context.go(AppRoutes.season);
        }
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _claimReward(QuestData quest) async {
    setState(() => _actionLoading = true);
    try {
      await SupabaseService.client.rpc(
        'claim_quest_reward',
        params: {'p_quest_id': quest.questId},
      );
      _snack('🎁 Ödül alındı: 🪙${quest.goldReward} + ✨${quest.xpReward} XP');
      _quests.removeWhere((q) => q.questId == quest.questId);
      if (mounted) setState(() {});
      ref.read(playerProvider.notifier).loadProfile();
    } catch (e) {
      _snack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _completeQuest(QuestData quest) async {
    setState(() => _actionLoading = true);
    try {
      await SupabaseService.client.rpc(
        'complete_quest',
        params: {'p_quest_id': quest.questId},
      );
      _snack('✅ Görev tamamlandı!');
      await _loadQuests();
      ref.read(playerProvider.notifier).loadProfile();
    } catch (e) {
      _snack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppMessenger.showError(context, msg);
    } else {
      AppMessenger.showSuccess(context, msg);
    }
  }

  List<QuestData> get _filtered {
    if (_category == _QuestCategory.all) return _quests;
    // quest_id prefix encodes type: daily quests start with 'q_d_',
    // weekly with 'q_w_', main with 'q_' (no prefix override).
    // Also use difficulty as a proxy for dungeon/elite types.
    return switch (_category) {
      _QuestCategory.daily => _quests.where((q) {
        if (q.isSeasonQuest) return q.questType == 'daily';
        return q.questId.startsWith('q_d') ||
            q.difficulty == QuestDifficulty.easy ||
            q.difficulty == QuestDifficulty.medium;
      }).toList(),
      _QuestCategory.weekly => _quests.where((q) {
        if (q.isSeasonQuest) return q.questType == 'weekly';
        return q.questId.startsWith('q_w') ||
            q.difficulty == QuestDifficulty.hard;
      }).toList(),
      _QuestCategory.main => _quests.where((q) {
        if (q.isSeasonQuest) return false;
        return q.difficulty == QuestDifficulty.elite ||
            q.difficulty == QuestDifficulty.dungeon;
      }).toList(),
      _QuestCategory.all => _quests,
    };
  }

  List<QuestData> get _sortedFiltered {
    final list = [..._filtered];
    list.sort((a, b) {
      int rank(QuestData q) {
        if (q.status == QuestStatus.completed) return 0;
        if (q.status == QuestStatus.active) return 1;
        return 2;
      }

      final cmp = rank(a).compareTo(rank(b));
      if (cmp != 0) return cmp;
      final aPct = a.progressMax > 0 ? a.progress / a.progressMax : 0.0;
      final bPct = b.progressMax > 0 ? b.progress / b.progressMax : 0.0;
      return bPct.compareTo(aPct);
    });
    return list;
  }

  double get _completionRate {
    if (_quests.isEmpty) return 0;
    final done = _quests.where((q) => q.status == QuestStatus.completed).length;
    return done / _quests.length;
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _quests
        .where((q) => q.status == QuestStatus.completed)
        .length;
    final sorted = _sortedFiltered;

    return Scaffold(
      appBar: GameTopBar(title: '📜 Görevler', onLogout: _doLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.quests,
        onLogout: _doLogout,
      ),
      backgroundColor: _QColors.bg,
      body: Column(
        children: [
          // ── Hero header ─────────────────────────────────────────────────
          _buildHeader(completedCount),

          // ── Tabs ─────────────────────────────────────────────────────────
          _buildTabs(),

          const SizedBox(height: 4),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _QColors.purple),
                  )
                : _error != null
                ? _buildError()
                : sorted.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _loadQuests,
                    color: _QColors.purple,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: sorted.length,
                      itemBuilder: (_, i) => _QuestCard(
                        quest: sorted[i],
                        actionLoading: _actionLoading,
                        onComplete: () => _completeQuest(sorted[i]),
                        onClaim: () => _claimReward(sorted[i]),
                        onGoToSeason: () => context.go(AppRoutes.season),
                        onDetail: () => _showDetail(sorted[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int completedCount) {
    final total = _quests.length;
    final rate = _completionRate;
    final pct = (rate * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF131826)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _QColors.purple.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _QColors.purple.withValues(alpha: 0.12),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Genel Tamamlanma',
                  style: TextStyle(
                    color: _QColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: rate,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate >= 1.0 ? _QColors.green : _QColors.purple,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$completedCount / $total görev tamamlandı · %$pct',
                  style: const TextStyle(
                    color: _QColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  rate >= 1.0 ? _QColors.green : _QColors.purple,
                  _QColors.purple.withValues(alpha: 0.4),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _QColors.purple.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '%$pct',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Bitti',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const tabs = [
      (Icons.grid_view_rounded, 'Tümü'),
      (Icons.wb_sunny_rounded, 'Günlük'),
      (Icons.date_range_rounded, 'Haftalık'),
      (Icons.auto_awesome_rounded, 'Ana'),
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _QColors.border),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          ),
          boxShadow: [
            BoxShadow(
              color: _QColors.purple.withValues(alpha: 0.4),
              blurRadius: 8,
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _QColors.textMuted,
        tabs: tabs
            .map(
              (t) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$1, size: 13),
                    const SizedBox(width: 4),
                    Text(t.$2),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, color: _QColors.textMuted, size: 48),
        const SizedBox(height: 12),
        Text(
          'Yüklenemedi: $_error',
          style: const TextStyle(color: _QColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loadQuests,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Tekrar Dene'),
          style: FilledButton.styleFrom(backgroundColor: _QColors.purple),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _QColors.purple.withValues(alpha: 0.1),
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            color: _QColors.purple,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Henüz görev yok',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Farklı bir sekmeyi dene ya da yenile.',
          style: TextStyle(color: _QColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _loadQuests,
          icon: const Icon(Icons.refresh_rounded, size: 14),
          label: const Text('Yenile'),
        ),
      ],
    ),
  );

  void _showDetail(QuestData quest) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _QuestDetailSheet(
        quest: quest,
        actionLoading: _actionLoading,
        onClaim: () {
          Navigator.pop(ctx);
          _claimReward(quest);
        },
        onComplete: () {
          Navigator.pop(ctx);
          _completeQuest(quest);
        },
        onGoToSeason: () {
          Navigator.pop(ctx);
          context.go(AppRoutes.season);
        },
      ),
    );
  }
}

// ── Quest Card ────────────────────────────────────────────────────────────────

class _QuestCard extends StatefulWidget {
  const _QuestCard({
    required this.quest,
    required this.actionLoading,
    required this.onComplete,
    required this.onClaim,
    required this.onGoToSeason,
    required this.onDetail,
  });

  final QuestData quest;
  final bool actionLoading;
  final VoidCallback onComplete;
  final VoidCallback onClaim;
  final VoidCallback onGoToSeason;
  final VoidCallback onDetail;

  @override
  State<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<_QuestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _shimmer = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Color get _diffColor => switch (widget.quest.difficulty) {
    QuestDifficulty.easy => _QColors.green,
    QuestDifficulty.medium => _QColors.blue,
    QuestDifficulty.hard => _QColors.orange,
    QuestDifficulty.elite => _QColors.red,
    QuestDifficulty.dungeon => _QColors.purple,
  };

  String get _diffLabel => switch (widget.quest.difficulty) {
    QuestDifficulty.easy => 'Kolay',
    QuestDifficulty.medium => 'Orta',
    QuestDifficulty.hard => 'Zor',
    QuestDifficulty.elite => 'Elite',
    QuestDifficulty.dungeon => 'Zindan',
  };

  String get _statusEmoji => switch (widget.quest.status) {
    QuestStatus.available => '📋',
    QuestStatus.active => '⚡',
    QuestStatus.completed => '✅',
    QuestStatus.failed => '❌',
  };

  bool get _isCompleted => widget.quest.status == QuestStatus.completed;
  bool get _isActive => widget.quest.status == QuestStatus.active;
  bool get _canClaim => _isCompleted;
  bool get _isSeasonQuest => widget.quest.isSeasonQuest;

  bool get _needsAction =>
      _isCompleted ||
      (_isActive &&
          widget.quest.progress >= widget.quest.progressMax &&
          widget.quest.progressMax > 0);

  String? _timeLeft() {
    if (widget.quest.expiresAt == null) return null;
    final dt = DateTime.tryParse(widget.quest.expiresAt!);
    if (dt == null) return null;
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Süresi doldu';
    if (diff.inDays > 0) return '${diff.inDays}g ${diff.inHours % 24}s';
    if (diff.inHours > 0) return '${diff.inHours}s ${diff.inMinutes % 60}dk';
    return '${diff.inMinutes}dk kaldı';
  }

  @override
  Widget build(BuildContext context) {
    final progressPct = widget.quest.progressMax > 0
        ? (widget.quest.progress / widget.quest.progressMax).clamp(0.0, 1.0)
        : 0.0;

    final timeLeft = _timeLeft();
    final borderColor = _isCompleted
        ? _QColors.green.withValues(alpha: 0.5)
        : _isActive
        ? _QColors.gold.withValues(alpha: 0.3)
        : _QColors.border;

    return GestureDetector(
      onTap: widget.onDetail,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: _isCompleted
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _QColors.green.withValues(alpha: 0.08),
                    _QColors.surface,
                  ],
                )
              : null,
          color: _isCompleted ? null : _QColors.surface,
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: _isCompleted
              ? [
                  BoxShadow(
                    color: _QColors.green.withValues(alpha: 0.1),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Shimmer overlay for completed quests
            if (_isCompleted)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (_, __) => ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment(_shimmer.value - 1, 0),
                        end: Alignment(_shimmer.value, 0),
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                      ).createShader(bounds),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.quest.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _QColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status emoji
                      Text(_statusEmoji, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Badges row
                  Row(
                    children: [
                      _Badge(_diffLabel, _diffColor),
                      const SizedBox(width: 6),
                      if (widget.quest.requiredLevel > 1)
                        _Badge(
                          'Lv.${widget.quest.requiredLevel}+',
                          Colors.white38,
                        ),
                      if (timeLeft != null) ...[
                        const SizedBox(width: 6),
                        _Badge('⏱ $timeLeft', _QColors.orange),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Description
                  Text(
                    widget.quest.description,
                    style: const TextStyle(
                      color: _QColors.textMuted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Rewards row
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      if (_isSeasonQuest && widget.quest.bppReward > 0)
                        _RewardChip(
                          Icons.military_tech_rounded,
                          '${widget.quest.bppReward} BPP',
                          _QColors.gold,
                        ),
                      if (!_isSeasonQuest && widget.quest.goldReward > 0)
                        _RewardChip(
                          Icons.paid_rounded,
                          '${widget.quest.goldReward}',
                          _QColors.gold,
                        ),
                      if (!_isSeasonQuest && widget.quest.xpReward > 0)
                        _RewardChip(
                          Icons.star_rounded,
                          '${widget.quest.xpReward} XP',
                          _QColors.blue,
                        ),
                      if (!_isSeasonQuest && widget.quest.gemReward > 0)
                        _RewardChip(
                          Icons.diamond_rounded,
                          '${widget.quest.gemReward}',
                          _QColors.purple,
                        ),
                      if (!_isSeasonQuest)
                        _RewardChip(
                          Icons.flash_on_rounded,
                          '${widget.quest.energyCost}',
                          _QColors.orange,
                        ),
                      if (_isSeasonQuest) _Badge('Sezon', _QColors.gold),
                    ],
                  ),

                  if (widget.quest.progressMax > 0 && !_isCompleted) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progressPct.toDouble(),
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progressPct >= 1.0
                                    ? _QColors.green
                                    : _QColors.gold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${widget.quest.progress}/${widget.quest.progressMax}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: progressPct >= 1.0
                                ? _QColors.green
                                : _QColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_needsAction) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (widget.actionLoading) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          backgroundColor: _QColors.purple.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    if (_isSeasonQuest && _isCompleted) {
      return FilledButton.icon(
        onPressed: widget.onGoToSeason,
        icon: const Icon(Icons.emoji_events_rounded, size: 16),
        label: const Text(
          '🏆 Sezona Git — Ödül Al',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _QColors.gold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }

    if (_canClaim) {
      return FilledButton.icon(
        onPressed: widget.onClaim,
        icon: const Icon(Icons.redeem_rounded, size: 16),
        label: const Text(
          '🎁 Ödülü Al',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _QColors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }

    if (_isActive &&
        widget.quest.progress >= widget.quest.progressMax &&
        widget.quest.progressMax > 0) {
      return FilledButton.icon(
        onPressed: widget.onComplete,
        icon: const Icon(Icons.check_circle_rounded, size: 16),
        label: const Text(
          '✅ Tamamla',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _QColors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Detail Sheet ──────────────────────────────────────────────────────────────

class _QuestDetailSheet extends StatelessWidget {
  const _QuestDetailSheet({
    required this.quest,
    required this.actionLoading,
    required this.onClaim,
    required this.onComplete,
    required this.onGoToSeason,
  });

  final QuestData quest;
  final bool actionLoading;
  final VoidCallback onClaim;
  final VoidCallback onComplete;
  final VoidCallback onGoToSeason;

  @override
  Widget build(BuildContext context) {
    final progressPct = quest.progressMax > 0
        ? (quest.progress / quest.progressMax).clamp(0.0, 1.0)
        : 0.0;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xF0131826),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: _QColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _QColors.purple.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              quest.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _QColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              quest.description,
              style: const TextStyle(
                color: _QColors.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            if (quest.progressMax > 0 &&
                quest.status != QuestStatus.completed) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressPct.toDouble(),
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressPct >= 1.0 ? _QColors.green : _QColors.purple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${quest.progress}/${quest.progressMax}',
                    style: const TextStyle(
                      color: _QColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Rewards
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _QColors.border),
              ),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '🎁 ÖDÜLLER',
                      style: TextStyle(
                        color: _QColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildRewardsRow(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_hasAction) ...[
              SizedBox(width: double.infinity, child: _buildAction()),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: _QColors.border),
                ),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardsRow() {
    final chips = <Widget>[
      if (quest.isSeasonQuest && quest.bppReward > 0)
        _BigReward(
          Icons.military_tech_rounded,
          '${quest.bppReward}',
          'BPP',
          _QColors.gold,
        ),
      if (quest.goldReward > 0)
        _BigReward(
          Icons.paid_rounded,
          '${quest.goldReward}',
          'Altın',
          _QColors.gold,
        ),
      if (quest.xpReward > 0)
        _BigReward(
          Icons.star_rounded,
          '${quest.xpReward}',
          'XP',
          _QColors.blue,
        ),
      if (quest.gemReward > 0)
        _BigReward(
          Icons.diamond_rounded,
          '${quest.gemReward}',
          'Elmas',
          _QColors.purple,
        ),
    ];

    if (chips.isEmpty) {
      return const Text(
        'Ödül tanımlı değil.',
        style: TextStyle(color: _QColors.textMuted, fontSize: 13),
        textAlign: TextAlign.center,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: chips,
    );
  }

  bool get _hasAction {
    if (quest.isSeasonQuest && quest.status == QuestStatus.completed)
      return true;
    if (quest.status == QuestStatus.completed) return true;
    if (quest.status == QuestStatus.active &&
        quest.progress >= quest.progressMax &&
        quest.progressMax > 0) {
      return true;
    }
    return false;
  }

  Widget _buildAction() {
    if (actionLoading) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          backgroundColor: _QColors.purple.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    if (quest.isSeasonQuest && quest.status == QuestStatus.completed) {
      return FilledButton.icon(
        onPressed: onGoToSeason,
        icon: const Icon(Icons.emoji_events_rounded),
        label: const Text(
          '🏆 Sezona Git — Ödül Al',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _QColors.gold,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    if (quest.status == QuestStatus.completed) {
      return FilledButton.icon(
        onPressed: onClaim,
        icon: const Icon(Icons.redeem_rounded),
        label: const Text(
          '🎁 Ödülü Al',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _QColors.green,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    if (quest.status == QuestStatus.active &&
        quest.progress >= quest.progressMax &&
        quest.progressMax > 0) {
      return FilledButton.icon(
        onPressed: onComplete,
        icon: const Icon(Icons.check_circle_rounded),
        label: const Text(
          '✅ Tamamla',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _QColors.green,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class _RewardChip extends StatelessWidget {
  const _RewardChip(this.icon, this.value, this.color);
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(
        value,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _BigReward extends StatelessWidget {
  const _BigReward(this.icon, this.value, this.label, this.color);
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: _QColors.textMuted),
      ),
    ],
  );
}

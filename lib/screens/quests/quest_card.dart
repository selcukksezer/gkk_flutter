import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../models/quest_model.dart';
import 'quest_logic.dart';
import 'quest_reward_illustrations.dart';

/// 2027 Aion 2 Mobile Quests Card (V3 Elevation).
/// Features authentic RPG parchment styling, celestial glowing quest marker icon,
/// 3D reward chest preview chips, multi-layered luminous progress meter,
/// and smooth expand/collapse tap animation.
class QuestCard extends StatefulWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.actionLoading,
    required this.onComplete,
    required this.onClaim,
    required this.onGoToSeason,
    required this.onDetail,
    this.highlightClaimAnchor = false,
  });

  final QuestData quest;
  final bool actionLoading;
  final VoidCallback onComplete;
  final VoidCallback onClaim;
  final VoidCallback onGoToSeason;
  final VoidCallback onDetail;
  final bool highlightClaimAnchor;

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandCtrl.forward();
      } else {
        _expandCtrl.reverse();
      }
    });
  }

  bool get _isCompleted => widget.quest.status == QuestStatus.completed;
  bool get _isActive => widget.quest.status == QuestStatus.active;
  bool get _isSeasonQuest => widget.quest.isSeasonQuest;

  bool get _isDaily =>
      widget.quest.questType == 'daily' ||
      widget.quest.questId.startsWith('q_d') ||
      widget.quest.difficulty == QuestDifficulty.easy ||
      widget.quest.difficulty == QuestDifficulty.medium;

  bool get _isWeekly =>
      widget.quest.questType == 'weekly' ||
      widget.quest.questId.startsWith('q_w') ||
      widget.quest.difficulty == QuestDifficulty.hard;

  bool get _isEpicOrStory =>
      widget.quest.difficulty == QuestDifficulty.elite ||
      widget.quest.difficulty == QuestDifficulty.dungeon;

  Color get _categoryColor {
    if (_isCompleted) return const Color(0xFF10B981);
    if (_isSeasonQuest) return const Color(0xFFFBBF24);
    if (_isEpicOrStory) return const Color(0xFFA855F7);
    if (_isWeekly) return const Color(0xFF38BDF8);
    if (_isDaily) return const Color(0xFFF59E0B);
    return const Color(0xFF6366F1);
  }

  String get _categoryTitle {
    if (_isSeasonQuest) return 'SEZON';
    if (_isEpicOrStory) return 'DESTANSI';
    if (_isWeekly) return 'HAFTALIK';
    if (_isDaily) return 'GÜNLÜK';
    return 'GÖREV';
  }

  Color get _diffColor => switch (widget.quest.difficulty) {
        QuestDifficulty.easy => const Color(0xFF22C55E),
        QuestDifficulty.medium => const Color(0xFF38BDF8),
        QuestDifficulty.hard => const Color(0xFFF59E0B),
        QuestDifficulty.elite => const Color(0xFFEF4444),
        QuestDifficulty.dungeon => const Color(0xFFA855F7),
      };

  String get _diffLabel => switch (widget.quest.difficulty) {
        QuestDifficulty.easy => 'Kolay',
        QuestDifficulty.medium => 'Orta',
        QuestDifficulty.hard => 'Zor',
        QuestDifficulty.elite => 'Elite',
        QuestDifficulty.dungeon => 'Zindan',
      };

  String? _timeLeft() => QuestLogic.formatTimeRemaining(widget.quest.expiresAt);

  bool get _needsAction => QuestLogic.needsAction(widget.quest);

  String get _chestAssetPath {
    if (_isEpicOrStory) return 'assets/chest/kasacevher.png';
    if (_isWeekly) return 'assets/chest/kasakorsan.png';
    if (_isSeasonQuest) return 'assets/chest/kasauzay.png';
    if (widget.quest.difficulty == QuestDifficulty.hard) {
      return 'assets/chest/kasalav.png';
    }
    return 'assets/chest/kasaamazon.png';
  }

  String get _chestLabel {
    if (widget.quest.itemRewards.isNotEmpty) {
      final item = widget.quest.itemRewards.first.toLowerCase();
      if (item.contains('scale')) return 'Ejder Sandığı';
      if (item.contains('crystal')) return 'Göksel Kasa';
      if (item.contains('herb')) return 'Şifalı Kasa';
      if (item.contains('gem') || item.contains('aether')) return 'Aether Sandığı';
      return 'Ganimet Sandığı';
    }
    if (_isEpicOrStory) return 'Destansı Sandık';
    if (_isWeekly) return 'Haftalık Kasa';
    if (_isSeasonQuest) return 'Sezon Hazinesi';
    return 'Ganimet Sandığı';
  }

  @override
  Widget build(BuildContext context) {
    final progressPct = QuestLogic.calculateProgressFraction(widget.quest);
    final timeLeft = _timeLeft();
    final isUrgent = timeLeft != null && timeLeft.contains('dk');

    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _expandAnimation]),
      builder: (context, child) {
        final glowAlpha = _isCompleted
            ? 0.28 + (_pulse.value * 0.22)
            : 0.08 + (_pulse.value * 0.08);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xF010162A),
                Color(0xF20B101F),
                Color(0xF0130E22),
              ],
            ),
            border: Border.all(
              color: _isCompleted
                  ? const Color(0xFF10B981).withValues(alpha: 0.55 + (_pulse.value * 0.3))
                  : _categoryColor.withValues(alpha: 0.32),
              width: _isCompleted ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _categoryColor.withValues(alpha: glowAlpha),
                blurRadius: _isCompleted ? 22 : 14,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0x77000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onDetail();
                  },
                  splashColor: _categoryColor.withValues(alpha: 0.15),
                  highlightColor: _categoryColor.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Meta Row: Category Badge, Difficulty, Expiry, Expand/Collapse Toggle
                        Row(
                          children: [
                            // Category Tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _categoryColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _categoryColor.withValues(alpha: 0.45),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                _categoryTitle,
                                style: TextStyle(
                                  color: _categoryColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Difficulty Tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _diffColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _diffColor.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                _diffLabel,
                                style: TextStyle(
                                  color: _diffColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (widget.quest.requiredLevel > 1) ...[
                              const SizedBox(width: 6),
                              Text(
                                'Lv.${widget.quest.requiredLevel}+',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (timeLeft != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (isUrgent
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFF59E0B))
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: (isUrgent
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFF59E0B))
                                        .withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '⏱ $timeLeft',
                                  style: TextStyle(
                                    color: isUrgent
                                        ? const Color(0xFFF87171)
                                        : const Color(0xFFFBBF24),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            // Interactive Expand / Collapse Pill
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleExpand,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    RotationTransition(
                                      turns: Tween(begin: 0.0, end: 0.5)
                                          .animate(_expandAnimation),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 15,
                                        color: _isExpanded
                                            ? _categoryColor
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Quest Marker & Quest Title Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Celestial Glowing Quest Marker
                            _buildGlowingQuestMarker(),
                            const SizedBox(width: 10),

                            // Quest Title & Optional Completion Checkmark
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.quest.name,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFF1F5F9),
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ),
                                      if (_isCompleted) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.all(2.5),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF10B981),
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // RPG Quest Parchment Styling Dialogue / Description
                        _buildParchmentDescriptionBox(),
                        const SizedBox(height: 10),

                        // Reward Items Preview Chips (assets/chest/ + vector pills)
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            // 3D Chest Preview Chip
                            _buildChestPreviewChip(),
                            if (_isSeasonQuest && widget.quest.bppReward > 0)
                              QuestRewardPill(
                                type: QuestRewardType.bpp,
                                amount: '+${widget.quest.bppReward}',
                                suffix: 'BPP',
                              ),
                            if (!_isSeasonQuest && widget.quest.goldReward > 0)
                              QuestRewardPill(
                                type: QuestRewardType.gold,
                                amount: '${widget.quest.goldReward}',
                              ),
                            if (!_isSeasonQuest && widget.quest.xpReward > 0)
                              QuestRewardPill(
                                type: QuestRewardType.xp,
                                amount: '+${widget.quest.xpReward} XP',
                              ),
                            if (!_isSeasonQuest && widget.quest.gemReward > 0)
                              QuestRewardPill(
                                type: QuestRewardType.gem,
                                amount: '${widget.quest.gemReward}',
                              ),
                            if (!_isSeasonQuest && widget.quest.energyCost > 0)
                              QuestRewardPill(
                                type: QuestRewardType.energy,
                                amount: '${widget.quest.energyCost}',
                                suffix: '⚡',
                              ),
                            for (final item in widget.quest.itemRewards)
                              QuestRewardPill(
                                type: QuestRewardType.material,
                                amount: item,
                              ),
                          ],
                        ),

                        // Objective Progress Meter with Luminous Fill
                        if (widget.quest.progressMax > 0 && !_isCompleted) ...[
                          const SizedBox(height: 10),
                          _buildLuminousProgressBar(progressPct),
                        ],

                        // Smooth Expand/Collapse Drawer Content
                        SizeTransition(
                          sizeFactor: _expandAnimation,
                          axisAlignment: -1.0,
                          child: _buildExpandedParchmentDrawer(progressPct),
                        ),

                        // Interactive Action Button
                        if (_needsAction) ...[
                          const SizedBox(height: 11),
                          SizedBox(
                            width: double.infinity,
                            child: _buildCardActionButton(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Glowing quest marker emblem wiring `hud_quest_marker_gold.png` with celestial glow.
  Widget _buildGlowingQuestMarker() {
    final markerGlow = _isCompleted
        ? const Color(0xFF10B981)
        : (_isSeasonQuest
            ? const Color(0xFFFBBF24)
            : (_isEpicOrStory ? const Color(0xFFA855F7) : const Color(0xFFF59E0B)));

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            markerGlow.withValues(alpha: 0.28),
            const Color(0xFF1E1B4B).withValues(alpha: 0.6),
          ],
        ),
        border: Border.all(
          color: markerGlow.withValues(alpha: 0.55 + (_pulse.value * 0.25)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: markerGlow.withValues(alpha: 0.3 + (_pulse.value * 0.25)),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          'assets/images/aion2_ui/hud_quest_marker_gold.png',
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => Icon(
            _isSeasonQuest
                ? Icons.emoji_events_rounded
                : (_isCompleted
                    ? Icons.assignment_turned_in_rounded
                    : Icons.explore_rounded),
            size: 20,
            color: markerGlow,
          ),
        ),
      ),
    );
  }

  /// RPG quest parchment card styling container for description/lore.
  Widget _buildParchmentDescriptionBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x1EF6E58D), // Subtle antique parchment tint
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.22), // Antique gold filigree
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1.5, right: 6),
            child: Icon(
              Icons.auto_stories_rounded,
              size: 13,
              color: Color(0xFFE2C489),
            ),
          ),
          Expanded(
            child: Text(
              widget.quest.description,
              maxLines: _isExpanded ? 5 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3D reward chest preview chip utilizing `assets/chest/`.
  Widget _buildChestPreviewChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _categoryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _categoryColor.withValues(alpha: 0.38),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            _chestAssetPath,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => Icon(
              Icons.inventory_2_rounded,
              size: 14,
              color: _categoryColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _chestLabel,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _categoryColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Objective progress meter with luminous fill and glint tip.
  Widget _buildLuminousProgressBar(double progressPct) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 7.0,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.6,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fillW = (constraints.maxWidth * progressPct).clamp(
                  0.0,
                  constraints.maxWidth,
                );
                return Stack(
                  children: [
                    Container(
                      width: fillW,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(
                          colors: progressPct >= 1.0
                              ? const [
                                  Color(0xFF059669),
                                  Color(0xFF10B981),
                                  Color(0xFF34D399),
                                ]
                              : const [
                                  Color(0xFF4338CA),
                                  Color(0xFF38BDF8),
                                  Color(0xFF7DD3FC),
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (progressPct >= 1.0
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF38BDF8))
                                .withValues(alpha: 0.45),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${widget.quest.progress}/${widget.quest.progressMax}',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: progressPct >= 1.0
                ? const Color(0xFF34D399)
                : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  /// Expanded drawer revealing full dialogue parchment box, mechanics, and quick details.
  Widget _buildExpandedParchmentDrawer(double progressPct) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dialogue Parchment Box Graphic Header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/images/aion2_ui/hud_dialogue_parchment_box.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'DAEVA GÖREV PARŞÖMENİ',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '%${(progressPct * 100).toInt()} Tamamlandı',
                  style: TextStyle(
                    color: progressPct >= 1.0
                        ? const Color(0xFF34D399)
                        : const Color(0xFF38BDF8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Target, Energy, and Level detail pills
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (widget.quest.target > 0)
                  _buildDrawerDetailPill(
                    icon: Icons.track_changes_rounded,
                    label: 'Hedef: ${widget.quest.target}x',
                    color: const Color(0xFF38BDF8),
                  ),
                if (widget.quest.energyCost > 0)
                  _buildDrawerDetailPill(
                    icon: Icons.bolt_rounded,
                    label: '${widget.quest.energyCost} Enerji',
                    color: const Color(0xFFFB923C),
                  ),
                if (widget.quest.requiredLevel > 1)
                  _buildDrawerDetailPill(
                    icon: Icons.shield_rounded,
                    label: 'Gereksinim: Lv.${widget.quest.requiredLevel}+',
                    color: const Color(0xFFA855F7),
                  ),
                if (widget.quest.itemRewards.isNotEmpty)
                  _buildDrawerDetailPill(
                    icon: Icons.diamond_rounded,
                    label: 'Özel Ganimet: ${widget.quest.itemRewards.first}',
                    color: const Color(0xFFFBBF24),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerDetailPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardActionButton() {
    if (widget.actionLoading) {
      return Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF38BDF8),
            ),
          ),
        ),
      );
    }

    if (_isSeasonQuest && _isCompleted) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onGoToSeason();
            },
            borderRadius: BorderRadius.circular(11),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_rounded, size: 15, color: Colors.black87),
                  SizedBox(width: 6),
                  Text(
                    '🏆 Sezona Git — Ödül Al',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isCompleted) {
      final Widget claimBtn = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.heavyImpact();
              widget.onClaim();
            },
            borderRadius: BorderRadius.circular(11),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '🎁 Ödülü Al',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      return widget.highlightClaimAnchor
          ? TutorialAnchorScope(
              id: TutorialAnchorId.questsClaimBtn,
              child: claimBtn,
            )
          : claimBtn;
    }

    if (_isActive &&
        widget.quest.progress >= widget.quest.progressMax &&
        widget.quest.progressMax > 0) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.32),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onComplete();
            },
            borderRadius: BorderRadius.circular(11),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '✅ Tamamla',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}


import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/quest_model.dart';
import '../../theme/app_colors.dart';
import 'quest_logic.dart';
import 'quest_reward_illustrations.dart';

/// Shows the Aion 2 2027 standard celestial quest detail modal sheet.
void showQuestDetailModal({
  required BuildContext context,
  required QuestData quest,
  required bool actionLoading,
  required VoidCallback onClaim,
  required VoidCallback onComplete,
  required VoidCallback onGoToSeason,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: true,
    builder: (ctx) => _QuestDetailModalSheet(
      quest: quest,
      actionLoading: actionLoading,
      onClaim: () {
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        HapticFeedback.mediumImpact();
        onClaim();
      },
      onComplete: () {
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        HapticFeedback.mediumImpact();
        onComplete();
      },
      onGoToSeason: () {
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        HapticFeedback.lightImpact();
        onGoToSeason();
      },
    ),
  );
}

class _QuestDetailModalSheet extends StatefulWidget {
  const _QuestDetailModalSheet({
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
  State<_QuestDetailModalSheet> createState() => _QuestDetailModalSheetState();
}

class _QuestDetailModalSheetState extends State<_QuestDetailModalSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _particleController;
  late final List<_GoldParticle> _particles;
  bool _isClaiming = false;

  QuestData get quest => widget.quest;
  bool get actionLoading => widget.actionLoading;
  VoidCallback get onClaim => widget.onClaim;
  VoidCallback get onComplete => widget.onComplete;
  VoidCallback get onGoToSeason => widget.onGoToSeason;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _particles = _generateParticles(32);
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    if (_isClaiming || widget.actionLoading) return;
    setState(() {
      _isClaiming = true;
    });
    HapticFeedback.heavyImpact();
    _particleController.forward(from: 0.0);
    // Allow particle burst animation to erupt before triggering claim callback
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    widget.onClaim();
  }

  void _handleComplete() {
    if (widget.actionLoading) return;
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    widget.onComplete();
  }

  void _handleGoToSeason() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    widget.onGoToSeason();
  }

  Color get _diffColor => switch (quest.difficulty) {
        QuestDifficulty.easy => const Color(0xFF22C55E),
        QuestDifficulty.medium => const Color(0xFF38BDF8),
        QuestDifficulty.hard => const Color(0xFFF59E0B),
        QuestDifficulty.elite => const Color(0xFFEF4444),
        QuestDifficulty.dungeon => const Color(0xFFA855F7),
      };

  String get _diffLabel => switch (quest.difficulty) {
        QuestDifficulty.easy => 'Kolay',
        QuestDifficulty.medium => 'Orta',
        QuestDifficulty.hard => 'Zor',
        QuestDifficulty.elite => 'Elite',
        QuestDifficulty.dungeon => 'Zindan',
      };

  String get _categoryLabel {
    if (quest.isSeasonQuest) return 'Sezon Görevi';
    if (quest.questType == 'daily' || quest.questId.startsWith('q_d')) {
      return 'Günlük Görev';
    }
    if (quest.questType == 'weekly' || quest.questId.startsWith('q_w')) {
      return 'Haftalık Sefer';
    }
    if (quest.difficulty == QuestDifficulty.dungeon) return 'Zindan Keşfi';
    if (quest.difficulty == QuestDifficulty.elite) return 'Destansı Görev';
    return 'Macera Görevi';
  }

  String? _timeLeft() => QuestLogic.formatTimeRemaining(quest.expiresAt);

  bool get _hasAction => QuestLogic.needsAction(quest);

  bool get _isObjectiveDone =>
      quest.status == QuestStatus.completed ||
      (quest.progressMax > 0 && quest.progress >= quest.progressMax);

  bool get _isEpicOrDungeon =>
      quest.difficulty == QuestDifficulty.elite ||
      quest.difficulty == QuestDifficulty.dungeon ||
      quest.itemRewards.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final progressPct = QuestLogic.calculateProgressFraction(quest);
    final timeLeft = _timeLeft();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: const Color(0xFA080D1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(
            color: _diffColor.withValues(alpha: 0.42),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 40,
              spreadRadius: 8,
            ),
            BoxShadow(
              color: _diffColor.withValues(alpha: 0.22),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag bar & close icon
              _buildTopBar(context),

              // Scrollable content area
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(timeLeft),
                      const SizedBox(height: 14),
                      _buildDescription(),
                      const SizedBox(height: 16),
                      _buildRequirementsChecklist(progressPct, timeLeft),
                      const SizedBox(height: 16),
                      _buildRewardsSection(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Bottom sticky action & close buttons
              _buildBottomActions(context, progressPct),
            ],
          ),
        ),
      ),
    );
  }

  /// Top bar with drag handle, celestial runic accents, and circular close button
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _diffColor.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 48,
                    height: 4.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _diffColor.withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0.55),
                          _diffColor.withValues(alpha: 0.35),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _diffColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF94A3B8),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(32, 32),
              shape: const CircleBorder(),
            ),
            tooltip: 'Kapat',
          ),
        ],
      ),
    );
  }

  /// Celestial Crest, Badges and Quest Title
  Widget _buildHeader(String? timeLeft) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Celestial Category Crest Icon with Gold Marker Wiring
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _diffColor.withValues(alpha: 0.38),
                const Color(0xFF1E1B4B),
              ],
            ),
            border: Border.all(
              color: _diffColor.withValues(alpha: 0.65),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: _diffColor.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/aion2_ui/hud_quest_marker_gold.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                quest.isSeasonQuest
                    ? Icons.military_tech_rounded
                    : (quest.difficulty == QuestDifficulty.dungeon
                        ? Icons.castle_rounded
                        : (quest.difficulty == QuestDifficulty.elite
                            ? Icons.shield_moon_rounded
                            : Icons.auto_awesome_rounded)),
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Title and Metadata Badges
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Difficulty badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: _diffColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _diffColor.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _diffLabel,
                      style: TextStyle(
                        color: _diffColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _categoryLabel,
                      style: const TextStyle(
                        color: Color(0xFFA5B4FC),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  // Level requirement badge
                  if (quest.requiredLevel > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Lv.${quest.requiredLevel}+',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Expiration badge
                  if (timeLeft != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB923C).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFB923C).withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '⏱ $timeLeft',
                        style: const TextStyle(
                          color: Color(0xFFFB923C),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                quest.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF8FAFC),
                  letterSpacing: 0.1,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Grand Quest Briefing Scroll & Parchment Lore Section
  Widget _buildDescription() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFA120E08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC5A059).withValues(alpha: 0.38),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Ambient parchment background texture
            Positioned.fill(
              child: Opacity(
                opacity: 0.20,
                child: Image.asset(
                  'assets/images/aion2_ui/hud_dialogue_parchment_box.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

            // Subtle parchment gradient overlay for high contrast
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1E1710).withValues(alpha: 0.88),
                      const Color(0xFF15100B).withValues(alpha: 0.94),
                      const Color(0xFF0F0B07).withValues(alpha: 0.96),
                    ],
                  ),
                ),
              ),
            ),

            // Parchment Lore Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Archival lore header rubric
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          size: 13,
                          color: Color(0xFFFFDF78),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '✦ GÖREV PROTOKOLÜ & KADİM PARŞÖMEN ✦',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'ARCHIVAL RECORD',
                        style: TextStyle(
                          color: Color(0xFF8A7A58),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Decorative filigree divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFD4AF37).withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Quest lore story typography
                  Text(
                    quest.description,
                    style: const TextStyle(
                      color: Color(0xFFE8DAC2),
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Requirement Checklists & Objectives
  Widget _buildRequirementsChecklist(double progressPct, String? timeLeft) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_rounded,
                size: 14,
                color: Color(0xFF38BDF8),
              ),
              const SizedBox(width: 6),
              const Text(
                'GÖREV GEREKSİNİMLERİ & HEDEFLER',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _isObjectiveDone
                      ? const Color(0xFF10B981).withValues(alpha: 0.18)
                      : const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isObjectiveDone
                        ? const Color(0xFF10B981).withValues(alpha: 0.45)
                        : const Color(0xFF38BDF8).withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _isObjectiveDone
                      ? 'Tamamlandı'
                      : '%${(progressPct * 100).toInt()}',
                  style: TextStyle(
                    color: _isObjectiveDone
                        ? const Color(0xFF34D399)
                        : const Color(0xFF38BDF8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Primary Target Checklist item
          _buildChecklistItem(
            icon: _isObjectiveDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            iconColor: _isObjectiveDone
                ? const Color(0xFF34D399)
                : const Color(0xFF38BDF8),
            title: quest.target > 0
                ? 'Hedef: ${quest.target}x ${quest.name}'
                : 'Görev Hedefini Gerçekleştir',
            statusText: quest.progressMax > 0
                ? '${quest.progress} / ${quest.progressMax}'
                : (_isObjectiveDone ? '1 / 1' : '0 / 1'),
            isDone: _isObjectiveDone,
            progressFraction: progressPct,
            showProgressBar: quest.progressMax > 0,
          ),
          const SizedBox(height: 8),

          // Level requirement checklist item
          _buildChecklistItem(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFFA855F7),
            title: 'Karakter Seviyesi: Lv.${quest.requiredLevel}+',
            statusText: 'Gereksinim Karşılandı',
            isDone: true,
          ),
          const SizedBox(height: 8),

          // Energy cost checklist item
          _buildChecklistItem(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFFFBBF24),
            title: quest.energyCost > 0
                ? 'Enerji Tüketimi: ${quest.energyCost} Enerji'
                : 'Enerji Tüketimi: 0 (Ücretsiz)',
            statusText: quest.energyCost > 0 ? 'Harcama' : 'Ücretsiz',
            isDone: true,
          ),

          // Expiration checklist item (if applicable)
          if (timeLeft != null) ...[
            const SizedBox(height: 8),
            _buildChecklistItem(
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFFFB923C),
              title: 'Görev Zaman Penceresi',
              statusText: timeLeft,
              isDone: !timeLeft.contains('Süresi doldu'),
            ),
          ],
        ],
      ),
    );
  }

  /// Individual checklist row with icon, title, progress bar, and status
  Widget _buildChecklistItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String statusText,
    required bool isDone,
    double progressFraction = 1.0,
    bool showProgressBar = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: isDone
                      ? const Color(0xFF34D399)
                      : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (showProgressBar && quest.status != QuestStatus.completed) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressFraction >= 1.0
                      ? const Color(0xFF34D399)
                      : const Color(0xFF38BDF8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Authentic Rewards Section with Epic Loot Styling & Item Drops Breakdown
  Widget _buildRewardsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isEpicOrDungeon
              ? const Color(0xFFA855F7).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.military_tech_outlined,
                size: 14,
                color: Color(0xFFFBBF24),
              ),
              const SizedBox(width: 5),
              // Must match exact test locator string '🎁 KAZANILACAK ÖDÜLLER'
              const Text(
                '🎁 KAZANILACAK ÖDÜLLER',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              if (_isEpicOrDungeon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 10,
                        color: Color(0xFFD8B4FE),
                      ),
                      SizedBox(width: 3.5),
                      Text(
                        'DESTANSI GANİMET',
                        style: TextStyle(
                          color: Color(0xFFD8B4FE),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Rewards Cards Grid
          _buildRewardsGrid(),

          // Detailed Item Drops breakdown (if quest contains items)
          if (quest.itemRewards.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildItemDropsList(),
          ],
        ],
      ),
    );
  }

  /// Horizontal scroll cards for standard currency & items
  Widget _buildRewardsGrid() {
    final cards = <Widget>[
      if (quest.isSeasonQuest && quest.bppReward > 0)
        QuestRewardDetailedCard(
          type: QuestRewardType.bpp,
          amount: '+${quest.bppReward}',
          title: 'Battle Pass',
        ),
      if (quest.goldReward > 0)
        QuestRewardDetailedCard(
          type: QuestRewardType.gold,
          amount: '+${quest.goldReward}',
          title: 'Altın',
        ),
      if (quest.xpReward > 0)
        QuestRewardDetailedCard(
          type: QuestRewardType.xp,
          amount: '+${quest.xpReward}',
          title: 'Deneyim',
        ),
      if (quest.gemReward > 0)
        QuestRewardDetailedCard(
          type: QuestRewardType.gem,
          amount: '+${quest.gemReward}',
          title: 'Elmas',
        ),
      if (quest.energyCost > 0)
        QuestRewardDetailedCard(
          type: QuestRewardType.energy,
          amount: '${quest.energyCost}',
          title: 'Enerji Harcar',
        ),
      for (final item in quest.itemRewards)
        QuestRewardDetailedCard(
          type: QuestRewardType.material,
          amount: '1x',
          title: _itemDisplayName(item),
        ),
    ];

    if (cards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Bu görev için ödül tanımlanmamış.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: c,
                ))
            .toList(),
      ),
    );
  }

  /// Authentic Item Drops breakdown list with rarity tiers and badges
  Widget _buildItemDropsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 12, color: Color(0xFFA855F7)),
            SizedBox(width: 4),
            Text(
              'ÖZEL EŞYA DROPLARI',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final item in quest.itemRewards) ...[
          _buildItemDropCard(item),
          const SizedBox(height: 5),
        ],
      ],
    );
  }

  /// Custom rarity-styled card for item drop
  Widget _buildItemDropCard(String itemId) {
    final color = _itemRarityColor(itemId);
    final rarityLabel = _itemRarityLabel(itemId);
    final displayName = _itemDisplayName(itemId);
    final icon = _itemRarityIcon(itemId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$rarityLabel Malzeme',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: const Text(
              '%100 Drop',
              style: TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sticky Bottom Action and Dismiss buttons
  Widget _buildBottomActions(BuildContext context, double progressPct) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF090D1A).withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasAction) ...[
            _buildActionButton(),
            const SizedBox(height: 10),
          ] else if (quest.status == QuestStatus.active) ...[
            _buildInProgressStatus(progressPct),
            const SizedBox(height: 10),
          ],

          // Close Button
          OutlinedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text(
              'Kapat',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Active in-progress informational pill
  Widget _buildInProgressStatus(double progressPct) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Görev Sürdürülüyor — %${(progressPct * 100).toInt()} Tamamlandı',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Primary Action Button (Claim with Gold Particle Burst, Complete, Season Redirect)
  Widget _buildActionButton() {
    if (actionLoading) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0xFF38BDF8),
            ),
          ),
        ),
      );
    }

    if (quest.isSeasonQuest && quest.status == QuestStatus.completed) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _handleGoToSeason,
          icon: const Icon(Icons.emoji_events_rounded, color: Colors.black87),
          label: const Text(
            '🏆 Sezona Git — Ödül Al',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    if (quest.status == QuestStatus.completed) {
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isClaiming ? null : _handleClaim,
              icon: const Icon(Icons.card_giftcard_rounded, color: Colors.white),
              label: const Text(
                '🎁 Ödülü Al',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          // Radiant Golden Particle Burst Overlay on Claim
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GoldParticleBurstPainter(
                  animation: _particleController,
                  particles: _particles,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (quest.status == QuestStatus.active &&
        quest.progress >= quest.progressMax &&
        quest.progressMax > 0) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _handleComplete,
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
          label: const Text(
            '✅ Tamamla',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ──────────────────────────── Item Rarity Helpers ──────────────────────────

  Color _itemRarityColor(String itemId) {
    final id = itemId.toLowerCase();
    if (id.contains('crystal') ||
        id.contains('celestial') ||
        id.contains('mythic')) {
      return AppColors.rarityLegendary;
    }
    if (id.contains('dragon') ||
        id.contains('scale') ||
        id.contains('epic') ||
        id.contains('boss')) {
      return AppColors.rarityEpic;
    }
    if (id.contains('gem') || id.contains('aether') || id.contains('rare')) {
      return AppColors.rarityRare;
    }
    if (id.contains('herb') || id.contains('uncommon')) {
      return AppColors.rarityUncommon;
    }
    return AppColors.rarityCommon;
  }

  String _itemRarityLabel(String itemId) {
    final id = itemId.toLowerCase();
    if (id.contains('crystal') ||
        id.contains('celestial') ||
        id.contains('mythic')) {
      return 'Efsanevi';
    }
    if (id.contains('dragon') ||
        id.contains('scale') ||
        id.contains('epic') ||
        id.contains('boss')) {
      return 'Destansı';
    }
    if (id.contains('gem') || id.contains('aether') || id.contains('rare')) {
      return 'Nadir';
    }
    if (id.contains('herb') || id.contains('uncommon')) {
      return 'Sıradışı';
    }
    return 'Standart';
  }

  IconData _itemRarityIcon(String itemId) {
    final id = itemId.toLowerCase();
    if (id.contains('crystal') || id.contains('celestial')) {
      return Icons.diamond_rounded;
    }
    if (id.contains('dragon') || id.contains('scale')) {
      return Icons.shield_rounded;
    }
    if (id.contains('gem') || id.contains('aether')) {
      return Icons.auto_awesome_rounded;
    }
    if (id.contains('herb')) {
      return Icons.eco_rounded;
    }
    return Icons.category_rounded;
  }

  String _itemDisplayName(String itemId) {
    switch (itemId.toLowerCase().trim()) {
      case 'herb_sacred':
        return 'Kutsal Şifalı Ot';
      case 'dragon_scale':
        return 'Kadim Ejderha Pulu';
      case 'celestial_crystal':
        return 'Göksel Aether Kristali';
      case 'aether_gem':
        return 'Saf Aether Mücevheri';
      default:
        return itemId
            .split('_')
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
    }
  }
}

// ──────────────────────────── Gold Particle Burst System ──────────────────────────

class _GoldParticle {
  const _GoldParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.isStar,
    required this.rotationSpeed,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final bool isStar;
  final double rotationSpeed;
}

List<_GoldParticle> _generateParticles(int count) {
  final math.Random random = math.Random(1337);
  final List<Color> goldPalette = <Color>[
    const Color(0xFFFFE066),
    const Color(0xFFFBBF24),
    const Color(0xFFF59E0B),
    const Color(0xFFFFFBEB),
    const Color(0xFFFFD700),
    const Color(0xFFD97706),
  ];

  return List<_GoldParticle>.generate(count, (int index) {
    final double angle =
        (index / count) * math.pi * 2 + (random.nextDouble() - 0.5) * 0.4;
    final double speed = 80.0 + random.nextDouble() * 95.0;
    final double size = 2.5 + random.nextDouble() * 3.5;
    final Color color = goldPalette[random.nextInt(goldPalette.length)];
    final bool isStar = index % 3 == 0;
    final double rotationSpeed =
        (random.nextBool() ? 1.0 : -1.0) * (2.0 + random.nextDouble() * 4.0);

    return _GoldParticle(
      angle: angle,
      speed: speed,
      size: size,
      color: color,
      isStar: isStar,
      rotationSpeed: rotationSpeed,
    );
  });
}

class _GoldParticleBurstPainter extends CustomPainter {
  _GoldParticleBurstPainter({
    required this.animation,
    required this.particles,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_GoldParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final double progress = animation.value;
    if (progress <= 0.0 || progress >= 1.0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double curved = Curves.easeOutCubic.transform(progress);
    final double alpha =
        (1.0 - Curves.easeInQuad.transform(progress)).clamp(0.0, 1.0);

    // 1. Expanding Golden Shockwave Ring
    final double shockwaveRadius = curved * (size.width * 0.65);
    final Paint shockwavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * (1.0 - progress)
      ..color = const Color(0xFFFFDF00).withValues(alpha: alpha * 0.7);
    canvas.drawCircle(center, shockwaveRadius, shockwavePaint);

    // 2. Radial Ambient Glow Flash
    final Paint flashPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE57F).withValues(alpha: alpha * 0.5),
          const Color(0xFFFBBF24).withValues(alpha: alpha * 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(
          Rect.fromCircle(center: center, radius: shockwaveRadius + 20));
    canvas.drawCircle(center, shockwaveRadius + 20, flashPaint);

    // 3. Gold particles & star glints
    final Paint particlePaint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final double dist = curved * particle.speed;
      final double x = center.dx + math.cos(particle.angle) * dist;
      final double y = center.dy + math.sin(particle.angle) * dist;
      final double particleAlpha =
          (alpha * (1.0 - (progress * 0.2))).clamp(0.0, 1.0);
      final double currentSize = particle.size * (1.0 - (progress * 0.35));

      particlePaint.color = particle.color.withValues(alpha: particleAlpha);

      if (particle.isStar) {
        // Draw 4-point golden star glint
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * particle.rotationSpeed);
        final Path starPath = Path()
          ..moveTo(0, -currentSize * 1.8)
          ..quadraticBezierTo(0, 0, currentSize * 1.8, 0)
          ..quadraticBezierTo(0, 0, 0, currentSize * 1.8)
          ..quadraticBezierTo(0, 0, -currentSize * 1.8, 0)
          ..quadraticBezierTo(0, 0, 0, -currentSize * 1.8)
          ..close();
        canvas.drawPath(starPath, particlePaint);
        canvas.restore();
      } else {
        // Draw circular spark with core
        canvas.drawCircle(Offset(x, y), currentSize, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoldParticleBurstPainter oldDelegate) => true;
}

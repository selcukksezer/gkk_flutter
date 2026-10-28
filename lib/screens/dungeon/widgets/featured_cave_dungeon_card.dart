import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/graphics_quality_service.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/gold_format.dart';
import '../../../core/utils/power_formula.dart';
import '../../../models/dungeon_model.dart';
import '../../../models/dungeon_siege_model.dart';
import '../dungeon_battle_profiles.dart';
import 'dungeon_cave_theme.dart';
import 'dungeon_mob_pack_rig.dart';
import 'dungeon_progress_row.dart';
import 'dungeon_siege_badge.dart';
import 'dungeon_siege_prime_timer_chip.dart';

const double _kBossArtWidth = 148.0;
const Color _kCardText = Color(0xFFFFFFFF);

/// AAA Dark-Fantasy Dungeon Encounter Banner Card for all 65 dungeons:
/// panoramic interior dungeon chamber backdrop + bespoke Guardian/Boss cutout
/// emerging from atmospheric dungeon mist on the right.
class FeaturedCaveDungeonCard extends StatelessWidget {
  const FeaturedCaveDungeonCard({
    super.key,
    required this.dungeon,
    required this.theme,
    required this.zoneIcon,
    required this.zoneLabel,
    required this.zoneColor,
    required this.canEnter,
    required this.inHospital,
    required this.inPrison,
    required this.entering,
    required this.successPercent,
    required this.energyCost,
    required this.minGold,
    required this.maxGold,
    required this.powerRequirement,
    required this.playerPower,
    this.debugText,
    required this.onEnter,
    required this.onLoot,
    this.siegeActive = false,
    this.siegeOccupiedSlots = 0,
    this.siegeHasMySlot = false,
    this.siegeSlotCount = 5,
    this.siegeConfig,
    this.onSiegeTap,
    this.useTutorialAnchors = false,
    this.onCardTap,
    this.zoneLevelLocked = false,
    this.zoneRequiredLevel = 1,
  });

  final DungeonData dungeon;
  final CaveCardTheme theme;
  final IconData zoneIcon;
  final String zoneLabel;
  final Color zoneColor;
  final bool canEnter;
  final bool inHospital;
  final bool inPrison;
  final bool entering;
  final int successPercent;
  final int energyCost;
  final int minGold;
  final int maxGold;
  final int powerRequirement;
  final int playerPower;
  final String? debugText;
  final VoidCallback onEnter;
  final VoidCallback onLoot;
  final bool siegeActive;
  final int siegeOccupiedSlots;
  final bool siegeHasMySlot;
  final int siegeSlotCount;
  final DungeonSiegeConfig? siegeConfig;
  final VoidCallback? onSiegeTap;
  final bool useTutorialAnchors;
  final VoidCallback? onCardTap;
  final bool zoneLevelLocked;
  final int zoneRequiredLevel;

  String get _threatLabel {
    if (successPercent >= 80) return 'KOLAY';
    if (successPercent >= 55) return 'ORTA';
    if (successPercent >= 30) return 'ZOR';
    return 'ÖLÜMCÜL';
  }

  String _fmtPower(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  String get _enterLabel {
    if (entering) return 'Giriliyor...';
    if (inHospital) return 'Hastane Kilidi';
    if (inPrison) return 'Hapis Kilidi';
    if (zoneLevelLocked) return 'Lv.$zoneRequiredLevel Gerekli';
    if (!canEnter) return 'Enerji Yetersiz';
    return 'Zindana Gir';
  }

  @override
  Widget build(BuildContext context) {
    final DungeonBattleProfile battleProfile =
        DungeonBattleProfile.forDungeonId(dungeon.dungeonId);
    final List<DungeonMobPackMember> pack =
        resolveDungeonMobPack(battleProfile);
    final bool compactPhone = MediaQuery.sizeOf(context).width < 395;
    final Color accent = battleProfile.primaryColor;
    final Color secondary = battleProfile.secondaryColor;
    final Color deepBg = battleProfile.deepSurface;
    final Color threat = theme.threatForSuccess(successPercent);
    final bool active = canEnter && !entering;
    final double powerRatio = powerRequirement > 0
        ? (playerPower / powerRequirement).clamp(0.0, 2.0)
        : 1.0;
    final bool powerOk = powerRatio >= 1.0;

    Widget enterButton = _CaveEnterButton(
      active: active,
      entering: entering,
      label: _enterLabel,
      accent: accent,
      secondary: secondary,
      panel: theme.panel,
      onTap: active ? onEnter : null,
    );
    if (useTutorialAnchors) {
      enterButton = TutorialAnchorScope(
        id: TutorialAnchorId.dungeonEnterBtn,
        child: enterButton,
      );
    }

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final int cardArenaCacheW =
        gfx.isLow ? 420 : (gfx.isLowOrMedium ? 640 : 960);
    final int cardSpriteCacheW = gfx.isLow ? 190 : 260;

    Widget card = RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: deepBg,
          border: Border.all(
            color: battleProfile.isBoss
                ? const Color(0xFFFFD700).withValues(alpha: 0.62)
                : accent.withValues(alpha: 0.40),
            width: battleProfile.isBoss ? 1.5 : 1.1,
          ),
          boxShadow: gfx.enableHeavyShadows
              ? <BoxShadow>[
                  BoxShadow(
                    color: (battleProfile.isBoss
                            ? const Color(0xFFFFD700)
                            : accent)
                        .withValues(alpha: battleProfile.isBoss ? 0.22 : 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: IntrinsicHeight(
            child: Stack(
              children: <Widget>[
                // 1. Full-card panoramic AAA interior dungeon chamber backdrop (downsampled + zero saveLayer!)
                Positioned.fill(
                  child: ColoredBox(color: deepBg),
                ),
                Positioned.fill(
                  child: Image.asset(
                    battleProfile.arenaAsset,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.0, 0.12),
                    cacheWidth: cardArenaCacheW,
                    opacity: const AlwaysStoppedAnimation<double>(0.88),
                    filterQuality: gfx.filterQuality,
                    errorBuilder: (_, _, _) => ColoredBox(color: deepBg),
                  ),
                ),

                // 2. Right-side Multi-Mob Pack Diorama (Flanking Vanguards skipped on Low to eliminate ColorFiltered saveLayers!)
                Positioned(
                  right: -6,
                  top: 6,
                  bottom: 0,
                  width: _kBossArtWidth + 34,
                  child: IgnorePointer(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: <Widget>[
                        if (!gfx.isLow)
                          Positioned(
                            right: 8,
                            bottom: 10,
                            width: 152,
                            height: 152,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: <Color>[
                                    (battleProfile.isBoss
                                            ? const Color(0xFFFFD700)
                                            : accent)
                                        .withValues(alpha: 0.38),
                                    secondary.withValues(alpha: 0.14),
                                    Colors.transparent,
                                  ],
                                  stops: const <double>[0.0, 0.56, 1.0],
                                ),
                              ),
                            ),
                          ),
                        if (!gfx.isLow && pack.length >= 2)
                          Positioned(
                            right: 68,
                            top: 26,
                            bottom: 18,
                            width: 96,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                deepBg.withValues(alpha: 0.32),
                                BlendMode.srcATop,
                              ),
                              child: Image.asset(
                                pack[1].spriteAsset,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                                cacheWidth: 190,
                                opacity:
                                    const AlwaysStoppedAnimation<double>(0.62),
                                filterQuality: gfx.filterQuality,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        if (!gfx.isLow && pack.isNotEmpty)
                          Positioned(
                            right: 44,
                            top: 40,
                            bottom: 2,
                            width: 102,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                deepBg.withValues(alpha: 0.18),
                                BlendMode.srcATop,
                              ),
                              child: Image.asset(
                                pack[0].spriteAsset,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                                cacheWidth: 200,
                                opacity:
                                    const AlwaysStoppedAnimation<double>(0.78),
                                filterQuality: gfx.filterQuality,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        // Commanding Pack Leader / Boss in front
                        Positioned(
                          right: 2,
                          top: 12,
                          bottom: 0,
                          width: _kBossArtWidth,
                          child: _buildEnemyCutout(
                            battleProfile,
                            cacheWidth: cardSpriteCacheW,
                            filterQuality: gfx.filterQuality,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3. Multi-stop Dark-Obsidian Readability Scrim (crisp left text, clear right boss/dungeon)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const <double>[0.0, 0.46, 0.68, 0.86, 1.0],
                      colors: <Color>[
                        deepBg.withValues(alpha: 0.95),
                        deepBg.withValues(alpha: 0.86),
                        deepBg.withValues(alpha: 0.54),
                        deepBg.withValues(alpha: 0.18),
                        deepBg.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
              ),
              // Subtle bottom ground vignette
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Foreground Content
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(zoneIcon, size: 12, color: accent),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: DungeonInsetText(
                                      '$zoneLabel • #${battleProfile.dungeonNumber}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          CaveTextStyle.label(color: _kCardText),
                                    ),
                                  ),
                                ],
                              ),
                              if (battleProfile.isBoss)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: <Color>[
                                        Color(0xFFFFD700),
                                        Color(0xFFEA580C),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    'BOSS',
                                    style: TextStyle(
                                      color: Color(0xFF090D16),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              _ThreatBadge(
                                label: _threatLabel,
                                color: threat,
                                panel: theme.panel,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: theme.panel.withValues(alpha: 0.82),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.52),
                                  ),
                                ),
                                child: Text(
                                  'SÜRÜ: ${pack.length} DÜŞMAN',
                                  style: CaveTextStyle.label(
                                    color: accent,
                                    size: 8,
                                  ),
                                ),
                              ),
                              if (onSiegeTap != null)
                                siegeConfig != null
                                    ? DungeonSiegeBadgeWithTimer(
                                        siegeActive: siegeActive,
                                        slotCount: siegeSlotCount,
                                        occupiedSlots: siegeOccupiedSlots,
                                        hasMySlot: siegeHasMySlot,
                                        config: siegeConfig!,
                                        onTap: onSiegeTap,
                                        compact: true,
                                      )
                                    : DungeonSiegeBadge(
                                        siegeActive: siegeActive,
                                        slotCount: siegeSlotCount,
                                        occupiedSlots: siegeOccupiedSlots,
                                        hasMySlot: siegeHasMySlot,
                                        onTap: onSiegeTap,
                                        compact: true,
                                      ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          DungeonInsetText(
                            dungeon.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CaveTextStyle.title(
                              color: _kCardText,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: <Widget>[
                              Icon(
                                battleProfile.isBoss
                                    ? Icons.workspace_premium_rounded
                                    : Icons.shield_moon_rounded,
                                size: 12,
                                color: battleProfile.isBoss
                                    ? const Color(0xFFFFD700)
                                    : accent,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${battleProfile.enemyName} • ${battleProfile.enemyElementLabel.trim()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accent.withValues(alpha: 0.95),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (dungeon.description.trim().isEmpty ||
                                    dungeon.description.trim().toLowerCase() ==
                                        dungeon.name.trim().toLowerCase())
                                ? battleProfile.introQuote
                                : dungeon.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 11,
                              height: 1.28,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              _CaveStatChip(
                                icon: Icons.bolt,
                                label: '${energyCost}E',
                                color: _kCardText,
                                panel: theme.panel,
                              ),
                              _CaveStatChip(
                                icon: Icons.monetization_on_outlined,
                                label: formatCompactGoldRange(minGold, maxGold),
                                color: theme.gold,
                                panel: theme.panel,
                                isGold: true,
                              ),
                              if (powerRequirement > 0)
                                _CaveStatChip(
                                  icon: Icons.security,
                                  label: _fmtPower(powerRequirement),
                                  color: _kCardText,
                                  panel: theme.panel,
                                ),
                            ],
                          ),
                          if (powerRequirement > 0) ...<Widget>[
                            const SizedBox(height: 8),
                            _CavePowerBar(
                              ratio: (powerRatio / 2).clamp(0.0, 1.0),
                              ok: powerOk,
                              threat: threat,
                              theme: theme,
                            ),
                          ],
                          const SizedBox(height: 8),
                          DungeonProgressRow(dungeon: dungeon, accent: accent),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              _CaveLootButton(
                                onTap: onLoot,
                                accent: secondary,
                                panel: theme.panel,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: enterButton,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: _kBossArtWidth * (compactPhone ? 0.50 : 0.64),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _CaveSuccessRing(
                  percent: successPercent,
                  color: threat,
                  panel: deepBg,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

    if (useTutorialAnchors) {
      card = TutorialAnchorScope(
        id: TutorialAnchorId.dungeonZone0,
        child: card,
      );
    }
    if (onCardTap != null) {
      card = GestureDetector(
        onTap: onCardTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    return card;
  }

  Widget _buildEnemyCutout(
    DungeonBattleProfile profile, {
    required int cacheWidth,
    required FilterQuality filterQuality,
  }) {
    final Widget img = Image.asset(
      profile.enemySpriteAsset,
      fit: BoxFit.contain,
      alignment: Alignment.bottomRight,
      cacheWidth: cacheWidth,
      filterQuality: filterQuality,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    if (profile.enemyColorTint == null || profile.enemyTintStrength <= 0) {
      return img;
    }
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        profile.enemyColorTint!.withValues(alpha: profile.enemyTintStrength),
        BlendMode.srcATop,
      ),
      child: img,
    );
  }
}

class _ThreatBadge extends StatelessWidget {
  const _ThreatBadge({
    required this.label,
    required this.color,
    required this.panel,
  });
  final String label;
  final Color color;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: panel.withValues(alpha: 0.78),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(label, style: CaveTextStyle.label(color: _kCardText, size: 8)),
    );
  }
}

class _CaveSuccessRing extends StatelessWidget {
  const _CaveSuccessRing({
    required this.percent,
    required this.color,
    required this.panel,
  });
  final int percent;
  final Color color;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: panel.withValues(alpha: 0.78),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: const Size(50, 50),
            painter: _CaveRingPainter(
              percent: percent.toDouble(),
              color: color,
              track: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DungeonInsetText(
                '$percent',
                style: CaveTextStyle.title(color: _kCardText, size: 13),
                depthOffset: const Offset(0, 1),
              ),
              Text('%', style: CaveTextStyle.label(color: _kCardText, size: 7)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaveRingPainter extends CustomPainter {
  const _CaveRingPainter({
    required this.percent,
    required this.color,
    required this.track,
  });
  final double percent;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 3;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    if (percent > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * (percent / 100),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CaveRingPainter old) =>
      old.percent != percent || old.color != color || old.track != track;
}

class _CaveStatChip extends StatelessWidget {
  const _CaveStatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.panel,
    this.isGold = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color panel;
  final bool isGold;

  @override
  Widget build(BuildContext context) {
    final Color display = isGold ? color : _kCardText;
    final Color border = isGold ? color : _kCardText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: panel.withValues(alpha: 0.72),
        border: Border.all(color: border.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: display),
          const SizedBox(width: 4),
          Text(label, style: CaveTextStyle.body(color: display, size: 11)),
        ],
      ),
    );
  }
}

class _CavePowerBar extends StatelessWidget {
  const _CavePowerBar({
    required this.ratio,
    required this.ok,
    required this.threat,
    required this.theme,
  });
  final double ratio;
  final bool ok;
  final Color threat;
  final CaveCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            DungeonInsetText(
              'GÜÇ',
              style: CaveTextStyle.label(color: _kCardText, size: 8),
              depthOffset: const Offset(0, 0.8),
            ),
            const Spacer(),
            Text(
              ok ? 'YETERLİ' : 'YETERSİZ',
              style: CaveTextStyle.label(
                color: ok ? const Color(0xFF34D399) : const Color(0xFFFF6B6B),
                size: 8.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: ratio,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              ok ? const Color(0xFF34D399) : threat,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaveLootButton extends StatelessWidget {
  const _CaveLootButton({
    required this.onTap,
    required this.accent,
    required this.panel,
  });
  final VoidCallback onTap;
  final Color accent;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: panel.withValues(alpha: 0.82),
            border: Border.all(
              color: accent.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: _kCardText,
              ),
              const SizedBox(width: 5),
              Text(
                'Ganimet',
                style: CaveTextStyle.body(color: _kCardText, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaveEnterButton extends StatelessWidget {
  const _CaveEnterButton({
    required this.active,
    required this.entering,
    required this.label,
    required this.accent,
    required this.secondary,
    required this.panel,
    this.onTap,
  });

  final bool active;
  final bool entering;
  final String label;
  final Color accent;
  final Color secondary;
  final Color panel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color deepEnd = Color.lerp(accent, const Color(0xFF090D16), 0.38)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: active
                ? LinearGradient(
                    colors: <Color>[accent, deepEnd],
                  )
                : null,
            color: active ? null : panel.withValues(alpha: 0.85),
            border: Border.all(
              color: active
                  ? secondary.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.18),
            ),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.36),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: entering
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kCardText,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            active
                                ? Icons.sports_martial_arts_rounded
                                : Icons.lock_outline,
                            size: 16,
                            color: _kCardText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: CaveTextStyle.title(
                              color: _kCardText,
                              size: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

CaveCardTheme? featuredCaveThemeFor(DungeonData dungeon) =>
    CaveCardTheme.forDungeonNumber(parseDungeonNumber(dungeon.dungeonId));

bool isFeaturedCaveDungeon(DungeonData dungeon) =>
    featuredCaveThemeFor(dungeon) != null;

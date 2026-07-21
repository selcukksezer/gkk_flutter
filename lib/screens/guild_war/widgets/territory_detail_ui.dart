import 'package:flutter/material.dart';

import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'guild_war_design.dart';

const List<String> kTerritoryMapIcons = <String>['🏰', '🌾', '🐉', '⚓', '🔥', '🏔'];

int territoryMapIndex(String territoryId, List<TerritoryData> territories) {
  final int idx = territories.indexWhere((TerritoryData t) => t.id == territoryId);
  if (idx >= 0) return idx;
  return territoryId.hashCode.abs();
}

String territoryMapIconFor(String territoryId, List<TerritoryData> territories) {
  return kTerritoryMapIcons[territoryMapIndex(territoryId, territories) % kTerritoryMapIcons.length];
}

String territoryMapCoordinateFor(String territoryId, List<TerritoryData> territories) {
  final int index = territoryMapIndex(territoryId, territories);
  final int x = (index % 4) + 1;
  final int y = (index ~/ 4) + 1;
  return 'Harita $x·$y';
}

List<String> territoryBonusSummary(TerritoryData territory) {
  final List<String> parts = <String>[];
  if (territory.tradeIncome > 0) {
    parts.add('💰 ${territory.tradeIncome}/gün');
  }
  if (territory.reward.isNotEmpty) {
    parts.add('🎁 ${territory.reward}');
  }
  if (territory.defenseLineLevel > 0) {
    parts.add('🏗 Savunma hattı Sv.${territory.defenseLineLevel}');
  }
  if (parts.isEmpty) {
    parts.add('🛡 Temel savunma bölgesi');
  }
  return parts;
}

class TerritoryDetailHero extends StatelessWidget {
  const TerritoryDetailHero({
    super.key,
    required this.territory,
    required this.ownerLabel,
    required this.mapIcon,
    required this.mapCoordinate,
    required this.accent,
    this.isOwner = false,
  });

  final TerritoryData territory;
  final String ownerLabel;
  final String mapIcon;
  final String mapCoordinate;
  final Color accent;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final List<String> bonuses = territoryBonusSummary(territory);

    return WarHeroBanner(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WarPalette.obsidian.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Text(mapIcon, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      territory.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        WarStatusPill(label: mapCoordinate, color: WarPalette.neon),
                        if (isOwner)
                          const WarStatusPill(label: 'Senin loncan', color: WarPalette.gold),
                        if (territory.isUnclaimed)
                          const WarStatusPill(label: 'Sahipsiz', color: WarPalette.coral),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '🏰 $ownerLabel',
            style: const TextStyle(color: WarPalette.titanium, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: bonuses
                .map(
                  (String label) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: WarPalette.obsidian.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class TerritoryAttackSummaryHeader extends StatelessWidget {
  const TerritoryAttackSummaryHeader({
    super.key,
    required this.attacks,
    this.myGuildId,
  });

  final List<GuildWarAttackLog> attacks;
  final String? myGuildId;

  @override
  Widget build(BuildContext context) {
    if (attacks.isEmpty) return const SizedBox.shrink();

    final List<GuildWarAttackLog> preview = attacks.take(3).toList();

    return WarNeonCard(
      accent: WarPalette.ruby,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Text(
                'Son Saldırılar',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Spacer(),
              Text(
                'Özet',
                style: TextStyle(color: WarPalette.titanium, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final GuildWarAttackLog log in preview) ...<Widget>[
            _AttackSummaryRow(log: log, myGuildId: myGuildId),
            if (log != preview.last) const SizedBox(height: 8),
          ],
          if (attacks.length > 3) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '+${attacks.length - 3} kayıt daha aşağıda',
              style: const TextStyle(color: WarPalette.titanium, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttackSummaryRow extends StatelessWidget {
  const _AttackSummaryRow({required this.log, this.myGuildId});

  final GuildWarAttackLog log;
  final String? myGuildId;

  bool get _weWon =>
      myGuildId != null &&
      ((log.attackerGuildId == myGuildId && log.success) ||
          (log.defenderGuildId == myGuildId && !log.success));

  bool get _weLost =>
      myGuildId != null &&
      ((log.attackerGuildId == myGuildId && !log.success) ||
          (log.defenderGuildId == myGuildId && log.success));

  String _timeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes}dk önce';
    if (diff.inDays < 1) return '${diff.inHours}sa önce';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final Color resultColor;
    final String resultLabel;
    if (_weWon) {
      resultColor = WarPalette.neon;
      resultLabel = 'Kazandık';
    } else if (_weLost) {
      resultColor = WarPalette.ruby;
      resultLabel = 'Kaybettik';
    } else {
      resultColor = log.success ? WarPalette.ruby : WarPalette.neon;
      resultLabel = log.success ? 'Saldırı' : 'Savunma';
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '${log.attackerGuildName ?? '?'} → ${log.defenderGuildName ?? 'Sahipsiz'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: WarPalette.titanium, fontSize: 11),
          ),
        ),
        const SizedBox(width: 6),
        WarStatusPill(label: resultLabel, color: resultColor),
        const SizedBox(width: 6),
        Text(
          _timeAgo(log.createdAt),
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
        ),
      ],
    );
  }
}

class TerritoryNotFoundPanel extends StatelessWidget {
  const TerritoryNotFoundPanel({
    super.key,
    required this.territoryId,
    required this.onBack,
  });

  final String territoryId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            WarHeroBanner(
              accent: WarPalette.coral,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Text('🗺', style: TextStyle(fontSize: 32)),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Bölge bulunamadı',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'ID: $territoryId',
                    style: const TextStyle(
                      color: WarPalette.titanium,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Bu bölge haritadan kaldırılmış, sezon değişmiş veya geçersiz bir bağlantı açılmış olabilir.',
                    style: TextStyle(color: WarPalette.titanium, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            WarNeonCard(
              accent: WarPalette.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Haritada bölgeler',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kTerritoryMapIcons
                        .map(
                          (String icon) => Container(
                            width: 54,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: WarPalette.obsidian.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: WarPalette.obsidian),
                            ),
                            child: Text(
                              icon,
                              style: TextStyle(
                                fontSize: 22,
                                color: WarPalette.titanium.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Lonca Savaşı haritasından aktif bölgelere dokunarak detay sayfasına gidebilirsin.',
                    style: TextStyle(color: WarPalette.titanium, fontSize: 11, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            WarGoldButton(label: 'Lonca Savaşı Haritasına Dön', onPressed: onBack),
          ],
        ),
      ),
    );
  }
}

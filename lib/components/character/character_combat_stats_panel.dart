import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Combat stats — compact unified panel, no icon glow, no inner tiles.
class CharacterCombatStatsPanel extends StatelessWidget {
  const CharacterCombatStatsPanel({
    super.key,
    required this.power,
    required this.intelligence,
    required this.maxHealth,
    required this.attack,
    required this.defense,
    required this.luck,
    required this.pvpWinRate,
    required this.pvpRating,
  });

  final String power;
  final String intelligence;
  final String maxHealth;
  final String attack;
  final String defense;
  final String luck;
  final String pvpWinRate;
  final String pvpRating;

  static const _iconBase = 'assets/ui/character_status_bar/';
  static const double _iconSize = 70;

  static const Color _liquidGold = Color(0xFFFFB800);
  static const Color _warningSolar = Color(0xFFFFD700);
  static const Color _mutedTitanium = Color(0xFF8E9CAE);

  @override
  Widget build(BuildContext context) {
    final List<_CombatStatDef> stats = <_CombatStatDef>[
      _CombatStatDef(
        label: 'Güç',
        value: power,
        icon: '${_iconBase}gucicon.png',
      ),
      _CombatStatDef(
        label: 'Zeka',
        value: intelligence,
        icon: '${_iconBase}zekaicon.png',
      ),
      _CombatStatDef(
        label: 'HP',
        value: maxHealth,
        icon: '${_iconBase}canicon.png',
      ),
      _CombatStatDef(
        label: 'Saldırı',
        value: attack,
        icon: '${_iconBase}saldırı.png',
      ),
      _CombatStatDef(
        label: 'Savunma',
        value: defense,
        icon: '${_iconBase}defansicon.png',
      ),
      _CombatStatDef(
        label: 'Şans',
        value: luck,
        icon: '${_iconBase}sansicon.png',
      ),
      _CombatStatDef(
        label: 'PvP Kazanma',
        value: pvpWinRate,
        icon: '${_iconBase}pvpicon.png',
      ),
      _CombatStatDef(
        label: 'Rating',
        value: pvpRating,
        icon: '${_iconBase}ratingicon.png',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Gelişim & Savaş İstatistikleri',
          style: GoogleFonts.urbanist(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 1.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: <Color>[
                _liquidGold,
                _warningSolar.withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          itemCount: stats.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (BuildContext context, int index) {
            return _CombatStatTile(stat: stats[index], iconSize: _iconSize);
          },
        ),
      ],
    );
  }
}

class _CombatStatDef {
  const _CombatStatDef({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final String icon;
}

class _CombatStatTile extends StatelessWidget {
  const _CombatStatTile({required this.stat, required this.iconSize});

  final _CombatStatDef stat;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${stat.label}: ${stat.value}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              stat.icon,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, Object error, StackTrace? stack) => Icon(
                Icons.bolt,
                size: iconSize * 0.5,
                color: CharacterCombatStatsPanel._mutedTitanium,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              child: Text(
                stat.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Text(
                stat.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: CharacterCombatStatsPanel._mutedTitanium,
                  height: 1.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

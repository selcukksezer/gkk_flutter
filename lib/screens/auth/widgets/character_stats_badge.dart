import 'package:flutter/material.dart';
import 'character_elemental_aura.dart';

class CharacterClassStats {
  const CharacterClassStats({
    required this.classId,
    required this.combatPower,
    required this.levelText,
    required this.roleTitle,
    required this.strPercent,
    required this.defPercent,
    required this.agiPercent,
    required this.intPercent,
    required this.difficultyStars,
    required this.traits,
  });

  final String classId;
  final int combatPower;
  final String levelText;
  final String roleTitle;
  final double strPercent;
  final double defPercent;
  final double agiPercent;
  final double intPercent;
  final int difficultyStars;
  final List<String> traits;

  static const CharacterClassStats warrior = CharacterClassStats(
    classId: 'warrior',
    combatPower: 1480,
    levelText: 'SEVİYE 1 // ŞÖVALYE',
    roleTitle: 'Frontline Bastion // Ağır Zırh',
    strPercent: 0.95,
    defPercent: 0.92,
    agiPercent: 0.45,
    intPercent: 0.30,
    difficultyStars: 3,
    traits: <String>['TANK', 'KİTLE KONTROL', 'YÜKSEK CAN'],
  );

  static const CharacterClassStats alchemist = CharacterClassStats(
    classId: 'alchemist',
    combatPower: 1420,
    levelText: 'SEVİYE 1 // SİMYAGER',
    roleTitle: 'Arcane Engineer // Eter Rezonans',
    strPercent: 0.48,
    defPercent: 0.58,
    agiPercent: 0.70,
    intPercent: 0.96,
    difficultyStars: 4,
    traits: <String>['ETER BÜYÜSÜ', 'DESTEK', 'İKİSİR'],
  );

  static const CharacterClassStats shadow = CharacterClassStats(
    classId: 'shadow',
    combatPower: 1530,
    levelText: 'SEVİYE 1 // SUİKASTÇI',
    roleTitle: 'Void Stalker // Ölümcül Suikast',
    strPercent: 0.78,
    defPercent: 0.42,
    agiPercent: 0.96,
    intPercent: 0.65,
    difficultyStars: 5,
    traits: <String>['KRİTİK PATLAMA', 'GİZLİLİK', 'HIZ'],
  );

  static CharacterClassStats forClass(String classId) {
    switch (classId.toLowerCase()) {
      case 'warrior':
        return warrior;
      case 'alchemist':
        return alchemist;
      case 'shadow':
        return shadow;
      default:
        return warrior;
    }
  }
}

class CharacterStatsBadge extends StatelessWidget {
  const CharacterStatsBadge({
    super.key,
    required this.stats,
    required this.affinity,
  });

  final CharacterClassStats stats;
  final ElementalAffinity affinity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE0101319),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: affinity.primaryColor.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: affinity.primaryColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header: Level Badge + Combat Power
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      affinity.primaryColor.withValues(alpha: 0.25),
                      affinity.secondaryColor.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: affinity.primaryColor.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Text(
                  stats.levelText,
                  style: TextStyle(
                    color: affinity.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.bolt_rounded, size: 14, color: affinity.primaryColor),
              const SizedBox(width: 3),
              Text(
                '${stats.combatPower} CP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Role & Archetype Subtitle
          Text(
            stats.roleTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // Stat Bars Grid (2x2)
          Row(
            children: <Widget>[
              Expanded(
                child: _StatBar(
                  label: 'GÜÇ',
                  value: stats.strPercent,
                  accent: affinity.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBar(
                  label: 'SAVUNMA',
                  value: stats.defPercent,
                  accent: affinity.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatBar(
                  label: 'ÇEVİKLİK',
                  value: stats.agiPercent,
                  accent: affinity.secondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBar(
                  label: 'ETER',
                  value: stats.intPercent,
                  accent: affinity.secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bottom Traits & Difficulty
          Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: stats.traits.map((String trait) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        trait,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              // Difficulty rating stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List<Widget>.generate(5, (int index) {
                  final bool active = index < stats.difficultyStars;
                  return Icon(
                    active ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 13,
                    color: active ? affinity.primaryColor : Colors.white24,
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: accent,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 5,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.08),
            child: Stack(
              children: <Widget>[
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          accent.withValues(alpha: 0.5),
                          accent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

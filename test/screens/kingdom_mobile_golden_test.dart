import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/kingdom/kingdom_crest_icons.dart';
import 'package:gkk_flutter/components/kingdom/kingdom_glass_card.dart';
import 'package:gkk_flutter/components/kingdom/kingdom_overview_card.dart';
import 'package:gkk_flutter/components/kingdom/kingdom_realm_header.dart';
import 'package:gkk_flutter/components/kingdom/kingdom_territory_realm_controller.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

import '../golden/mobile_viewport_harness.dart';

// =============================================================================
// MOCK DATA MODELS FOR KINGDOMS, BOUNDARIES, AND RESOURCE NODES
// =============================================================================

/// Genuine data model representing a sovereign Kingdom realm.
class MockKingdom {
  const MockKingdom({
    required this.id,
    required this.realmTitle,
    required this.reigningKing,
    required this.reigningGuild,
    required this.faction,
    required this.dominionLevel,
    required this.goldBalance,
    required this.gemsBalance,
    required this.dailyTaxRevenue,
    required this.activeBlessingSummary,
    required this.controlledProvinces,
    required this.totalProvinces,
    required this.defenseLevel,
    required this.taxYieldMultiplier,
    required this.isUnderSiege,
    required this.legionName,
    required this.activeSoldiers,
    required this.readinessRating,
    required this.warDefenseBonusPct,
  });

  final String id;
  final String realmTitle;
  final String reigningKing;
  final String reigningGuild;
  final FactionType faction;
  final int dominionLevel;
  final num goldBalance;
  final num gemsBalance;
  final num dailyTaxRevenue;
  final String activeBlessingSummary;
  final int controlledProvinces;
  final int totalProvinces;
  final int defenseLevel;
  final double taxYieldMultiplier;
  final bool isUnderSiege;
  final String legionName;
  final int activeSoldiers;
  final int readinessRating;
  final int warDefenseBonusPct;
}

/// Genuine data model representing strategic territory frontiers and boundary fortifications.
class MockTerritoryBoundary {
  const MockTerritoryBoundary({
    required this.id,
    required this.name,
    required this.adjacentKingdom,
    required this.lengthKm,
    required this.fortificationLevel,
    required this.wallIntegrityPct,
    required this.defensiveTurrets,
    required this.taxTollRate,
    required this.isUnderSiege,
    required this.statusLabel,
    required this.faction,
  });

  final String id;
  final String name;
  final String adjacentKingdom;
  final double lengthKm;
  final int fortificationLevel;
  final int wallIntegrityPct;
  final int defensiveTurrets;
  final double taxTollRate;
  final bool isUnderSiege;
  final String statusLabel;
  final FactionType faction;
}

/// Genuine data model representing continental kingdom resource extraction nodes.
class MockResourceNode {
  const MockResourceNode({
    required this.id,
    required this.name,
    required this.resourceType,
    required this.icon,
    required this.accentColor,
    required this.hourlyYield,
    required this.currentStorage,
    required this.maxCapacity,
    required this.status,
    required this.guardingGuild,
    required this.defenseRating,
    this.canCollect = true,
  });

  final String id;
  final String name;
  final String resourceType;
  final IconData icon;
  final Color accentColor;
  final String hourlyYield;
  final int currentStorage;
  final int maxCapacity;
  final String status;
  final String guardingGuild;
  final int defenseRating;
  final bool canCollect;
}

// =============================================================================
// MOCK FACTORY GENERATORS
// =============================================================================

/// Generates realistic kingdoms across Elyos, Asmodian, and Neutral allegiances.
List<MockKingdom> createMockKingdoms() {
  return const <MockKingdom>[
    MockKingdom(
      id: 'kingdom_elyos_aethelgard',
      realmTitle: 'Aethelgard Hükümranlığı',
      reigningKing: 'Lord Kaelen',
      reigningGuild: 'Gök Muhafızları',
      faction: FactionType.elyos,
      dominionLevel: 15,
      goldBalance: 15200000,
      gemsBalance: 5600,
      dailyTaxRevenue: 720000,
      activeBlessingSummary: 'Krallık Ticaret Lütfu (%20 İndirim)',
      controlledProvinces: 8,
      totalProvinces: 9,
      defenseLevel: 5,
      taxYieldMultiplier: 1.40,
      isUnderSiege: false,
      legionName: 'İmparatorluk Lejyonu & Başkent Muhafızları',
      activeSoldiers: 21500,
      readinessRating: 96,
      warDefenseBonusPct: 25,
    ),
    MockKingdom(
      id: 'kingdom_asmodian_morheim',
      realmTitle: 'Morheim Karanlık Krallığı',
      reigningKing: 'Lord Vane',
      reigningGuild: 'Gölge İttifakı',
      faction: FactionType.asmodian,
      dominionLevel: 13,
      goldBalance: 12800000,
      gemsBalance: 4200,
      dailyTaxRevenue: 610000,
      activeBlessingSummary: 'Abis Savaş Narası (+%15 Hasar)',
      controlledProvinces: 6,
      totalProvinces: 9,
      defenseLevel: 4,
      taxYieldMultiplier: 1.25,
      isUnderSiege: true,
      legionName: 'Kara Pençe Süvarileri',
      activeSoldiers: 18400,
      readinessRating: 91,
      warDefenseBonusPct: 20,
    ),
    MockKingdom(
      id: 'kingdom_neutral_ereshkigal',
      realmTitle: 'Ereshkigal Buz Krallığı',
      reigningKing: 'Kraliçe Sylva',
      reigningGuild: 'Buz Lejyonu',
      faction: FactionType.neutral,
      dominionLevel: 11,
      goldBalance: 8400000,
      gemsBalance: 2900,
      dailyTaxRevenue: 430000,
      activeBlessingSummary: 'Buz Kalkanı Kutsaması',
      controlledProvinces: 4,
      totalProvinces: 9,
      defenseLevel: 3,
      taxYieldMultiplier: 1.15,
      isUnderSiege: false,
      legionName: 'Kutup Muhafızları',
      activeSoldiers: 12500,
      readinessRating: 88,
      warDefenseBonusPct: 15,
    ),
  ];
}

/// Generates authentic territory boundaries with fortification levels and wall integrity.
List<MockTerritoryBoundary> createMockTerritoryBoundaries() {
  return const <MockTerritoryBoundary>[
    MockTerritoryBoundary(
      id: 'boundary_north_abyss',
      name: 'Kuzey Abis Sınır Tahkimatı',
      adjacentKingdom: 'Morheim Asmodian Krallığı',
      lengthKm: 142.5,
      fortificationLevel: 5,
      wallIntegrityPct: 94,
      defensiveTurrets: 24,
      taxTollRate: 0.08,
      isUnderSiege: false,
      statusLabel: 'GÜVENLİ SINIR',
      faction: FactionType.elyos,
    ),
    MockTerritoryBoundary(
      id: 'boundary_obsidian_canyon',
      name: 'Obsidiyen Kanyonu Sınır Hattı',
      adjacentKingdom: 'Gölge Muhafızları Cephesi',
      lengthKm: 88.0,
      fortificationLevel: 4,
      wallIntegrityPct: 62,
      defensiveTurrets: 16,
      taxTollRate: 0.12,
      isUnderSiege: true,
      statusLabel: 'KUŞATMA ALARMI',
      faction: FactionType.asmodian,
    ),
    MockTerritoryBoundary(
      id: 'boundary_sun_valley',
      name: 'Güneş Vadisi Batı Rampartı',
      adjacentKingdom: 'Serbest Ticaret Boğazı',
      lengthKm: 110.0,
      fortificationLevel: 6,
      wallIntegrityPct: 98,
      defensiveTurrets: 30,
      taxTollRate: 0.05,
      isUnderSiege: false,
      statusLabel: 'TAHKİM EDİLMİŞ',
      faction: FactionType.elyos,
    ),
  ];
}

/// Generates strategic continental resource production nodes.
List<MockResourceNode> createMockResourceNodes() {
  return const <MockResourceNode>[
    MockResourceNode(
      id: 'node_aether_mine',
      name: 'Kadim Aether Kristal Madeni',
      resourceType: 'aether',
      icon: Icons.diamond_rounded,
      accentColor: AppColors.accentCyan,
      hourlyYield: '+180 Aether / saat',
      currentStorage: 18400,
      maxCapacity: 25000,
      status: 'Aktif Üretim',
      guardingGuild: 'Gök Muhafızları',
      defenseRating: 5,
      canCollect: true,
    ),
    MockResourceNode(
      id: 'node_gold_vein',
      name: 'İmparatorluk Altın Damarı',
      resourceType: 'gold',
      icon: Icons.monetization_on_rounded,
      accentColor: AppColors.liquidGold,
      hourlyYield: '+45.000 Altın / saat',
      currentStorage: 320000,
      maxCapacity: 500000,
      status: 'Hasat Hazır',
      guardingGuild: 'Hazine Muhafızları',
      defenseRating: 4,
      canCollect: true,
    ),
    MockResourceNode(
      id: 'node_mithril_quarry',
      name: 'Kadim Mithril Ocağı',
      resourceType: 'mithril',
      icon: Icons.hardware_rounded,
      accentColor: Color(0xFF60A5FA),
      hourlyYield: '+95 Mithril / saat',
      currentStorage: 4200,
      maxCapacity: 8000,
      status: 'Aktif Üretim',
      guardingGuild: 'Demirci Locası',
      defenseRating: 4,
      canCollect: true,
    ),
    MockResourceNode(
      id: 'node_mana_spring',
      name: 'Abis Ruh Pınarı (Mana Çeşmesi)',
      resourceType: 'mana',
      icon: Icons.auto_awesome_rounded,
      accentColor: Color(0xFFA78BFA),
      hourlyYield: '+260 Saf Mana / saat',
      currentStorage: 12000,
      maxCapacity: 15000,
      status: 'Hasat Hazır',
      guardingGuild: 'Büyücüler Meclisi',
      defenseRating: 5,
      canCollect: true,
    ),
  ];
}

// =============================================================================
// REUSABLE PRESENTATION WIDGETS FOR BOUNDARIES & RESOURCE NODES
// =============================================================================

/// Dark glassmorphic presentation card for territory boundaries and border defenses.
class KingdomTerritoryBoundaryCard extends StatelessWidget {
  const KingdomTerritoryBoundaryCard({
    super.key,
    required this.boundary,
    this.onFortify,
    this.onPatrol,
  });

  final MockTerritoryBoundary boundary;
  final VoidCallback? onFortify;
  final VoidCallback? onPatrol;

  @override
  Widget build(BuildContext context) {
    final bool isSiege = boundary.isUnderSiege;
    final Color accentColor = isSiege ? const Color(0xFFEF4444) : const Color(0xFF38BDF8);
    final double integrityRatio = (boundary.wallIntegrityPct / 100.0).clamp(0.0, 1.0);

    return KingdomGlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      accentGlowColor: accentColor,
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accentColor.withValues(alpha: 0.75),
          const Color(0xFF1E293B).withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Icon(
                  isSiege ? Icons.warning_amber_rounded : Icons.shield_moon_outlined,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      boundary.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Komşu: ${boundary.adjacentKingdom} · ${boundary.lengthKm} km Sınır',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 0.8),
                ),
                child: Text(
                  boundary.statusLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Wall Integrity Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Sınır Duvarı Dayanıklılığı',
                style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
              Text(
                '%${boundary.wallIntegrityPct} Bütünlük',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: integrityRatio,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 10),

          // Frontier Metrics
          Row(
            children: <Widget>[
              Expanded(
                child: _buildBoundaryMetric(
                  label: 'Tahkimat',
                  value: 'Sv.${boundary.fortificationLevel}',
                  icon: Icons.fort_rounded,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBoundaryMetric(
                  label: 'Savunma Taretleri',
                  value: '${boundary.defensiveTurrets} Kule',
                  icon: Icons.radar_rounded,
                  color: AppColors.liquidGold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBoundaryMetric(
                  label: 'Geçiş Vergisi',
                  value: '%${(boundary.taxTollRate * 100).toInt()}',
                  icon: Icons.monetization_on_outlined,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Actions
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onPatrol ?? () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Devriye Gönder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onFortify ?? () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Sınırı Güçlendir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoundaryMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Dark glassmorphic presentation card for strategic kingdom resource nodes.
class KingdomResourceNodeCard extends StatelessWidget {
  const KingdomResourceNodeCard({
    super.key,
    required this.node,
    this.onCollect,
    this.onUpgrade,
  });

  final MockResourceNode node;
  final VoidCallback? onCollect;
  final VoidCallback? onUpgrade;

  String _formatNumber(num val) {
    final String raw = val.round().toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buf.write('.');
      buf.write(raw[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final double storageRatio = (node.currentStorage / node.maxCapacity).clamp(0.0, 1.0);

    return KingdomGlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      accentGlowColor: node.accentColor,
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          node.accentColor.withValues(alpha: 0.75),
          const Color(0xFF1E293B).withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: node.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: node.accentColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Icon(node.icon, color: node.accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Muhafız: ${node.guardingGuild} · Sv.${node.defenseRating} Koruma',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: node.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: node.accentColor.withValues(alpha: 0.5), width: 0.8),
                ),
                child: Text(
                  node.hourlyYield,
                  style: TextStyle(
                    color: node.accentColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Storage indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Depo: ${_formatNumber(node.currentStorage)} / ${_formatNumber(node.maxCapacity)}',
                style: const TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
              Text(
                node.status,
                style: TextStyle(
                  color: node.accentColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: storageRatio,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(node.accentColor),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Action Strip
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onUpgrade ?? () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Kapasite Yükselt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: node.canCollect ? (onCollect ?? () {}) : null,
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Hasat Et', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    backgroundColor: node.accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper builder for mobile app bar
PreferredSizeWidget _buildKingdomAppBar(String title) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(56),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xEB0A0E1A),
        border: Border(bottom: BorderSide(color: Color(0x3338BDF8), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('👑', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 4),
                  Text(
                    'AION-2',
                    style: TextStyle(
                      color: AppColors.liquidGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper builder for mobile bottom navigation bar
Widget _buildKingdomBottomBar({int activeIndex = 3}) {
  return Container(
    height: 60,
    color: const Color(0xEB070A12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        Icon(Icons.home, color: activeIndex == 0 ? AppColors.liquidGold : AppColors.textSecondary),
        Icon(Icons.nightlife, color: activeIndex == 1 ? AppColors.liquidGold : AppColors.textSecondary),
        Icon(Icons.domain, color: activeIndex == 2 ? AppColors.liquidGold : AppColors.textSecondary),
        Icon(Icons.castle, color: activeIndex == 3 ? AppColors.liquidGold : AppColors.textSecondary),
      ],
    ),
  );
}

// =============================================================================
// MAIN TEST SUITE
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kingdom Screen Mobile Golden & 390x844 Viewport Suite', () {
    // -------------------------------------------------------------------------
    // TEST 1: MASTER KINGDOM OVERVIEW & TAHT MECLİSİ DASHBOARD
    // -------------------------------------------------------------------------
    testWidgets('Kingdom screen renders celestial header & realm cards on 390x844 without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      final MockKingdom primaryKingdom = createMockKingdoms().first;

      final Widget kingdomScreen = Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: _buildKingdomAppBar('Krallık & Taht Meclisi'),
        bottomNavigationBar: _buildKingdomBottomBar(activeIndex: 3),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: <Widget>[
              // Twilight Celestial Citadel Artwork Header
              KingdomRealmHeader(
                realmTitle: primaryKingdom.realmTitle,
                reigningKing: primaryKingdom.reigningKing,
                reigningGuild: primaryKingdom.reigningGuild,
                dominionLevel: primaryKingdom.dominionLevel,
                activeBlessingSummary: primaryKingdom.activeBlessingSummary,
                height: 185,
              ),
              const SizedBox(height: 10),

              // Territory Dominance Card
              KingdomTerritoryCard(
                realmName: primaryKingdom.realmTitle,
                controlledProvinces: primaryKingdom.controlledProvinces,
                totalProvinces: primaryKingdom.totalProvinces,
                defenseLevel: primaryKingdom.defenseLevel,
                taxYieldMultiplier: primaryKingdom.taxYieldMultiplier,
                isUnderSiege: primaryKingdom.isUnderSiege,
                onManage: () {},
                onViewMap: () {},
              ),
              const SizedBox(height: 12),

              // Treasury Reserves Card
              KingdomTreasuryCard(
                goldBalance: primaryKingdom.goldBalance,
                gemBalance: primaryKingdom.gemsBalance,
                dailyTaxRevenue: primaryKingdom.dailyTaxRevenue,
                isKing: true,
                canGift: true,
                onViewLedger: () {},
                onGiftSend: () {},
              ),
              const SizedBox(height: 12),

              // Army & Garrison Card
              KingdomArmyCard(
                legionName: primaryKingdom.legionName,
                activeSoldiers: primaryKingdom.activeSoldiers,
                readinessRating: primaryKingdom.readinessRating,
                warDefenseBonusPct: primaryKingdom.warDefenseBonusPct,
                onInspect: () {},
              ),
              const SizedBox(height: 12),

              // Diplomacy Card
              KingdomDiplomacyCard(
                month: 'Temmuz 2027 Seçim Dönemi',
                kingName: primaryKingdom.reigningKing,
                guildName: primaryKingdom.reigningGuild,
                isElectionActive: true,
                countdownLabel: '3 Gün Kaldı',
                canVote: true,
                alreadyVoted: false,
                onVote: () {},
                onViewCouncil: () {},
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: kingdomScreen,
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Krallık & Taht Meclisi'), findsOneWidget);
      expect(find.byType(KingdomRealmHeader), findsOneWidget);
      expect(find.byType(KingdomTerritoryCard), findsOneWidget);
      expect(find.byType(KingdomTreasuryCard), findsOneWidget);
      expect(find.byType(KingdomArmyCard), findsOneWidget);
      expect(find.byType(KingdomDiplomacyCard), findsOneWidget);

      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'kingdom_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden);
    });

    // -------------------------------------------------------------------------
    // TEST 2: TERRITORY BOUNDARIES & FRONTIER DEFENSE DECK
    // -------------------------------------------------------------------------
    testWidgets('Kingdom territory boundaries & frontier defense deck renders cleanly on 390x844 without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      final List<MockTerritoryBoundary> boundaries = createMockTerritoryBoundaries();

      final Widget boundariesScreen = Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: _buildKingdomAppBar('Sınır Savunma Hattı'),
        bottomNavigationBar: _buildKingdomBottomBar(activeIndex: 3),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: <Widget>[
              // Sınır Savunma Durum Başlığı
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF0B172A), Color(0xFF070B14)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1),
                ),
                child: const Row(
                  children: <Widget>[
                    KingdomCrestIcon(
                      type: KingdomCrestType.territory,
                      size: 38,
                      showGlow: true,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'KITA HARİTASI VE SINIR TAHKİMATI',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '3 Aktif Sınır Hattı Nöbette',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Boundary cards
              for (final MockTerritoryBoundary boundary in boundaries) ...<Widget>[
                KingdomTerritoryBoundaryCard(boundary: boundary),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: boundariesScreen,
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sınır Savunma Hattı'), findsOneWidget);
      expect(find.text('Kuzey Abis Sınır Tahkimatı'), findsOneWidget);
      expect(find.text('Obsidiyen Kanyonu Sınır Hattı'), findsOneWidget);
      expect(find.text('Güneş Vadisi Batı Rampartı'), findsOneWidget);
      expect(find.byType(KingdomTerritoryBoundaryCard), findsNWidgets(3));

      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'kingdom_territory_boundaries_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden);
    });

    // -------------------------------------------------------------------------
    // TEST 3: STRATEGIC RESOURCE NODES & CONTINENTAL HARVESTER DECK
    // -------------------------------------------------------------------------
    testWidgets('Kingdom strategic resource nodes & continental harvester deck renders cleanly on 390x844 without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      final List<MockResourceNode> nodes = createMockResourceNodes();

      final Widget resourceScreen = Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: _buildKingdomAppBar('Krallık Kaynak Düğümleri'),
        bottomNavigationBar: _buildKingdomBottomBar(activeIndex: 3),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: <Widget>[
              // Resource Production Header Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF1E170A), Color(0xFF0C101A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.4), width: 1),
                ),
                child: const Row(
                  children: <Widget>[
                    KingdomCrestIcon(
                      type: KingdomCrestType.treasury,
                      size: 38,
                      showGlow: true,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'STRATEJİK KAYNAK SAHALARI',
                            style: TextStyle(
                              color: AppColors.liquidGold,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '4 Kaynak Madeni ve Çeşme Aktif',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Resource Node Cards
              for (final MockResourceNode node in nodes) ...<Widget>[
                KingdomResourceNodeCard(node: node),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: resourceScreen,
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Krallık Kaynak Düğümleri'), findsOneWidget);
      expect(find.text('Kadim Aether Kristal Madeni'), findsOneWidget);
      expect(find.text('İmparatorluk Altın Damarı'), findsOneWidget);
      expect(find.text('Kadim Mithril Ocağı'), findsOneWidget);
      expect(find.text('Abis Ruh Pınarı (Mana Çeşmesi)'), findsOneWidget);
      expect(find.byType(KingdomResourceNodeCard), findsNWidgets(4));

      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'kingdom_resource_nodes_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden);
    });

    // -------------------------------------------------------------------------
    // TEST 4: INTEGRATED MASTER COMPOSITE SCREEN
    // -------------------------------------------------------------------------
    testWidgets('Integrated Master Kingdom composite screen mocks kingdoms, boundaries, and resource nodes on 390x844 cleanly', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();
      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      final MockKingdom kingdom = createMockKingdoms().first;
      final List<MockTerritoryBoundary> boundaries = createMockTerritoryBoundaries();
      final List<MockResourceNode> resources = createMockResourceNodes();

      final Widget fullScreen = Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: _buildKingdomAppBar('Krallık & Taht Meclisi'),
        bottomNavigationBar: _buildKingdomBottomBar(activeIndex: 3),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: <Widget>[
              // 1. Celestial Monarch Header
              KingdomRealmHeader(
                realmTitle: kingdom.realmTitle,
                reigningKing: kingdom.reigningKing,
                reigningGuild: kingdom.reigningGuild,
                dominionLevel: kingdom.dominionLevel,
                activeBlessingSummary: kingdom.activeBlessingSummary,
                height: 180,
              ),
              const SizedBox(height: 10),

              // 2. Territory Dominance Card
              KingdomTerritoryCard(
                realmName: kingdom.realmTitle,
                controlledProvinces: kingdom.controlledProvinces,
                totalProvinces: kingdom.totalProvinces,
                defenseLevel: kingdom.defenseLevel,
                taxYieldMultiplier: kingdom.taxYieldMultiplier,
                isUnderSiege: kingdom.isUnderSiege,
                onManage: () {},
                onViewMap: () {},
              ),
              const SizedBox(height: 12),

              // 3. Territory Boundary Alert & Fortification Card
              KingdomTerritoryBoundaryCard(boundary: boundaries.first),
              const SizedBox(height: 12),

              // 4. Strategic Resource Node Card
              KingdomResourceNodeCard(node: resources.first),
              const SizedBox(height: 12),

              // 5. Treasury Reserves Card
              KingdomTreasuryCard(
                goldBalance: kingdom.goldBalance,
                gemBalance: kingdom.gemsBalance,
                dailyTaxRevenue: kingdom.dailyTaxRevenue,
                isKing: true,
                canGift: true,
                onViewLedger: () {},
                onGiftSend: () {},
              ),
              const SizedBox(height: 12),

              // 6. Army & Garrison Card
              KingdomArmyCard(
                legionName: kingdom.legionName,
                activeSoldiers: kingdom.activeSoldiers,
                readinessRating: kingdom.readinessRating,
                warDefenseBonusPct: kingdom.warDefenseBonusPct,
                onInspect: () {},
              ),
              const SizedBox(height: 12),

              // 7. Diplomacy Card
              KingdomDiplomacyCard(
                month: 'Temmuz 2027 Seçim Dönemi',
                kingName: kingdom.reigningKing,
                guildName: kingdom.reigningGuild,
                isElectionActive: true,
                countdownLabel: '3 Gün Kaldı',
                canVote: true,
                alreadyVoted: false,
                onVote: () {},
                onViewCouncil: () {},
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: fullScreen,
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(KingdomRealmHeader), findsOneWidget);
      expect(find.byType(KingdomTerritoryCard), findsOneWidget);
      expect(find.byType(KingdomTerritoryBoundaryCard), findsOneWidget);
      expect(find.byType(KingdomResourceNodeCard), findsOneWidget);
      expect(find.byType(KingdomTreasuryCard), findsOneWidget);
      expect(find.byType(KingdomArmyCard), findsOneWidget);
      expect(find.byType(KingdomDiplomacyCard), findsOneWidget);

      final File golden = await captureWidgetToMobilePng(
        tester: tester,
        repaintKey: repaintKey,
        filename: 'kingdom_full_composite_390x844_golden.png',
      );

      verifyMobileGoldenFile(golden);
    });
  });
}

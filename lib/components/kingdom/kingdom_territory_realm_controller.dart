import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../models/guild_war_model.dart';

/// Viewing modes for the 3D Kingdom Realm viewport.
enum KingdomRealmMode {
  /// Imperial Citadel & Royal Castle view (Keep, towers, portcullis, royal banners)
  citadel,

  /// Strategic Continental Realm view (6 territory bastions, glowing ley-lines, faction balance)
  territory,

  /// Royal Treasury Stronghold view (Gold reserves, vaults, tax collection ledger)
  treasury,
}

/// Daytime lighting phase for dynamic celestial illumination in the 3D realm.
enum RealmLightingPhase {
  dawn,
  midday,
  goldenHour,
  midnight,
}

/// Faction allegiance for kingdom territory nodes.
enum FactionType {
  elyos,
  asmodian,
  neutral,
}

/// Strategic 3D territory node on the continental realm.
class RealmTerritoryNode {
  const RealmTerritoryNode({
    required this.id,
    required this.name,
    required this.title,
    required this.worldX,
    required this.worldY,
    required this.worldZ,
    required this.faction,
    required this.icon,
    this.defenseLevel = 4,
    this.taxMultiplier = 1.25,
    this.isUnderSiege = false,
    this.garrisonCount = 12000,
    this.modelAssetPath,
  });

  final String id;
  final String name;
  final String title;
  final double worldX; // -1.0 to 1.0 in realm space
  final double worldY;
  final double worldZ;
  final FactionType faction;
  final String icon;
  final int defenseLevel;
  final double taxMultiplier;
  final bool isUnderSiege;
  final int garrisonCount;
  final String? modelAssetPath;
}

/// Master controller orchestrating the 3D Kingdom Realm viewport:
/// - 360-degree orbital camera (yaw, pitch, zoom) with momentum and detent haptics
/// - Active viewing mode (Citadel, Strategic Continental, Treasury Stronghold)
/// - Selected territory bastion with camera focusing
/// - Day/Night celestial lighting cycle
class KingdomTerritoryRealmController extends ChangeNotifier {
  KingdomTerritoryRealmController({
    KingdomRealmMode initialMode = KingdomRealmMode.citadel,
    RealmLightingPhase initialLighting = RealmLightingPhase.goldenHour,
  })  : _mode = initialMode,
        _lighting = initialLighting;

  KingdomRealmMode _mode;
  KingdomRealmMode get mode => _mode;

  RealmLightingPhase _lighting;
  RealmLightingPhase get lighting => _lighting;

  // Camera angles (in radians)
  double _yaw = 0.0;
  double get yaw => _yaw;

  double _pitch = 0.12;
  double get pitch => _pitch;

  double _zoom = 1.0;
  double get zoom => _zoom;

  double _lastDetentAngle = 0.0;
  int? _selectedNodeIndex;
  int? get selectedNodeIndex => _selectedNodeIndex;

  bool _isDragging = false;
  bool get isDragging => _isDragging;

  bool _runicGlowActive = true;
  bool get runicGlowActive => _runicGlowActive;

  /// Default predefined territory bastions situated across the 3D fantasy continent.
  static const List<RealmTerritoryNode> defaultNodes = <RealmTerritoryNode>[
    RealmTerritoryNode(
      id: 'node_dawn',
      name: 'Şafak Hisarı',
      title: 'Güneşin İlk Işıltısı',
      worldX: -0.55,
      worldY: 0.10,
      worldZ: -0.40,
      faction: FactionType.elyos,
      icon: '🏰',
      defenseLevel: 5,
      taxMultiplier: 1.35,
      garrisonCount: 18500,
      modelAssetPath: 'assets/models/props/Portcullis_HeavyIron.glb',
    ),
    RealmTerritoryNode(
      id: 'node_abyss',
      name: 'Uçurum Kalesi',
      title: 'Karanlık Sınır Kalesi',
      worldX: 0.58,
      worldY: -0.05,
      worldZ: -0.35,
      faction: FactionType.asmodian,
      icon: '🏔',
      defenseLevel: 4,
      taxMultiplier: 1.20,
      isUnderSiege: true,
      garrisonCount: 14200,
      modelAssetPath: 'assets/models/environment/pillar-obelisk.glb',
    ),
    RealmTerritoryNode(
      id: 'node_center',
      name: 'Merkez Bastion',
      title: 'İmparatorluk Tahtı',
      worldX: 0.0,
      worldY: 0.22,
      worldZ: 0.0,
      faction: FactionType.elyos,
      icon: '👑',
      defenseLevel: 6,
      taxMultiplier: 1.50,
      garrisonCount: 28000,
      modelAssetPath: 'assets/models/environment/crypt-large.glb',
    ),
    RealmTerritoryNode(
      id: 'node_dragon',
      name: 'Ejderha Mabedi',
      title: 'Kadim Ateş Tapınağı',
      worldX: -0.60,
      worldY: -0.15,
      worldZ: 0.45,
      faction: FactionType.asmodian,
      icon: '🐉',
      defenseLevel: 4,
      taxMultiplier: 1.30,
      garrisonCount: 11000,
      modelAssetPath: 'assets/models/props/StoneAltar_Ritual.glb',
    ),
    RealmTerritoryNode(
      id: 'node_obsidian',
      name: 'Obsidiyen Kule',
      title: 'Gölge Nöbetçisi',
      worldX: 0.62,
      worldY: 0.08,
      worldZ: 0.42,
      faction: FactionType.asmodian,
      icon: '🔥',
      defenseLevel: 5,
      taxMultiplier: 1.40,
      garrisonCount: 16400,
      modelAssetPath: 'assets/models/props/Gargoyle_DarkStone.glb',
    ),
    RealmTerritoryNode(
      id: 'node_sunken',
      name: 'Batık Geçit',
      title: 'Korsan Boğazı',
      worldX: 0.05,
      worldY: -0.25,
      worldZ: 0.60,
      faction: FactionType.neutral,
      icon: '⚓',
      defenseLevel: 3,
      taxMultiplier: 1.10,
      garrisonCount: 8500,
      modelAssetPath: 'assets/models/environment/column-large.glb',
    ),
  ];

  List<RealmTerritoryNode> _nodes = defaultNodes;
  List<RealmTerritoryNode> get nodes => _nodes;

  void setMode(KingdomRealmMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    HapticFeedback.mediumImpact();
    // Reframe camera for target mode
    switch (newMode) {
      case KingdomRealmMode.citadel:
        _pitch = 0.12;
        _zoom = 1.0;
        break;
      case KingdomRealmMode.territory:
        _pitch = 0.28;
        _zoom = 0.88;
        break;
      case KingdomRealmMode.treasury:
        _pitch = 0.08;
        _zoom = 1.15;
        break;
    }
    notifyListeners();
  }

  void setLightingPhase(RealmLightingPhase phase) {
    if (_lighting == phase) return;
    _lighting = phase;
    notifyListeners();
  }

  void toggleRunicGlow() {
    _runicGlowActive = !_runicGlowActive;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void selectNode(int? index) {
    _selectedNodeIndex = index;
    if (index != null && index >= 0 && index < _nodes.length) {
      HapticFeedback.lightImpact();
      // Smoothly orient camera toward target node
      final RealmTerritoryNode node = _nodes[index];
      final double targetYaw = math.atan2(node.worldX, node.worldZ);
      _yaw = targetYaw;
    }
    notifyListeners();
  }

  void updateNodesFromTerritoryData(List<TerritoryData> data) {
    if (data.isEmpty) return;
    final List<RealmTerritoryNode> updated = <RealmTerritoryNode>[];
    for (int i = 0; i < defaultNodes.length; i++) {
      final RealmTerritoryNode base = defaultNodes[i];
      if (i < data.length) {
        final TerritoryData d = data[i];
        final FactionType faction = d.isUnclaimed
            ? FactionType.neutral
            : (i % 2 == 0 ? FactionType.elyos : FactionType.asmodian);
        updated.add(RealmTerritoryNode(
          id: d.id,
          name: d.name.isNotEmpty ? d.name : base.name,
          title: base.title,
          worldX: base.worldX,
          worldY: base.worldY,
          worldZ: base.worldZ,
          faction: faction,
          icon: base.icon,
          defenseLevel: d.defenseLineLevel > 0 ? d.defenseLineLevel : base.defenseLevel,
          taxMultiplier: base.taxMultiplier,
          isUnderSiege: d.hasActiveSiegeSession,
          garrisonCount: d.displayDefensePower > 0 ? d.displayDefensePower : base.garrisonCount,
          modelAssetPath: base.modelAssetPath,
        ));
      } else {
        updated.add(base);
      }
    }
    _nodes = updated;
    notifyListeners();
  }

  void onScaleStart(ScaleStartDetails details) {
    _isDragging = true;
    notifyListeners();
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    // Pan orbit via focalPointDelta
    if (details.focalPointDelta.dx != 0 || details.focalPointDelta.dy != 0) {
      _yaw += details.focalPointDelta.dx * 0.016;
      _pitch = (_pitch - details.focalPointDelta.dy * 0.012).clamp(-0.25, 0.45);

      // Subtle haptic feedback detent on quadrant crossings (every 90 deg)
      if ((_yaw - _lastDetentAngle).abs() > (math.pi / 2)) {
        _lastDetentAngle = _yaw;
        HapticFeedback.selectionClick();
      }
    }

    // Pinch zoom via scale
    if (details.scale != 1.0) {
      _zoom = (_zoom * details.scale).clamp(0.65, 2.2);
    }
    notifyListeners();
  }

  void onScaleEnd(ScaleEndDetails details) {
    _isDragging = false;
    notifyListeners();
  }

  void resetCamera() {
    HapticFeedback.mediumImpact();
    _yaw = 0.0;
    _pitch = 0.12;
    _zoom = 1.0;
    _selectedNodeIndex = null;
    notifyListeners();
  }
}

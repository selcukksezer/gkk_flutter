import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/utils/combat_restriction.dart';
import '../../core/vfx/directional_camera_shake.dart';
import '../../core/vfx/rim_hit_flash_effect.dart';
import '../../models/guild_war_model.dart';
import '../../providers/guild_vault_provider.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import 'widgets/defense_power_bar.dart';
import 'widgets/faction_crest_painter.dart';
import 'widgets/guild_war_design.dart';
import 'widgets/guild_war_sub_screen_scaffold.dart';
import 'widgets/siege_combat_viewport.dart';
import 'widgets/territory_guild_duel_panel.dart';

/// Interactive battalion deployment configuration for the fortress siege.
class _SiegeBattalion {
  _SiegeBattalion({
    required this.id,
    required this.name,
    required this.codeName,
    required this.role,
    required this.icon,
    required this.basePower,
    required this.troops,
    required this.wallBonus,
    required this.vectorName,
    required this.themeColor,
    required this.perkText,
    this.isDeployed = true,
  });

  final String id;
  final String name;
  final String codeName;
  final String role;
  final IconData icon;
  final int basePower;
  final int troops;
  final double wallBonus;
  final String vectorName;
  final Color themeColor;
  final String perkText;
  bool isDeployed;
}

/// Tactical siege weapon launch battery item.
class _SiegeWeapon {
  _SiegeWeapon({
    required this.id,
    required this.name,
    required this.typeName,
    required this.icon,
    required this.minDamage,
    required this.maxDamage,
    required this.targetPart,
    required this.accentColor,
    required this.shakePreset,
    required this.flashTint,
    required this.soundDesc,
    this.isFiring = false,
    this.shotsFired = 0,
  });

  final String id;
  final String name;
  final String typeName;
  final IconData icon;
  final int minDamage;
  final int maxDamage;
  final String targetPart;
  final Color accentColor;
  final CameraShakePreset shakePreset;
  final Color flashTint;
  final String soundDesc;
  bool isFiring;
  int shotsFired;
}

class GuildWarAttackScreen extends ConsumerStatefulWidget {
  const GuildWarAttackScreen({super.key, required this.territoryId});

  final String territoryId;

  @override
  ConsumerState<GuildWarAttackScreen> createState() => _GuildWarAttackScreenState();
}

class _GuildWarAttackScreenState extends ConsumerState<GuildWarAttackScreen>
    with SingleTickerProviderStateMixin {
  TerritoryAttackPreview? _preview;
  bool _loading = true;
  bool _attacking = false;
  bool _showSiegeTactics = false;

  // Combat Juice controllers (Module 1 Directional Shake & Module 3 Rim Hit Flash)
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final DirectionalCameraShake _shakeController = DirectionalCameraShake();
  final RimHitFlashController _flashController = RimHitFlashController();

  // Multi-layered fortress wall health state
  int _gateHp = 60000;
  int _gateMaxHp = 60000;
  int _wallHp = 120000;
  int _wallMaxHp = 120000;
  int _coreHp = 80000;
  int _coreMaxHp = 80000;
  bool _isBreached = false;
  bool _showBreachBanner = false;

  // Real-time Clash alerts feed
  final List<String> _clashAlerts = <String>[
    '🛡️ [Savunma İstihbaratı]: Düşman hisarı alarm verdi, nöbetçiler sur hattına geçti.',
    '⚡ [Öncü Alayı]: Kuşatma siperlerine yerleşti, hücum borusu bekleniyor.',
    '🎯 [Topçu Bataryası]: Hedefler kilitlendi, hisar duvarlarına ateş serbest.',
  ];

  // Battalion Deployment cards
  late final List<_SiegeBattalion> _battalions;

  // Siege Weapon Artillery battery
  late final List<_SiegeWeapon> _siegeWeapons;

  @override
  void initState() {
    super.initState();
    _initBattalionsAndWeapons();
    _initJuiceTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _initBattalionsAndWeapons() {
    _battalions = <_SiegeBattalion>[
      _SiegeBattalion(
        id: 'vanguard',
        name: 'Öncü Hücum Alayı',
        codeName: 'TABUR-01',
        role: 'Ağır Piyade & Cephe Hücumu',
        icon: Icons.shield_rounded,
        basePower: 18500,
        troops: 140,
        wallBonus: 1.15,
        vectorName: 'Ana Kuşatma Kapısı',
        themeColor: AppColors.coralFlare,
        perkText: '+%15 Hücum İvmesi & Cephe Kalkan Hattı',
        isDeployed: true,
      ),
      _SiegeBattalion(
        id: 'wall_breakers',
        name: 'Gök Gürültüsü Sur Kırıcıları',
        codeName: 'TABUR-02',
        role: 'Kuşatma & Duvar Parçalama',
        icon: Icons.landslide_rounded,
        basePower: 24200,
        troops: 95,
        wallBonus: 1.35,
        vectorName: 'Doğu Sur Burcu',
        themeColor: AppColors.liquidGold,
        perkText: '+%35 Sur Hasarı & Merdiven Hattı',
        isDeployed: true,
      ),
      _SiegeBattalion(
        id: 'spell_weavers',
        name: 'Hiçlik Büyü Dokuyucuları',
        codeName: 'TABUR-03',
        role: 'Arkana Bombardımanı',
        icon: Icons.auto_fix_high_rounded,
        basePower: 20800,
        troops: 60,
        wallBonus: 1.20,
        vectorName: 'Kuzey Kule Bataryası',
        themeColor: AppColors.cyberFuchsia,
        perkText: 'Rünik Kalkan Aşımı & Alan Şoku',
        isDeployed: true,
      ),
      _SiegeBattalion(
        id: 'shadow_infiltrators',
        name: 'Gölge Sızma Kolu',
        codeName: 'TABUR-04',
        role: 'Yan Kanat Sabotajı',
        icon: Icons.visibility_off_rounded,
        basePower: 16500,
        troops: 45,
        wallBonus: 1.10,
        vectorName: 'Gizli Kanal & Yan Gedik',
        themeColor: AppColors.toxicNeon,
        perkText: '+%20 Kritik Gedik Şansı & Savunma Sabotajı',
        isDeployed: false,
      ),
    ];

    _siegeWeapons = <_SiegeWeapon>[
      _SiegeWeapon(
        id: 'trebuchet',
        name: 'Ağır Trebüşe "Kaya Bükücü"',
        typeName: 'Ağır Kinetik Mancınık',
        icon: Icons.storm_rounded,
        minDamage: 24000,
        maxDamage: 32000,
        targetPart: 'Sur Duvarı',
        accentColor: AppColors.coralFlare,
        shakePreset: CameraShakePreset.explosiveShock,
        flashTint: const Color(0xFFFF5722),
        soundDesc: 'Gök gürültüsü kaya çarpması!',
      ),
      _SiegeWeapon(
        id: 'ballista',
        name: 'Ejder Alevi Balistası',
        typeName: 'Alevli Delici Batarya',
        icon: Icons.local_fire_department_rounded,
        minDamage: 18000,
        maxDamage: 24000,
        targetPart: 'Dış Kapı',
        accentColor: AppColors.mysticRuby,
        shakePreset: CameraShakePreset.heavyCrit,
        flashTint: const Color(0xFFFF2222),
        soundDesc: 'Alev püsküren demir zıpkın!',
      ),
      _SiegeWeapon(
        id: 'ram',
        name: 'Demir Başlı Muhasara Koçbaşı',
        typeName: 'Hidrolik Darbe Koçbaşı',
        icon: Icons.hardware_rounded,
        minDamage: 22000,
        maxDamage: 28000,
        targetPart: 'Dış Kapı',
        accentColor: AppColors.liquidGold,
        shakePreset: CameraShakePreset.heavyCrit,
        flashTint: const Color(0xFFFFD54F),
        soundDesc: 'Kapı menteşelerini parçalayan koçbaşı darbesi!',
      ),
      _SiegeWeapon(
        id: 'void_mortar',
        name: 'Hiçlik Kristal Havanı',
        typeName: 'Arkana Alan Bombardımanı',
        icon: Icons.auto_awesome_rounded,
        minDamage: 26000,
        maxDamage: 36000,
        targetPart: 'Rünik Kalkan',
        accentColor: AppColors.cyberFuchsia,
        shakePreset: CameraShakePreset.explosiveShock,
        flashTint: const Color(0xFFEA80FC),
        soundDesc: 'Rünik kalkanı eriten hiçlik infilakı!',
      ),
    ];
  }

  void _initJuiceTicker() {
    _ticker = createTicker((Duration elapsed) {
      if (_lastTick != Duration.zero) {
        final double dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
        if (_shakeController.isActive) {
          _shakeController.update(dt);
        }
        if (_flashController.isFlashing) {
          _flashController.update(dt);
        }
      }
      _lastTick = elapsed;
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shakeController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final TerritoryAttackPreview? p =
        await ref.read(guildWarProvider.notifier).loadAttackPreview(widget.territoryId);
    if (!mounted) return;
    setState(() {
      _preview = p;
      _loading = false;
      if (p != null) {
        _initFortressState(p);
      }
    });
  }

  void _initFortressState(TerritoryAttackPreview p) {
    final int baseDef = p.defensePower > 0 ? p.defensePower : 200000;
    _gateMaxHp = (baseDef * 0.30).round();
    _wallMaxHp = (baseDef * 0.45).round();
    _coreMaxHp = (baseDef * 0.25).round();

    _gateHp = _gateMaxHp;
    _wallHp = _wallMaxHp;
    _coreHp = _coreMaxHp;
    _isBreached = false;
    _showBreachBanner = false;
  }

  int get _deployedTroopCount =>
      _battalions.where((_SiegeBattalion b) => b.isDeployed).fold<int>(0, (int sum, _SiegeBattalion b) => sum + b.troops);

  int get _deployedBattalionPower =>
      _battalions.where((_SiegeBattalion b) => b.isDeployed).fold<int>(0, (int sum, _SiegeBattalion b) => sum + b.basePower);

  double get _battalionWallMultiplier => _battalions
      .where((_SiegeBattalion b) => b.isDeployed)
      .fold<double>(1.0, (double mult, _SiegeBattalion b) => mult * (1.0 + (b.wallBonus - 1.0) * 0.4));

  void _addClashAlert(String message) {
    setState(() {
      _clashAlerts.insert(0, message);
      if (_clashAlerts.length > 8) {
        _clashAlerts.removeLast();
      }
    });
  }

  Future<void> _soundWarHorn() async {
    await HapticFeedback.heavyImpact();
    _shakeController.triggerPreset(CameraShakePreset.lightJab);
    _flashController.triggerHit(
      tint: AppColors.liquidGold,
      duration: const Duration(milliseconds: 160),
      intensityMultiplier: 1.4,
    );
    _addClashAlert('📯 [Lonca Komutanı]: Savaş Borusu çaldı! Tüm taburlara hücum ivmesi verildi!');
  }

  void _toggleBattalion(_SiegeBattalion battalion) {
    final int deployedCount = _battalions.where((_SiegeBattalion b) => b.isDeployed).length;
    if (battalion.isDeployed && deployedCount <= 1) {
      AppMessenger.showInfo(context, 'En az 1 tabur hücum hattında kalmalıdır.');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      battalion.isDeployed = !battalion.isDeployed;
    });
    _addClashAlert(
      battalion.isDeployed
          ? '⚔️ [Tabur Emri]: ${battalion.name} ${battalion.vectorName} hattına konuşlandırıldı.'
          : '🛡️ [Tabur Emri]: ${battalion.name} ihtiyat hattına çekildi.',
    );
  }

  Future<void> _fireSiegeWeapon(_SiegeWeapon weapon) async {
    if (weapon.isFiring) return;
    setState(() {
      weapon.isFiring = true;
      weapon.shotsFired += 1;
    });

    // Tactile tremor + hit flash combat juice
    await HapticFeedback.heavyImpact();
    _shakeController.triggerPreset(
      weapon.shakePreset,
      hitDirection: const Offset(0, 1.2),
    );
    _flashController.triggerHit(
      tint: weapon.flashTint,
      duration: const Duration(milliseconds: 150),
      intensityMultiplier: 1.3,
    );

    // Compute realistic kinetic damage
    final math.Random random = math.Random();
    final int damage = weapon.minDamage +
        random.nextInt(math.max(1, weapon.maxDamage - weapon.minDamage));

    // Inflict damage to fortress wall health meters
    setState(() {
      if (weapon.targetPart == 'Sur Duvarı') {
        _wallHp = math.max(0, _wallHp - damage);
      } else if (weapon.targetPart == 'Dış Kapı') {
        _gateHp = math.max(0, _gateHp - damage);
      } else {
        _coreHp = math.max(0, _coreHp - damage);
      }
    });

    final String formattedDmg = NumberFormat('#,###').format(damage);
    _addClashAlert(
      '💥 [${weapon.name}]: ${weapon.targetPart} hedefine $formattedDmg hasar verdi! (${weapon.soundDesc})',
    );

    // Check critical breach conditions
    final int totalRemaining = _gateHp + _wallHp + _coreHp;
    final int totalMax = math.max(1, _gateMaxHp + _wallMaxHp + _coreMaxHp);
    final double ratio = totalRemaining / totalMax;

    if ((ratio <= 0.35 || _gateHp == 0 || _wallHp == 0) && !_isBreached) {
      _triggerBreachSequence();
    }

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) {
      setState(() => weapon.isFiring = false);
    }
  }

  void _triggerBreachSequence() {
    _isBreached = true;
    _shakeController.triggerPreset(
      CameraShakePreset.explosiveShock,
      hitDirection: const Offset(0, 2.0),
    );
    _flashController.triggerHit(
      tint: AppColors.mysticRuby,
      duration: const Duration(milliseconds: 280),
      intensityMultiplier: 1.8,
    );
    HapticFeedback.vibrate();
    _addClashAlert(
      '🔥 [KRİTİK GEDİK]: Hisar savunma hattı çöktü! Duvarlar yarıldı, nihai hücum emri verildi!',
    );
    setState(() {
      _showBreachBanner = true;
    });
  }

  Future<void> _attack() async {
    final profile = ref.read(playerProvider).profile;
    final String? combatBlock = combatRestrictionMessage(
      hospitalUntil: profile?.hospitalUntil,
      prisonUntil: profile?.prisonUntil,
      health: profile?.health,
      maxHealth: profile?.maxHealth,
    );
    if (combatBlock != null) {
      AppMessenger.showError(context, combatBlock);
      return;
    }
    if (_preview != null) {
      final liveVault = ref.read(guildVaultProvider);
      final int gold = liveVault.hydrated ? liveVault.vaultGold : _preview!.vaultGold;
      if (gold < _preview!.attackGoldCost) {
        AppMessenger.showError(context, 'Lonca kasasında yeterli altın yok.');
        return;
      }
    }

    // Tactile heavy impact tremor feedback when launching the fortress siege assault
    await HapticFeedback.heavyImpact();
    _shakeController.triggerPreset(
      CameraShakePreset.explosiveShock,
      hitDirection: const Offset(0, 1.5),
    );
    _flashController.triggerHit(
      tint: AppColors.mysticRuby,
      duration: const Duration(milliseconds: 220),
      intensityMultiplier: 1.6,
    );

    setState(() => _attacking = true);
    final GuildWarAttackResult? result =
        await ref.read(guildWarProvider.notifier).attackTerritory(widget.territoryId);
    if (!mounted) return;
    setState(() => _attacking = false);

    if (result == null) return;
    if (result.error != null) {
      AppMessenger.showError(context, result.error!);
      await _load();
      return;
    }
    unawaited(ref.read(playerProvider.notifier).loadProfile());
    await context.push(AppRoutes.guildWarBattleResult, extra: result);
    if (!mounted) return;

    // Win -> own territory now; don't reload attack preview.
    if (result.success) {
      context.go('/');
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final TerritoryAttackPreview? p = _preview;
    final liveVault = ref.watch(guildVaultProvider);
    final int displayVaultGold = liveVault.hydrated
        ? liveVault.vaultGold
        : (p?.vaultGold ?? 0);
    final bool canAfford = p == null
        ? false
        : displayVaultGold >= p.attackGoldCost;

    return GuildWarSubScreenScaffold(
      title: '⚔ Lonca Saldırısı',
      onLogout: () async => performLogout(ref),
      currentRoute: AppRoutes.guildWar,
      body: DirectionalCameraShakeHost(
        controller: _shakeController,
        child: RimHitFlashWidget(
          controller: _flashController,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: WarPalette.gold))
              : p == null || p.error != null
                  ? _buildErrorState(p)
                  : _buildMainContent(context, p, displayVaultGold, canAfford),
        ),
      ),
    );
  }

  Widget _buildErrorState(TerritoryAttackPreview? p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('⚔️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text(
              p?.error ?? 'Önizleme yüklenemedi',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if ((p?.error ?? '').contains('Kendi bölgene'))
              OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.map_rounded, size: 16, color: WarPalette.gold),
                label: const Text('Bölgeye Dön', style: TextStyle(color: WarPalette.gold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: WarPalette.gold.withValues(alpha: 0.4)),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: WarPalette.gold),
                label: const Text('Tekrar Dene', style: TextStyle(color: WarPalette.gold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: WarPalette.gold.withValues(alpha: 0.4)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    TerritoryAttackPreview p,
    int displayVaultGold,
    bool canAfford,
  ) {
    return ListView(
      padding: GameScrollLayout.pagePadding(context),
      children: <Widget>[
        // 1. Live Clash Alert Ticker & Rally Shout trigger
        _buildLiveClashTicker(),

        // 2. Critical Territory Breach Announcement Banner
        if (_showBreachBanner) _buildBreachBanner(),

        // 3. Dark Fantasy Fortress Siege Header
        _buildFortressHeader(p),
        const SizedBox(height: AppSpacing.base),

        // 4. Multi-Layer Fortress Wall Health Meters
        _buildFortressDefenseConsole(p),
        const SizedBox(height: AppSpacing.base),

        // 5. Battalion Deployment Cards
        _buildBattalionDeploymentSection(p),
        const SizedBox(height: AppSpacing.base),

        // 6. Siege Weapon Launch Battery Triggers
        _buildSiegeWeaponBatterySection(),
        const SizedBox(height: AppSpacing.base),

        // 7. Territory Guild Duel Header
        TerritoryGuildDuelPanel(
          attacker: p.attackerGuild,
          defender: p.defenderGuild,
        ),
        const SizedBox(height: AppSpacing.base),

        // 8. War Metrics Breakdown Card
        WarNeonCard(
          accent: WarPalette.coral,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _row('Saldırı Maliyeti', '${NumberFormat('#,###').format(p.attackGoldCost)} Altın'),
              _row('Günlük Ticaret Geliri', '+${NumberFormat('#,###').format(p.tradeIncome)} Altın/gün'),
              if (p.roiDays != null)
                _row('Yatırım Geri Dönüşü (ROI)', '~${p.roiDays!.toStringAsFixed(1)} gün'),
              _row('Lonca Kasası Durumu', '${NumberFormat('#,###').format(displayVaultGold)} Altın'),
              _row('Temel Lonca Saldırı Gücü', NumberFormat('#,###').format(p.attackPower)),
              _row('Konuşlu Tabur Gücü', NumberFormat('#,###').format(_deployedBattalionPower)),
              if (p.sizeAttackMult > 1.001)
                _row(
                  'Küçük Lonca Güç Çarpanı',
                  '+${((p.sizeAttackMult - 1.0) * 100).toStringAsFixed(0)}% (${p.memberCount} üye)',
                ),
              if (p.gemAttackBoost > 0)
                _row('Elmas Saldırı Takviyesi', '+${p.gemAttackBoost}%'),
              _row('Hedef Savunma Gücü', NumberFormat('#,###').format(p.defensePower)),
              _row('Tahmini Zafer İhtimali', '%${p.winChancePct.toStringAsFixed(1)}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.base),

        // Power comparison bar
        DefensePowerBar(
          current: p.attackPower,
          max: p.attackPower + p.defensePower,
          height: 14,
          showLabel: false,
        ),
        const SizedBox(height: AppSpacing.base),

        // 9. Tactical Siege Drill & Combat VFX Simulator (All 9 Juice Modules)
        _buildSiegeTacticsSimulator(p),
        const SizedBox(height: AppSpacing.base),

        // 10. Real-time Clash Battlefield Logs
        _buildBattlefieldLogFeed(),
        const SizedBox(height: AppSpacing.lg),

        // 11. Primary Assault Launch Action
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _attacking || !canAfford ? null : _attack,
            style: ElevatedButton.styleFrom(
              backgroundColor: WarPalette.ruby,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 6,
              shadowColor: WarPalette.ruby.withValues(alpha: 0.6),
            ),
            child: Text(
              _attacking
                  ? 'Kuşatma Başlatılıyor...'
                  : canAfford
                      ? '⚔️ KUŞATMAYI BAŞLAT (${NumberFormat('#,###').format(p.attackGoldCost)} Altın)'
                      : 'Lonca Kasası Yetersiz',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildLiveClashTicker() {
    final String latestAlert = _clashAlerts.isNotEmpty
        ? _clashAlerts.first
        : 'Savaş hattında keşif devam ediyor.';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF10141E),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.coralFlare,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.coralFlare,
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'RADAR:',
            style: TextStyle(
              color: AppColors.liquidGold,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              latestAlert,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _soundWarHorn,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: WarPalette.goldGrad,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.campaign_rounded, size: 12, color: WarPalette.void_),
                  SizedBox(width: 4),
                  Text(
                    'NARA AT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: WarPalette.void_,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreachBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF4A0E1A),
            Color(0xFF260A10),
            Color(0xFF14070A),
          ],
        ),
        border: Border.all(
          color: AppColors.mysticRuby,
          width: 1.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.mysticRuby.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.mysticRuby.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.coralFlare, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '⚠️ KRİTİK BÖLGE İHLALİ · SUR GEDİĞİ AÇILDI!',
                      style: TextStyle(
                        color: AppColors.coralFlare,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hisar dış savunması çöktü! Savunan lonca savunmasız durumda, nihai hücum emri verildi.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white60),
                onPressed: () => setState(() => _showBreachBanner = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFortressHeader(TerritoryAttackPreview p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF260D15),
            Color(0xFF141724),
            Color(0xFF1D1409),
          ],
        ),
        border: Border.all(
          color: AppColors.mysticRuby.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const FactionCrestWidget(
                faction: FactionType.asmodian,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '⚔️ KALE KUŞATMASI & SUR YARMA',
                      style: TextStyle(
                        color: AppColors.coralFlare,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      p.territoryName,
                      style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const FactionCrestWidget(
                faction: FactionType.elyos,
                size: 36,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFortressDefenseConsole(TerritoryAttackPreview p) {
    final int totalCurrent = _gateHp + _wallHp + _coreHp;
    final int totalMax = math.max(1, _gateMaxHp + _wallMaxHp + _coreMaxHp);
    final double overallRatio = (totalCurrent / totalMax).clamp(0.0, 1.0);

    final String conditionText;
    final Color conditionColor;
    if (overallRatio > 0.70) {
      conditionText = 'MUHKEM TAHKİMAT';
      conditionColor = AppColors.toxicNeon;
    } else if (overallRatio > 0.40) {
      conditionText = 'AĞIR HASARLI';
      conditionColor = AppColors.liquidGold;
    } else if (overallRatio > 0.15) {
      conditionText = 'YIKILMAK ÜZERE';
      conditionColor = AppColors.coralFlare;
    } else {
      conditionText = 'GEDİK AÇILDI';
      conditionColor = AppColors.mysticRuby;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        color: const Color(0xFF141724),
        border: Border.all(
          color: conditionColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.shield_outlined, size: 16, color: conditionColor),
                  const SizedBox(width: 6),
                  const Text(
                    'HİSAR SAVUNMA BÜTÜNLÜĞÜ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: conditionColor.withValues(alpha: 0.2),
                  border: Border.all(color: conditionColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '$conditionText (%${(overallRatio * 100).toStringAsFixed(1)})',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: conditionColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: overallRatio,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(conditionColor),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildSubMeter(
            label: 'Dış Hisar Kapısı & Zırh Kaplama',
            current: _gateHp,
            max: _gateMaxHp,
            barColor: AppColors.coralFlare,
          ),
          const SizedBox(height: 8),
          _buildSubMeter(
            label: 'Bastion Ana Savunma Suru (Doğu/Batı)',
            current: _wallHp,
            max: _wallMaxHp,
            barColor: AppColors.liquidGold,
          ),
          const SizedBox(height: 8),
          _buildSubMeter(
            label: 'Citadel Rünik Kalkan Muhafazası',
            current: _coreHp,
            max: _coreMaxHp,
            barColor: AppColors.cyberFuchsia,
          ),
        ],
      ),
    );
  }

  Widget _buildSubMeter({
    required String label,
    required int current,
    required int max,
    required Color barColor,
  }) {
    final int safeMax = math.max(1, max);
    final double ratio = (current.clamp(0, safeMax) / safeMax).clamp(0.0, 1.0);
    final bool isDestroyed = current <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              isDestroyed
                  ? 'GEDİK AÇILDI!'
                  : '${NumberFormat('#,###').format(current)} / ${NumberFormat('#,###').format(safeMax)}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isDestroyed ? AppColors.mysticRuby : Colors.white60,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDestroyed ? AppColors.mysticRuby : barColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBattalionDeploymentSection(TerritoryAttackPreview p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        WarSectionHeader(
          title: 'TABUR KONUŞLANDIRMA & ASKERİ DÜZEN',
          subtitle:
              'Aktif: $_deployedTroopCount Asker · ${_battalionWallMultiplier > 1.0 ? '+%${((_battalionWallMultiplier - 1.0) * 100).toStringAsFixed(0)} Kuşatma Gücü' : 'Standart Güç'}',
          accent: AppColors.liquidGold,
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._battalions.map((_SiegeBattalion battalion) {
          final bool active = battalion.isDeployed;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _toggleBattalion(battalion),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: active
                      ? const Color(0xFF151928)
                      : const Color(0xFF0F111A).withValues(alpha: 0.6),
                  border: Border.all(
                    color: active
                        ? battalion.themeColor.withValues(alpha: 0.7)
                        : Colors.white12,
                    width: active ? 1.4 : 1.0,
                  ),
                  boxShadow: active
                      ? <BoxShadow>[
                          BoxShadow(
                            color: battalion.themeColor.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: battalion.themeColor.withValues(alpha: active ? 0.25 : 0.1),
                        border: Border.all(
                          color: battalion.themeColor.withValues(alpha: active ? 0.8 : 0.3),
                        ),
                      ),
                      child: Icon(
                        battalion.icon,
                        size: 20,
                        color: active ? battalion.themeColor : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                battalion.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : Colors.white60,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.white10,
                                ),
                                child: Text(
                                  battalion.codeName,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${battalion.vectorName} · ${battalion.role}',
                            style: TextStyle(
                              fontSize: 10,
                              color: active ? Colors.white70 : Colors.white30,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Text(
                                '⚔️ ${NumberFormat('#,###').format(battalion.basePower)} Güç',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: active ? AppColors.liquidGold : Colors.white38,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '🛡️ ${battalion.troops} Asker',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: active
                            ? battalion.themeColor.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: active ? battalion.themeColor : Colors.white24,
                        ),
                      ),
                      child: Text(
                        active ? 'HÜCUMDA' : 'İHTİYAT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: active ? Colors.white : Colors.white38,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSiegeWeaponBatterySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const WarSectionHeader(
          title: 'KUŞATMA ARTİLERİSİ & TOPÇU BATARYASI',
          subtitle: 'Hisar kapı ve surlarına kinetik / arkana salvosu gönderin',
          accent: AppColors.coralFlare,
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double cardWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _siegeWeapons.map((_SiegeWeapon weapon) {
                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF141724),
                      border: Border.all(
                        color: weapon.accentColor.withValues(alpha: weapon.isFiring ? 0.9 : 0.35),
                        width: weapon.isFiring ? 1.6 : 1.0,
                      ),
                      boxShadow: weapon.isFiring
                          ? <BoxShadow>[
                              BoxShadow(
                                color: weapon.accentColor.withValues(alpha: 0.4),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(weapon.icon, size: 18, color: weapon.accentColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                weapon.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hedef: ${weapon.targetPart}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hasar: ~${NumberFormat('#,###').format(weapon.minDamage)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: weapon.accentColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: weapon.isFiring ? null : () => _fireSiegeWeapon(weapon),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: weapon.accentColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              weapon.isFiring ? 'ATEŞLENDİ!' : 'ATEŞLE',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSiegeTacticsSimulator(TerritoryAttackPreview p) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showSiegeTactics = !_showSiegeTactics);
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.military_tech_rounded, size: 18, color: AppColors.liquidGold),
                      SizedBox(width: 8),
                      Text(
                        '⚔️ KUŞATMA TATBİKATI & SAVAŞ SİMÜLATÖRÜ',
                        style: TextStyle(
                          color: AppColors.liquidGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showSiegeTactics ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_showSiegeTactics)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SiegeCombatViewport(
                territoryName: p.territoryName,
                attackPower: p.attackPower,
                defensePower: p.defensePower,
                pointsGained: 10,
                isVictory: p.winChancePct >= 50.0,
                attackerGuildName: p.attackerGuild.name,
                defenderGuildName: p.defenderGuild?.name ?? 'Savunan Lonca',
                autoPlay: false,
                height: 290,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBattlefieldLogFeed() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        color: const Color(0xFF0F121C),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.history_edu_rounded, size: 16, color: AppColors.liquidGold),
                  SizedBox(width: 6),
                  Text(
                    'CANLI ÇARPIŞMA TELGRAFI & BİLDİRİLER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text(
                '${_clashAlerts.length} Kayıt',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._clashAlerts.take(5).map((String log) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('• ', style: TextStyle(color: AppColors.liquidGold, fontSize: 11)),
                  Expanded(
                    child: Text(
                      log,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

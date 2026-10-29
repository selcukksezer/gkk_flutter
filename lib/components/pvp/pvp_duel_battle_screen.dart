import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/supabase_service.dart';
import '../../providers/pvp_invite_provider.dart';
import '../common/item_icon_view.dart';
import '../common/profile_avatar.dart';
import 'colosseum_arena_lighting.dart';
import 'pvp_combat_vfx_coordinator.dart';
import 'pvp_combat_vfx_overlay.dart';
import 'pvp_gladiator_3d_view.dart';

// ============================================================================
// PVP DÜELLO SAVAŞ EKRANI (2027 Aion 2 Obsidian-Glass & Arena Luminescence)
// Davet kabul edilince: loadout yükle → VS intro → dövüş → zafer/yenilgi.
// Sonuç backend'de zaten belli; buradaki akış sinematik sunum.
// ============================================================================

const Color _kBgTop = Color(0xFF070A12);
const Color _kBgBottom = Color(0xFF0F1524);
const Color _kBattleCrimson = Color(0xFFFF3366);
const Color _kCelestialGold = Color(0xFFE5C158);
const Color _kRed = _kBattleCrimson;
const Color _kBlue = Color(0xFF38BDF8);
const Color _kGold = _kCelestialGold;
const Color _kGreen = Color(0xFF10B981);
const Color _kCyanAether = Color(0xFF00E5FF);
const Color _kObsidianGlassBg = Color(0xD90B101D);
const Color _kObsidianGlassBorder = Color(0x33FFFFFF);

Color _rarityColor(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'legendary':
      return const Color(0xFFF59E0B);
    case 'epic':
      return const Color(0xFFA855F7);
    case 'rare':
      return const Color(0xFF3B82F6);
    case 'uncommon':
      return const Color(0xFF22C55E);
    default:
      return Colors.white38;
  }
}

/// 2027 Aion 2 Frosted Obsidian Glass Container
class _ObsidianGlassPanel extends StatelessWidget {
  const _ObsidianGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16.0,
    this.borderColor,
    this.backgroundColor,
    this.glowColor,
    this.glowRadius = 16.0,
    this.borderWidth = 1.0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? glowColor;
  final double glowRadius;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: glowColor != null
            ? <BoxShadow>[
                BoxShadow(
                  color: glowColor!,
                  blurRadius: glowRadius,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? _kObsidianGlassBg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? _kObsidianGlassBorder,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PvpDuelFighter {
  const PvpDuelFighter({
    required this.name,
    required this.level,
    required this.power,
    required this.attack,
    required this.defense,
    required this.rating,
    required this.wins,
    required this.losses,
    this.avatarUrl,
    this.items = const <PvpDuelItem>[],
  });

  final String name;
  final String? avatarUrl;
  final int level;
  final int power;
  final int attack;
  final int defense;
  final int rating;
  final int wins;
  final int losses;
  final List<PvpDuelItem> items;

  factory PvpDuelFighter.fromLoadout(Map<String, dynamic> json) {
    final Map<String, dynamic> p = json['player'] is Map
        ? Map<String, dynamic>.from(json['player'] as Map)
        : <String, dynamic>{};
    final String display = (p['display_name'] ?? '').toString();
    final List<PvpDuelItem> items = (json['items'] is List)
        ? (json['items'] as List)
            .whereType<Map>()
            .map((Map e) => PvpDuelItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <PvpDuelItem>[];
    return PvpDuelFighter(
      name: display.isNotEmpty
          ? display
          : (p['username'] ?? 'Oyuncu').toString(),
      avatarUrl: p['avatar_url']?.toString(),
      level: (p['level'] as num?)?.toInt() ?? 1,
      power: (p['power'] as num?)?.toInt() ?? 0,
      attack: (p['attack'] as num?)?.toInt() ?? 10,
      defense: (p['defense'] as num?)?.toInt() ?? 10,
      rating: (p['pvp_rating'] as num?)?.toInt() ?? 1000,
      wins: (p['pvp_wins'] as num?)?.toInt() ?? 0,
      losses: (p['pvp_losses'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }
}

class PvpDuelItem {
  const PvpDuelItem({
    required this.itemId,
    required this.name,
    required this.icon,
    required this.rarity,
    required this.enhancementLevel,
  });

  final String itemId;
  final String name;
  final String icon;
  final String rarity;
  final int enhancementLevel;

  factory PvpDuelItem.fromJson(Map<String, dynamic> json) {
    return PvpDuelItem(
      itemId: (json['item_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      rarity: (json['rarity'] ?? 'common').toString(),
      enhancementLevel: (json['enhancement_level'] as num?)?.toInt() ?? 0,
    );
  }
}

enum _DuelPhase { loading, intro, fight, result }

/// Tam ekran düello sunumu. [duel] respond_pvp_invite'ın ürettiği sonuç.
/// Hem kabul eden (target) hem davet eden (challenger) tarafta kullanılır;
/// [iAmChallenger] hangi perspektiften izlendiğini belirler.
class PvpDuelBattleScreen extends StatefulWidget {
  const PvpDuelBattleScreen({
    super.key,
    required this.duel,
    required this.myAuthId,
    required this.iAmChallenger,
    required this.wager,
    required this.opponentId,
    required this.opponentName,
    this.opponentAvatar,
    this.opponentLevel = 1,
    this.opponentPower = 0,
    this.opponentRating = 1000,
  });

  final Map<String, dynamic> duel;
  final String myAuthId;
  final bool iAmChallenger;
  final int wager;
  final String opponentId;
  final String opponentName;
  final String? opponentAvatar;
  final int opponentLevel;
  final int opponentPower;
  final int opponentRating;

  /// Kabul eden taraf (ben = target, rakip = challenger).
  static Future<void> show(
    BuildContext context, {
    required PvpInvite invite,
    required Map<String, dynamic> duel,
    required String myAuthId,
  }) {
    return _push(
      context,
      PvpDuelBattleScreen(
        duel: duel,
        myAuthId: myAuthId,
        iAmChallenger: false,
        wager: invite.wager,
        opponentId: invite.challengerId,
        opponentName: invite.challengerName,
        opponentAvatar: invite.challengerAvatar,
        opponentLevel: invite.challengerLevel,
        opponentPower: invite.challengerPower,
        opponentRating: invite.challengerRating,
      ),
    );
  }

  /// Davet eden taraf (ben = challenger, rakip = target).
  static Future<void> showForChallenger(
    BuildContext context, {
    required PvpDuelResultNotice notice,
    required String myAuthId,
  }) {
    return _push(
      context,
      PvpDuelBattleScreen(
        duel: notice.duel,
        myAuthId: myAuthId,
        iAmChallenger: true,
        wager: notice.wager,
        opponentId: notice.opponentId,
        opponentName: notice.opponentName,
        opponentAvatar: notice.opponentAvatar,
        opponentLevel: notice.opponentLevel,
        opponentPower: notice.opponentPower,
        opponentRating: notice.opponentRating,
      ),
    );
  }

  static Future<void> _push(BuildContext context, PvpDuelBattleScreen screen) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, Animation<double> a1, Animation<double> a2) => screen,
        transitionsBuilder:
            (_, Animation<double> anim, Animation<double> a2, Widget child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  State<PvpDuelBattleScreen> createState() => _PvpDuelBattleScreenState();
}

class _PvpDuelBattleScreenState extends State<PvpDuelBattleScreen>
    with TickerProviderStateMixin {
  _DuelPhase _phase = _DuelPhase.loading;
  PvpDuelFighter? _opponent;
  PvpDuelFighter? _me;

  late final AnimationController _introCtrl;
  late final AnimationController _fxCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _resultCtrl;
  late final AnimationController _countdownRingCtrl;
  late final PvpCombatVfxCoordinator _vfx;

  // Dövüş ve Telemetri Durumu
  double _hpOpponent = 1.0;
  double _hpMe = 1.0;
  double _ghostHpOpponent = 1.0;
  double _ghostHpMe = 1.0;
  final List<String> _log = <String>[];
  Timer? _fightTimer;
  Timer? _battleClockTimer;
  int _battleElapsedSeconds = 0;
  int _countdownSeconds = 3;
  int _hitIndex = 0;
  late List<_DuelHit> _hits;
  bool _flashLeft = false;
  bool _flashRight = false;
  GladiatorStance _meStance = GladiatorStance.idle;
  GladiatorStance _opponentStance = GladiatorStance.idle;

  final math.Random _rng = math.Random();

  bool get _iWon => widget.iAmChallenger
      ? widget.duel['challenger_won'] == true
      : widget.duel['challenger_won'] != true;
  int get _wager => (widget.duel['wager'] as num?)?.toInt() ?? widget.wager;
  int get _netWin => (widget.duel['net_win'] as num?)?.toInt() ?? 0;
  int get _nemesisRevengeGold =>
      (widget.duel['nemesis_revenge_gold'] as num?)?.toInt() ?? 0;
  int get _myRatingChange => widget.iAmChallenger
      ? (widget.duel['challenger_rating_change'] as num?)?.toInt() ?? 0
      : (widget.duel['target_rating_change'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _fxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _countdownRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _vfx = PvpCombatVfxCoordinator();
    _fxCtrl.addListener(_onVfxTick);
    _loadFighters();
  }

  void _onVfxTick() {
    _vfx.update(0.016);
    if (mounted && _phase == _DuelPhase.fight) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _fightTimer?.cancel();
    _battleClockTimer?.cancel();
    _fxCtrl.removeListener(_onVfxTick);
    _vfx.dispose();
    _introCtrl.dispose();
    _fxCtrl.dispose();
    _shakeCtrl.dispose();
    _resultCtrl.dispose();
    _countdownRingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFighters() async {
    Map<String, dynamic>? ch;
    Map<String, dynamic>? me;
    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        SupabaseService.client.rpc('get_pvp_loadout', params: <String, dynamic>{
          'p_auth_id': widget.opponentId,
        }),
        SupabaseService.client.rpc('get_pvp_loadout', params: <String, dynamic>{
          'p_auth_id': widget.myAuthId,
        }),
      ]);
      if (results[0] is Map) ch = Map<String, dynamic>.from(results[0] as Map);
      if (results[1] is Map) me = Map<String, dynamic>.from(results[1] as Map);
    } catch (_) {
      // RPC düşerse davet verisiyle devam.
    }
    if (!mounted) return;

    setState(() {
      _opponent = (ch != null && ch['success'] == true)
          ? PvpDuelFighter.fromLoadout(ch)
          : PvpDuelFighter(
              name: widget.opponentName,
              avatarUrl: widget.opponentAvatar,
              level: widget.opponentLevel,
              power: widget.opponentPower,
              attack: 10,
              defense: 10,
              rating: widget.opponentRating,
              wins: 0,
              losses: 0,
            );
      _me = (me != null && me['success'] == true)
          ? PvpDuelFighter.fromLoadout(me)
          : const PvpDuelFighter(
              name: 'Sen',
              level: 1,
              power: 0,
              attack: 10,
              defense: 10,
              rating: 1000,
              wins: 0,
              losses: 0,
            );
      _phase = _DuelPhase.intro;
      _countdownSeconds = 3;
    });
    HapticFeedback.mediumImpact();
    _introCtrl.forward();

    // Kartların sahneye oturmasını bekle
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    // 2027 Aion 2 Düello Geri Sayım Halkası (3... 2... 1... SAVAŞ!)
    for (int sec = 3; sec >= 1; sec--) {
      if (!mounted) return;
      setState(() {
        _countdownSeconds = sec;
      });
      HapticFeedback.selectionClick();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    if (!mounted) return;
    setState(() {
      _countdownSeconds = 0; // 0 = SAVAŞ! / ENGAGE!
    });
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _startFight();
  }

  // ── Dövüş simülasyonu (sonuç belli, sunum rastgele) ───────────────────────
  void _startFight() {
    _hits = _buildHitScript();
    _battleElapsedSeconds = 0;
    _hpOpponent = 1.0;
    _hpMe = 1.0;
    _ghostHpOpponent = 1.0;
    _ghostHpMe = 1.0;
    setState(() {
      _phase = _DuelPhase.fight;
      _meStance = GladiatorStance.combatReady;
      _opponentStance = GladiatorStance.combatReady;
    });
    HapticFeedback.heavyImpact();

    // Savaş Zamanlayıcısı (Battle Timer)
    _battleClockTimer?.cancel();
    _battleClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _phase == _DuelPhase.fight) {
        setState(() {
          _battleElapsedSeconds++;
        });
      }
    });

    _fightTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      _applyNextHit();
    });
  }

  List<_DuelHit> _buildHitScript() {
    // 8 vuruş: kaybeden 0'a iner, kazanan %20-55 arasında kalır.
    final bool opponentWins = !_iWon;
    final double winnerFinal = 0.20 + _rng.nextDouble() * 0.35;
    const int totalHits = 8;
    final List<_DuelHit> hits = <_DuelHit>[];

    // Kaybedenin aldığı toplam hasar 1.0, kazananın 1-winnerFinal.
    final List<double> loserDmg = _splitDamage(1.0, 5);
    final List<double> winnerDmg = _splitDamage(1.0 - winnerFinal, 3);

    int li = 0;
    int wi = 0;
    for (int i = 0; i < totalHits; i++) {
      // Sıra karışık ama kaybeden daha çok yer.
      final bool hitLoser = wi >= winnerDmg.length ||
          (li < loserDmg.length && (i % 3 != 2));
      final bool isCrit = _rng.nextDouble() < 0.28;
      final bool isParry = !isCrit && _rng.nextDouble() < 0.20;
      final PvpWeaponTrailType weapon = (i % 2 == 0)
          ? PvpWeaponTrailType.greatsword
          : PvpWeaponTrailType.dualBlades;

      if (hitLoser && li < loserDmg.length) {
        hits.add(_DuelHit(
          targetIsOpponent: !opponentWins,
          damage: loserDmg[li++],
          crit: isCrit,
          isParried: isParry,
          weaponType: weapon,
        ));
      } else if (wi < winnerDmg.length) {
        hits.add(_DuelHit(
          targetIsOpponent: opponentWins,
          damage: winnerDmg[wi++],
          crit: isCrit,
          isParried: isParry,
          weaponType: weapon,
        ));
      }
    }
    return hits;
  }

  List<double> _splitDamage(double total, int parts) {
    final List<double> weights =
        List<double>.generate(parts, (_) => 0.5 + _rng.nextDouble());
    final double sum = weights.fold(0, (double a, double b) => a + b);
    return weights.map((double w) => total * w / sum).toList(growable: false);
  }

  void _applyNextHit() {
    if (!mounted) return;
    if (_hitIndex >= _hits.length) {
      _fightTimer?.cancel();
      _battleClockTimer?.cancel();
      _finishFight();
      return;
    }
    final _DuelHit hit = _hits[_hitIndex++];
    final String attacker =
        hit.targetIsOpponent ? (_me?.name ?? 'Sen') : (_opponent?.name ?? 'Rakip');
    final String target =
        hit.targetIsOpponent ? (_opponent?.name ?? 'Rakip') : (_me?.name ?? 'Sen');
    final int shownDmg = (hit.damage * 900 + _rng.nextInt(80)).round();

    // Tactile Haptic Feedback
    if (hit.crit) {
      HapticFeedback.heavyImpact();
    } else if (hit.isParried) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() {
      if (hit.targetIsOpponent) {
        _meStance = GladiatorStance.attacking;
        _opponentStance = GladiatorStance.hitReact;
        _hpOpponent = (_hpOpponent - hit.damage).clamp(0.0, 1.0);
        _flashLeft = true;
      } else {
        _opponentStance = GladiatorStance.attacking;
        _meStance = GladiatorStance.hitReact;
        _hpMe = (_hpMe - hit.damage).clamp(0.0, 1.0);
        _flashRight = true;
      }
      _log.insert(
        0,
        hit.crit
            ? '💥 $attacker KRİTİK vurdu! $target -$shownDmg'
            : (hit.isParried
                ? '⚡ $target SAVUŞTURDU! -$shownDmg'
                : '⚔️ $attacker saldırdı: $target -$shownDmg'),
      );
      if (_log.length > 5) _log.removeLast();
    });

    // Ghost Bar yakalama gecikmesi
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _phase == _DuelPhase.fight) {
        setState(() {
          _ghostHpOpponent = _hpOpponent;
          _ghostHpMe = _hpMe;
        });
      }
    });

    // Wire ALL 9 Combat VFX modules:
    // Positions: opponent (left ~100, 190), player me (right ~280, 190)
    final Offset attackerPos =
        hit.targetIsOpponent ? const Offset(280, 190) : const Offset(100, 190);
    final Offset defenderPos =
        hit.targetIsOpponent ? const Offset(100, 190) : const Offset(280, 190);

    // 4. Weapon Ribbon Trails
    _vfx.triggerWeaponSwing(
      attackerIsMe: hit.targetIsOpponent,
      attackerPos: attackerPos,
      defenderPos: defenderPos,
      weaponType: hit.weaponType,
      isHeavy: hit.crit,
    );

    // 1-3, 5-9: Camera Shake, Hit-Stop, Rim Flash, Decals, Particles, Haptics, Damage Numbers, Knockback & Stun
    _vfx.triggerHitImpact(
      targetIsOpponent: hit.targetIsOpponent,
      damageValue: shownDmg.toDouble(),
      isCritical: hit.crit,
      impactPoint: defenderPos,
      isParried: hit.isParried,
      isBlocked: hit.isBlocked,
      isStun: hit.crit && shownDmg > 350,
    );

    _shakeCtrl.forward(from: 0);
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (mounted && _phase == _DuelPhase.fight) {
        setState(() {
          _flashLeft = false;
          _flashRight = false;
          _meStance = GladiatorStance.combatReady;
          _opponentStance = GladiatorStance.combatReady;
        });
      }
    });
  }

  Future<void> _finishFight() async {
    _battleClockTimer?.cancel();
    _fightTimer?.cancel();

    // Son darbe: kaybeden 0'a sabitlenir.
    setState(() {
      if (_iWon) {
        _hpOpponent = 0;
        _ghostHpOpponent = 0;
        _meStance = GladiatorStance.victory;
        _opponentStance = GladiatorStance.defeated;
      } else {
        _hpMe = 0;
        _ghostHpMe = 0;
        _meStance = GladiatorStance.defeated;
        _opponentStance = GladiatorStance.victory;
      }
      _log.insert(0, _iWon ? '🏆 Son darbe! Rakip yere düştü.' : '💀 Yere düştün...');
    });

    // Lethal finisher: explosive shock shake, 50ms freeze, blood pool, lethal popup, haptics
    final Offset fatalPos =
        _iWon ? const Offset(100, 190) : const Offset(280, 190);
    _vfx.triggerLethalFinisher(
      targetIsOpponent: _iWon,
      impactPoint: fatalPos,
    );

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _phase = _DuelPhase.result);
    HapticFeedback.heavyImpact();
    _resultCtrl.forward(from: 0);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_kBgTop, _kBgBottom],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Arka plan: Dinamik Aion 2 PvP Koloseum Işıklandırması & Gladyatör Gölgeleri
            AnimatedBuilder(
              animation: _fxCtrl,
              builder: (BuildContext ctx, Widget? child) => CustomPaint(
                painter: _DuelBackdropPainter(
                  t: _fxCtrl.value,
                  flashLeft: _flashLeft,
                  flashRight: _flashRight,
                  phase: _phase,
                ),
              ),
            ),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: switch (_phase) {
                  _DuelPhase.loading => _buildLoading(),
                  _DuelPhase.intro => _buildIntro(),
                  _DuelPhase.fight => _buildFight(),
                  _DuelPhase.result => _buildResult(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      key: const ValueKey<String>('loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(color: _kGold, strokeWidth: 2),
          const SizedBox(height: 16),
          Text(
            'DÜELLO HAZIRLANIYOR...',
            style: TextStyle(
              color: _kGold.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── INTRO: Obsidian-Glass VS & Duel Countdown Ring ────────────────────────
  Widget _buildIntro() {
    return AnimatedBuilder(
      key: const ValueKey<String>('intro'),
      animation: Listenable.merge(<Listenable>[_introCtrl, _countdownRingCtrl]),
      builder: (BuildContext context, _) {
        final double t = _introCtrl.value;
        final double slide = Curves.easeOutCubic.transform((t / 0.45).clamp(0, 1));
        final double vsPop = Curves.elasticOut
            .transform(((t - 0.4) / 0.4).clamp(0, 1));
        final double statsIn = ((t - 0.55) / 0.45).clamp(0, 1);

        return Column(
          children: <Widget>[
            const SizedBox(height: 12),
            // Obsidian-Glass Wager Capsule with Celestial Gold Luminescence
            _ObsidianGlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              borderRadius: 20,
              borderColor: _kCelestialGold.withValues(alpha: 0.5),
              glowColor: _kCelestialGold.withValues(alpha: 0.2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    widget.wager > 0 ? '💰' : '🤝',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.wager > 0
                        ? '${widget.wager} ALTIN BAHİSLİ DÜELLO'
                        : 'DOSTLUK DÜELLOSU',
                    style: const TextStyle(
                      color: _kCelestialGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Split VS Cards
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Transform.translate(
                          offset: Offset(-300 * (1 - slide), 0),
                          child: _fighterCard(
                            _opponent!,
                            accent: _kBattleCrimson,
                            statsT: statsIn,
                            alignRight: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                      Expanded(
                        child: Transform.translate(
                          offset: Offset(300 * (1 - slide), 0),
                          child: _fighterCard(
                            _me!,
                            accent: _kCelestialGold,
                            statsT: statsIn,
                            alignRight: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Centered Duel Countdown Ring
                  Center(
                    child: _DuelCountdownRing(
                      seconds: _countdownSeconds,
                      rotationValue: _countdownRingCtrl.value,
                      scaleValue: vsPop,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Opacity(
                opacity: statsIn,
                child: Text(
                  _countdownSeconds == 0
                      ? '⚔️ DÜELLO BAŞLADI!'
                      : 'ARENA PROTOKOLÜ DEVREDE • GERİ SAYIM',
                  style: TextStyle(
                    color: _countdownSeconds == 0
                        ? _kBattleCrimson
                        : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fighterCard(
    PvpDuelFighter f, {
    required Color accent,
    required double statsT,
    required bool alignRight,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: alignRight ? 0 : 8,
        right: alignRight ? 8 : 0,
      ),
      child: _ObsidianGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        borderRadius: 18,
        borderColor: accent.withValues(alpha: 0.45),
        glowColor: accent.withValues(alpha: 0.18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.55),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ProfileAvatar(size: 74, avatarUrl: f.avatarUrl),
            ),
            const SizedBox(height: 8),
            Text(
              f.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Lv.${f.level} · 🏆${f.rating}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: statsT,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - statsT)),
                child: Column(
                  children: <Widget>[
                    _statRow('⚡ Güç', f.power, accent, statsT),
                    _statRow('⚔️ Saldırı', f.attack, accent, statsT),
                    _statRow('🛡️ Savunma', f.defense, accent, statsT),
                    _statRow('W/L', 0, accent, statsT,
                        textOverride: '${f.wins} / ${f.losses}'),
                    const SizedBox(height: 6),
                    if (f.items.isNotEmpty) _itemsRow(f.items),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, int value, Color accent, double t,
      {String? textOverride}) {
    final int shown = (value * t).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 6),
          Text(
            textOverride ?? '$shown',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsRow(List<PvpDuelItem> items) {
    final List<PvpDuelItem> shown = items.take(6).toList(growable: false);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 5,
      runSpacing: 5,
      children: shown.map((PvpDuelItem it) {
        final Color rc = _rarityColor(it.rarity);
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rc.withValues(alpha: 0.7)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: rc.withValues(alpha: 0.25), blurRadius: 8),
            ],
          ),
          child: Stack(
            children: <Widget>[
              Center(
                child: ItemIconView(
                  iconValue: it.icon,
                  itemId: it.itemId,
                  size: 22,
                ),
              ),
              if (it.enhancementLevel > 0)
                Positioned(
                  right: 1,
                  top: 0,
                  child: Text(
                    '+${it.enhancementLevel}',
                    style: const TextStyle(
                      color: _kGold,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  // ── FIGHT: 2027 Aion 2 Obsidian-Glass Split VS HUD + Telemetry ───────────
  Widget _buildFight() {
    return PvpCombatVfxStage(
      key: const ValueKey<String>('fight'),
      coordinator: _vfx,
      child: AnimatedBuilder(
        animation: _shakeCtrl,
        builder: (BuildContext context, Widget? child) {
          final double s = math.sin(_shakeCtrl.value * math.pi * 5) *
              6 *
              (1 - _shakeCtrl.value);
          return Transform.translate(offset: Offset(s, 0), child: child);
        },
        child: Column(
          children: <Widget>[
            // 1. Top Split VS HUD in Obsidian Glass
            _buildTopFightHud(),

            // 2. Center 3D Gladiator Arena Stage
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Expanded(
                        child: PvpFighterVfxWrapper(
                          reaction: _vfx.opponentReaction,
                          rimFlashController: _vfx.opponentRimFlash,
                          child: _fightGladiatorSide(
                            _opponent!,
                            accent: _kBattleCrimson,
                            flash: _flashLeft,
                            stance: _opponentStance,
                            facingRight: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PvpFighterVfxWrapper(
                          reaction: _vfx.meReaction,
                          rimFlashController: _vfx.meRimFlash,
                          child: _fightGladiatorSide(
                            _me!,
                            accent: _kCelestialGold,
                            flash: _flashRight,
                            stance: _meStance,
                            facingRight: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Bottom Obsidian-Glass Combat Telemetry Console
            _buildBottomCombatConsole(),
          ],
        ),
      ),
    );
  }

  /// Top Split VS HUD in Obsidian Glass with Health Telemetry & Battle Timer
  Widget _buildTopFightHud() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: _ObsidianGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderRadius: 14,
        borderColor: Colors.white.withValues(alpha: 0.18),
        child: Row(
          children: <Widget>[
            // Opponent Telemetry Module
            Expanded(
              child: Row(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _kBattleCrimson.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ProfileAvatar(size: 34, avatarUrl: _opponent?.avatarUrl),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _opponent?.name ?? 'Rakip',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _kBattleCrimson,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildDynamicHealthBar(
                          currentHp: _hpOpponent,
                          ghostHp: _ghostHpOpponent,
                          accentColor: _kBattleCrimson,
                          isOpponent: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Center Battle Timer Capsule
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildBattleTimerCapsule(),
            ),
            // Player (Me) Telemetry Module
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          _me?.name ?? 'Sen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _kCelestialGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildDynamicHealthBar(
                          currentHp: _hpMe,
                          ghostHp: _ghostHpMe,
                          accentColor: _kCelestialGold,
                          isOpponent: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _kCelestialGold.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ProfileAvatar(size: 34, avatarUrl: _me?.avatarUrl),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2027 Aion 2 Battle Timer Capsule with Pulsing Combat Indicator
  Widget _buildBattleTimerCapsule() {
    final String formattedTime =
        '00:${_battleElapsedSeconds.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _kCelestialGold.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kCelestialGold.withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Pulsing live indicator dot
              AnimatedBuilder(
                animation: _countdownRingCtrl,
                builder: (BuildContext context, _) => Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kBattleCrimson.withValues(
                      alpha: 0.4 +
                          0.6 * math.sin(_countdownRingCtrl.value * math.pi),
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: _kBattleCrimson,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                formattedTime,
                style: const TextStyle(
                  color: _kCelestialGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          const Text(
            'VS',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Dynamic Health Telemetry Gauge with Numeric Readout, Lagging Ghost Bar, and Critical Alert
  Widget _buildDynamicHealthBar({
    required double currentHp,
    required double ghostHp,
    required Color accentColor,
    required bool isOpponent,
  }) {
    final bool isCritical = currentHp <= 0.25 && currentHp > 0.0;
    return Column(
      crossAxisAlignment:
          isOpponent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: <Widget>[
        // Numeric telemetry readout with Critical Alert
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isOpponent ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: <Widget>[
            if (isCritical)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kBattleCrimson.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _kBattleCrimson,
                      width: 0.6,
                    ),
                  ),
                  child: const Text(
                    '⚠️ KRİTİK',
                    style: TextStyle(
                      color: _kBattleCrimson,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            Text(
              '${(currentHp * 1000).round()} HP',
              style: TextStyle(
                color: isCritical ? _kBattleCrimson : accentColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${(currentHp * 100).round()}%',
              style: TextStyle(
                color: isCritical ? _kBattleCrimson : Colors.white70,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Glassmorphic Health Bar Track with Critical Glow
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isCritical
                  ? _kBattleCrimson.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.15),
              width: isCritical ? 1.0 : 0.8,
            ),
            boxShadow: isCritical
                ? <BoxShadow>[
                    BoxShadow(
                      color: _kBattleCrimson.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              alignment:
                  isOpponent ? Alignment.centerLeft : Alignment.centerRight,
              children: <Widget>[
                // Ghost bar (lagging damage receiver)
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  alignment:
                      isOpponent ? Alignment.centerLeft : Alignment.centerRight,
                  widthFactor: ghostHp.clamp(0.0, 1.0),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                // Active HP bar
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment:
                      isOpponent ? Alignment.centerLeft : Alignment.centerRight,
                  widthFactor: currentHp.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: currentHp > 0.4
                            ? <Color>[accentColor, _kGreen]
                            : <Color>[_kBattleCrimson, const Color(0xFFFF6B8B)],
                      ),
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

  /// Bottom Obsidian-Glass Combat Telemetry Console with SafeArea protection
  Widget _buildBottomCombatConsole() {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        math.max(8.0, bottomInset > 0 ? bottomInset * 0.4 : 8.0),
      ),
      child: _ObsidianGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 14,
        borderColor: Colors.white.withValues(alpha: 0.12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  '⚡ DÜELLO TELEMETRİSİ',
                  style: TextStyle(
                    color: _kCelestialGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  'TUR ${_hits.isNotEmpty ? _hitIndex : 0} / ${_hits.isNotEmpty ? _hits.length : 8}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 74),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(3, _log.length),
                itemBuilder: (BuildContext context, int index) {
                  final String line = _log[index];
                  final bool isLatest = index == 0;
                  final bool isCrit = line.contains('KRİTİK');
                  final bool isParry = line.contains('SAVUŞTURDU');
                  final Color tagColor = isCrit
                      ? _kBattleCrimson
                      : (isParry ? _kCyanAether : _kCelestialGold);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: tagColor.withValues(alpha: 0.5),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            isCrit
                                ? 'KRİTİK'
                                : (isParry ? 'SAVUŞTUR' : 'VURUŞ'),
                            style: TextStyle(
                              color: tagColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isLatest ? Colors.white : Colors.white54,
                              fontSize: isLatest ? 11.5 : 10.5,
                              fontWeight:
                                  isLatest ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Backward-compatible fight side method
  Widget _fightSide(
    PvpDuelFighter f, {
    required double hp,
    required Color accent,
    required bool flash,
    required GladiatorStance stance,
    required bool facingRight,
  }) {
    return _fightGladiatorSide(
      f,
      accent: accent,
      flash: flash,
      stance: stance,
      facingRight: facingRight,
    );
  }

  Widget _fightGladiatorSide(
    PvpDuelFighter f, {
    required Color accent,
    required bool flash,
    required GladiatorStance stance,
    required bool facingRight,
  }) {
    // Resolve equipped weapon from items
    GladiatorWeapon weapon = GladiatorWeapon.claymore;
    for (final PvpDuelItem item in f.items) {
      final String n = item.name.toLowerCase();
      if (n.contains('balta') || n.contains('axe')) {
        weapon = GladiatorWeapon.battleaxe;
        break;
      } else if (n.contains('hançer') || n.contains('dagger') || n.contains('bıçak')) {
        weapon = GladiatorWeapon.dagger;
        break;
      } else if (n.contains('altın') || n.contains('gold')) {
        weapon = GladiatorWeapon.goldenSword;
        break;
      } else if (n.contains('aion') || n.contains('efsun') || n.contains('dark')) {
        weapon = GladiatorWeapon.darkSword;
        break;
      }
    }

    // Resolve gladiator archetype
    GladiatorClass charClass = GladiatorClass.knight;
    if (f.power > 3000) {
      charClass = GladiatorClass.barbarian;
    } else if (f.level > 15) {
      charClass = GladiatorClass.soldier;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Genuine 3D Gladiator combatant with real .glb models & stances
              PvpGladiator3dView(
                gladiatorClass: charClass,
                weapon: weapon,
                stance: stance,
                accentColor: accent,
                facingRight: facingRight,
                interactiveRotation: false,
                size: const Size(140, 180),
              ),
              // Corner Player Avatar Badge
              Positioned(
                top: 0,
                left: facingRight ? 4 : null,
                right: facingRight ? null : 4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: flash
                            ? Colors.white.withValues(alpha: 0.85)
                            : accent.withValues(alpha: 0.45),
                        blurRadius: flash ? 24 : 12,
                        spreadRadius: flash ? 4 : 1,
                      ),
                    ],
                  ),
                  child: ProfileAvatar(size: 34, avatarUrl: f.avatarUrl),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Gladiator Archetype & Telemetry Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Text(
            '${charClass.name.toUpperCase()} · ATK ${f.attack}',
            style: TextStyle(
              color: accent.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  // ── RESULT: 2027 Aion 2 Obsidian-Glass Podium & Luminescence ──────────────
  Widget _buildResult() {
    final bool won = _iWon;
    final Color accent = won ? _kCelestialGold : _kBattleCrimson;

    return AnimatedBuilder(
      key: const ValueKey<String>('result'),
      animation: _resultCtrl,
      builder: (BuildContext context, _) {
        final double t = _resultCtrl.value;
        final double pop = Curves.elasticOut.transform((t / 0.6).clamp(0, 1));
        final double detailsT = ((t - 0.45) / 0.55).clamp(0, 1);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Celestial Gold rays on victory / Deep Crimson vignette on defeat
            if (won)
              AnimatedBuilder(
                animation: _fxCtrl,
                builder: (BuildContext ctx, Widget? child) => CustomPaint(
                  painter: _VictoryRaysPainter(
                    t: _fxCtrl.value,
                    intensity: t,
                  ),
                ),
              )
            else
              AnimatedBuilder(
                animation: _fxCtrl,
                builder: (BuildContext ctx, Widget? child) => CustomPaint(
                  painter: _DefeatVignettePainter(
                    t: _fxCtrl.value,
                    intensity: t,
                  ),
                ),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _ObsidianGlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  borderRadius: 24,
                  borderColor: accent.withValues(alpha: 0.5),
                  glowColor: accent.withValues(alpha: 0.25),
                  glowRadius: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Transform.scale(
                        scale: pop,
                        child: Text(
                          won ? '🏆' : '💀',
                          style: const TextStyle(fontSize: 68),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Transform.scale(
                        scale: pop,
                        child: Text(
                          won ? 'ZAFER!' : 'YENİLGİ',
                          style: TextStyle(
                            color: accent,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            shadows: <Shadow>[
                              Shadow(
                                color: accent.withValues(alpha: 0.7),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Opacity(
                        opacity: detailsT,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - detailsT)),
                          child: Column(
                            children: <Widget>[
                              Text(
                                won
                                    ? '${widget.opponentName} karşısında zafer kazandın!'
                                    : '${widget.opponentName} karşısında mağlup oldun.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_wager > 0)
                                _resultChip(
                                  won ? '+$_netWin altın' : '-$_wager altın',
                                  won ? _kCelestialGold : _kBattleCrimson,
                                ),
                              if (won && _nemesisRevengeGold > 0) ...<Widget>[
                                const SizedBox(height: 6),
                                _resultChip(
                                  'Nemesis intikam bonusu: +$_nemesisRevengeGold g',
                                  const Color(0xFFFFB800),
                                ),
                              ],
                              const SizedBox(height: 6),
                              _resultChip(
                                _myRatingChange >= 0
                                    ? '🏆 +$_myRatingChange rating'
                                    : '🏆 $_myRatingChange rating',
                                _myRatingChange >= 0 ? _kGreen : _kBattleCrimson,
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: 220,
                                child: FilledButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).pop();
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: won
                                        ? _kCelestialGold
                                        : const Color(0xFF334155),
                                    foregroundColor:
                                        won ? Colors.black : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: won ? 8 : 2,
                                    shadowColor: won
                                        ? _kCelestialGold.withValues(alpha: 0.5)
                                        : null,
                                  ),
                                  child: const Text(
                                    'DEVAM ET',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _resultChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 2027 Aion 2 Animated Duel Countdown Ring
class _DuelCountdownRing extends StatelessWidget {
  const _DuelCountdownRing({
    required this.seconds,
    required this.rotationValue,
    required this.scaleValue,
  });

  final int seconds;
  final double rotationValue;
  final double scaleValue;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scaleValue,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (seconds == 0 ? _kBattleCrimson : _kCelestialGold)
                  .withValues(alpha: 0.5),
              blurRadius: 28,
              spreadRadius: 3,
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kObsidianGlassBg,
                border: Border.all(
                  color: (seconds == 0 ? _kBattleCrimson : _kCelestialGold)
                      .withValues(alpha: 0.8),
                  width: 2.0,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Rotating energy arcs
                  CustomPaint(
                    size: const Size(82, 82),
                    painter: _CountdownArcPainter(
                      progress: rotationValue,
                      isEngage: seconds == 0,
                    ),
                  ),
                  // Center Content
                  if (seconds > 0)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (Widget child, Animation<double> anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text(
                        '$seconds',
                        key: ValueKey<int>(seconds),
                        style: const TextStyle(
                          color: _kCelestialGold,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          shadows: <Shadow>[
                            Shadow(
                              color: _kCelestialGold,
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '⚔️',
                          style: TextStyle(fontSize: 18),
                        ),
                        Text(
                          'DUEL',
                          style: TextStyle(
                            color: _kBattleCrimson,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: <Shadow>[
                              Shadow(
                                color: _kBattleCrimson,
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownArcPainter extends CustomPainter {
  const _CountdownArcPainter({
    required this.progress,
    required this.isEngage,
  });

  final double progress;
  final bool isEngage;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 4;

    final Paint goldArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = _kCelestialGold;

    final Paint crimsonArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = _kBattleCrimson;

    final double startAngle = progress * math.pi * 2;
    // Draw two rotating arcs
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      math.pi * 0.7,
      false,
      goldArc,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + math.pi,
      math.pi * 0.7,
      false,
      crimsonArc,
    );
  }

  @override
  bool shouldRepaint(_CountdownArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isEngage != isEngage;
}

class _DuelHit {
  const _DuelHit({
    required this.targetIsOpponent,
    required this.damage,
    required this.crit,
    this.isParried = false,
    this.isBlocked = false,
    this.isStun = false,
    this.weaponType = PvpWeaponTrailType.dualBlades,
  });

  final bool targetIsOpponent;
  final double damage;
  final bool crit;
  final bool isParried;
  final bool isBlocked;
  final bool isStun;
  final PvpWeaponTrailType weaponType;
}

// ── Painters ─────────────────────────────────────────────────────────────────

/// Aion 2 Dynamic PvP Colosseum Arena Backdrop with sunbeams, aether crystals,
/// directional shadow casting, and Battle Crimson / Celestial Gold luminescence.
class _DuelBackdropPainter extends CustomPainter {
  _DuelBackdropPainter({
    required this.t,
    this.flashLeft = false,
    this.flashRight = false,
    this.phase = _DuelPhase.fight,
  });

  final double t;
  final bool flashLeft;
  final bool flashRight;
  final _DuelPhase phase;

  @override
  void paint(Canvas canvas, Size size) {
    final ArenaLightingTheme theme = ArenaLightingTheme(
      name: 'Duel Colosseum',
      sunAzimuth: -0.75,
      sunElevation: 0.95,
      sunIntensity: 0.92,
      sunColor: _kCelestialGold,
      ambientColor: _kBgTop,
      crystalColor: _kCyanAether,
      secondaryCrystalColor: _kBattleCrimson,
      shadowColor: const Color(0xFF070A14),
      beamCount: 6,
      dustMoteCount: 28,
    );

    // Duelist shadow positions corresponding to the VS fighter cards & combat positions
    final List<GladiatorShadowSlot> slots = <GladiatorShadowSlot>[
      GladiatorShadowSlot(
        position: const Offset(0.25, 0.46),
        height: 75.0,
        width: 34.0,
        lungeOffset: Offset(
          math.sin(t * 2 * math.pi) * 2.0,
          math.cos(t * 2 * math.pi) * 1.0,
        ),
        hitShake: flashLeft ? 1.0 : 0.0,
      ),
      GladiatorShadowSlot(
        position: const Offset(0.75, 0.46),
        height: 75.0,
        width: 34.0,
        lungeOffset: Offset(
          -math.sin(t * 2 * math.pi) * 2.0,
          -math.cos(t * 2 * math.pi) * 1.0,
        ),
        hitShake: flashRight ? 1.0 : 0.0,
      ),
    ];

    final ColosseumArenaPainter arenaPainter = ColosseumArenaPainter(
      animationProgress: t,
      theme: theme,
      gladiatorSlots: slots,
      showColosseumWalls: true,
      showCrystals: true,
      showGodrays: true,
      showShadows: phase != _DuelPhase.loading,
      combatFlashIntensity: (flashLeft || flashRight) ? 0.75 : 0.0,
    );
    arenaPainter.paint(canvas, size);

    // 2027 Aion 2 Dynamic Duel Floor Arena Rune Luminescence
    if (phase == _DuelPhase.intro || phase == _DuelPhase.fight) {
      final Offset runeCenter = Offset(size.width * 0.5, size.height * 0.46);
      final double runeRadius = size.width * 0.38;

      // Radiant gold/crimson ground aura
      final Paint glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          runeCenter,
          runeRadius * 1.2,
          <Color>[
            _kCelestialGold.withValues(alpha: 0.14),
            _kBattleCrimson.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          <double>[0.0, 0.65, 1.0],
        );
      canvas.drawCircle(runeCenter, runeRadius * 1.2, glowPaint);

      // Rotating inner duel rune ring
      final Paint ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _kCelestialGold.withValues(alpha: 0.35);

      canvas.drawCircle(runeCenter, runeRadius * 0.9, ringPaint);

      // Segmented rune tick arcs
      final Paint arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = _kBattleCrimson.withValues(alpha: 0.4);

      final double rotation = t * math.pi * 0.4;
      for (int i = 0; i < 4; i++) {
        final double a = rotation + (i * math.pi / 2);
        canvas.drawArc(
          Rect.fromCircle(center: runeCenter, radius: runeRadius * 0.95),
          a,
          0.35,
          false,
          arcPaint,
        );
      }
    }

    // Ambient floating embers in Battle Crimson and Celestial Gold
    final math.Random rng = math.Random(7);
    final Paint ember = Paint();
    for (int i = 0; i < 22; i++) {
      final double baseX = rng.nextDouble() * size.width;
      final double speed = 0.4 + rng.nextDouble() * 0.6;
      final double p = ((t * speed + rng.nextDouble()) % 1.0);
      final double y = size.height * (1.05 - p * 1.1);
      final double x = baseX + math.sin((t * 2 + i) * math.pi) * 12;
      final double alpha = (1 - p) * 0.45;
      ember.color = (i.isEven ? _kCelestialGold : _kBattleCrimson)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 1.2 + rng.nextDouble() * 1.2, ember);
    }
  }

  @override
  bool shouldRepaint(_DuelBackdropPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.flashLeft != flashLeft ||
      oldDelegate.flashRight != flashRight ||
      oldDelegate.phase != phase;
}

/// Zafer ekranı dönen ışınlar (Celestial Gold).
class _VictoryRaysPainter extends CustomPainter {
  _VictoryRaysPainter({required this.t, required this.intensity});

  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height * 0.38);
    final double maxR = size.longestSide;
    const int rays = 14;
    final Paint p = Paint()
      ..color = _kCelestialGold.withValues(alpha: 0.08 * intensity);
    for (int i = 0; i < rays; i++) {
      final double a = (i / rays) * math.pi * 2 + t * math.pi * 2 * 0.15;
      final Path path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.05) * maxR, c.dy + math.sin(a - 0.05) * maxR)
        ..lineTo(c.dx + math.cos(a + 0.05) * maxR, c.dy + math.sin(a + 0.05) * maxR)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_VictoryRaysPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.intensity != intensity;
}

/// Yenilgi ekranı Battle Crimson colosseum vignette.
class _DefeatVignettePainter extends CustomPainter {
  _DefeatVignettePainter({required this.t, required this.intensity});

  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height * 0.42);
    final Paint p = Paint()
      ..shader = ui.Gradient.radial(
        c,
        size.longestSide * 0.65,
        <Color>[
          Colors.transparent,
          _kBattleCrimson.withValues(alpha: 0.18 * intensity),
          Colors.black.withValues(alpha: 0.72 * intensity),
        ],
        <double>[0.0, 0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & size, p);
  }

  @override
  bool shouldRepaint(_DefeatVignettePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.intensity != intensity;
}

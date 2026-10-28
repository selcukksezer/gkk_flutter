import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/supabase_service.dart';
import '../../providers/pvp_invite_provider.dart';
import '../common/item_icon_view.dart';
import '../common/profile_avatar.dart';
import 'pvp_colosseum_stage.dart';

// ============================================================================
// PVP DÜELLO SAVAŞ EKRANI
// Davet kabul edilince: loadout yükle → VS intro → dövüş → zafer/yenilgi.
// Sonuç backend'de zaten belli; buradaki akış sinematik sunum.
// ============================================================================

const Color _kBgTop = Color(0xFF0B0E17);
const Color _kBgBottom = Color(0xFF141B2A);
const Color _kRed = Color(0xFFEF4444);
const Color _kBlue = Color(0xFF3B82F6);
const Color _kGold = Color(0xFFF5C842);
const Color _kGreen = Color(0xFF22C55E);

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

  // Dövüş durumu
  double _hpOpponent = 1.0;
  double _hpMe = 1.0;
  final List<String> _log = <String>[];
  Timer? _fightTimer;
  int _hitIndex = 0;
  late List<_DuelHit> _hits;
  bool _flashLeft = false;
  bool _flashRight = false;
  int _exchangeSeq = 0;
  bool _leftIsAttacker = false;
  bool _lastHitCrit = false;
  int? _lastShownDmg;

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
    _loadFighters();
  }

  @override
  void dispose() {
    _fightTimer?.cancel();
    _introCtrl.dispose();
    _fxCtrl.dispose();
    _shakeCtrl.dispose();
    _resultCtrl.dispose();
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
    });
    HapticFeedback.mediumImpact();
    _introCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 3400));
    if (!mounted) return;
    _startFight();
  }

  // ── Dövüş simülasyonu (sonuç belli, sunum rastgele) ───────────────────────
  void _startFight() {
    _hits = _buildHitScript();
    setState(() => _phase = _DuelPhase.fight);
    HapticFeedback.heavyImpact();
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
      if (hitLoser && li < loserDmg.length) {
        hits.add(_DuelHit(
          targetIsOpponent: !opponentWins,
          damage: loserDmg[li++],
          crit: _rng.nextDouble() < 0.3,
        ));
      } else if (wi < winnerDmg.length) {
        hits.add(_DuelHit(
          targetIsOpponent: opponentWins,
          damage: winnerDmg[wi++],
          crit: _rng.nextDouble() < 0.2,
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
      _finishFight();
      return;
    }
    final _DuelHit hit = _hits[_hitIndex++];
    final String attacker =
        hit.targetIsOpponent ? (_me?.name ?? 'Sen') : (_opponent?.name ?? 'Rakip');
    final String target =
        hit.targetIsOpponent ? (_opponent?.name ?? 'Rakip') : (_me?.name ?? 'Sen');
    final int shownDmg = (hit.damage * 900 + _rng.nextInt(80)).round();
    _exchangeSeq++;
    _leftIsAttacker = !hit.targetIsOpponent;
    _lastHitCrit = hit.crit;
    _lastShownDmg = shownDmg;

    setState(() {
      if (hit.targetIsOpponent) {
        _hpOpponent = (_hpOpponent - hit.damage).clamp(0.0, 1.0);
        _flashLeft = true;
      } else {
        _hpMe = (_hpMe - hit.damage).clamp(0.0, 1.0);
        _flashRight = true;
      }
      _log.insert(
        0,
        hit.crit
            ? '💥 $attacker KRİTİK vurdu! $target -$shownDmg'
            : '⚔️ $attacker saldırdı: $target -$shownDmg',
      );
      if (_log.length > 5) _log.removeLast();
    });
    HapticFeedback.selectionClick();
    _shakeCtrl.forward(from: 0);
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) {
        setState(() {
          _flashLeft = false;
          _flashRight = false;
        });
      }
    });
  }

  void _skipToResult() {
    _fightTimer?.cancel();
    if (!mounted) return;
    setState(() {
      if (_iWon) {
        _hpOpponent = 0;
      } else {
        _hpMe = 0;
      }
      _phase = _DuelPhase.result;
    });
    _resultCtrl.forward(from: 0);
  }

  Widget _buildColosseumFight() {
    return Column(
      key: const ValueKey<String>('colosseum_fight'),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '⚔️ KOLEZYUM DÜELLOSU SÜRÜYOR',
                  style: TextStyle(
                    color: _kRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('pvp_duel_skip_btn'),
                onPressed: _skipToResult,
                icon: const Icon(Icons.fast_forward_rounded, size: 15),
                label: const Text('Atla'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PvpColosseumStage(
            height: 176,
            leftName: _opponent!.name,
            rightName: _me!.name,
            leftHp: _hpOpponent,
            rightHp: _hpMe,
            leftEnhancement: _opponent!.items.fold<int>(
              7,
              (int m, PvpDuelItem e) => math.max(m, e.enhancementLevel),
            ),
            rightEnhancement: _me!.items.fold<int>(
              7,
              (int m, PvpDuelItem e) => math.max(m, e.enhancementLevel),
            ),
            exchangeSeq: _exchangeSeq,
            leftIsAttacker: _leftIsAttacker,
            isCritical: _lastHitCrit,
            damageNumber: _lastShownDmg,
          ),
        ),
        Expanded(child: _buildFight()),
      ],
    );
  }

  Future<void> _finishFight() async {
    // Son darbe: kaybeden 0'a sabitlenir.
    setState(() {
      if (_iWon) {
        _hpOpponent = 0;
      } else {
        _hpMe = 0;
      }
      _log.insert(0, _iWon ? '🏆 Son darbe! Rakip yere düştü.' : '💀 Yere düştün...');
    });
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
            // Arka plan noktalar + hareketli emberler
            AnimatedBuilder(
              animation: _fxCtrl,
              builder: (BuildContext ctx, Widget? child) => CustomPaint(
                painter: _DuelBackdropPainter(t: _fxCtrl.value),
              ),
            ),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: switch (_phase) {
                  _DuelPhase.loading => _buildLoading(),
                  _DuelPhase.intro => _buildIntro(),
                  _DuelPhase.fight => _buildColosseumFight(),
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

  // ── INTRO: VS kartları ─────────────────────────────────────────────────────
  Widget _buildIntro() {
    return AnimatedBuilder(
      key: const ValueKey<String>('intro'),
      animation: _introCtrl,
      builder: (BuildContext context, _) {
        final double t = _introCtrl.value;
        final double slide = Curves.easeOutCubic.transform((t / 0.45).clamp(0, 1));
        final double vsPop = Curves.elasticOut
            .transform(((t - 0.4) / 0.4).clamp(0, 1));
        final double statsIn = ((t - 0.55) / 0.45).clamp(0, 1);

        return Column(
          children: <Widget>[
            const SizedBox(height: 12),
            Text(
              widget.wager > 0
                  ? '💰 ${widget.wager} ALTIN BAHİSLİ DÜELLO'
                  : '🤝 DOSTLUK DÜELLOSU',
              style: const TextStyle(
                color: _kGold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Transform.translate(
                          offset: Offset(-300 * (1 - slide), 0),
                          child: _fighterCard(
                            _opponent!,
                            accent: _kRed,
                            statsT: statsIn,
                            alignRight: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 60),
                      Expanded(
                        child: Transform.translate(
                          offset: Offset(300 * (1 - slide), 0),
                          child: _fighterCard(
                            _me!,
                            accent: _kBlue,
                            statsT: statsIn,
                            alignRight: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // VS merkez
                  Center(
                    child: Transform.scale(
                      scale: vsPop,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kBgTop,
                          border: Border.all(color: _kGold, width: 2),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _kGold.withValues(alpha: 0.5 * vsPop),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          'VS',
                          style: TextStyle(
                            color: _kGold,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Opacity(
                opacity: statsIn,
                child: const Text(
                  'SAVAŞ BAŞLIYOR...',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
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
        left: alignRight ? 0 : 12,
        right: alignRight ? 12 : 0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.55),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ProfileAvatar(size: 84, avatarUrl: f.avatarUrl),
          ),
          const SizedBox(height: 10),
          Text(
            f.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Lv.${f.level} · 🏆${f.rating}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
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
                  const SizedBox(height: 8),
                  if (f.items.isNotEmpty) _itemsRow(f.items),
                ],
              ),
            ),
          ),
        ],
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

  // ── FIGHT: HP barları + log ────────────────────────────────────────────────
  Widget _buildFight() {
    return AnimatedBuilder(
      key: const ValueKey<String>('fight'),
      animation: _shakeCtrl,
      builder: (BuildContext context, Widget? child) {
        final double s = math.sin(_shakeCtrl.value * math.pi * 5) *
            6 *
            (1 - _shakeCtrl.value);
        return Transform.translate(offset: Offset(s, 0), child: child);
      },
      child: Column(
        children: <Widget>[
          const SizedBox(height: 16),
          const Text(
            '⚔️ SAVAŞ SÜRÜYOR',
            style: TextStyle(
              color: _kRed,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _fightSide(
                    _opponent!,
                    hp: _hpOpponent,
                    accent: _kRed,
                    flash: _flashLeft,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '⚡',
                    style: TextStyle(fontSize: 26),
                  ),
                ),
                Expanded(
                  child: _fightSide(
                    _me!,
                    hp: _hpMe,
                    accent: _kBlue,
                    flash: _flashRight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Savaş logu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: _log
                    .map(
                      (String line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          line,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: line == _log.first
                                ? Colors.white
                                : Colors.white38,
                            fontSize: line == _log.first ? 13 : 11,
                            fontWeight: line == _log.first
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fightSide(
    PvpDuelFighter f, {
    required double hp,
    required Color accent,
    required bool flash,
  }) {
    return Column(
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: flash
                    ? Colors.white.withValues(alpha: 0.85)
                    : accent.withValues(alpha: 0.45),
                blurRadius: flash ? 34 : 20,
                spreadRadius: flash ? 6 : 1,
              ),
            ],
          ),
          child: ProfileAvatar(size: 64, avatarUrl: f.avatarUrl),
        ),
        const SizedBox(height: 8),
        Text(
          f.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        // HP bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: <Widget>[
              Container(height: 12, color: Colors.black45),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: hp,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        hp > 0.4 ? _kGreen : _kRed,
                        hp > 0.4
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(hp * 100).round()}%',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  // ── RESULT: zafer / yenilgi ───────────────────────────────────────────────
  Widget _buildResult() {
    final bool won = _iWon;
    final Color accent = won ? _kGold : _kRed;

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
            // Işınlar (zafer) / kararma (yenilgi)
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
              Container(color: Colors.black.withValues(alpha: 0.35 * t)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Transform.scale(
                    scale: pop,
                    child: Text(
                      won ? '🏆' : '💀',
                      style: const TextStyle(fontSize: 72),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Transform.scale(
                    scale: pop,
                    child: Text(
                      won ? 'ZAFER!' : 'YENİLGİ',
                      style: TextStyle(
                        color: accent,
                        fontSize: 42,
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
                  const SizedBox(height: 20),
                  Opacity(
                    opacity: detailsT,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - detailsT)),
                      child: Column(
                        children: <Widget>[
                          Text(
                            won
                                ? '${widget.opponentName} karşısında kazandın!'
                                : '${widget.opponentName} seni yendi.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_wager > 0)
                            _resultChip(
                              won ? '+$_netWin altın' : '-$_wager altın',
                              won ? _kGold : _kRed,
                            ),
                          if (won && _nemesisRevengeGold > 0) ...<Widget>[
                            const SizedBox(height: 6),
                            _resultChip(
                              'Nemesis intikam bonusu: +$_nemesisRevengeGold g',
                              const Color(0xFFFFB800), // Liquid Gold
                            ),
                          ],
                          const SizedBox(height: 6),
                          _resultChip(
                            _myRatingChange >= 0
                                ? '🏆 +$_myRatingChange rating'
                                : '🏆 $_myRatingChange rating',
                            _myRatingChange >= 0 ? _kGreen : _kRed,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: 200,
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    won ? _kGold : const Color(0xFF334155),
                                foregroundColor:
                                    won ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'DEVAM ET',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
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
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DuelHit {
  const _DuelHit({
    required this.targetIsOpponent,
    required this.damage,
    required this.crit,
  });

  final bool targetIsOpponent;
  final double damage;
  final bool crit;
}

// ── Painters ─────────────────────────────────────────────────────────────────

/// Sabit nokta deseni + yavaş yükselen emberler.
class _DuelBackdropPainter extends CustomPainter {
  _DuelBackdropPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dot = Paint()..color = Colors.white.withValues(alpha: 0.04);
    const double gap = 26;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }

    final math.Random rng = math.Random(7);
    final Paint ember = Paint();
    for (int i = 0; i < 22; i++) {
      final double baseX = rng.nextDouble() * size.width;
      final double speed = 0.4 + rng.nextDouble() * 0.6;
      final double phase = rng.nextDouble();
      final double p = ((t * speed + phase) % 1.0);
      final double y = size.height * (1.05 - p * 1.1);
      final double x =
          baseX + math.sin((t * 2 + phase) * math.pi * 2) * 14;
      final double alpha = (1 - p) * 0.35;
      ember.color = (i.isEven ? _kGold : _kRed).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 1.4 + rng.nextDouble(), ember);
    }
  }

  @override
  bool shouldRepaint(_DuelBackdropPainter oldDelegate) => oldDelegate.t != t;
}

/// Zafer ekranı dönen ışınlar.
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
      ..color = _kGold.withValues(alpha: 0.08 * intensity);
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

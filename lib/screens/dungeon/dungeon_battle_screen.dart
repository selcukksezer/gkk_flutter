import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/power_formula.dart';
import '../../models/dungeon_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'dungeon_item_utils.dart';
import 'dungeon_result_widgets.dart';
import 'dungeon_victory_effects.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

class DungeonBattleScreen extends ConsumerStatefulWidget {
  const DungeonBattleScreen({super.key});

  @override
  ConsumerState<DungeonBattleScreen> createState() => _DungeonBattleScreenState();
}

class _DungeonBattleScreenState extends ConsumerState<DungeonBattleScreen> {
  String _phase = 'idle';
  String _dungeonId = '';
  String _dungeonName = 'Zindan';
  int _zone = 1;
  int _energyCost = 0;
  bool _autoStart = false;
  int _countdown = 3;
  DungeonResult? _result;
  Timer? _countdownTimer;
  Timer? _logTimer;
  bool _paramsLoaded = false;
  int _logIndex = 0;
  final List<String> _battleLog = <String>[];

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _logTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paramsLoaded) return;
    _paramsLoaded = true;
    final Map<String, String> params = GoRouterState.of(context).uri.queryParameters;
    setState(() {
      _dungeonId = params['dungeon_id'] ?? '';
      _dungeonName = params['dungeon_name'] ?? 'Zindan';
      _zone = int.tryParse(params['zone'] ?? '') ?? 1;
      _energyCost = int.tryParse(params['energy_cost'] ?? '') ?? 0;
      _autoStart = params['auto'] == '1';
    });
    if (_autoStart && _dungeonId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
    }
  }

  void _resetForRetry() {
    _countdownTimer?.cancel();
    _logTimer?.cancel();
    setState(() {
      _result = null;
      _battleLog.clear();
      _logIndex = 0;
    });
    _startCountdown();
  }

  void _startCountdown() {
    final player = ref.read(playerProvider).profile;
    if (player == null) {
      AppMessenger.showError(context, 'Oyuncu bilgisi yüklenemedi.');
      context.pop();
      return;
    }
    if (_energyCost > 0 && player.energy < _energyCost) {
      AppMessenger.show(context, 'Enerji yetersiz.');
      context.pop();
      return;
    }

    setState(() {
      _phase = 'counting';
      _countdown = 3;
      _result = null;
      _battleLog.clear();
      _logIndex = 0;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        _startBattle();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _startBattle() async {
    final List<String> flavor = zoneFlavorLines(_zone);
    setState(() {
      _phase = 'fighting';
      _battleLog
        ..clear()
        ..addAll(flavor);
      _logIndex = 0;
    });

    _logTimer = Timer.periodic(const Duration(milliseconds: 650), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_logIndex < _battleLog.length - 1) {
        setState(() => _logIndex++);
      }
    });

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'attack_dungeon',
        params: <String, dynamic>{'p_dungeon_id': _dungeonId},
      );
      _logTimer?.cancel();

      if (!mounted) return;

      if (raw is Map) {
        final DungeonResult parsed =
            DungeonResult.fromJson(Map<String, dynamic>.from(raw));
        if ((parsed.error ?? '').isNotEmpty) {
          AppMessenger.showError(context, _mapError(parsed.error!));
          context.pop();
          return;
        }

        await ref.read(playerProvider.notifier).loadProfile();
        await ref.read(inventoryProvider.notifier).loadInventory(silent: true);

        if (!mounted) return;

        if (parsed.success) {
          if (parsed.isCritical) {
            _battleLog.add('Ezici bir vuruş!');
          } else {
            _battleLog.add('Düşmanı alt ettin!');
          }
        } else if (parsed.hospitalized) {
          _battleLog.add('Son vuruşta düştün...');
          _battleLog.add('Hastaneye kaldırılıyorsun.');
        } else {
          _battleLog.add('Son vuruşta düştün...');
          _battleLog.add('Bu sefer şans senden yana değildi.');
        }

        setState(() {
          _result = parsed;
          _logIndex = _battleLog.length - 1;
          _phase = parsed.success ? 'success' : 'failure';
        });

        if (parsed.inventoryFull) {
          AppMessenger.show(context, 'Envanter dolu! Bazı eşyalar alınamadı.');
        }
      } else {
        setState(() {
          _result = null;
          _phase = 'failure';
        });
      }
    } catch (e) {
      _logTimer?.cancel();
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Savaş başlatılamadı.'),
      );
      context.pop();
    }
  }

  String _mapError(String raw) {
    return userFacingErrorMessage(raw, fallback: 'Operasyon tamamlanamadı.');
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 dk';
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m dk';
    return '$h sa $m dk';
  }

  bool _canRetry() {
    final player = ref.read(playerProvider).profile;
    if (player == null) return false;
    if (_energyCost <= 0) return true;
    return player.energy >= _energyCost;
  }

  @override
  Widget build(BuildContext context) {
    Future<void> logoutHandler() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      appBar: GameTopBar(title: _dungeonName, onLogout: logoutHandler),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.dungeon, onLogout: logoutHandler),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildPhaseContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_phase) {
      case 'idle':
        return _buildIdlePhase();
      case 'counting':
        return _buildCountingPhase();
      case 'fighting':
        return _buildFightingPhase();
      case 'success':
        return _buildSuccessPhase();
      case 'failure':
        return _buildFailurePhase();
      default:
        return _buildIdlePhase();
    }
  }

  Widget _buildIdlePhase() {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              _dungeonName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Zindana saldırmak için butona bas.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startCountdown,
                icon: const Icon(Icons.sports_martial_arts),
                label: const Text('Saldır'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('← Geri Dön', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountingPhase() {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _countdown.toString(),
                key: ValueKey<int>(_countdown),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Hazırlan...', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildFightingPhase() {
    final List<String> visible = _battleLog.take(_logIndex + 1).toList();
    return SizedBox(
      height: 320,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('⚔️', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text('Savaş devam ediyor…', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ...visible.map(
            (String line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _buildSuccessPhase() {
    final DungeonResult? result = _result;
    if (result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DungeonVictoryPanel(
          gold: result.goldEarned,
          xp: result.xpEarned,
          items: result.itemDetails,
          isCritical: result.isCritical,
          isFirstClear: result.isFirstClear,
          milestoneRewards: result.milestoneRewards,
          rewardMultiplier: result.rewardMultiplier,
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Zindanlara Dön'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _canRetry() ? _resetForRetry : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDDB200),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Tekrar Dene', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFailurePhase() {
    final DungeonResult? result = _result;
    final bool hospitalized = result?.hospitalized == true;
    final String duration =
        _formatDuration(result?.hospitalDurationSeconds ?? 0);
    final int dungeonNum = parseDungeonNumber(_dungeonId);
    final List<String> notices = hospitalized
        ? <String>['Hastaneye düştün', 'Tedavi süresi: $duration']
        : dungeonNum <= 3
            ? <String>['Başarısız', 'Tekrar dene.']
            : <String>['Yenildin', 'Bu sefer şanssızdın, tekrar dene.'];

    final int hospitalCount =
        ref.read(playerProvider).profile?.hospitalLifetimeCount ?? 0;
    final bool canFree = canFreeHospitalDischarge(hospitalCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnimatedResultCard(
          child: DefeatCard(
            animation: const AlwaysStoppedAnimation<double>(1.0),
            notices: notices,
          ),
        ),
        if (hospitalized && canFree) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF166534).withValues(alpha: 0.2),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
            ),
            child: const Text(
              'İlk 2 düşüşte ücretsiz taburcu hakkın var.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF86EFAC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (hospitalized)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.hospital),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF991B1B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Hastane'),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('Geri Dön'),
              ),
            ),
            if (!hospitalized) ...<Widget>[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _canRetry() ? _resetForRetry : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tekrar Dene'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

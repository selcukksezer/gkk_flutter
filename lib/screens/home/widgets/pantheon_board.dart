import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../l10n/l10n.dart';

class _PantheonEntry {
  const _PantheonEntry({
    required this.rank,
    required this.username,
    required this.value,
    this.guild,
  });

  final int rank;
  final String username;
  final int value;
  final String? guild;
}

String _compactPower(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

class PantheonBoard extends StatefulWidget {
  const PantheonBoard({super.key});

  @override
  State<PantheonBoard> createState() => _PantheonBoardState();
}

class _PantheonBoardState extends State<PantheonBoard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  List<_PantheonEntry> _top3 = <_PantheonEntry>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
        throw StateError('Supabase hazir degil');
      }

      final dynamic result = await SupabaseService.client.rpc(
        'get_leaderboard',
        params: <String, dynamic>{
          'p_category': 'power',
          'p_limit': 3,
          'p_timeframe': 'alltime',
        },
      );

      if (!mounted) return;

      if (result is! List || result.isEmpty) {
        setState(() {
          _top3 = <_PantheonEntry>[];
          _loading = false;
        });
        return;
      }

      final List<_PantheonEntry> entries =
          result
              .whereType<Map>()
              .map((Map<dynamic, dynamic> raw) {
                final Map<String, dynamic> row = Map<String, dynamic>.from(raw);
                return _PantheonEntry(
                  rank: (row['rank'] as num?)?.toInt() ?? 0,
                  username: (row['username'] as String?) ?? '—',
                  value: (row['value'] as num?)?.toInt() ?? 0,
                  guild: row['guild'] as String?,
                );
              })
              .where((_PantheonEntry e) => e.rank > 0 && e.username.isNotEmpty)
              .toList()
            ..sort((a, b) => a.rank.compareTo(b.rank));

      if (!mounted) return;
      setState(() {
        _top3 = entries.take(3).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _top3 = <_PantheonEntry>[];
        _loading = false;
        _error = 'Siralama yuklenemedi';
      });
    }
  }

  _PantheonEntry? _entryForRank(int rank) {
    for (final _PantheonEntry entry in _top3) {
      if (entry.rank == rank) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () => context.push(AppRoutes.leaderboard),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.leaderboard_rounded,
                  color: AppColors.gold,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Siralama',
                        style: AppTextStyles.h3.copyWith(color: Colors.white),
                      ),
                      Text(
                        'Guc liderleri • canli',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Tumu',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_loading)
          const SizedBox(
            height: 320,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error != null)
          SizedBox(
            height: 180,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    _error!,
                    style: AppTextStyles.body.copyWith(color: Colors.white54),
                  ),
                  TextButton(
                    onPressed: _loadLeaderboard,
                    child: Text(context.l10n.tekrar_dene_2),
                  ),
                ],
              ),
            ),
          )
        else if (_top3.isEmpty)
          SizedBox(
            height: 180,
            child: Center(
              child: Text(
                'Henuz siralama verisi yok.',
                style: AppTextStyles.body.copyWith(color: Colors.white54),
              ),
            ),
          )
        else
          SizedBox(
            height: 320,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _buildPodiumColumn(
                      entry: _entryForRank(2),
                      rank: 2,
                      height: 140,
                      color: Colors.blueGrey.shade300,
                    ),
                    const SizedBox(width: 100),
                    _buildPodiumColumn(
                      entry: _entryForRank(3),
                      rank: 3,
                      height: 110,
                      color: Colors.brown.shade400,
                    ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final double glowIntensity =
                          10 + (_pulseController.value * 20);
                      return _buildPodiumColumn(
                        entry: _entryForRank(1),
                        rank: 1,
                        height: 180,
                        color: const Color(0xFFFFB800),
                        isGold: true,
                        glowIntensity: glowIntensity,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required _PantheonEntry? entry,
    required int rank,
    required double height,
    required Color color,
    bool isGold = false,
    double glowIntensity = 0,
  }) {
    final String name = entry?.username ?? '—';
    final String subtitle = entry == null
        ? ''
        : entry.guild != null && entry.guild!.isNotEmpty
        ? entry.guild!
        : '⚡ ${_compactPower(entry.value)}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        SizedBox(
          width: 96,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isGold ? color : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              shadows: isGold
                  ? <Shadow>[Shadow(color: color, blurRadius: 10)]
                  : null,
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          SizedBox(
            width: 96,
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isGold ? color.withValues(alpha: 0.85) : Colors.white38,
                fontSize: 10,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: <BoxShadow>[
              if (isGold)
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: glowIntensity,
                ),
            ],
            gradient: RadialGradient(
              colors: <Color>[color.withValues(alpha: 0.3), Colors.transparent],
            ),
          ),
          child: CircleAvatar(
            radius: isGold ? 35 : 30,
            backgroundColor: const Color(0xFF161E34),
            child: Icon(Icons.person, color: color, size: isGold ? 40 : 35),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                color.withValues(alpha: 0.8),
                color.withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

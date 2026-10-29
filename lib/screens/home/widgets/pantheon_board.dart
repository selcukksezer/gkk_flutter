import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/app_foreground_service.dart';
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
    this.avatarUrl,
    this.title,
  });

  final int rank;
  final String username;
  final int value;
  final String? guild;
  final String? avatarUrl;
  final String? title;
}

String _compactPower(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String _rankAvatarAsset(int rank, String? avatarUrl) {
  if (avatarUrl != null &&
      avatarUrl.isNotEmpty &&
      avatarUrl.startsWith('assets/')) {
    return avatarUrl;
  }
  switch (rank) {
    case 1:
      return 'assets/characters/savasci.png';
    case 2:
      return 'assets/characters/golge.png';
    case 3:
      return 'assets/characters/simyaci.png';
    default:
      return 'assets/profile/profil1.png';
  }
}

String _rankTierTitle(int rank) {
  switch (rank) {
    case 1:
      return 'Efsanevi Şampiyon';
    case 2:
      return 'Yıldız Muhafızı';
    case 3:
      return 'Kozmik Titan';
    default:
      return 'Seçkin Savaşçı';
  }
}

class PantheonBoard extends StatefulWidget {
  const PantheonBoard({super.key});

  @override
  State<PantheonBoard> createState() => _PantheonBoardState();
}

class _PantheonBoardState extends State<PantheonBoard>
    with SingleTickerProviderStateMixin, LifecycleAnimationPause {
  late AnimationController _pulseController;
  List<_PantheonEntry> _top3 = <_PantheonEntry>[];
  bool _loading = true;
  String? _error;

  @override
  AnimationController? get lifecycleAnimationController => _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (AppForegroundService.instance.isForeground) {
      _pulseController.repeat(reverse: true);
    }
    attachLifecycleAnimationPause();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    detachLifecycleAnimationPause();
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
        throw StateError('Supabase hazır değil');
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
                  avatarUrl: (row['avatar_url'] ?? row['avatar']) as String?,
                  title: row['title'] as String?,
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
        _error = 'Sıralama yüklenemedi';
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
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(0.0, -0.6),
                radius: 1.25,
                colors: <Color>[
                  Color(0xF5131C30),
                  Color(0xFA090D18),
                  Color(0xFD060912),
                ],
                stops: <double>[0.0, 0.65, 1.0],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.36),
                width: 1.3,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.72),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.10),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: 0.05),
                  blurRadius: 28,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                // Custom Celestial Frame Ornaments
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) => CustomPaint(
                        painter: _AionCelestialFramePainter(
                          accentColor: AppColors.liquidGold,
                          glowValue: _pulseController.value,
                        ),
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Card Header
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push(AppRoutes.leaderboard);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: <Color>[
                                      AppColors.liquidGold.withValues(alpha: 0.35),
                                      const Color(0xFF141E34),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.liquidGold.withValues(alpha: 0.75),
                                    width: 1.6,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.liquidGold.withValues(alpha: 0.45),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.military_tech_rounded,
                                  color: AppColors.liquidGold,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Text(
                                          'PANTHEON',
                                          style: AppTextStyles.h3.copyWith(
                                            color: Colors.white,
                                            letterSpacing: 1.6,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.liquidGold.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: AppColors.liquidGold.withValues(alpha: 0.55),
                                              width: 0.9,
                                            ),
                                          ),
                                          child: const Text(
                                            'TOP 3',
                                            style: TextStyle(
                                              color: AppColors.liquidGold,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        AnimatedBuilder(
                                          animation: _pulseController,
                                          builder: (context, _) => Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.success,
                                              boxShadow: <BoxShadow>[
                                                BoxShadow(
                                                  color: AppColors.success.withValues(
                                                    alpha: 0.5 + (_pulseController.value * 0.4),
                                                  ),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Efsaneler Kürsüsü • Canlı Güç Sıralaması',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      AppColors.accentCyan.withValues(alpha: 0.16),
                                      AppColors.spaceNavy.withValues(alpha: 0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.accentCyan.withValues(alpha: 0.55),
                                    width: 1.1,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.accentCyan.withValues(alpha: 0.20),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'Tümü',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.accentCyan,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: AppColors.accentCyan,
                                      size: 11,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_loading)
                        const SizedBox(
                          height: 240,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.liquidGold,
                              ),
                            ),
                          ),
                        )
                      else if (_error != null)
                        SizedBox(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.danger,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _loadLeaderboard();
                                  },
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                  ),
                                  label: Text(context.l10n.tekrar_dene_2),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.liquidGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_top3.isEmpty)
                        SizedBox(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.military_tech_outlined,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Henüz sıralama verisi yok.',
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.white54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _loadLeaderboard();
                                  },
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Yenile'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.accentCyan,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (
                            BuildContext context,
                            BoxConstraints constraints,
                          ) {
                            final double availableWidth = constraints.maxWidth;
                            final double centerWidth =
                                (availableWidth * 0.36).clamp(96.0, 120.0);
                            final double sideWidth =
                                ((availableWidth - centerWidth - 16) / 2).clamp(
                                  84.0,
                                  106.0,
                                );

                            return SizedBox(
                              height: 322,
                              width: availableWidth,
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  final double glowIntensity =
                                      10 + (_pulseController.value * 12);
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      // Rank 2: Silver (Left)
                                      SizedBox(
                                        width: sideWidth,
                                        child: _buildPodiumColumn(
                                          entry: _entryForRank(2),
                                          rank: 2,
                                          pedestalHeight: 126,
                                          avatarRadius: 26,
                                          color: const Color(0xFFC0D2E8),
                                          cardWidth: sideWidth,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Rank 1: Gold Champion (Center)
                                      SizedBox(
                                        width: centerWidth,
                                        child: _buildPodiumColumn(
                                          entry: _entryForRank(1),
                                          rank: 1,
                                          pedestalHeight: 162,
                                          avatarRadius: 32,
                                          color: const Color(0xFFFFB800),
                                          isGold: true,
                                          glowIntensity: glowIntensity,
                                          cardWidth: centerWidth,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Rank 3: Bronze (Right)
                                      SizedBox(
                                        width: sideWidth,
                                        child: _buildPodiumColumn(
                                          entry: _entryForRank(3),
                                          rank: 3,
                                          pedestalHeight: 98,
                                          avatarRadius: 24,
                                          color: const Color(0xFFCD7F32),
                                          cardWidth: sideWidth,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHeroDetailsModal(
    BuildContext context,
    _PantheonEntry? entry,
    int rank,
    Color rankColor,
  ) {
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('#$rank sırada henüz oyuncu yok.'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF161F33),
        ),
      );
      return;
    }

    final String avatarAsset = _rankAvatarAsset(rank, entry.avatarUrl);
    final String tierTitle = entry.title != null && entry.title!.isNotEmpty
        ? entry.title!
        : _rankTierTitle(rank);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xF5131C30),
                        Color(0xF80B111F),
                        Color(0xFA070B14),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: rankColor.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: rankColor.withValues(alpha: 0.25),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                      const BoxShadow(
                        color: Colors.black87,
                        blurRadius: 32,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Handle bar
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Rank tier title badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: rankColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: rankColor.withValues(alpha: 0.50),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          tierTitle.toUpperCase(),
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Rank badge and real hero avatar
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: <Widget>[
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: rankColor, width: 2.8),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: rankColor.withValues(alpha: 0.55),
                                  blurRadius: 22,
                                  spreadRadius: 1,
                                ),
                              ],
                              gradient: RadialGradient(
                                colors: <Color>[
                                  rankColor.withValues(alpha: 0.40),
                                  const Color(0xFF0F1728),
                                ],
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                avatarAsset,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    CircleAvatar(
                                  radius: 38,
                                  backgroundColor: const Color(0xFF161E34),
                                  child: Icon(
                                    Icons.person,
                                    color: rankColor,
                                    size: 46,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: rankColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: rankColor.withValues(alpha: 0.7),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Text(
                                '#$rank',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        entry.username,
                        style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (entry.guild != null && entry.guild!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.shield_outlined,
                                size: 14,
                                color: AppColors.accentCyan,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                entry.guild!,
                                style: const TextStyle(
                                  color: AppColors.accentCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      // Power & Stats card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141D30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.borderDefault.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.liquidGold.withValues(alpha: 0.15),
                                    border: Border.all(
                                      color: AppColors.liquidGold.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    color: AppColors.liquidGold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Toplam Güç',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${entry.value} (${_compactPower(entry.value)})',
                              style: const TextStyle(
                                color: AppColors.liquidGold,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // View full leaderboard button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: rankColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 4,
                            shadowColor: rankColor.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(modalContext).pop();
                            context.push(AppRoutes.leaderboard);
                          },
                          icon: const Icon(Icons.military_tech_rounded, size: 20),
                          label: const Text(
                            'Liderlik Tablosunu Aç',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPodiumColumn({
    required _PantheonEntry? entry,
    required int rank,
    required double pedestalHeight,
    required double avatarRadius,
    required Color color,
    required double cardWidth,
    bool isGold = false,
    double glowIntensity = 0,
  }) {
    final String name = entry?.username ?? '—';
    final String subtitle = entry == null
        ? ''
        : entry.guild != null && entry.guild!.isNotEmpty
        ? entry.guild!
        : '⚡ ${_compactPower(entry.value)}';
    final String avatarAsset = _rankAvatarAsset(rank, entry?.avatarUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          switch (rank) {
            case 1:
              HapticFeedback.heavyImpact();
              break;
            case 2:
              HapticFeedback.mediumImpact();
              break;
            case 3:
              HapticFeedback.lightImpact();
              break;
            default:
              HapticFeedback.selectionClick();
          }
          _showHeroDetailsModal(context, entry, rank, color);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            // Crown / Crest icon
            if (isGold)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: color,
                  size: 22,
                  shadows: <Shadow>[
                    Shadow(
                      color: color.withValues(alpha: 0.9),
                      blurRadius: glowIntensity.clamp(8.0, 20.0),
                    ),
                    const Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Icon(
                  rank == 2
                      ? Icons.shield_rounded
                      : Icons.local_fire_department_rounded,
                  color: color.withValues(alpha: 0.85),
                  size: 16,
                ),
              ),

            // Player name
            SizedBox(
              width: cardWidth,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isGold ? color : Colors.white,
                  fontWeight: isGold ? FontWeight.w900 : FontWeight.w800,
                  fontSize: isGold ? 12.5 : 11.5,
                  letterSpacing: 0.3,
                  shadows: isGold
                      ? <Shadow>[
                          Shadow(
                            color: color.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ]
                      : const <Shadow>[
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                ),
              ),
            ),

            // Subtitle / Power / Guild
            if (subtitle.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              SizedBox(
                width: cardWidth,
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isGold
                        ? color.withValues(alpha: 0.9)
                        : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 14),

            const SizedBox(height: 6),

            // Avatar Container with real artwork and floating medal badge
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: avatarRadius * 2 + (isGold ? 8 : 6),
                  height: avatarRadius * 2 + (isGold ? 8 : 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color,
                      width: isGold ? 2.6 : 1.8,
                    ),
                    boxShadow: <BoxShadow>[
                      if (isGold)
                        BoxShadow(
                          color: color.withValues(alpha: 0.55),
                          blurRadius: glowIntensity,
                          spreadRadius: 1,
                        ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    gradient: RadialGradient(
                      colors: <Color>[
                        color.withValues(alpha: 0.40),
                        const Color(0xFF0F1524),
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      avatarAsset,
                      width: avatarRadius * 2,
                      height: avatarRadius * 2,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: const Color(0xFF141C2E),
                        child: Icon(
                          Icons.person,
                          color: color,
                          size: avatarRadius * 1.25,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: color.withValues(alpha: 0.65),
                          blurRadius: 6,
                        ),
                        const BoxShadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Pedestal Pillar
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  width: cardWidth * 0.86,
                  height: pedestalHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        color.withValues(alpha: isGold ? 0.90 : 0.70),
                        color.withValues(alpha: 0.22),
                        const Color(0xF8090E1A),
                      ],
                      stops: const <double>[0.0, 0.38, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border.all(
                      color: color.withValues(alpha: isGold ? 0.95 : 0.75),
                      width: isGold ? 2.0 : 1.4,
                    ),
                    boxShadow: <BoxShadow>[
                      if (isGold)
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: glowIntensity,
                          spreadRadius: -1,
                        ),
                      const BoxShadow(
                        color: Colors.black87,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      // Top glowing bezel line
                      Container(
                        height: 2.2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.95),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: color.withValues(alpha: 0.8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      // Rank number and power badge
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '#$rank',
                            style: TextStyle(
                              fontSize: isGold ? 28 : 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                              shadows: <Shadow>[
                                Shadow(
                                  color: isGold ? color : Colors.black,
                                  blurRadius: isGold ? 12 : 6,
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                          if (entry != null && entry.value > 0) ...<Widget>[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '⚡ ${_compactPower(entry.value)}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Bottom base ornament
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Icon(
                          isGold
                              ? Icons.auto_awesome_rounded
                              : rank == 2
                              ? Icons.shield_rounded
                              : Icons.local_fire_department_rounded,
                          color: color.withValues(alpha: 0.7),
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AionCelestialFramePainter extends CustomPainter {
  const _AionCelestialFramePainter({
    required this.accentColor,
    required this.glowValue,
  });

  final Color accentColor;
  final double glowValue;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const double bracketSize = 18.0;
    const double inset = 6.0;

    final Paint bracketPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35 + (glowValue * 0.25))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final Paint innerBracketPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18 + (glowValue * 0.15))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    final Paint dotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.65 + (glowValue * 0.35))
      ..style = PaintingStyle.fill;

    // Helper: draw diamond star glyph
    void drawDiamond(Offset center, double radius) {
      final Path path = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius * 0.7, center.dy)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius * 0.7, center.dy)
        ..close();
      canvas.drawPath(path, dotPaint);
    }

    // Top-left bracket
    final Path tlPath = Path()
      ..moveTo(inset, inset + bracketSize)
      ..lineTo(inset, inset)
      ..lineTo(inset + bracketSize, inset);
    canvas.drawPath(tlPath, bracketPaint);

    final Path tlInner = Path()
      ..moveTo(inset + 4, inset + bracketSize - 4)
      ..lineTo(inset + 4, inset + 4)
      ..lineTo(inset + bracketSize - 4, inset + 4);
    canvas.drawPath(tlInner, innerBracketPaint);
    drawDiamond(Offset(inset, inset), 2.2);

    // Top-right bracket
    final Path trPath = Path()
      ..moveTo(w - inset - bracketSize, inset)
      ..lineTo(w - inset, inset)
      ..lineTo(w - inset, inset + bracketSize);
    canvas.drawPath(trPath, bracketPaint);

    final Path trInner = Path()
      ..moveTo(w - inset - bracketSize + 4, inset + 4)
      ..lineTo(w - inset - 4, inset + 4)
      ..lineTo(w - inset - 4, inset + bracketSize - 4);
    canvas.drawPath(trInner, innerBracketPaint);
    drawDiamond(Offset(w - inset, inset), 2.2);

    // Bottom-left bracket
    final Path blPath = Path()
      ..moveTo(inset, h - inset - bracketSize)
      ..lineTo(inset, h - inset)
      ..lineTo(inset + bracketSize, h - inset);
    canvas.drawPath(blPath, bracketPaint);

    final Path blInner = Path()
      ..moveTo(inset + 4, h - inset - bracketSize + 4)
      ..lineTo(inset + 4, h - inset - 4)
      ..lineTo(inset + bracketSize - 4, h - inset - 4);
    canvas.drawPath(blInner, innerBracketPaint);
    drawDiamond(Offset(inset, h - inset), 2.2);

    // Bottom-right bracket
    final Path brPath = Path()
      ..moveTo(w - inset - bracketSize, h - inset)
      ..lineTo(w - inset, h - inset)
      ..lineTo(w - inset, h - inset - bracketSize);
    canvas.drawPath(brPath, bracketPaint);

    final Path brInner = Path()
      ..moveTo(w - inset - bracketSize + 4, h - inset - 4)
      ..lineTo(w - inset - 4, h - inset - 4)
      ..lineTo(w - inset - 4, h - inset - bracketSize + 4);
    canvas.drawPath(brInner, innerBracketPaint);
    drawDiamond(Offset(w - inset, h - inset), 2.2);

    // Top-center celestial arch with diamond star
    final double midX = w / 2;
    final Path topCrest = Path()
      ..moveTo(midX - 24, inset)
      ..lineTo(midX - 10, inset - 1)
      ..lineTo(midX, inset - 3)
      ..lineTo(midX + 10, inset - 1)
      ..lineTo(midX + 24, inset);
    canvas.drawPath(topCrest, innerBracketPaint);
    drawDiamond(Offset(midX, inset - 1.5), 2.0);
  }

  @override
  bool shouldRepaint(covariant _AionCelestialFramePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.glowValue != glowValue;
  }
}

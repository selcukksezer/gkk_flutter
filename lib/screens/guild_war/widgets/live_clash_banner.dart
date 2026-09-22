import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/guild_war_model.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';
import 'guild_war_design.dart';

class LiveClashBanner extends StatefulWidget {
  const LiveClashBanner({
    super.key,
    required this.clash,
    this.onRally,
    this.onOpenPvp,
  });

  final LiveGuildWarClash clash;
  final VoidCallback? onRally;
  final VoidCallback? onOpenPvp;

  @override
  State<LiveClashBanner> createState() => _LiveClashBannerState();
}

class _LiveClashBannerState extends State<LiveClashBanner> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  LiveGuildWarClash get clash => widget.clash;

  String _countdown(DateTime? end) {
    if (end == null) return '';
    final Duration d = end.toUtc().difference(DateTime.now().toUtc());
    if (d.isNegative) return '';
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}s ${m.toString().padLeft(2, '0')}dk';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (clash.isLive) {
      final int total = (clash.guild1Score + clash.guild2Score).clamp(1, 1 << 30);
      final double p1 = clash.guild1Score / total;
      final String left = _countdown(clash.windowEnd);
      return WarNeonCard(
        accent: WarPalette.ruby,
        glow: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '⚔ CANLI CLASH · ${clash.guild1Name ?? '?'} vs ${clash.guild2Name ?? '?'}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p1,
                minHeight: 8,
                backgroundColor: WarPalette.fuchsia.withValues(alpha: 0.35),
                color: WarPalette.gold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${clash.guild1Score}–${clash.guild2Score}'
              '${left.isNotEmpty ? ' · $left kaldı' : ''}'
              '${clash.roundName != null ? ' · ${clash.roundName}' : ''}',
              style: const TextStyle(color: WarPalette.titanium, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                if (clash.tournamentId != null)
                  Expanded(
                    child: TextButton(
                      onPressed: () => context.push(
                        '${AppRoutes.guildWar}/tournament/${clash.tournamentId}',
                      ),
                      child: const Text('Maça git'),
                    ),
                  ),
                if (widget.onRally != null)
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onRally,
                      child: const Text('Rally ol'),
                    ),
                  ),
                if (widget.onOpenPvp != null)
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onOpenPvp,
                      child: const Text('PvP aç'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (clash.status == 'spectator') {
      final String left = _countdown(clash.windowEnd);
      return WarNeonCard(
        accent: WarPalette.fuchsia,
        padding: const EdgeInsets.all(12),
        child: Text(
          '⚔ Canlı Clash: ${clash.guild1Name ?? '?'} vs ${clash.guild2Name ?? '?'}'
          '${left.isNotEmpty ? ' · $left' : ''}'
          ' · Loncan maçta değil',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (clash.status == 'waiting') {
      final String name = clash.nextTournamentName ?? clash.tournamentName ?? 'Haftalık Arena';
      return WarNeonCard(
        accent: WarPalette.gold,
        padding: const EdgeInsets.all(12),
        child: Text(
          '⚔ Clash aktif · $name'
          '${clash.prizePool != null && clash.prizePool!.isNotEmpty ? ' · ${clash.prizePool}' : ''}'
          '\nSenin maç penceren açılınca burada görünür.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final String nextName = clash.nextTournamentName ?? 'Haftalık Arena';
    final String when = _countdown(clash.nextStartAt);
    final String phase = clash.phase ?? '';
    final String phaseLabel = switch (phase) {
      'registration_opens' => 'Kayıt açılışı',
      'registration_closes' => 'Kayıt kapanışı',
      'starts' => 'Başlangıç',
      _ => 'Sonraki Clash',
    };

    final String line = when.isEmpty
        ? (clash.message ?? 'Yakında yeni Clash · $nextName'
            '${clash.prizePool != null && clash.prizePool!.isNotEmpty ? ' · ${clash.prizePool}' : ''}')
        : '$phaseLabel $when · $nextName'
            '${clash.prizePool != null && clash.prizePool!.isNotEmpty ? ' · ${clash.prizePool}' : ''}';

    return WarNeonCard(
      accent: WarPalette.titanium,
      padding: const EdgeInsets.all(12),
      child: Text(
        line,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

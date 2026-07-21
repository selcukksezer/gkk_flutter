import 'dart:async';

import 'package:flutter/material.dart';

class DungeonRestrictionMiniStrip extends StatelessWidget {
  const DungeonRestrictionMiniStrip({
    super.key,
    required this.hospitalUntil,
    required this.parseUntil,
    required this.onGoHospital,
    required this.title,
    required this.actionLabel,
    required this.icon,
    required this.accent,
    this.availableLabel = 'Taburcu olabilirsin',
  });

  final String? hospitalUntil;
  final DateTime? Function(String?) parseUntil;
  final VoidCallback onGoHospital;
  final String title;
  final String actionLabel;
  final IconData icon;
  final Color accent;
  final String availableLabel;

  @override
  Widget build(BuildContext context) {
    final DateTime? until = parseUntil(hospitalUntil);
    if (until == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                _DungeonRestrictionCountdownText(until: until, availableLabel: availableLabel),
              ],
            ),
          ),
          TextButton(
            onPressed: onGoHospital,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: accent.withValues(alpha: 0.18),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _DungeonRestrictionCountdownText extends StatefulWidget {
  const _DungeonRestrictionCountdownText({required this.until, required this.availableLabel});

  final DateTime until;
  final String availableLabel;

  @override
  State<_DungeonRestrictionCountdownText> createState() => _DungeonRestrictionCountdownTextState();
}

class _DungeonRestrictionCountdownTextState extends State<_DungeonRestrictionCountdownText> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatCountdown(Duration diff) {
    if (diff.isNegative) return '00:00';
    final int hours = diff.inHours;
    final int minutes = diff.inMinutes % 60;
    final int seconds = diff.inSeconds % 60;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Duration remaining = widget.until.difference(_now);
    return Text(
      remaining.isNegative ? widget.availableLabel : 'Kalan: ${_formatCountdown(remaining)}',
      style: const TextStyle(fontSize: 11, color: Colors.white70),
    );
  }
}

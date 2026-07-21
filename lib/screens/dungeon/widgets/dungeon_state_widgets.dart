import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class DungeonLoadingShimmer extends StatelessWidget {
  const DungeonLoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      itemCount: 5,
      itemBuilder: (_, int i) => Container(
        height: 160,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF0D1525),
          border: Border.all(color: const Color(0xFF1A2540)),
        ),
      ),
    );
  }
}

class DungeonErrorState extends StatelessWidget {
  const DungeonErrorState({super.key, this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 44, color: Color(0xFF3A5080)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Zindan listesi yüklenemedi.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF4A5880)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

class DungeonEmptyState extends StatelessWidget {
  const DungeonEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.search_off, size: 44, color: Color(0xFF2A3A60)),
          SizedBox(height: 10),
          Text('Zindan bulunamadı.', style: TextStyle(color: Color(0xFF3A5080))),
        ],
      ),
    );
  }
}

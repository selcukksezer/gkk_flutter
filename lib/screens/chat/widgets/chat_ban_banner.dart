import 'package:flutter/material.dart';

import '../chat_design_system.dart';
import '../chat_models.dart';

class ChatBanBanner extends StatelessWidget {
  const ChatBanBanner({super.key, required this.ban});

  final ChatBan ban;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ChatDesignSystem.durationBase,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ChatDesignSystem.colorError.withValues(alpha: 0.15), ChatDesignSystem.colorError.withValues(alpha: 0.05)]),
        border: Border.all(color: ChatDesignSystem.colorError.withValues(alpha: 0.3), width: 1.5),
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusXl),
        boxShadow: [BoxShadow(color: ChatDesignSystem.colorError.withValues(alpha: 0.1), blurRadius: 12)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(ChatDesignSystem.spaceSm),
                  decoration: BoxDecoration(
                    color: ChatDesignSystem.colorError.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                  ),
                  child: const Icon(Icons.block_rounded, size: 14, color: ChatDesignSystem.colorError),
                ),
                const SizedBox(width: ChatDesignSystem.spaceSm),
                const Text(
                  'Sohbet Erişimi Kısıtlandı',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ChatDesignSystem.colorError),
                ),
              ],
            ),
            const SizedBox(height: ChatDesignSystem.spaceSm),
            Padding(
              padding: const EdgeInsets.only(left: ChatDesignSystem.spaceLg + ChatDesignSystem.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(ban.reason, style: const TextStyle(fontSize: 12, color: ChatDesignSystem.colorTextSecondary)),
                  const SizedBox(height: ChatDesignSystem.spaceXs),
                  Text(
                    'Bitiş: ${ban.expiresAt.toString().split('.')[0]}',
                    style: TextStyle(fontSize: 10, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

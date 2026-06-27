import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';

/// Shared compact spacing + surfaces for facilities hub/detail.
abstract final class FacilitiesUi {
  static const double gap = GameScrollLayout.sectionGap;
  static const double gapSm = GameScrollLayout.itemGap;
  static EdgeInsets scrollPadding(BuildContext context) => GameScrollLayout.pagePadding(context);
  static const EdgeInsets panelPadding = EdgeInsets.all(8);
}

Widget facilitiesScreenShell({required Widget child}) {
  return GameScreenBackground(child: child);
}

Widget facilitiesPanel({
  required Widget child,
  Color? borderColor,
  EdgeInsetsGeometry? padding,
}) {
  return DottedPanel(
    padding: padding ?? FacilitiesUi.panelPadding,
    borderRadius: 12,
    borderColor: borderColor ?? AppColors.liquidGold.withValues(alpha: 0.2),
    child: child,
  );
}

Widget facilitiesStatChip(String label, String value, {Color? valueColor}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: AppColors.darkObsidian.withValues(alpha: 0.72),
      border: Border.all(color: AppColors.mutedTitanium.withValues(alpha: 0.16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppColors.mutedTitanium, height: 1.1),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
            height: 1.15,
          ),
        ),
      ],
    ),
  );
}

typedef FacilitiesTabOption = ({String id, String label});

Widget facilitiesSegmentTabs({
  required String activeId,
  required List<FacilitiesTabOption> tabs,
  required ValueChanged<String> onChanged,
}) {
  return Row(
    children: tabs.map((FacilitiesTabOption tab) {
      final bool active = tab.id == activeId;
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: tab.id == tabs.last.id ? 0 : FacilitiesUi.gapSm),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(tab.id),
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? AppColors.liquidGold
                        : AppColors.mutedTitanium.withValues(alpha: 0.28),
                  ),
                  color: active
                      ? AppColors.liquidGold.withValues(alpha: 0.1)
                      : AppColors.carbonVoid.withValues(alpha: 0.35),
                ),
                child: Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.liquidGold : AppColors.mutedTitanium,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

Widget facilitiesSectionTitle(String title, {String? trailing}) {
  return Row(
    children: <Widget>[
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      if (trailing != null)
        Text(
          trailing,
          style: const TextStyle(fontSize: 10, color: AppColors.mutedTitanium),
        ),
    ],
  );
}

Widget facilitiesErrorPanel({required String message, required VoidCallback onRetry}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: facilitiesPanel(
        borderColor: AppColors.mysticRuby.withValues(alpha: 0.35),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '⚠️ Tesisler yüklenemedi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.mutedTitanium, height: 1.35),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.liquidGold,
                  foregroundColor: AppColors.carbonVoid,
                ),
                child: const Text('Tekrar Dene', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

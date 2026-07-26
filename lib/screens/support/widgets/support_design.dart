import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';
import '../../settings/widgets/settings_design.dart';

export '../../settings/widgets/settings_design.dart'
    show
        SettingsGlassCard,
        SettingsPressable,
        SettingsPrimaryButton,
        SettingsSectionHeader,
        SettingsPalette;

/// Tasarim-aligned input for support/staff forms.
InputDecoration supportInputDecoration({
  required String label,
  String? hint,
  String? errorText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    labelStyle: AppTextStyles.caption.copyWith(color: SettingsPalette.titanium),
    hintStyle: AppTextStyles.caption.copyWith(
      color: SettingsPalette.titanium.withValues(alpha: 0.65),
    ),
    filled: true,
    fillColor: SettingsPalette.obsidian.withValues(alpha: 0.55),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: SettingsPalette.titanium.withValues(alpha: 0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SettingsPalette.gold),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SettingsPalette.ruby),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SettingsPalette.ruby),
    ),
  );
}

TextStyle get supportBodyStyle =>
    AppTextStyles.body.copyWith(color: SettingsPalette.textHi, height: 1.45);

TextStyle get supportCaptionStyle =>
    AppTextStyles.caption.copyWith(color: SettingsPalette.textMid);

/// Ticket / bug list tile shell.
class SupportListTileCard extends StatelessWidget {
  const SupportListTileCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.accent = SettingsPalette.neon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SettingsPressable(
        onTap: onTap,
        child: SettingsGlassCard(
          accent: accent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: supportCaptionStyle),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.85)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../core/services/app_haptics.dart';
import '../../../core/utils/keyboard_dismiss.dart';
import '../../../theme/app_text_styles.dart';
import '../../support/widgets/support_design.dart';

export '../../../core/services/app_haptics.dart' show AppHaptics;
export '../../support/widgets/support_design.dart'
    show
        SettingsGlassCard,
        SettingsPressable,
        SettingsPrimaryButton,
        SettingsSectionHeader,
        SettingsPalette,
        supportBodyStyle,
        supportCaptionStyle,
        supportInputDecoration;

/// Staff / Admin / LiveOps — tasarim skill UI kit.
abstract final class StaffDesign {
  static const double cardRadius = 16.0;
  static const double dialogRadius = 18.0;
  static const double sheetRadius = 22.0;
  static const double defaultBlurSigma = 12.0;

  static const List<String> hubTabs = <String>[
    'Özet',
    'Oyuncu',
    'Ticket',
    'Bug',
    'Chat',
    'Audit',
    'GM',
  ];

  static Color statusAccent(String status) {
    switch (status) {
      case 'open':
      case 'submitted':
        return SettingsPalette.coral;
      case 'needs_info':
        return SettingsPalette.titanium;
      case 'staff_reply':
      case 'triaged':
        return SettingsPalette.gold;
      case 'approved':
      case 'resolved':
        return SettingsPalette.neon;
      case 'rejected':
      case 'banned':
      case 'spam':
      case 'closed':
        return SettingsPalette.ruby;
      default:
        return SettingsPalette.fuchsia;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'submitted':
        return 'İletildi';
      case 'needs_info':
        return 'Bilgi Bekleniyor';
      case 'staff_reply':
        return 'Yetkili Yanıtı';
      case 'triaged':
        return 'İnceleniyor';
      case 'approved':
        return 'Onaylandı';
      case 'resolved':
        return 'Çözüldü';
      case 'rejected':
        return 'Reddedildi';
      case 'banned':
        return 'Yasaklandı';
      case 'spam':
        return 'Spam';
      case 'closed':
        return 'Kapatıldı';
      default:
        return status.toUpperCase();
    }
  }

  /// Adaptive blur radius scaling for low-spec / thermal throttled devices.
  static double adaptiveBlur(BuildContext context, {double defaultSigma = defaultBlurSigma}) {
    final MediaQueryData? mq = MediaQuery.maybeOf(context);
    if (mq != null && mq.disableAnimations) return 0.0;
    return defaultSigma;
  }
}

enum StaffRoleTier {
  administrator,
  gm,
  support,
  operator;

  static StaffRoleTier fromString(String? role) {
    if (role == null) return StaffRoleTier.support;
    final String r = role.toLowerCase().trim();
    if (r == 'admin' || r == 'administrator') return StaffRoleTier.administrator;
    if (r == 'gm' || r == 'gamemaster' || r == 'game_master') return StaffRoleTier.gm;
    if (r == 'support' || r == 'destek') return StaffRoleTier.support;
    return StaffRoleTier.operator;
  }

  String get displayName {
    switch (this) {
      case StaffRoleTier.administrator:
        return 'ADMINISTRATOR';
      case StaffRoleTier.gm:
        return 'GAME MASTER';
      case StaffRoleTier.support:
        return 'SUPPORT SPECIALIST';
      case StaffRoleTier.operator:
        return 'OPERATOR';
    }
  }

  String get tierCode {
    switch (this) {
      case StaffRoleTier.administrator:
        return 'RANK 01 · ARCHON';
      case StaffRoleTier.gm:
        return 'RANK 02 · SENTINEL';
      case StaffRoleTier.support:
        return 'RANK 03 · CURATOR';
      case StaffRoleTier.operator:
        return 'RANK 04 · OBSERVER';
    }
  }

  Color get accent {
    switch (this) {
      case StaffRoleTier.administrator:
        return SettingsPalette.gold;
      case StaffRoleTier.gm:
        return SettingsPalette.neon;
      case StaffRoleTier.support:
        return SettingsPalette.fuchsia;
      case StaffRoleTier.operator:
        return SettingsPalette.titanium;
    }
  }

  IconData get icon {
    switch (this) {
      case StaffRoleTier.administrator:
        return Icons.workspace_premium_rounded;
      case StaffRoleTier.gm:
        return Icons.security_rounded;
      case StaffRoleTier.support:
        return Icons.headset_mic_rounded;
      case StaffRoleTier.operator:
        return Icons.terminal_rounded;
    }
  }
}

/// Aion 2 standard luminous role badge with radiant glow border.
class StaffRoleBadge extends StatelessWidget {
  const StaffRoleBadge({
    super.key,
    required this.tier,
    this.compact = false,
    this.showGlow = true,
  });

  final StaffRoleTier tier;
  final bool compact;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final Color accent = tier.accent;
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: accent.withValues(alpha: 0.16),
          border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.1),
          boxShadow: showGlow
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(tier.icon, size: 12, color: accent),
            const SizedBox(width: 4),
            Text(
              tier.displayName,
              style: AppTextStyles.captionBold.copyWith(
                color: accent,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.22),
            SettingsPalette.obsidian.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.2),
        boxShadow: showGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.2),
              border: Border.all(color: accent.withValues(alpha: 0.8)),
            ),
            child: Icon(tier.icon, size: 14, color: accent),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                tier.displayName,
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.textHi,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                tier.tierCode,
                style: AppTextStyles.caption.copyWith(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2027 Aion 2 High-Tier Glassmorphic Console Card.
class StaffConsoleCard extends StatelessWidget {
  const StaffConsoleCard({
    super.key,
    required this.child,
    this.accent = SettingsPalette.gold,
    this.padding = const EdgeInsets.all(16),
    this.glow = true,
    this.hasRunicBorders = true,
    this.blurSigma,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final bool hasRunicBorders;
  final double? blurSigma;

  @override
  Widget build(BuildContext context) {
    final double effectiveSigma = blurSigma ?? StaffDesign.adaptiveBlur(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StaffDesign.cardRadius),
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 20,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(StaffDesign.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveSigma, sigmaY: effectiveSigma),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(StaffDesign.cardRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withValues(alpha: 0.12),
                  SettingsPalette.navy.withValues(alpha: 0.88),
                  SettingsPalette.obsidian.withValues(alpha: 0.94),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.42),
                width: 1.2,
              ),
            ),
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: CustomPaint(
                    painter: DotGridPainter(spacing: 14, dotOpacity: 0.05),
                  ),
                ),
                // Specular top highlight
                Positioned(
                  top: 0,
                  left: 14,
                  right: 14,
                  height: 1.2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          accent.withValues(alpha: 0.7),
                          Colors.white.withValues(alpha: 0.5),
                          accent.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasRunicBorders)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RunicConsolePainter(accent: accent),
                    ),
                  ),
                Padding(
                  padding: padding,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RunicConsolePainter extends CustomPainter {
  const _RunicConsolePainter({this.accent = SettingsPalette.gold});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = accent.withValues(alpha: 0.20)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final Paint whiteCore = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double notch = 8.0;
    for (final Paint p in <Paint>[paint, whiteCore]) {
      // Top-left
      canvas.drawLine(const Offset(4, 4 + notch), const Offset(4, 4), p);
      canvas.drawLine(const Offset(4, 4), const Offset(4 + notch, 4), p);
      // Top-right
      canvas.drawLine(Offset(size.width - 4 - notch, 4), Offset(size.width - 4, 4), p);
      canvas.drawLine(Offset(size.width - 4, 4), Offset(size.width - 4, 4 + notch), p);
      // Bottom-left
      canvas.drawLine(Offset(4, size.height - 4 - notch), Offset(4, size.height - 4), p);
      canvas.drawLine(Offset(4, size.height - 4), Offset(4 + notch, size.height - 4), p);
      // Bottom-right
      canvas.drawLine(Offset(size.width - 4 - notch, size.height - 4), Offset(size.width - 4, size.height - 4), p);
      canvas.drawLine(Offset(size.width - 4, size.height - 4 - notch), Offset(size.width - 4, size.height - 4), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RunicConsolePainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Sleek command action tile for administrative console matrix.
class StaffCommandActionTile extends StatelessWidget {
  const StaffCommandActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent = SettingsPalette.gold,
    this.badgeText,
    this.badgeColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.08),
                  SettingsPalette.navy.withValues(alpha: 0.72),
                  SettingsPalette.obsidian.withValues(alpha: 0.85),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.38)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: <Color>[
                        accent.withValues(alpha: 0.32),
                        SettingsPalette.obsidian.withValues(alpha: 0.85),
                      ],
                    ),
                    border: Border.all(color: accent.withValues(alpha: 0.55)),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              title,
                              style: AppTextStyles.bodyBold.copyWith(
                                color: SettingsPalette.textHi,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? accent).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: (badgeColor ?? accent).withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                badgeText!,
                                style: AppTextStyles.captionBold.copyWith(
                                  color: badgeColor ?? accent,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: supportCaptionStyle.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, color: accent.withValues(alpha: 0.75), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Telemetry HUD with live sync status and fast shortcuts.
class StaffTelemetryHud extends StatelessWidget {
  const StaffTelemetryHud({
    super.key,
    required this.openTickets,
    required this.pendingBugs,
    required this.openChatReports,
    this.isRealtimeActive = true,
    this.onTicketsTap,
    this.onBugsTap,
    this.onChatReportsTap,
  });

  final int openTickets;
  final int pendingBugs;
  final int openChatReports;
  final bool isRealtimeActive;
  final VoidCallback? onTicketsTap;
  final VoidCallback? onBugsTap;
  final VoidCallback? onChatReportsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: SettingsPalette.obsidian.withValues(alpha: 0.75),
        border: Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRealtimeActive ? SettingsPalette.neon : SettingsPalette.coral,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (isRealtimeActive ? SettingsPalette.neon : SettingsPalette.coral).withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isRealtimeActive ? 'TELEMETRY SYNC · ONLINE' : 'TELEMETRY SYNC · OFFLINE',
                style: AppTextStyles.captionBold.copyWith(
                  color: isRealtimeActive ? SettingsPalette.neon : SettingsPalette.coral,
                  fontSize: 9,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                'AION 2 ADMIN PROTOCOL',
                style: AppTextStyles.caption.copyWith(
                  color: SettingsPalette.titanium.withValues(alpha: 0.8),
                  fontSize: 8,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              StaffMiniStat(
                icon: Icons.confirmation_number_outlined,
                label: 'Ticket',
                value: openTickets,
                accent: SettingsPalette.neon,
                onTap: onTicketsTap,
              ),
              const SizedBox(width: 8),
              StaffMiniStat(
                icon: Icons.bug_report_outlined,
                label: 'Bug',
                value: pendingBugs,
                accent: SettingsPalette.gold,
                onTap: onBugsTap,
              ),
              const SizedBox(width: 8),
              StaffMiniStat(
                icon: Icons.flag_outlined,
                label: 'Rapor',
                value: openChatReports,
                accent: SettingsPalette.fuchsia,
                onTap: onChatReportsTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ADMIN / GM hero — modernized to 2027 Aion 2 standard.
class StaffHeroBanner extends StatelessWidget {
  const StaffHeroBanner({
    super.key,
    required this.isAdmin,
    this.openTickets = 0,
    this.pendingBugs = 0,
    this.openChatReports = 0,
    this.onTicketsTap,
    this.onBugsTap,
    this.onChatReportsTap,
    this.roleTier,
  });

  final bool isAdmin;
  final int openTickets;
  final int pendingBugs;
  final int openChatReports;
  final VoidCallback? onTicketsTap;
  final VoidCallback? onBugsTap;
  final VoidCallback? onChatReportsTap;
  final StaffRoleTier? roleTier;

  @override
  Widget build(BuildContext context) {
    final StaffRoleTier effectiveTier = roleTier ??
        (isAdmin ? StaffRoleTier.administrator : StaffRoleTier.gm);
    final Color accent = effectiveTier.accent;

    return StaffConsoleCard(
      accent: accent,
      glow: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StaffRoleBadge(tier: effectiveTier),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SettingsPalette.ruby.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SettingsPalette.ruby.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: SettingsPalette.ruby,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'CANLI MODERASYON',
                      style: AppTextStyles.captionBold.copyWith(
                        color: SettingsPalette.ruby,
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isAdmin ? 'ADMIN KOMUTA MATRİSİ' : 'GM OPERASYON HATTI',
            style: AppTextStyles.h3.copyWith(
              color: SettingsPalette.textHi,
              letterSpacing: 1.2,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAdmin
                ? 'Tam yetki · sezon · ödül onayları · GM atama · liveops ve audit izleme'
                : 'Atanan yetkilerle oyuncu takibi · ticket triage · sohbet moderasyonu',
            style: supportCaptionStyle,
          ),
          const SizedBox(height: 16),
          StaffTelemetryHud(
            openTickets: openTickets,
            pendingBugs: pendingBugs,
            openChatReports: openChatReports,
            onTicketsTap: onTicketsTap,
            onBugsTap: onBugsTap,
            onChatReportsTap: onChatReportsTap,
          ),
        ],
      ),
    );
  }
}

class StaffMiniStat extends StatelessWidget {
  const StaffMiniStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.onTap,
    this.flexible = true,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;
  final VoidCallback? onTap;
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: SettingsPalette.obsidian.withValues(alpha: 0.65),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 14, color: accent),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: supportCaptionStyle.copyWith(fontSize: 10)),
                Text(
                  '$value',
                  style: AppTextStyles.bodyBold.copyWith(color: accent, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final Widget pressableContent = onTap != null
        ? SettingsPressable(
            onTap: () {
              AppHaptics.selection();
              onTap!();
            },
            child: content,
          )
        : content;

    if (flexible) {
      return Expanded(child: pressableContent);
    }
    return pressableContent;
  }
}

/// Dashboard stat — büyük kart (ref 3 vault value).
class StaffStatCard extends StatelessWidget {
  const StaffStatCard({
    super.key,
    required this.label,
    required this.value,
    this.accent = SettingsPalette.gold,
    this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SettingsGlassCard(
        accent: accent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: <Color>[accent.withValues(alpha: 0.35), SettingsPalette.obsidian],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(label, style: supportCaptionStyle)),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(color: accent, fontSize: 22),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab strip — modernized with 2027 Aion 2 tab badges & luminous indicators.
class StaffTabStrip extends StatelessWidget {
  const StaffTabStrip({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.accent = SettingsPalette.gold,
    this.tabBadges,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color accent;
  final Map<int, int>? tabBadges;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: List<Widget>.generate(tabs.length, (int i) {
          final bool selected = i == selectedIndex;
          final int badgeCount = tabBadges?[i] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SettingsPressable(
              onTap: () {
                AppHaptics.selection();
                onSelected(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: selected
                      ? LinearGradient(
                          colors: <Color>[
                            accent.withValues(alpha: 0.35),
                            SettingsPalette.obsidian,
                          ],
                        )
                      : null,
                  color: selected ? null : SettingsPalette.obsidian.withValues(alpha: 0.5),
                  border: Border.all(
                    color: selected ? accent.withValues(alpha: 0.75) : SettingsPalette.titanium.withValues(alpha: 0.25),
                    width: selected ? 1.4 : 1,
                  ),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 12),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      tabs[i].toUpperCase(),
                      style: AppTextStyles.captionBold.copyWith(
                        color: selected ? accent : SettingsPalette.titanium,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (badgeCount > 0) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: selected ? accent : SettingsPalette.ruby,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: (selected ? accent : SettingsPalette.ruby).withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '$badgeCount',
                          style: TextStyle(
                            color: selected ? SettingsPalette.void_ : Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Filtre chip satırı (ticket status vb.).
class StaffFilterChipRow extends StatelessWidget {
  const StaffFilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.accent = SettingsPalette.neon,
    this.labels,
  });

  final List<String?> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final Color accent;
  final Map<String?, String>? labels;

  String _labelFor(String? opt) {
    if (labels != null && labels!.containsKey(opt)) return labels![opt]!;
    if (opt == null) return 'Tümü';
    return opt;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: options.map((String? opt) {
          final bool isSel = selected == opt;
          final String label = _labelFor(opt);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(label),
              selected: isSel,
              showCheckmark: false,
              selectedColor: accent.withValues(alpha: 0.22),
              backgroundColor: SettingsPalette.obsidian.withValues(alpha: 0.55),
              side: BorderSide(
                color: isSel ? accent.withValues(alpha: 0.65) : SettingsPalette.titanium.withValues(alpha: 0.25),
              ),
              labelStyle: TextStyle(
                color: isSel ? accent : SettingsPalette.textMid,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (_) {
                AppHaptics.selection();
                onSelected(opt);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Arama + filtre satırı (staff tab toolbar).
class StaffQueryToolbar extends StatelessWidget {
  const StaffQueryToolbar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSearch,
    this.secondaryController,
    this.secondaryHint,
    this.filter,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSearch;
  final TextEditingController? secondaryController;
  final String? secondaryHint;
  final Widget? filter;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  style: supportBodyStyle,
                  decoration: supportInputDecoration(label: hint),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              StaffActionButton(
                label: 'Ara',
                outlined: true,
                onPressed: onSearch,
                accent: SettingsPalette.neon,
              ),
            ],
          ),
          if (secondaryController != null) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: secondaryController,
              style: supportBodyStyle,
              decoration: supportInputDecoration(label: secondaryHint ?? 'Hedef ara'),
              onSubmitted: (_) => onSearch(),
            ),
          ],
          if (filter != null) ...<Widget>[
            const SizedBox(height: 6),
            filter!,
          ],
          if (trailing != null) ...<Widget>[
            const SizedBox(height: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class StaffStatusPill extends StatelessWidget {
  const StaffStatusPill({super.key, required this.status, this.label});

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final Color accent = StaffDesign.statusAccent(status);
    final String text = label ?? StaffDesign.statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text.toUpperCase(),
            style: AppTextStyles.captionBold.copyWith(color: accent, fontSize: 9, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

class StaffEmptyState extends StatelessWidget {
  const StaffEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.accent = SettingsPalette.fuchsia,
  });

  final IconData icon;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SettingsGlassCard(
      accent: accent,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.15),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, size: 36, color: accent),
          ),
          const SizedBox(height: 12),
          Text(message, style: supportBodyStyle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class StaffChatReportCard extends StatelessWidget {
  const StaffChatReportCard({
    super.key,
    required this.sender,
    required this.reason,
    required this.preview,
    this.reporter,
    this.onReviewed,
    this.onAction,
    this.onDismiss,
    this.busy = false,
  });

  final String sender;
  final String? reporter;
  final String reason;
  final String preview;
  final VoidCallback? onReviewed;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SettingsGlassCard(
        accent: SettingsPalette.fuchsia,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            title: Text('@$sender — $reason', style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi, fontSize: 13)),
            subtitle: Text(
              reporter != null && reporter!.isNotEmpty
                  ? 'Raporlayan: @$reporter · $preview'
                  : preview,
              style: supportCaptionStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            iconColor: SettingsPalette.fuchsia,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: busy
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(color: SettingsPalette.fuchsia, strokeWidth: 2),
                        ),
                      )
                    : Row(
                        children: <Widget>[
                          Expanded(child: StaffActionButton(label: 'İncele', outlined: true, onPressed: onReviewed)),
                          const SizedBox(width: 6),
                          Expanded(child: StaffActionButton(label: 'Sil', danger: true, outlined: true, onPressed: onAction)),
                          const SizedBox(width: 6),
                          Expanded(child: StaffActionButton(label: 'Red', outlined: true, onPressed: onDismiss)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StaffAuditExpansionTile extends StatelessWidget {
  const StaffAuditExpansionTile({
    super.key,
    required this.action,
    required this.subtitle,
    this.detailLines = const <String>[],
    this.accent = SettingsPalette.gold,
  });

  final String action;
  final String subtitle;
  final List<String> detailLines;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SettingsGlassCard(
        accent: accent,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            title: Text(action, style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi)),
            subtitle: Text(subtitle, style: supportCaptionStyle),
            iconColor: accent,
            collapsedIconColor: SettingsPalette.titanium,
            children: detailLines.isEmpty
                ? const <Widget>[]
                : <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: SettingsPalette.obsidian.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: detailLines
                              .map(
                                (String line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(line, style: supportCaptionStyle.copyWith(fontSize: 11)),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

class StaffActionButton extends StatelessWidget {
  const StaffActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.accent = SettingsPalette.gold,
    this.outlined = false,
    this.danger = false,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool outlined;
  final bool danger;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color c = danger ? SettingsPalette.ruby : accent;
    final bool enabled = onPressed != null && !loading;

    if (outlined) {
      return SettingsPressable(
        enabled: enabled,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? c.withValues(alpha: 0.65) : SettingsPalette.titanium.withValues(alpha: 0.25),
              width: 1.1,
            ),
            color: SettingsPalette.obsidian.withValues(alpha: 0.5),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: c.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (loading) ...<Widget>[
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(c),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: enabled ? c : SettingsPalette.titanium),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.captionBold.copyWith(
                  color: enabled ? c : SettingsPalette.titanium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final Color textForeground = danger ? Colors.white : (c == SettingsPalette.titanium ? Colors.white : SettingsPalette.void_);
    return SettingsPressable(
      enabled: enabled,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: enabled
              ? LinearGradient(
                  colors: <Color>[
                    c.withValues(alpha: 0.95),
                    c,
                    Color.lerp(c, Colors.black, 0.25) ?? c,
                  ],
                )
              : null,
          color: enabled ? null : SettingsPalette.obsidian.withValues(alpha: 0.6),
          border: enabled
              ? Border.all(color: c.withValues(alpha: 0.8), width: 1.1)
              : Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.2)),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: c.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (loading) ...<Widget>[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textForeground),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (icon != null) ...<Widget>[
              Icon(icon, size: 16, color: textForeground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(
                color: enabled ? textForeground : SettingsPalette.titanium,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 2027 Aion 2 Luminous Neon Switch.
/// Standardized replacement for Flutter's [Switch] with zero deprecated [activeThumbColor] issues.
class StaffSwitch extends StatelessWidget {
  const StaffSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = SettingsPalette.neon,
    this.inactiveColor = SettingsPalette.titanium,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    final Color trackColor = value
        ? activeColor.withValues(alpha: enabled ? 0.85 : 0.35)
        : SettingsPalette.obsidian;
    final Color thumbColor = value ? SettingsPalette.textHi : inactiveColor;

    return SettingsPressable(
      enabled: enabled,
      onTap: enabled
          ? () {
              AppHaptics.selection();
              onChanged!(!value);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 50,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: trackColor,
          border: Border.all(
            color: value
                ? activeColor.withValues(alpha: 0.9)
                : inactiveColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: value && enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: thumbColor,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Luminous staff switch row with icon, title, subtitle, and [StaffSwitch].
class StaffSwitchTile extends StatelessWidget {
  const StaffSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.activeColor = SettingsPalette.neon,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Color activeColor;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color accent = danger ? SettingsPalette.ruby : activeColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: accent.withValues(alpha: 0.12),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: supportCaptionStyle.copyWith(fontSize: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          StaffSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: accent,
          ),
        ],
      ),
    );
  }
}

/// Blur bottom sheet — ref 2 item popup.
Future<T?> showStaffBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  Color accent = SettingsPalette.gold,
  bool showCloseButton = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: SettingsPalette.void_.withValues(alpha: 0.72),
    builder: (BuildContext ctx) {
      final MediaQueryData mq = MediaQuery.of(ctx);
      return DismissKeyboard(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                mq.padding.bottom + mq.viewInsets.bottom + 12,
              ),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22), bottom: Radius.circular(22)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        SettingsPalette.navy.withValues(alpha: 0.96),
                        SettingsPalette.void_.withValues(alpha: 0.98),
                      ],
                    ),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22), bottom: Radius.circular(22)),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: <Widget>[
                        const Positioned.fill(
                          child: CustomPaint(
                            painter: DotGridPainter(spacing: 14, dotOpacity: 0.07),
                          ),
                        ),
                        // Top specular highlight
                        Positioned(
                          top: 0,
                          left: 20,
                          right: 20,
                          height: 1.2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  Colors.transparent,
                                  accent.withValues(alpha: 0.65),
                                  Colors.white.withValues(alpha: 0.45),
                                  accent.withValues(alpha: 0.65),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Drag handle pill
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: SettingsPalette.titanium.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            showCloseButton ? 40 : 20,
                            16,
                            16,
                          ),
                          child: SizedBox(
                            width: mq.size.width - 24,
                            child: child,
                          ),
                        ),
                        if (showCloseButton)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IconButton(
                              tooltip: 'Kapat',
                              onPressed: () => Navigator.of(ctx).maybePop(),
                              style: IconButton.styleFrom(
                                foregroundColor: SettingsPalette.titanium,
                                backgroundColor:
                                    SettingsPalette.void_.withValues(alpha: 0.55),
                                minimumSize: const Size(36, 36),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Staff süre seçimi. [until] null = kalıcı ban. Dialog iptal → null.
class StaffDurationPick {
  const StaffDurationPick({required this.until});

  final DateTime? until;
}

StaffDurationPick? staffDurationFromParts({
  required int minutes,
  required int hours,
  required int days,
  required int months,
}) {
  final int totalMinutes = minutes + (hours * 60) + (days * 24 * 60) + (months * 30 * 24 * 60);
  if (totalMinutes <= 0) return null;
  return StaffDurationPick(until: DateTime.now().toUtc().add(Duration(minutes: totalMinutes)));
}

Future<StaffDurationPick?> showStaffDurationPicker({
  required BuildContext context,
  required String title,
  bool allowPermanent = false,
}) {
  final Color accent = allowPermanent ? SettingsPalette.ruby : SettingsPalette.gold;
  final TextEditingController minuteCtrl = TextEditingController(text: '0');
  final TextEditingController hourCtrl = TextEditingController(text: '0');
  final TextEditingController dayCtrl = TextEditingController(text: '0');
  final TextEditingController monthCtrl = TextEditingController(text: '0');

  return showDialog<StaffDurationPick>(
    context: context,
    builder: (BuildContext ctx) {
      Widget presetTile({
        required IconData icon,
        required String label,
        required StaffDurationPick pick,
      }) {
        return SettingsPressable(
          onTap: () => Navigator.pop(ctx, pick),
          child: SettingsGlassCard(
            accent: accent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: accent, size: 26),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionBold.copyWith(color: SettingsPalette.textHi, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }

      Widget customField(String label, TextEditingController controller) {
        return Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: supportBodyStyle,
            decoration: supportInputDecoration(label: label),
          ),
        );
      }

      final DateTime now = DateTime.now().toUtc();
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: SettingsPalette.navy.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: accent.withValues(alpha: 0.4)),
          ),
          title: Text(title, style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Hızlı seçim', style: AppTextStyles.caption.copyWith(color: SettingsPalette.textMid)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: presetTile(
                        icon: Icons.schedule_rounded,
                        label: '1 saat',
                        pick: StaffDurationPick(until: now.add(const Duration(hours: 1))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: presetTile(
                        icon: Icons.today_rounded,
                        label: '1 gün',
                        pick: StaffDurationPick(until: now.add(const Duration(hours: 24))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: presetTile(
                        icon: Icons.date_range_rounded,
                        label: '1 ay',
                        pick: StaffDurationPick(until: now.add(const Duration(days: 30))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: presetTile(
                        icon: Icons.all_inclusive_rounded,
                        label: 'Sınırsız',
                        pick: StaffDurationPick(
                          until: allowPermanent ? null : now.add(const Duration(days: 36500)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Özel süre (elle yaz)', style: AppTextStyles.caption.copyWith(color: SettingsPalette.textMid)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    customField('Dakika', minuteCtrl),
                    const SizedBox(width: 8),
                    customField('Saat', hourCtrl),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    customField('Gün', dayCtrl),
                    const SizedBox(width: 8),
                    customField('Ay', monthCtrl),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal', style: TextStyle(color: SettingsPalette.titanium)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: allowPermanent ? Colors.white : SettingsPalette.void_,
              ),
              onPressed: () {
                final StaffDurationPick? pick = staffDurationFromParts(
                  minutes: int.tryParse(minuteCtrl.text.trim()) ?? 0,
                  hours: int.tryParse(hourCtrl.text.trim()) ?? 0,
                  days: int.tryParse(dayCtrl.text.trim()) ?? 0,
                  months: int.tryParse(monthCtrl.text.trim()) ?? 0,
                );
                if (pick == null) {
                  AppMessenger.showError(ctx, 'Geçerli bir süre girin (dk/saat/gün/ay).');
                  return;
                }
                Navigator.pop(ctx, pick);
              },
              child: const Text('Uygula'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(() {
    minuteCtrl.dispose();
    hourCtrl.dispose();
    dayCtrl.dispose();
    monthCtrl.dispose();
  });
}

Future<bool?> showStaffConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Onayla',
  bool danger = false,
}) {
  final Color accent = danger ? SettingsPalette.ruby : SettingsPalette.gold;
  return showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: SettingsPalette.navy.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: accent.withValues(alpha: 0.4)),
          ),
          title: Text(title, style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi)),
          content: Text(message, style: supportBodyStyle),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('İptal', style: TextStyle(color: SettingsPalette.titanium)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: danger ? Colors.white : SettingsPalette.void_,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
    },
  );
}

class StaffFormFieldSpec {
  const StaffFormFieldSpec({
    required this.key,
    required this.label,
    this.initial = '',
    this.keyboardType,
    this.maxLines = 1,
  });

  final String key;
  final String label;
  final String initial;
  final TextInputType? keyboardType;
  final int maxLines;
}

Future<Map<String, String>?> showStaffFormDialog({
  required BuildContext context,
  required String title,
  required List<StaffFormFieldSpec> fields,
  String confirmLabel = 'Kaydet',
  bool danger = false,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (BuildContext ctx) => _StaffFormDialog(
      title: title,
      fields: fields,
      confirmLabel: confirmLabel,
      danger: danger,
    ),
  );
}

class _StaffFormDialog extends StatefulWidget {
  const _StaffFormDialog({
    required this.title,
    required this.fields,
    required this.confirmLabel,
    required this.danger,
  });

  final String title;
  final List<StaffFormFieldSpec> fields;
  final String confirmLabel;
  final bool danger;

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = <String, TextEditingController>{
      for (final StaffFormFieldSpec f in widget.fields)
        f.key: TextEditingController(text: f.initial),
    };
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _popWithResult(Map<String, String>? result) {
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.danger ? SettingsPalette.ruby : SettingsPalette.gold;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: AlertDialog(
        backgroundColor: SettingsPalette.navy.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: accent.withValues(alpha: 0.4)),
        ),
        title: Text(widget.title, style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.fields.map((StaffFormFieldSpec f) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _controllers[f.key],
                  keyboardType: f.keyboardType,
                  maxLines: f.maxLines,
                  style: supportBodyStyle,
                  decoration: supportInputDecoration(label: f.label),
                ),
              );
            }).toList(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _popWithResult(null),
            child: Text('İptal', style: TextStyle(color: SettingsPalette.titanium)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: widget.danger ? Colors.white : SettingsPalette.void_,
            ),
            onPressed: () {
              _popWithResult(<String, String>{
                for (final StaffFormFieldSpec f in widget.fields)
                  f.key: _controllers[f.key]!.text.trim(),
              });
            },
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}

class StaffGmRosterTile extends StatelessWidget {
  const StaffGmRosterTile({
    super.key,
    required this.username,
    required this.permCount,
    required this.onTap,
    required this.onSave,
    this.selected = false,
  });

  final String username;
  final int permCount;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SettingsGlassCard(
        accent: selected ? SettingsPalette.gold : SettingsPalette.neon,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: <Widget>[
            const StaffRoleBadge(tier: StaffRoleTier.gm, compact: true),
            const SizedBox(width: 10),
            Expanded(
              child: SettingsPressable(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('@$username', style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi)),
                    Text('$permCount aktif izin atanmış', style: supportCaptionStyle),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.save_outlined, color: selected ? SettingsPalette.gold : SettingsPalette.neon),
              tooltip: 'İzinleri kaydet',
              onPressed: onSave,
            ),
          ],
        ),
      ),
    );
  }
}

class StaffPermissionGroup extends StatelessWidget {
  const StaffPermissionGroup({
    super.key,
    required this.category,
    required this.items,
    required this.selected,
    required this.onToggle,
  });

  final String category;
  final List<({String key, String label, bool dangerous})> items;
  final Set<String> selected;
  final void Function(String key, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SettingsGlassCard(
        accent: SettingsPalette.fuchsia,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            title: Text(
              category.toUpperCase(),
              style: AppTextStyles.captionBold.copyWith(color: SettingsPalette.textHi, letterSpacing: 0.8),
            ),
            iconColor: SettingsPalette.fuchsia,
            children: items
                .map(
                  (({String key, String label, bool dangerous}) p) => CheckboxListTile(
                    dense: true,
                    activeColor: SettingsPalette.gold,
                    checkColor: SettingsPalette.void_,
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: BorderSide(
                      color: selected.contains(p.key)
                          ? SettingsPalette.gold
                          : SettingsPalette.titanium.withValues(alpha: 0.5),
                    ),
                    title: Text(p.label, style: supportBodyStyle.copyWith(fontSize: 13)),
                    subtitle: p.dangerous
                        ? Text('Tehlikeli', style: supportCaptionStyle.copyWith(color: SettingsPalette.ruby))
                        : null,
                    value: selected.contains(p.key),
                    onChanged: (bool? v) {
                      AppHaptics.selection();
                      onToggle(p.key, v == true);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

/// Staff hub sekmesi — filtre + liste tek scroll; bottom bar altında kalmaz.
class StaffScrollTab extends StatelessWidget {
  const StaffScrollTab({
    super.key,
    required this.accent,
    required this.onRefresh,
    required this.header,
    this.itemCount = 0,
    this.itemBuilder,
    this.emptyChild,
    this.footer = const <Widget>[],
    this.horizontalPadding = 12,
  });

  final Color accent;
  final Future<void> Function() onRefresh;
  final List<Widget> header;
  final int itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final Widget? emptyChild;
  final List<Widget> footer;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final bool showList = itemCount > 0 && itemBuilder != null;

    return RefreshIndicator(
      color: accent,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          for (final Widget w in header) SliverToBoxAdapter(child: w),
          if (showList)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  itemBuilder!,
                  childCount: itemCount,
                ),
              ),
            )
          else if (emptyChild != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                child: emptyChild,
              ),
            ),
          for (final Widget w in footer) SliverToBoxAdapter(child: w),
          SliverToBoxAdapter(child: GameScrollLayout.bottomSpacer(context)),
        ],
      ),
    );
  }
}

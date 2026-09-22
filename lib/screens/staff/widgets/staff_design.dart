import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../core/utils/keyboard_dismiss.dart';
import '../../../theme/app_text_styles.dart';
import '../../support/widgets/support_design.dart';

/// Staff / Admin / LiveOps — tasarim skill UI kit.
abstract final class StaffDesign {
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
}

/// ADMIN / GM hero — ref 6 CANLI EKONOMİ pill + gold header.
class StaffHeroBanner extends StatelessWidget {
  const StaffHeroBanner({
    super.key,
    required this.isAdmin,
    this.openTickets = 0,
    this.pendingBugs = 0,
    this.openChatReports = 0,
  });

  final bool isAdmin;
  final int openTickets;
  final int pendingBugs;
  final int openChatReports;

  @override
  Widget build(BuildContext context) {
    final Color accent = isAdmin ? SettingsPalette.gold : SettingsPalette.neon;
    final String role = isAdmin ? 'ADMIN KOMUTA' : 'GM OPERASYON';

    return SettingsGlassCard(
      accent: accent,
      glow: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SettingsPalette.ruby.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SettingsPalette.ruby.withValues(alpha: 0.55)),
                ),
                child: Text(
                  'CANLI MODERASYON',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.ruby,
                    fontSize: 9,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.shield_moon_rounded, color: accent, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            role,
            style: AppTextStyles.h3.copyWith(
              color: SettingsPalette.textHi,
              letterSpacing: 1.2,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAdmin
                ? 'Tam yetki · sezon · ödül · GM atama · bug elmas onayı'
                : 'Atanan izinlerle oyuncu · ticket · chat moderasyonu',
            style: supportCaptionStyle,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              StaffMiniStat(icon: Icons.confirmation_number_outlined, label: 'Ticket', value: openTickets, accent: SettingsPalette.neon),
              const SizedBox(width: 8),
              StaffMiniStat(icon: Icons.bug_report_outlined, label: 'Bug', value: pendingBugs, accent: SettingsPalette.gold),
              const SizedBox(width: 8),
              StaffMiniStat(icon: Icons.flag_outlined, label: 'Rapor', value: openChatReports, accent: SettingsPalette.fuchsia),
            ],
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
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: SettingsPalette.obsidian.withValues(alpha: 0.65),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: accent),
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
      ),
    );
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

/// Tab strip — ref 6 kategori chip'leri.
class StaffTabStrip extends StatelessWidget {
  const StaffTabStrip({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.accent = SettingsPalette.gold,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: List<Widget>.generate(tabs.length, (int i) {
          final bool selected = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SettingsPressable(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
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
                    color: selected ? accent.withValues(alpha: 0.7) : SettingsPalette.titanium.withValues(alpha: 0.25),
                    width: selected ? 1.4 : 1,
                  ),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 12),
                        ]
                      : null,
                ),
                child: Text(
                  tabs[i].toUpperCase(),
                  style: AppTextStyles.captionBold.copyWith(
                    color: selected ? accent : SettingsPalette.titanium,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
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
              onSelected: (_) => onSelected(opt),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        (label ?? status).toUpperCase(),
        style: AppTextStyles.captionBold.copyWith(color: accent, fontSize: 9, letterSpacing: 0.6),
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
          Icon(icon, size: 40, color: accent.withValues(alpha: 0.7)),
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
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool outlined;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color c = danger ? SettingsPalette.ruby : accent;
    if (outlined) {
      return SettingsPressable(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withValues(alpha: 0.55)),
            color: SettingsPalette.obsidian.withValues(alpha: 0.4),
          ),
          child: Text(
            label,
            style: AppTextStyles.captionBold.copyWith(color: c),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SettingsPrimaryButton(label: label, onPressed: onPressed);
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
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            showCloseButton ? 40 : 12,
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
                foregroundColor: SettingsPalette.void_,
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
                foregroundColor: SettingsPalette.void_,
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
              foregroundColor: SettingsPalette.void_,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: SettingsPressable(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('@$username', style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi)),
                    Text('$permCount izin', style: supportCaptionStyle),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.save_outlined, color: SettingsPalette.gold),
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
                    title: Text(p.label, style: supportBodyStyle.copyWith(fontSize: 13)),
                    subtitle: p.dangerous
                        ? Text('Tehlikeli', style: supportCaptionStyle.copyWith(color: SettingsPalette.ruby))
                        : null,
                    value: selected.contains(p.key),
                    onChanged: (bool? v) => onToggle(p.key, v == true),
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

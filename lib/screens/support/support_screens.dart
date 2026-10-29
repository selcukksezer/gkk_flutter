import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/services/app_haptics.dart';
import '../../providers/support_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/support_model.dart';
import 'widgets/support_design.dart';
import 'widgets/bug_report_reward.dart';
import 'widgets/support_screen_shell.dart';

String _formatDate(DateTime dt) {
  final String day = dt.day.toString().padLeft(2, '0');
  final String month = dt.month.toString().padLeft(2, '0');
  final String year = dt.year.toString();
  return '$day.$month.$year';
}

/// Category chip with luminous border and neon glow on selection.
class _SupportNeonCategoryChip extends StatelessWidget {
  const _SupportNeonCategoryChip({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? <Color>[
                    accent.withValues(alpha: 0.28),
                    SettingsPalette.obsidian.withValues(alpha: 0.95),
                  ]
                : <Color>[
                    SettingsPalette.navy.withValues(alpha: 0.45),
                    SettingsPalette.obsidian.withValues(alpha: 0.75),
                  ],
          ),
          border: Border.all(
            color: selected ? accent : accent.withValues(alpha: 0.22),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 15,
              color: selected ? accent : SettingsPalette.titanium,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                color: selected ? SettingsPalette.textHi : SettingsPalette.textMid,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact preset chip with glowing feedback.
class _SupportPresetChip extends StatelessWidget {
  const _SupportPresetChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? accent.withValues(alpha: 0.22)
              : SettingsPalette.obsidian.withValues(alpha: 0.6),
          border: Border.all(
            color: selected ? accent : SettingsPalette.titanium.withValues(alpha: 0.25),
            width: selected ? 1.2 : 1.0,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? SettingsPalette.textHi : SettingsPalette.textMid,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Luminous staff response indicator pill.
class _StaffResponseBadge extends StatelessWidget {
  const _StaffResponseBadge({this.label = 'Staff Yanıtı'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: <Color>[
            SettingsPalette.neon.withValues(alpha: 0.22),
            AppColors.accentBlue.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(
          color: SettingsPalette.neon.withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SettingsPalette.neon.withValues(alpha: 0.25),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.verified_user_rounded,
            size: 11,
            color: SettingsPalette.neon,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.neon,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status badge for support tickets with category color codes.
class _TicketStatusBadge extends StatelessWidget {
  const _TicketStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, IconData icon) = switch (status) {
      'open' => ('Açık', SettingsPalette.gold, Icons.hourglass_top_rounded),
      'in_progress' => ('İnceleniyor', AppColors.accentBlue, Icons.sync_rounded),
      'answered' => ('Yanıtlandı', SettingsPalette.neon, Icons.mark_chat_read_rounded),
      'resolved' => ('Çözüldü', SettingsPalette.neon, Icons.check_circle_outline_rounded),
      'closed' => ('Kapatıldı', SettingsPalette.titanium, Icons.lock_outline_rounded),
      'spam' => ('Spam', SettingsPalette.ruby, Icons.block_rounded),
      _ => (status, SettingsPalette.titanium, Icons.info_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: color,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status badge for bug reports.
class _BugReportStatusBadge extends StatelessWidget {
  const _BugReportStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, IconData icon) = switch (status) {
      'submitted' => ('Beklemede', AppColors.accentBlue, Icons.access_time_rounded),
      'triaged' => ('İnceleniyor', SettingsPalette.gold, Icons.search_rounded),
      'needs_info' => ('Ek Bilgi Gerekli', SettingsPalette.coral, Icons.help_outline_rounded),
      'approved' => ('Onaylandı', SettingsPalette.neon, Icons.verified_rounded),
      'rejected' => ('Reddedildi', SettingsPalette.ruby, Icons.cancel_outlined),
      'duplicate' => ('Duplike', SettingsPalette.titanium, Icons.copy_rounded),
      _ => (status, SettingsPalette.titanium, Icons.info_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: status == 'approved'
            ? <BoxShadow>[
                BoxShadow(
                  color: SettingsPalette.neon.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: color,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact category tag with icon.
class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category});

  final String category;

  static const Map<String, (String, IconData)> _meta = <String, (String, IconData)>{
    'account': ('Hesap', Icons.person_rounded),
    'payment': ('Ödeme', Icons.payments_rounded),
    'bug': ('Bug', Icons.bug_report_rounded),
    'abuse': ('Kötüye Kullanım', Icons.security_rounded),
    'crash': ('Çökme', Icons.warning_amber_rounded),
    'ui': ('Arayüz', Icons.layers_rounded),
    'economy': ('Ekonomi', Icons.monetization_on_rounded),
    'chat': ('Sohbet', Icons.chat_bubble_outline_rounded),
    'suggestion': ('Öneri', Icons.lightbulb_outline_rounded),
    'other': ('Diğer', Icons.tune_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon) = _meta[category] ?? (category, Icons.label_outline_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: SettingsPalette.navy.withValues(alpha: 0.5),
        border: Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: SettingsPalette.textMid),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: SettingsPalette.textMid,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Liquid gold gem reward pill.
class _GemRewardPill extends StatelessWidget {
  const _GemRewardPill({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: <Color>[
            SettingsPalette.gold.withValues(alpha: 0.28),
            AppColors.accentBlue.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(color: SettingsPalette.gold.withValues(alpha: 0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SettingsPalette.gold.withValues(alpha: 0.25),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.diamond_rounded, size: 11, color: SettingsPalette.gold),
          const SizedBox(width: 3),
          Text(
            '+$gems 💎',
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.gold,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggested gems pill.
class _SuggestedGemPill extends StatelessWidget {
  const _SuggestedGemPill({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: SettingsPalette.obsidian.withValues(alpha: 0.7),
        border: Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Öneri: $gems 💎',
        style: AppTextStyles.caption.copyWith(
          color: SettingsPalette.titanium,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

/// High-polish glassmorphism ticket card.
class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({
    required this.ticket,
    required this.onTap,
  });

  final SupportTicketSummary ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasStaffResponse =
        ticket.status == 'in_progress' || ticket.status == 'answered' || ticket.status == 'resolved';

    final Color accent = switch (ticket.status) {
      'resolved' || 'answered' => SettingsPalette.neon,
      'open' => SettingsPalette.gold,
      'in_progress' => AppColors.accentBlue,
      _ => SettingsPalette.titanium,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SettingsPressable(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: SettingsGlassCard(
          accent: accent,
          glow: hasStaffResponse,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 14.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: accent.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _TicketStatusBadge(status: ticket.status),
                  _CategoryTag(category: ticket.category),
                  if (hasStaffResponse)
                    const _StaffResponseBadge(label: 'Destek Yanıtı'),
                  if (ticket.createdAt != null)
                    Text(
                      _formatDate(ticket.createdAt!),
                      style: supportCaptionStyle.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// High-polish glassmorphism bug report card with staff review banner.
class _BugReportCard extends StatelessWidget {
  const _BugReportCard({
    required this.report,
    required this.onTap,
  });

  final BugReportSummary report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isApproved = report.status == 'approved';
    final bool hasReviewNote =
        report.reviewNote != null && report.reviewNote!.trim().isNotEmpty;

    final Color accent = switch (report.status) {
      'approved' => SettingsPalette.neon,
      'needs_info' => SettingsPalette.coral,
      'triaged' => SettingsPalette.gold,
      'rejected' => SettingsPalette.ruby,
      _ => AppColors.accentBlue,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SettingsPressable(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: SettingsGlassCard(
          accent: accent,
          glow: isApproved || hasReviewNote,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      report.title,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 14.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: accent.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _BugReportStatusBadge(status: report.status),
                  _CategoryTag(category: report.category),
                  if (report.rewardGemsApproved != null)
                    _GemRewardPill(gems: report.rewardGemsApproved!)
                  else if (report.suggestedGems != null)
                    _SuggestedGemPill(gems: report.suggestedGems!),
                  if (report.createdAt != null)
                    Text(
                      _formatDate(report.createdAt!),
                      style: supportCaptionStyle.copyWith(fontSize: 11),
                    ),
                ],
              ),
              if (hasReviewNote) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: <Color>[
                        SettingsPalette.neon.withValues(alpha: 0.12),
                        SettingsPalette.obsidian.withValues(alpha: 0.6),
                      ],
                    ),
                    border: Border.all(
                      color: SettingsPalette.neon.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.shield_rounded,
                        size: 14,
                        color: SettingsPalette.neon,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Staff Notu: ${report.reviewNote}',
                          style: AppTextStyles.caption.copyWith(
                            color: SettingsPalette.textHi,
                            fontSize: 11.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SupportTicketListScreen extends ConsumerStatefulWidget {
  const SupportTicketListScreen({super.key});

  @override
  ConsumerState<SupportTicketListScreen> createState() => _SupportTicketListScreenState();
}

class _SupportTicketListScreenState extends ConsumerState<SupportTicketListScreen> {
  List<SupportTicketSummary> _items = <SupportTicketSummary>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<SupportTicketSummary> items =
        await ref.read(supportProvider.notifier).loadMyTickets();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SupportScreenShell(
      title: 'Destek Talepleri',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SettingsPalette.gold,
        foregroundColor: SettingsPalette.void_,
        onPressed: () {
          AppHaptics.selection();
          context.push(AppRoutes.createTicket).then((_) => _load());
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Yeni Ticket',
          style: AppTextStyles.button.copyWith(
            color: SettingsPalette.void_,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SettingsPalette.gold))
          : RefreshIndicator(
              color: SettingsPalette.gold,
              onRefresh: _load,
              child: ListView(
                padding: GameScrollLayout.padding(context, bottomExtra: 72),
                children: <Widget>[
                  const SettingsSectionHeader(
                    icon: Icons.support_agent_rounded,
                    title: 'Ticketlarım',
                    subtitle: 'Destek ekibi yanıtlarını buradan takip et',
                    accent: SettingsPalette.neon,
                  ),
                  const SizedBox(height: 14),
                  if (_items.isEmpty)
                    SettingsGlassCard(
                      accent: SettingsPalette.titanium,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: SettingsPalette.navy.withValues(alpha: 0.8),
                                border: Border.all(
                                  color: SettingsPalette.titanium.withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.inbox_rounded,
                                size: 26,
                                color: SettingsPalette.titanium,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Henüz ticket yok',
                              style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sorun yaşarsan veya bir sorun olursa yeni ticket açabilirsin.',
                              textAlign: TextAlign.center,
                              style: supportCaptionStyle,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._items.map(
                      (SupportTicketSummary t) => _SupportTicketCard(
                        ticket: t,
                        onTap: () => context.push('${AppRoutes.supportTickets}/${t.id}').then((_) => _load()),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  String _category = 'other';
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _isValid => _subject.text.trim().isNotEmpty && _body.text.trim().length >= 20;

  Future<void> _submit() async {
    final String subject = _subject.text.trim();
    final String body = _body.text.trim();

    if (subject.isEmpty) {
      AppHaptics.heavy();
      AppMessenger.showError(context, 'Lütfen konu başlığı girin.');
      return;
    }
    if (body.length < 20) {
      AppHaptics.heavy();
      AppMessenger.showError(context, 'Açıklama en az 20 karakter olmalıdır.');
      return;
    }

    AppHaptics.medium();
    setState(() => _busy = true);
    final String? err = await ref.read(supportProvider.notifier).createTicket(
          category: _category,
          subject: subject,
          body: body,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppHaptics.heavy();
      AppMessenger.showError(context, err);
    } else {
      AppHaptics.success();
      AppMessenger.showSuccess(context, 'Destek talebi başarıyla oluşturuldu.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int bodyLength = _body.text.trim().length;
    final bool bodyValid = bodyLength >= 20;

    return SupportScreenShell(
      title: 'Ticket Aç',
      fallbackRoute: AppRoutes.supportTickets,
      body: ListView(
        padding: GameScrollLayout.padding(context),
        children: <Widget>[
          const SettingsSectionHeader(
            icon: Icons.add_comment_rounded,
            title: 'Yeni destek talebi',
            subtitle: 'En kısa sürede incelenip yanıtlanacaktır',
            accent: SettingsPalette.neon,
          ),
          const SizedBox(height: 16),
          SettingsGlassCard(
            accent: SettingsPalette.gold,
            glow: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'KATEGORİ SEÇİN',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.titanium,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _SupportNeonCategoryChip(
                      label: 'Hesap',
                      icon: Icons.person_rounded,
                      accent: AppColors.accentBlue,
                      selected: _category == 'account',
                      onTap: () => setState(() => _category = 'account'),
                    ),
                    _SupportNeonCategoryChip(
                      label: 'Ödeme',
                      icon: Icons.payments_rounded,
                      accent: SettingsPalette.gold,
                      selected: _category == 'payment',
                      onTap: () => setState(() => _category = 'payment'),
                    ),
                    _SupportNeonCategoryChip(
                      label: 'Bug',
                      icon: Icons.bug_report_rounded,
                      accent: SettingsPalette.coral,
                      selected: _category == 'bug',
                      onTap: () => setState(() => _category = 'bug'),
                    ),
                    _SupportNeonCategoryChip(
                      label: 'Kötüye Kullanım',
                      icon: Icons.security_rounded,
                      accent: SettingsPalette.ruby,
                      selected: _category == 'abuse',
                      onTap: () => setState(() => _category = 'abuse'),
                    ),
                    _SupportNeonCategoryChip(
                      label: 'Diğer',
                      icon: Icons.tune_rounded,
                      accent: SettingsPalette.neon,
                      selected: _category == 'other',
                      onTap: () => setState(() => _category = 'other'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _subject,
                  style: supportBodyStyle,
                  onChanged: (_) => setState(() {}),
                  decoration: supportInputDecoration(
                    label: 'Konu',
                    hint: 'Sorununuzu kısaca özetleyin',
                  ).copyWith(
                    prefixIcon: const Icon(
                      Icons.edit_note_rounded,
                      color: SettingsPalette.gold,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _body,
                  style: supportBodyStyle,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: supportInputDecoration(
                    label: 'Açıklama (min 20 karakter)',
                    hint: 'Sorunu ayrıntılı şekilde anlatın...',
                  ).copyWith(
                    prefixIcon: const Icon(
                      Icons.subject_rounded,
                      color: SettingsPalette.gold,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Icon(
                      bodyValid
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 13,
                      color: bodyValid ? SettingsPalette.neon : SettingsPalette.ruby,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bodyValid
                          ? 'Açıklama uzunluğu uygun ($bodyLength kr.)'
                          : 'Min 20 karakter gerekli ($bodyLength/20)',
                      style: AppTextStyles.caption.copyWith(
                        color: bodyValid ? SettingsPalette.neon : SettingsPalette.ruby,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SettingsPrimaryButton(
                  label: _busy ? 'Gönderiliyor…' : 'Talebi Gönder',
                  icon: Icons.send_rounded,
                  onPressed: (_busy || !_isValid) ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  String _category = 'other';
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _steps = TextEditingController();
  bool _busy = false;

  static const Map<String, List<String>> _titlePresets = <String, List<String>>{
    'crash': <String>['Uygulama çöküyor', 'Siyah ekran', 'Giriş yapılamıyor', 'Savaşta donma'],
    'ui': <String>['Buton çalışmıyor', 'Metin taşıyor', 'Görsel hata', 'Menü açılmıyor'],
    'economy': <String>['Item kayboldu', 'Yanlış fiyat', 'Ödül gelmedi', 'Envanter hatası'],
    'chat': <String>['Spam / taciz', 'Mesaj gitmiyor', 'Filtre sorunu'],
    'suggestion': <String>[
      'Yeni özellik önerisi',
      'UI iyileştirme',
      'Etkinlik fikri',
      'Ekonomi dengesi',
      'Oyun dengesi',
      'Sosyal özellik',
      'Kalite of life',
    ],
    'other': <String>['Genel bug', 'Diğer'],
  };

  List<String> get _currentTitlePresets => _titlePresets[_category] ?? _titlePresets['other']!;

  bool get _isValid => _title.text.trim().isNotEmpty && _description.text.trim().length >= 30;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String title = _title.text.trim();
    final String description = _description.text.trim();

    if (title.isEmpty) {
      AppHaptics.heavy();
      AppMessenger.showError(context, 'Lütfen bir başlık girin veya seçin.');
      return;
    }
    if (description.length < 30) {
      AppHaptics.heavy();
      AppMessenger.showError(context, 'Açıklama en az 30 karakter olmalıdır.');
      return;
    }

    AppHaptics.medium();
    setState(() => _busy = true);
    final String? err = await ref.read(supportProvider.notifier).submitBugReport(
          category: _category,
          title: title,
          description: description,
          reproSteps: _steps.text.trim().isEmpty ? null : _steps.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppHaptics.heavy();
      AppMessenger.showError(context, err);
    } else {
      AppHaptics.success();
      AppMessenger.showSuccess(context, 'Bug raporu gönderildi. Teşekkürler!');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int descLength = _description.text.trim().length;
    final bool descValid = descLength >= 30;

    return SupportScreenShell(
      title: 'Bug / Öneri',
      body: ListView(
        padding: GameScrollLayout.padding(context),
        children: <Widget>[
          SettingsPressable(
            onTap: () => showBugReportRewardInfoDialog(context),
            child: SettingsGlassCard(
              accent: AppColors.accentBlue,
              glow: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Bug bildir veya öneride bulun',
                          style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Onaylanan raporlar için elmas ödülü. Detay için dokun.',
                          style: supportCaptionStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const BugReportGemRangeBadge(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SettingsGlassCard(
            accent: SettingsPalette.fuchsia,
            child: Text(
              'Doğrulama sonrası uygun bulunursa ${BugReportReward.minGems}–${BugReportReward.maxGems} elmas verilebilir. '
              'App Store/Play yorumu karşılığı ödül talep edilemez.',
              style: AppTextStyles.caption.copyWith(color: SettingsPalette.textMid, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          SettingsGlassCard(
            accent: SettingsPalette.coral,
            glow: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'KATEGORİ SEÇİN',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.titanium,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _SupportNeonCategoryChip(
                      label: 'Çökme',
                      icon: Icons.warning_amber_rounded,
                      accent: SettingsPalette.ruby,
                      selected: _category == 'crash',
                      onTap: () => setState(() => _category = 'crash'),
                    ),
                    _SupportNeonCategoryChip(
                      label: 'Arayüz',
                      icon: Icons.layers_rounded,
                      accent: SettingsPalette.fuchsia,
                      selected: _category == 'ui',
                      onTap: () => setState(() => _category = 'ui'),
                    ),
                    _SupportNeonCategoryChip(
                      label: 'Ekonomi',
                      icon: Icons.monetization_on_rounded,
                      accent: SettingsPalette.gold,
                      selected: _category == 'economy',
                      onTap: () => setState(() => _category = 'economy'),
                    ),
                    _SupportNeonCategoryChip(
                      label: 'Sohbet',
                      icon: Icons.chat_bubble_outline_rounded,
                      accent: AppColors.accentBlue,
                      selected: _category == 'chat',
                      onTap: () => setState(() => _category = 'chat'),
                    ),
                    _SupportNeonCategoryChip(
                      label: 'Öneri',
                      icon: Icons.lightbulb_outline_rounded,
                      accent: SettingsPalette.neon,
                      selected: _category == 'suggestion',
                      onTap: () => setState(() => _category = 'suggestion'),
                    ),
                    _SupportNeonCategoryChip(
                      label: 'Diğer',
                      icon: Icons.tune_rounded,
                      accent: SettingsPalette.titanium,
                      selected: _category == 'other',
                      onTap: () => setState(() => _category = 'other'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'HIZLI BAŞLIK SEÇİMİ',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.titanium,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _currentTitlePresets.map((String preset) {
                    final bool selected = _title.text.trim() == preset;
                    return _SupportPresetChip(
                      label: preset,
                      selected: selected,
                      accent: SettingsPalette.coral,
                      onTap: () => setState(() => _title.text = preset),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _title,
                  style: supportBodyStyle,
                  onChanged: (_) => setState(() {}),
                  decoration: supportInputDecoration(
                    label: 'Başlık',
                    hint: 'Hatanın veya önerinin kısa adı',
                  ).copyWith(
                    prefixIcon: const Icon(
                      Icons.title_rounded,
                      color: SettingsPalette.coral,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _description,
                  style: supportBodyStyle,
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                  decoration: supportInputDecoration(
                    label: 'Açıklama (min 30 karakter)',
                    hint: 'Sorunu veya öneriyi ayrıntılı şekilde tarif edin...',
                  ).copyWith(
                    prefixIcon: const Icon(
                      Icons.description_rounded,
                      color: SettingsPalette.coral,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Icon(
                      descValid
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 13,
                      color: descValid ? SettingsPalette.neon : SettingsPalette.ruby,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      descValid
                          ? 'Açıklama uzunluğu uygun ($descLength kr.)'
                          : 'Min 30 karakter gerekli ($descLength/30)',
                      style: AppTextStyles.caption.copyWith(
                        color: descValid ? SettingsPalette.neon : SettingsPalette.ruby,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _steps,
                  style: supportBodyStyle,
                  maxLines: 4,
                  decoration: supportInputDecoration(
                    label: 'Tekrar adımları (opsiyonel)',
                    hint: '1. Adım\n2. Adım\n3. Adım',
                  ).copyWith(
                    prefixIcon: const Icon(
                      Icons.format_list_numbered_rounded,
                      color: SettingsPalette.coral,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SettingsPrimaryButton(
                  label: _busy ? 'Gönderiliyor…' : 'Raporu Gönder',
                  icon: Icons.bug_report_rounded,
                  onPressed: (_busy || !_isValid) ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyBugReportsScreen extends ConsumerStatefulWidget {
  const MyBugReportsScreen({super.key});

  @override
  ConsumerState<MyBugReportsScreen> createState() => _MyBugReportsScreenState();
}

class _MyBugReportsScreenState extends ConsumerState<MyBugReportsScreen> {
  List<BugReportSummary> _items = <BugReportSummary>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<BugReportSummary> items =
        await ref.read(supportProvider.notifier).loadMyBugReports();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SupportScreenShell(
      title: 'Bug Raporlarım',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SettingsPalette.gold,
        foregroundColor: SettingsPalette.void_,
        onPressed: () {
          AppHaptics.selection();
          context.push(AppRoutes.bugReport).then((_) => _load());
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Yeni Rapor',
          style: AppTextStyles.button.copyWith(
            color: SettingsPalette.void_,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SettingsPalette.gold))
          : RefreshIndicator(
              color: SettingsPalette.gold,
              onRefresh: _load,
              child: ListView(
                padding: GameScrollLayout.padding(context, bottomExtra: 72),
                children: <Widget>[
                  const SettingsSectionHeader(
                    icon: Icons.bug_report_rounded,
                    title: 'Bug / öneri raporları',
                    subtitle: 'Onay sonrası elmas ödülü çana da düşer',
                    accent: SettingsPalette.gold,
                  ),
                  const SizedBox(height: 14),
                  if (_items.isEmpty)
                    SettingsGlassCard(
                      accent: SettingsPalette.titanium,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: SettingsPalette.navy.withValues(alpha: 0.8),
                                border: Border.all(
                                  color: SettingsPalette.gold.withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.bug_report_outlined,
                                size: 26,
                                color: SettingsPalette.gold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Henüz bug veya öneri raporun yok',
                              style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Karşılaştığın hataları veya geliştirme önerilerini göndererek elmas kazanabilirsin.',
                              textAlign: TextAlign.center,
                              style: supportCaptionStyle,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._items.map(
                      (BugReportSummary b) => _BugReportCard(
                        report: b,
                        onTap: () => context.push('${AppRoutes.myBugReports}/${b.id}').then((_) => _load()),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

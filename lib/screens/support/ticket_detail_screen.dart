import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/services/supabase_service.dart';
import '../../models/support_detail_model.dart';
import '../../models/support_model.dart';
import '../../providers/staff_provider.dart';
import '../../providers/support_provider.dart';
import '../../repositories/staff_repository.dart';
import '../../routing/app_router.dart';
import '../../theme/app_text_styles.dart';
import '../staff/widgets/staff_design.dart';
import 'widgets/support_design.dart';
import 'widgets/support_screen_shell.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  SupportTicketDetail? _detail;
  bool _loading = true;
  final TextEditingController _reply = TextEditingController();
  bool _busy = false;
  final StaffRepository _staffRepo = StaffRepository();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final SupportTicketDetail? detail =
        await ref.read(supportProvider.notifier).loadTicketDetail(widget.ticketId);
    if (mounted) setState(() { _detail = detail; _loading = false; });
  }

  Future<void> _sendReply() async {
    if (_reply.text.trim().length < 2) return;
    setState(() => _busy = true);
    final bool isStaff = ref.read(staffProvider).profile.has('ticket.view_all');
    final String? err = isStaff
        ? await ref.read(supportProvider.notifier).staffReplyTicket(widget.ticketId, _reply.text)
        : await ref.read(supportProvider.notifier).replyTicket(widget.ticketId, _reply.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      _reply.clear();
      await _load();
    }
  }

  Future<void> _assignToMe() async {
    final String? uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _busy = true);
    final String? err = await _staffRepo.assignTicket(widget.ticketId, uid);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    AppMessenger.showSuccess(context, 'Ticket üstlenildi.');
    await _load();
  }

  Future<void> _closeTicket(String status) async {
    final String? err = await ref
        .read(supportProvider.notifier)
        .staffUpdateTicketStatus(widget.ticketId, status);
    if (!mounted) return;
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      AppMessenger.showSuccess(context, 'Durum güncellendi.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isStaff = ref.watch(staffProvider).profile.has('ticket.view_all');
    final bool canReplyStaff = ref.watch(staffProvider).profile.has('ticket.reply');
    final bool canClose = ref.watch(staffProvider).profile.has('ticket.close');

    if (_loading) {
      return const SupportScreenShell(
        title: 'Ticket',
        fallbackRoute: AppRoutes.supportTickets,
        body: Center(child: CircularProgressIndicator(color: SettingsPalette.gold)),
      );
    }

    final SupportTicketDetail? detail = _detail;
    if (detail == null) {
      return const SupportScreenShell(
        title: 'Ticket',
        fallbackRoute: AppRoutes.supportTickets,
        body: Center(child: Text('Ticket bulunamadı.', style: TextStyle(color: SettingsPalette.textMid))),
      );
    }

    final SupportTicketSummary t = detail.ticket;

    return SupportScreenShell(
      title: t.subject.length > 28 ? '${t.subject.substring(0, 28)}…' : t.subject,
      fallbackRoute: AppRoutes.supportTickets,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SettingsGlassCard(
              accent: SettingsPalette.neon,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${t.category} · ${t.status}', style: supportCaptionStyle),
                  if (isStaff) ...<Widget>[
                    const SizedBox(height: 10),
                    StaffActionButton(
                      label: 'Üstlen',
                      outlined: true,
                      accent: SettingsPalette.neon,
                      onPressed: _busy ? null : _assignToMe,
                    ),
                  ],
                  if (isStaff && canClose) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _statusChip('Çözüldü', () => _closeTicket('resolved'), SettingsPalette.neon),
                        _statusChip('Kapat', () => _closeTicket('closed'), SettingsPalette.gold),
                        _statusChip('Spam', () => _closeTicket('spam'), SettingsPalette.ruby),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: GameScrollLayout.padding(context, top: 12),
              itemCount: detail.messages.length,
              itemBuilder: (BuildContext context, int i) {
                final SupportTicketMessage m = detail.messages[i];
                final bool staffMsg = m.isStaff;
                return Align(
                  alignment: staffMsg ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: staffMsg
                            ? <Color>[
                                SettingsPalette.navy.withValues(alpha: 0.95),
                                SettingsPalette.obsidian.withValues(alpha: 0.9),
                              ]
                            : <Color>[
                                SettingsPalette.fuchsia.withValues(alpha: 0.35),
                                SettingsPalette.navy.withValues(alpha: 0.85),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (staffMsg ? SettingsPalette.neon : SettingsPalette.fuchsia)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(m.body, style: supportBodyStyle.copyWith(fontSize: 13)),
                  ),
                );
              },
            ),
          ),
          if (!isStaff || canReplyStaff)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, GameScrollLayout.bottomInset(context) * 0.15),
              child: SettingsGlassCard(
                accent: SettingsPalette.gold,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        style: supportBodyStyle,
                        decoration: supportInputDecoration(label: 'Yanıt yaz…'),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : _sendReply,
                      icon: Icon(Icons.send_rounded, color: SettingsPalette.gold.withValues(alpha: _busy ? 0.4 : 1)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, VoidCallback onTap, Color accent) {
    return SettingsPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.7)),
          color: accent.withValues(alpha: 0.12),
        ),
        child: Text(
          label,
          style: AppTextStyles.captionBold.copyWith(color: accent, fontSize: 12),
        ),
      ),
    );
  }
}

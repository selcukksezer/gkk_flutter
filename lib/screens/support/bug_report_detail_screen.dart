import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/support_detail_model.dart';
import '../../providers/support_provider.dart';
import '../../theme/app_text_styles.dart';
import 'widgets/support_design.dart';
import 'widgets/support_screen_shell.dart';

class PlayerBugReportDetailScreen extends ConsumerStatefulWidget {
  const PlayerBugReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<PlayerBugReportDetailScreen> createState() => _PlayerBugReportDetailScreenState();
}

class _PlayerBugReportDetailScreenState extends ConsumerState<PlayerBugReportDetailScreen> {
  PlayerBugReportDetail? _detail;
  bool _loading = true;
  bool _busy = false;
  final TextEditingController _followup = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _followup.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final PlayerBugReportDetail? detail =
        await ref.read(supportProvider.notifier).loadPlayerBugDetail(widget.reportId);
    if (mounted) {
      setState(() {
        _detail = detail;
        _loading = false;
      });
    }
  }

  Future<void> _sendFollowup() async {
    if (_followup.text.trim().length < 10) {
      AppMessenger.showError(context, 'Ek bilgi en az 10 karakter olmalı.');
      return;
    }
    setState(() => _busy = true);
    final String? err = await ref.read(supportProvider.notifier).appendBugFollowup(
          widget.reportId,
          _followup.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    _followup.clear();
    AppMessenger.showSuccess(context, 'Ek bilgi gönderildi.');
    await _load();
  }

  String _statusLabel(String status) => switch (status) {
        'submitted' => 'Beklemede',
        'triaged' => 'İnceleniyor',
        'needs_info' => 'Ek bilgi gerekli',
        'approved' => 'Onaylandı',
        'rejected' => 'Reddedildi',
        'duplicate' => 'Duplike',
        _ => status,
      };

  String _categoryLabel(String category) => switch (category) {
        'crash' => 'Çökme',
        'ui' => 'Arayüz',
        'economy' => 'Ekonomi',
        'chat' => 'Sohbet',
        'suggestion' => 'Öneri',
        _ => 'Diğer',
      };

  Widget _messageBubble({required String body, required bool isStaff, DateTime? at}) {
    final Color accent = isStaff ? SettingsPalette.gold : SettingsPalette.neon;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SettingsGlassCard(
        accent: accent,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(isStaff ? 'Staff' : 'Sen', style: supportCaptionStyle.copyWith(color: accent)),
            const SizedBox(height: 4),
            Text(body, style: supportBodyStyle),
            if (at != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${at.toLocal()}'.substring(0, 16),
                  style: supportCaptionStyle.copyWith(fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlayerBugReportDetail? detail = _detail;
    final bool needsInfo = detail?.report.status == 'needs_info';

    return SupportScreenShell(
      title: 'Bug raporu',
      fallbackRoute: '/support/my-bug-reports',
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SettingsPalette.gold))
          : detail == null
              ? Center(child: Text('Rapor yüklenemedi', style: supportBodyStyle))
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: RefreshIndicator(
                        color: SettingsPalette.gold,
                        onRefresh: _load,
                        child: ListView(
                          padding: GameScrollLayout.padding(context, bottomExtra: 16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: <Widget>[
                            SettingsSectionHeader(
                              icon: Icons.bug_report_rounded,
                              title: detail.report.title,
                              subtitle: '${_categoryLabel(detail.report.category)} · ${_statusLabel(detail.report.status)}',
                              accent: needsInfo ? SettingsPalette.gold : SettingsPalette.fuchsia,
                            ),
                            if (detail.report.reviewNote != null && detail.report.reviewNote!.trim().isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              SettingsGlassCard(
                                accent: SettingsPalette.gold,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text('Staff notu', style: AppTextStyles.captionBold.copyWith(color: SettingsPalette.gold)),
                                    const SizedBox(height: 6),
                                    Text(detail.report.reviewNote!, style: supportBodyStyle),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (detail.report.description != null && detail.report.description!.isNotEmpty)
                              _messageBubble(
                                body: detail.report.description!,
                                isStaff: false,
                                at: detail.report.createdAt,
                              ),
                            if (detail.report.reproSteps != null && detail.report.reproSteps!.isNotEmpty)
                              _messageBubble(body: 'Adımlar:\n${detail.report.reproSteps}', isStaff: false),
                            ...detail.followups.map(
                              (BugReportFollowup f) => _messageBubble(
                                body: f.body,
                                isStaff: f.isStaff,
                                at: f.createdAt,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (needsInfo)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: GameScrollLayout.padding(context, top: 0, bottomExtra: 8),
                          child: SettingsGlassCard(
                            accent: SettingsPalette.gold,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  'Ek bilgi yaz — aynı rapor güncellenir, yeni rapor açılmaz.',
                                  style: supportCaptionStyle.copyWith(color: SettingsPalette.gold),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _followup,
                                  style: supportBodyStyle,
                                  maxLines: 4,
                                  decoration: supportInputDecoration(label: 'Ek açıklama (min 10 karakter)'),
                                ),
                                const SizedBox(height: 10),
                                SettingsPrimaryButton(
                                  label: _busy ? 'Gönderiliyor…' : 'Ek bilgi gönder',
                                  onPressed: _busy ? null : _sendFollowup,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

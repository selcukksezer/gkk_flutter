import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../providers/support_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/support_model.dart';
import 'widgets/support_design.dart';
import 'widgets/bug_report_reward.dart';
import 'widgets/support_screen_shell.dart';

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
        onPressed: () => context.push(AppRoutes.createTicket).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('Yeni ticket'),
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
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    SettingsGlassCard(
                      accent: SettingsPalette.fuchsia,
                      child: Text(
                        'Henüz ticket yok. Sorun yaşarsan yeni ticket aç.',
                        style: supportCaptionStyle,
                      ),
                    )
                  else
                    ..._items.map(
                      (SupportTicketSummary t) => SupportListTileCard(
                        title: t.subject,
                        subtitle: '${t.category} · ${t.status}',
                        accent: SettingsPalette.neon,
                        onTap: () => context.push('${AppRoutes.supportTickets}/${t.id}'),
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

  Future<void> _submit() async {
    setState(() => _busy = true);
    final String? err = await ref.read(supportProvider.notifier).createTicket(
          category: _category,
          subject: _subject.text,
          body: _body.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      AppMessenger.showSuccess(context, 'Ticket oluşturuldu.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SupportScreenShell(
      title: 'Ticket Aç',
      fallbackRoute: AppRoutes.supportTickets,
      body: ListView(
        padding: GameScrollLayout.padding(context),
        children: <Widget>[
          const SettingsSectionHeader(
            icon: Icons.add_comment_rounded,
            title: 'Yeni destek talebi',
            subtitle: 'Min 20 karakter açıklama',
            accent: SettingsPalette.neon,
          ),
          const SizedBox(height: 16),
          SettingsGlassCard(
            accent: SettingsPalette.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: SettingsPalette.navy,
                  style: supportBodyStyle,
                  decoration: supportInputDecoration(label: 'Kategori'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'account', child: Text('Hesap')),
                    DropdownMenuItem(value: 'payment', child: Text('Ödeme')),
                    DropdownMenuItem(value: 'bug', child: Text('Bug')),
                    DropdownMenuItem(value: 'abuse', child: Text('Kötüye kullanım')),
                    DropdownMenuItem(value: 'other', child: Text('Diğer')),
                  ],
                  onChanged: (String? v) => setState(() => _category = v ?? 'other'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subject,
                  style: supportBodyStyle,
                  decoration: supportInputDecoration(label: 'Konu'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _body,
                  style: supportBodyStyle,
                  decoration: supportInputDecoration(label: 'Açıklama (min 20 karakter)'),
                  maxLines: 6,
                ),
                const SizedBox(height: 16),
                SettingsPrimaryButton(
                  label: _busy ? 'Gönderiliyor…' : 'Gönder',
                  onPressed: _busy ? null : _submit,
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

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final String? err = await ref.read(supportProvider.notifier).submitBugReport(
          category: _category,
          title: _title.text,
          description: _description.text,
          reproSteps: _steps.text.isEmpty ? null : _steps.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      AppMessenger.showSuccess(context, 'Bug raporu gönderildi.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          'Bug bildir yada öneride bulun',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: SettingsPalette.navy,
                  style: supportBodyStyle,
                  decoration: supportInputDecoration(label: 'Kategori'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'crash', child: Text('Çökme')),
                    DropdownMenuItem(value: 'ui', child: Text('Arayüz')),
                    DropdownMenuItem(value: 'economy', child: Text('Ekonomi')),
                    DropdownMenuItem(value: 'chat', child: Text('Sohbet')),
                    DropdownMenuItem(value: 'suggestion', child: Text('Öneri')),
                    DropdownMenuItem(value: 'other', child: Text('Diğer')),
                  ],
                  onChanged: (String? v) => setState(() => _category = v ?? 'other'),
                ),
                const SizedBox(height: 12),
                Text('Başlık seç', style: supportCaptionStyle),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _currentTitlePresets.map((String preset) {
                    final bool selected = _title.text.trim() == preset;
                    return ChoiceChip(
                      label: Text(preset, style: supportCaptionStyle),
                      selected: selected,
                      selectedColor: SettingsPalette.fuchsia.withValues(alpha: 0.35),
                      backgroundColor: SettingsPalette.obsidian.withValues(alpha: 0.6),
                      onSelected: (_) => setState(() => _title.text = preset),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  style: supportBodyStyle,
                  decoration: supportInputDecoration(label: 'Başlık'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  style: supportBodyStyle,
                  decoration: supportInputDecoration(label: 'Açıklama (min 30 karakter)'),
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _steps,
                  style: supportBodyStyle,
                  decoration: supportInputDecoration(label: 'Tekrar adımları (opsiyonel)'),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                SettingsPrimaryButton(
                  label: _busy ? 'Gönderiliyor…' : 'Gönder',
                  onPressed: _busy ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _bugStatusLabel(String status) {
  return switch (status) {
    'submitted' => 'Beklemede',
    'triaged' => 'İnceleniyor',
    'needs_info' => 'Ek bilgi gerekli',
    'approved' => 'Onaylandı',
    'rejected' => 'Reddedildi',
    'duplicate' => 'Duplike',
    _ => status,
  };
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
        onPressed: () => context.push(AppRoutes.bugReport).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('Yeni rapor'),
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
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    SettingsGlassCard(
                      accent: SettingsPalette.fuchsia,
                      child: Text(
                        'Henüz rapor yok. Bug veya öneri gönder.',
                        style: supportCaptionStyle,
                      ),
                    )
                  else
                    ..._items.map((BugReportSummary b) {
                      final StringBuffer subtitle = StringBuffer(_bugStatusLabel(b.status));
                      if (b.rewardGemsApproved != null) {
                        subtitle.write(' · +${b.rewardGemsApproved}💎');
                      } else if (b.suggestedGems != null) {
                        subtitle.write(' · öneri ${b.suggestedGems}💎');
                      }
                      if (b.reviewNote != null && b.reviewNote!.trim().isNotEmpty) {
                        subtitle.write(' · ${b.reviewNote}');
                      }
                      return SupportListTileCard(
                        title: b.title,
                        subtitle: subtitle.toString(),
                        accent: b.status == 'approved'
                            ? SettingsPalette.neon
                            : b.status == 'needs_info'
                            ? SettingsPalette.gold
                            : SettingsPalette.fuchsia,
                        onTap: () => context.push('${AppRoutes.myBugReports}/${b.id}'),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

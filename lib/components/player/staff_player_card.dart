import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/staff_model.dart';
import '../../screens/staff/widgets/staff_design.dart';
import '../../screens/support/widgets/support_design.dart';
import '../../theme/app_text_styles.dart';
import 'staff_badge.dart';

class StaffPlayerCard extends StatelessWidget {
  const StaffPlayerCard({
    super.key,
    required this.player,
    this.loading = false,
    this.onExtendHospital,
    this.onShortenHospital,
    this.onReleaseHospital,
    this.onExtendPrison,
    this.onShortenPrison,
    this.onReleasePrison,
    this.onReleaseTradeBan,
    this.onUnban,
    this.onReleaseChatMute,
  });

  final StaffPlayerDetail player;
  final bool loading;
  final VoidCallback? onExtendHospital;
  final VoidCallback? onShortenHospital;
  final VoidCallback? onReleaseHospital;
  final VoidCallback? onExtendPrison;
  final VoidCallback? onShortenPrison;
  final VoidCallback? onReleasePrison;
  final VoidCallback? onReleaseTradeBan;
  final VoidCallback? onUnban;
  final VoidCallback? onReleaseChatMute;

  static final DateFormat _dateFmt = DateFormat('dd.MM.yyyy HH:mm');
  static final NumberFormat _numFmt = NumberFormat('#,###', 'tr_TR');

  String _fmt(num? value) => value == null ? '—' : _numFmt.format(value);

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return _dateFmt.format(dt.toLocal());
  }

  String _fmtDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '—';
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (h > 24) return '${h ~/ 24}g ${h % 24}s';
    if (h > 0) return '${h}s ${m}dk';
    return '${m}dk';
  }

  Widget _statChip(String label, String value, {Color? accent}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: SettingsPalette.obsidian.withValues(alpha: 0.55),
          border: Border.all(color: (accent ?? SettingsPalette.titanium).withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: supportCaptionStyle.copyWith(fontSize: 9)),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyBold.copyWith(
                color: accent ?? SettingsPalette.textHi,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner({
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
    List<({String label, VoidCallback? onTap})> actions = const <({String label, VoidCallback? onTap})>[],
  }) {
    final Iterable<({String label, VoidCallback? onTap})> visibleActions =
        actions.where((({String label, VoidCallback? onTap}) action) => action.onTap != null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SettingsGlassCard(
        accent: accent,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi, fontSize: 13)),
                      Text(subtitle, style: supportCaptionStyle),
                    ],
                  ),
                ),
              ],
            ),
            if (visibleActions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final ({String label, VoidCallback? onTap}) action in visibleActions)
                    StaffActionButton(
                      label: action.label,
                      outlined: true,
                      accent: SettingsPalette.neon,
                      onPressed: action.onTap,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: SettingsPalette.gold, strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsGlassCard(
          accent: SettingsPalette.neon,
          glow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          player.displayName ?? player.username,
                          style: AppTextStyles.h3.copyWith(color: SettingsPalette.textHi, fontSize: 18),
                        ),
                        Text('@${player.username}', style: supportCaptionStyle),
                        const SizedBox(height: 4),
                        Text(
                          'Lv${player.level ?? '?'} · ${player.classLabelTr} · Güç ${player.power ?? 0}',
                          style: supportBodyStyle.copyWith(color: SettingsPalette.gold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (player.staffBadge != null) StaffBadge(badge: player.staffBadge),
                  if (player.kingBadge != null) StaffBadge(badge: player.kingBadge),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  if (player.isOnline)
                    const StaffStatusPill(status: 'approved', label: 'Çevrimiçi')
                  else
                    StaffStatusPill(status: 'closed', label: 'Çevrimdışı'),
                  if (player.isAccountBanned) const StaffStatusPill(status: 'banned', label: 'Banlı'),
                  if (player.inHospital) const StaffStatusPill(status: 'needs_info', label: 'Hastane'),
                  if (player.inPrison) const StaffStatusPill(status: 'rejected', label: 'Hapishane'),
                  if (player.isTradeBanned) const StaffStatusPill(status: 'closed', label: 'Ticaret ban'),
                  if (player.isChatMuted) const StaffStatusPill(status: 'closed', label: 'Chat mute'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('Ekonomi', style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold)),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _statChip('Altın', _fmt(player.gold), accent: SettingsPalette.gold),
            const SizedBox(width: 6),
            _statChip('Elmas', _fmt(player.gems), accent: SettingsPalette.fuchsia),
            const SizedBox(width: 6),
            _statChip('İtibar', _fmt(player.reputation), accent: SettingsPalette.neon),
          ],
        ),
        const SizedBox(height: 10),
        Text('Can & enerji', style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold)),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _statChip('Enerji', '${player.energy ?? 0}/${player.maxEnergy ?? 0}', accent: SettingsPalette.coral),
            const SizedBox(width: 6),
            _statChip('Can', '${player.health ?? 0}/${player.maxHealth ?? 0}', accent: SettingsPalette.ruby),
            const SizedBox(width: 6),
            _statChip('XP', _fmt(player.xp), accent: SettingsPalette.titanium),
          ],
        ),
        const SizedBox(height: 10),
        Text('Savaş', style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold)),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _statChip('Saldırı', '${player.attack ?? 0}'),
            const SizedBox(width: 6),
            _statChip('Savunma', '${player.defense ?? 0}'),
            const SizedBox(width: 6),
            _statChip('Şans', '${player.luck ?? 0}'),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _statChip('PvP', '${player.pvpWins ?? 0}W / ${player.pvpLosses ?? 0}L'),
            const SizedBox(width: 6),
            _statChip('Rating', '${player.pvpRating ?? 1000}'),
            const SizedBox(width: 6),
            _statChip('Stat puan', '${player.statPoints ?? 0}'),
          ],
        ),
        const SizedBox(height: 10),
        Text('Lonca & envanter', style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold)),
        const SizedBox(height: 6),
        SettingsGlassCard(
          accent: SettingsPalette.obsidian,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                player.guildName != null
                    ? '${player.guildName}${player.guildRole != null ? ' · ${player.guildRole}' : ''}'
                    : 'Lonca yok',
                style: supportBodyStyle,
              ),
              const SizedBox(height: 4),
              Text(
                'Envanter: ${player.inventorySlotsUsed ?? 0}/${player.inventoryCapacity} slot · ${player.inventoryItemRows ?? 0} satır',
                style: supportCaptionStyle,
              ),
              Text(
                'Bağımlılık ${player.addictionLevel ?? 0} · Tolerans ${player.tolerance ?? 0}',
                style: supportCaptionStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('Aktivite', style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold)),
        const SizedBox(height: 6),
        SettingsGlassCard(
          accent: SettingsPalette.titanium,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Son giriş: ${_fmtDate(player.lastLoginAt)}', style: supportCaptionStyle),
              Text('Son aktif: ${_fmtDate(player.lastActiveAt)}', style: supportCaptionStyle),
              Text('Kayıt: ${_fmtDate(player.createdAt)}', style: supportCaptionStyle),
              Text('Oyun süresi: ${_fmtDuration(player.totalPlaytimeSeconds)}', style: supportCaptionStyle),
              if (player.email != null && player.email!.isNotEmpty)
                Text('E-posta: ${player.email}', style: supportCaptionStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (player.inHospital ||
            player.inPrison ||
            player.isAccountBanned ||
            player.isTradeBanned ||
            player.isChatMuted) ...<Widget>[
          const SizedBox(height: 12),
          Text('Aktif kısıtlar — hızlı işlem', style: AppTextStyles.caption.copyWith(color: SettingsPalette.coral)),
          const SizedBox(height: 6),
          if (player.inHospital)
            _statusBanner(
              title: 'Hastane',
              subtitle: 'Bitiş: ${_fmtDate(player.hospitalUntil)}'
                  '${player.hospitalReason != null ? '\n${player.hospitalReason}' : ''}',
              accent: SettingsPalette.coral,
              icon: Icons.local_hospital_rounded,
              actions: <({String label, VoidCallback? onTap})>[
                (label: '+ Süre', onTap: onExtendHospital),
                (label: '- Süre', onTap: onShortenHospital),
                (label: 'Çıkar', onTap: onReleaseHospital),
              ],
            ),
          if (player.inPrison)
            _statusBanner(
              title: 'Hapishane',
              subtitle: 'Bitiş: ${_fmtDate(player.prisonUntil)}'
                  '${player.prisonReason != null ? '\n${player.prisonReason}' : ''}',
              accent: SettingsPalette.ruby,
              icon: Icons.gavel_rounded,
              actions: <({String label, VoidCallback? onTap})>[
                (label: '+ Süre', onTap: onExtendPrison),
                (label: '- Süre', onTap: onShortenPrison),
                (label: 'Çıkar', onTap: onReleasePrison),
              ],
            ),
          if (player.isAccountBanned)
            _statusBanner(
              title: 'Hesap banı',
              subtitle: 'Bitiş: ${player.bannedUntil == null ? 'Kalıcı' : _fmtDate(player.bannedUntil)}'
                  '${player.banReason != null ? '\n${player.banReason}' : ''}',
              accent: SettingsPalette.ruby,
              icon: Icons.block_rounded,
              actions: <({String label, VoidCallback? onTap})>[
                (label: 'Ban kaldır', onTap: onUnban),
              ],
            ),
          if (player.isTradeBanned)
            _statusBanner(
              title: 'Ticaret yasağı',
              subtitle: 'Bitiş: ${_fmtDate(player.tradeBannedUntil)}',
              accent: SettingsPalette.titanium,
              icon: Icons.swap_horiz_rounded,
              actions: <({String label, VoidCallback? onTap})>[
                (label: 'Kaldır', onTap: onReleaseTradeBan),
              ],
            ),
          if (player.isChatMuted)
            _statusBanner(
              title: 'Chat susturma',
              subtitle: 'Bitiş: ${_fmtDate(player.chatMutedUntil)}',
              accent: SettingsPalette.fuchsia,
              icon: Icons.volume_off_rounded,
              actions: <({String label, VoidCallback? onTap})>[
                (label: 'Aç', onTap: onReleaseChatMute),
              ],
            ),
        ],
      ],
    );
  }
}

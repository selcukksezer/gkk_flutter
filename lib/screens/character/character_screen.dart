import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/character/character_combat_stats_panel.dart';
import '../../components/common/profile_avatar.dart';
import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/xp_formula.dart';
import '../../models/player_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../../utils/logout_helper.dart';

// ─── Constants & Helpers ───────────────────────────────────────────────────

const _spaceNavy = Color(0xFF121826);
const _liquidGold = Color(0xFFFFB800);
const _warningSolar = Color(0xFFFFD700);
const _mutedTitanium = Color(0xFF8E9CAE);
const _coralFlare = Color(0xFFFF6B35);
const _cyberFuchsia = Color(0xFFE01E5A);
const _toxicNeon = Color(0xFF00FF66);

const _xpBarGradient = LinearGradient(colors: [_liquidGold, _warningSolar]);

const _skills = [
  (key: 'combat', icon: '⚔️', label: 'Savaş'),
  (key: 'stealth', icon: '🥷', label: 'Gizlilik'),
  (key: 'magic', icon: '🔮', label: 'Büyü'),
  (key: 'crafting', icon: '🔨', label: 'Zanaat'),
  (key: 'trade', icon: '💰', label: 'Ticaret'),
  (key: 'leadership', icon: '👑', label: 'Liderlik'),
];

({String title, Color color}) _getReputationTier(int rep) {
  if (rep >= 100000) return (title: '👑 Efsane', color: Colors.amber);
  if (rep >= 50000) return (title: '🔱 Usta', color: _liquidGold);
  if (rep >= 20000) return (title: '⭐ Kahraman', color: _coralFlare);
  if (rep >= 5000) return (title: '🥈 Ünlü', color: Colors.blueGrey);
  if (rep >= 1000) return (title: '🌱 Tanınan', color: Colors.greenAccent);
  return (title: '🕵️ Bilinmeyen', color: Colors.white38);
}

String _fmtCompact(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toInt().toString();
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class CharacterScreen extends ConsumerStatefulWidget {
  const CharacterScreen({super.key});

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> {
  bool _claimingDetox = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(inventoryProvider.notifier).loadInventory();
    });
  }

  Future<void> _claimAlchemistDetox() async {
    setState(() => _claimingDetox = true);
    try {
      final res =
          await SupabaseService.client.rpc('claim_alchemist_detox') as Map;
      if (res['success'] == true) {
        if (mounted)
          AppMessenger.showSuccess(context, '✅ Minor Detox başarıyla alındı!');
      } else {
        if (mounted)
          AppMessenger.showError(
            context,
            '❌ ${res['message'] ?? 'Bir hata oluştu.'}',
          );
      }
    } catch (e) {
      if (mounted) AppMessenger.showError(context, '❌ İşlem başarısız');
    } finally {
      if (mounted) setState(() => _claimingDetox = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;

    Future<void> logout() async {
      await performLogout(ref);
}

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.screenTitleCharacter, onLogout: logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.character,
        onLogout: logout,
      ),
      body: switch (playerState.status) {
        PlayerStatus.initial || PlayerStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PlayerStatus.error => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playerState.errorMessage ?? 'Hata',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(playerProvider.notifier).loadProfile(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        PlayerStatus.ready => _buildBody(profile),
      },
    );
  }

  Widget _buildBody(PlayerProfile? profile) {
    final profileLevel = profile?.level ?? 1;
    final xp = profile?.xp ?? 0;
    final xpProgress = buildXpProgress(level: profileLevel, totalXp: xp);
    final level = xpProgress.level;

    final repTier = _getReputationTier(profile?.reputation ?? 0);

    return GameScreenBackground(
      child: ListView(
        padding: GameScrollLayout.pagePadding(context),
        children: <Widget>[
          GameScrollSection(
            leadingGap: false,
            child: _buildIdentityCard(profile, level, repTier, xpProgress),
          ),
          GameScrollSection(child: _buildQuickResources(profile)),
          GameScrollSection(child: _buildCombatStats(profile, level)),
          GameScrollSection(child: _buildClassDetails(profile)),
          GameScrollSection(child: _buildExtraInfo(profile)),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return DottedPanel(padding: padding, child: child);
  }

  Future<void> _showAvatarPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _spaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profil Fotoğrafı Seç',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ProfilePhotoCatalog.selectablePhotos.map((path) {
                    return Semantics(
                      button: true,
                      label: 'Profil fotoğrafı seç',
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            await SupabaseService.client
                                .from('users')
                                .update({'avatar_url': path})
                                .eq(
                                  'auth_id',
                                  SupabaseService.client.auth.currentUser!.id,
                                );
                            ref.read(playerProvider.notifier).loadProfile();
                          } catch (e) {
                            if (mounted) {
                              AppMessenger.show(
                                context,
                                userFacingErrorMessage(
                                  e,
                                  fallback: 'Profil fotoğrafı güncellenemedi.',
                                ),
                              );
                            }
                          }
                        },
                        child: ProfileAvatar(
                          size: 64,
                          avatarUrl: path,
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFramePicker() async {
    final frames = [
      {'id': null, 'name': 'Çerçevesiz (Normal)'},
      {'id': 'glow', 'name': '✨ Parlayan Mavi Çerçeve'},
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: _spaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Çerçeve Seç',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: frames.map((frameData) {
                    return ListTile(
                      title: Text(
                        frameData['name'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          await SupabaseService.client
                              .from('users')
                              .update({'avatar_frame': frameData['id']})
                              .eq(
                                'auth_id',
                                SupabaseService.client.auth.currentUser!.id,
                              );
                          ref.read(playerProvider.notifier).loadProfile();
                        } catch (e) {
                          if (mounted) {
                            AppMessenger.show(
                              context,
                              userFacingErrorMessage(
                                e,
                                fallback: 'Çerçeve güncellenemedi.',
                              ),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomizationPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _spaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profili Düzenle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.person, color: _liquidGold),
                  title: const Text(
                    'Profil Fotoğrafını Değiştir',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAvatarPicker();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.stars, color: Colors.amber),
                  title: const Text(
                    'Çerçeveyi Değiştir',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showFramePicker();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdentityCard(
    PlayerProfile? profile,
    int level,
    ({Color color, String title}) repTier,
    XpProgress xpProgress,
  ) {
    final name = profile?.displayName ?? profile?.username ?? 'Oyuncu';
    final guild = (profile?.guildName != null && profile!.guildName!.isNotEmpty)
        ? '🏰 ${profile.guildName}'
        : 'Lonca Yok';

    final charClass = profile?.characterClass;
    final className = charClass == CharacterClass.warrior
        ? '🗡️ Savaşçı'
        : charClass == CharacterClass.alchemist
        ? '⚗️ Simyacı'
        : charClass == CharacterClass.shadow
        ? '🌑 Gölge'
        : 'Sınıf Seçilmedi';

    return _card(
      child: Row(
        children: [
          GestureDetector(
            onTap: _showCustomizationPicker,
            child: Stack(
              children: [
                ProfileAvatar(
                  size: 64,
                  avatarUrl: profile?.avatarUrl,
                  backgroundColor: GameScreenBackground.spaceNavy,
                  glowFrame: profile?.avatarFrame == 'glow',
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _spaceNavy,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.edit,
                      size: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        className,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Seviye $level • $guild',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ColoredBox(color: Colors.white.withValues(alpha: 0.1)),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: xpProgress.percent.clamp(0.0, 1.0),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(gradient: _xpBarGradient),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'XP: ${_fmtCompact(xpProgress.xpInLevel)} / ${_fmtCompact(xpProgress.xpNeededInLevel)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickResources(PlayerProfile? profile) {
    return Row(
      children: [
        Expanded(
          child: _miniResource(
            '💰 Altın',
            _fmtCompact(profile?.gold ?? 0),
            _warningSolar,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _miniResource(
            '💎 Elmas',
            _fmtCompact(profile?.gems ?? 0),
            _mutedTitanium,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _miniResource(
            '⚡ Enerji',
            '${profile?.energy ?? 0}/${profile?.maxEnergy ?? 100}',
            _cyberFuchsia,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _miniResource(
            '⚖️ Tolerans',
            '${profile?.tolerance ?? 0}%',
            _toxicNeon,
          ),
        ),
      ],
    );
  }

  Widget _miniResource(String label, String value, Color color) {
    return DottedPanel(
      borderRadius: 10,
      borderColor: color.withValues(alpha: 0.25),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombatStats(PlayerProfile? profile, int level) {
    final winRate = (profile?.pvpWins ?? 0) + (profile?.pvpLosses ?? 0) > 0
        ? (((profile?.pvpWins ?? 0) /
                      ((profile?.pvpWins ?? 0) + (profile?.pvpLosses ?? 0))) *
                  100)
              .round()
        : 0;
    return _card(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: CharacterCombatStatsPanel(
        power: _fmtCompact(profile?.power ?? 0),
        intelligence: '${profile?.intelligence ?? 0}',
        maxHealth: '${profile?.maxHealth ?? 0}',
        attack: '${profile?.attack ?? 0}',
        defense: '${profile?.defense ?? 0}',
        luck: '${profile?.luck ?? 0}',
        pvpWinRate: '%$winRate',
        pvpRating: '${profile?.pvpRating ?? 0}',
      ),
    );
  }

  Widget _buildClassDetails(PlayerProfile? profile) {
    final charClass = profile?.characterClass;
    final isAlchemist = charClass == CharacterClass.alchemist;

    if (charClass == null) {
      return const SizedBox.shrink();
    }

    final title = charClass == CharacterClass.warrior
        ? 'Savaşçı'
        : charClass == CharacterClass.alchemist
        ? 'Simyacı'
        : 'Gölge';
    final desc = charClass == CharacterClass.warrior
        ? 'Yakın dövüşte uzmanlaşmış bir sınıf. PvP galibiyetlerinden sonra 30 dk boyunca saldınırı %10 (üst üste 3 kazanımda %20) artırarak "Kan Hırsı" durumuna geçer.'
        : charClass == CharacterClass.alchemist
        ? 'Biyolojik toleransları daha iyidir ve her gün ücretsiz Minor Detox Drink (Toksin Atıcı) üretebilir. Craft odaklı karakterdir.'
        : 'Şüpheli faaliyetlerde ustalaşmış, gizlilik ve kaçınma oranları yüksek bir sınıftır. Rüşvet maliyetleri %25 daha düşüktür.';

    final statsList = charClass == CharacterClass.warrior
        ? ['+20% PvP Hasar', '+15% Boss Hasarı', '+10% PvP Kritik Şansı']
        : charClass == CharacterClass.alchemist
        ? [
            '+30% İksir Etkinliği',
            '-25% Tolerans Artışı',
            '+15% Crafting Başarısı',
          ]
        : [
            '-30% Tesis Şüphesi',
            '+20% Hapishaneden Kaçış',
            '+40% Zindan Loot Şansı',
          ];

    final color = charClass == CharacterClass.warrior
        ? Colors.redAccent
        : charClass == CharacterClass.alchemist
        ? _coralFlare
        : _mutedTitanium;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🎭 Sınıf Özellikleri: $title',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
              if (isAlchemist)
                IconButton(
                  onPressed: _claimingDetox ? null : _claimAlchemistDetox,
                  icon: _claimingDetox
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.clean_hands_rounded,
                          color: _coralFlare,
                          size: 20,
                        ),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Günlük Detox',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statsList.map((st) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  st,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraInfo(PlayerProfile? profile) {
    return _card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            '📚 Yetenekler & Adli Sicil',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          children: [
            Wrap(
              children: [
                _infoRow(
                  'Şüphe Seviyesi',
                  '${profile?.globalSuspicionLevel ?? 0}%',
                ),
                _infoRow(
                  'Bağımlılık Seviyesi',
                  'Lvl ${profile?.addictionLevel ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.icon),
                          const SizedBox(width: 6),
                          Text(
                            s.label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Opacity(
              opacity: 0.5,
              child: Text(
                'Yetenek sistemi yakında güncellenecek.',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

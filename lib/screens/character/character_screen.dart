import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/character/badge_showcase_panel.dart';
import '../../components/character/character_combat_stats_panel.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../components/character/stat_allocation_panel.dart';
import '../../components/common/profile_avatar.dart';
import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/character_class_abilities.dart';
import '../../core/utils/cosmetic_title.dart';
import '../../core/utils/reputation_tier.dart';
import '../../core/utils/xp_formula.dart';
import '../../models/player_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_badges_provider.dart';
import '../../providers/player_provider.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../components/common/app_messenger.dart';
import '../../components/common/cosmetic_title_badge.dart';
import '../../utils/logout_helper.dart';

// ─── Constants & Helpers ───────────────────────────────────────────────────

const _xpBarGradient = LinearGradient(
  colors: <Color>[AppColors.liquidGold, AppColors.warningSolar],
);

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(inventoryProvider.notifier).loadInventory();
      ref.read(playerBadgesProvider.notifier).load();
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.character);
    });
  }

  Future<void> _claimAlchemistDetox() async {
    setState(() => _claimingDetox = true);
    try {
      final dynamic res =
          await SupabaseService.client.rpc('claim_alchemist_detox');
      if (res is! Map) {
        if (mounted) {
          AppMessenger.showError(context, 'Beklenmeyen yanıt');
        }
        return;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(res);
      if (data['success'] == true) {
        if (mounted) {
          AppMessenger.showSuccess(context, '✅ Minor Detox başarıyla alındı!');
        }
      } else {
        if (mounted) {
          AppMessenger.showError(
            context,
            '❌ ${data['message'] ?? 'Bir hata oluştu.'}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(context, '❌ İşlem başarısız');
      }
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

    final int reputation = (profile?.reputation ?? 0).clamp(0, 999999999);

    return GameScreenBackground(
      child: ListView(
        padding: GameScrollLayout.pagePadding(context),
        children: <Widget>[
          GameScrollSection(
            leadingGap: false,
            child: _buildIdentityCard(profile, level, xpProgress, reputation),
          ),
          const GameScrollSection(child: BadgeShowcasePanel()),
          GameScrollSection(
            child: _buildCodexLink(context),
          ),
          GameScrollSection(child: _buildQuickResources(profile)),
          if ((profile?.statPoints ?? 0) > 0)
            GameScrollSection(
              child: TutorialAnchorScope(
                id: TutorialAnchorId.characterStatPanel,
                child: StatAllocationPanel(
                  availablePoints: profile!.statPoints,
                ),
              ),
            ),
          GameScrollSection(child: _buildCombatStats(profile, level, reputation)),
          GameScrollSection(child: _buildClassDetails(profile)),
          GameScrollSection(child: _buildExtraInfo(profile)),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return DottedPanel(padding: padding, child: child);
  }

  Widget _buildCodexLink(BuildContext context) {
    return TutorialAnchorScope(
      id: TutorialAnchorId.characterCodexTile,
      child: _card(
        child: InkWell(
          onTap: () {
            unawaited(
              TutorialTriggers.onAnchorTap(ref, TutorialAnchorId.characterCodexTile),
            );
            context.push(AppRoutes.codex);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.liquidGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: AppColors.liquidGold),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Koleksiyon Kodex',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Eşya, boss ve zindan keşiflerini topla.',
                        style: TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.mutedTitanium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAvatarPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.spaceNavy,
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
    bool codexFrameUnlocked = false;
    try {
      final dynamic dashRaw =
          await SupabaseService.client.rpc('get_codex_dashboard');
      if (dashRaw is Map && dashRaw['success'] == true) {
        final List<dynamic> milestones = dashRaw['milestones'] is List
            ? dashRaw['milestones'] as List
            : const <dynamic>[];
        codexFrameUnlocked = milestones.any(
          (dynamic row) =>
              row is Map &&
              (row['threshold'] as num?)?.toInt() == 50 &&
              row['claimed'] == true,
        );
      }
    } catch (_) {
      // Frame picker still works with default frames.
    }

    final List<Map<String, Object?>> frames = <Map<String, Object?>>[
      <String, Object?>{'id': null, 'name': 'Çerçevesiz (Normal)'},
      <String, Object?>{'id': 'glow', 'name': '✨ Parlayan Mavi Çerçeve'},
      if (codexFrameUnlocked)
        <String, Object?>{'id': 'codex', 'name': '📖 Kodex Kaşifi Çerçevesi'},
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.spaceNavy,
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
      backgroundColor: AppColors.spaceNavy,
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
                  leading: const Icon(Icons.person, color: AppColors.liquidGold),
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
    XpProgress xpProgress,
    int reputation,
  ) {
    final ReputationTier tier = reputationTierFor(reputation);
    final ReputationTierProgress tierProgress =
        reputationTierProgressFor(reputation);
    final int tierProgressPct =
        (tierProgress.progress.clamp(0.0, 1.0) * 100).round();
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
                  codexFrame: profile?.avatarFrame == 'codex',
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.spaceNavy,
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
                if (hasCosmeticTitle(profile?.cosmeticTitle)) ...<Widget>[
                  const SizedBox(height: 6),
                  CosmeticTitleBadge(titleKey: profile!.cosmeticTitle),
                ],
                const SizedBox(height: 4),
                Text(
                  'Seviye $level • $guild',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => context.push(AppRoutes.reputation),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.military_tech_rounded,
                        size: 12,
                        color: AppColors.liquidGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${tier.title} · %$tierProgressPct',
                        style: const TextStyle(
                          color: AppColors.liquidGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
    final List<Widget> cards = <Widget>[
      _miniResource(
        '⚡ Enerji',
        '${profile?.energy ?? 0}/${profile?.maxEnergy ?? 100}',
        AppColors.cyberFuchsia,
      ),
      _miniResource(
        '⚖️ Tolerans',
        '${profile?.tolerance ?? 0}%',
        AppColors.toxicNeon,
      ),
    ];

    return Row(
      children: <Widget>[
        for (int i = 0; i < cards.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: cards[i]),
        ],
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
              style: TextStyle(color: AppColors.mutedTitanium, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombatStats(PlayerProfile? profile, int level, int reputation) {
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
        maxHealth: '${profile?.maxHealth ?? 0}',
        attack: '${profile?.attack ?? 0}',
        defense: '${profile?.defense ?? 0}',
        luck: '${profile?.luck ?? 0}',
        pvpWinRate: '%$winRate',
        pvpRating: '${profile?.pvpRating ?? 0}',
        reputation: reputation,
        highlightPowerAnchor: true,
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

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎭 Sınıf Özellikleri: $title',
            style: AppTextStyles.title.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
          if (isAlchemist) ...<Widget>[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _claimingDetox ? null : _claimAlchemistDetox,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coralFlare.withValues(alpha: 0.14),
                  foregroundColor: AppColors.coralFlare,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: AppColors.coralFlare.withValues(alpha: 0.35),
                  ),
                ),
                child: _claimingDetox
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.coralFlare,
                        ),
                      )
                    : Text(
                        'Günlük Detox Al',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.coralFlare,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExtraInfo(PlayerProfile? profile) {
    final CharacterClass? charClass = profile?.characterClass;
    final List<CharacterAbilityDef> abilities = abilitiesForClass(charClass);
    final Color accent = accentForClass(charClass);
    final bool bloodlustActive = isWarriorBloodlustActive(profile);

    return _card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: true,
          title: Text(
            'Yetenekler & Adli Sicil',
            style: AppTextStyles.title.copyWith(color: AppColors.textSecondary),
          ),
          iconColor: AppColors.liquidGold,
          collapsedIconColor: AppColors.mutedTitanium,
          children: <Widget>[
            if (charClass != null && abilities.isNotEmpty) ...<Widget>[
              Text(
                '${_classTitle(charClass)} — Sınıf Yetenekleri',
                style: AppTextStyles.captionBold.copyWith(color: accent),
              ),
              const SizedBox(height: 10),
              ...abilities.map((CharacterAbilityDef ability) {
                final bool isSignature =
                    ability.kind == CharacterAbilityKind.signature;
                final bool isActive = ability.name == 'Kan Hırsı' &&
                    bloodlustActive;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _abilityTile(
                    ability: ability,
                    accent: accent,
                    isSignature: isSignature,
                    isActive: isActive,
                  ),
                );
              }),
              const SizedBox(height: 8),
              Divider(color: AppColors.mutedTitanium.withValues(alpha: 0.15)),
              const SizedBox(height: 8),
            ],
            Text(
              'Adli Sicil',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _infoRow(
              'Şüphe Seviyesi',
              '${effectiveSuspicionLevel(profile)}%'
              '${profile?.characterClass == CharacterClass.shadow ? ' (tavan 80)' : ''}',
            ),
            _infoRow(
              'Bağımlılık Seviyesi',
              'Lvl ${profile?.addictionLevel ?? 0}',
            ),
          ],
        ),
      ),
    );
  }

  String _classTitle(CharacterClass charClass) {
    return switch (charClass) {
      CharacterClass.warrior => 'Savaşçı',
      CharacterClass.alchemist => 'Simyacı',
      CharacterClass.shadow => 'Gölge',
    };
  }

  Widget _abilityTile({
    required CharacterAbilityDef ability,
    required Color accent,
    required bool isSignature,
    required bool isActive,
  }) {
    final Color borderColor = isActive
        ? AppColors.toxicNeon
        : isSignature
        ? AppColors.liquidGold.withValues(alpha: 0.45)
        : accent.withValues(alpha: 0.28);
    final Color bgColor = isActive
        ? AppColors.toxicNeon.withValues(alpha: 0.08)
        : isSignature
        ? AppColors.liquidGold.withValues(alpha: 0.06)
        : AppColors.darkObsidian.withValues(alpha: 0.55);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(ability.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        ability.name,
                        style: AppTextStyles.captionBold.copyWith(
                          color: isActive
                              ? AppColors.toxicNeon
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSignature)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.liquidGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.liquidGold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          isActive ? 'AKTİF' : 'ÖZEL',
                          style: AppTextStyles.micro.copyWith(
                            color: isActive
                                ? AppColors.toxicNeon
                                : AppColors.liquidGold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    if (ability.system != null && !isSignature) ...<Widget>[
                      const SizedBox(width: 6),
                      Text(
                        ability.system!,
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.mutedTitanium,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ability.effect,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
          Text(
            value,
            style: AppTextStyles.captionBold,
          ),
        ],
      ),
    );
  }
}

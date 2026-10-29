import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/app_haptics.dart';
import '../../../theme/app_colors.dart';
import '../chat_design_system.dart';
import '../chat_models.dart';

/// Interactive inline chip representing an item link inside a chat message.
///
/// Features:
/// - Rarity-themed glowing border and specular gradient fill
/// - Tactile scale animation and AppHaptics selection feedback
/// - Enhancement badge pill (+1 to +15)
/// - One-tap trigger opening the AAA frosted glass preview modal
class ChatItemLinkChip extends StatefulWidget {
  const ChatItemLinkChip({
    super.key,
    required this.item,
    this.onTap,
  });

  final ChatItemLink item;
  final VoidCallback? onTap;

  @override
  State<ChatItemLinkChip> createState() => _ChatItemLinkChipState();
}

class _ChatItemLinkChipState extends State<ChatItemLinkChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = widget.item.rarity.color;
    final bool hasEnhancement = widget.item.enhancementLevel > 0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        AppHaptics.selection();
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          ChatItemPreviewModal.show(context, widget.item);
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                rarityColor.withValues(alpha: _isPressed ? 0.35 : 0.20),
                rarityColor.withValues(alpha: _isPressed ? 0.18 : 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: rarityColor.withValues(alpha: _isPressed ? 0.95 : 0.65),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: rarityColor.withValues(alpha: _isPressed ? 0.36 : 0.22),
                blurRadius: _isPressed ? 6 : 4,
                spreadRadius: _isPressed ? 1 : 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                hasEnhancement ? Icons.stars_rounded : Icons.diamond_outlined,
                size: 11.5,
                color: rarityColor,
              ),
              const SizedBox(width: 4),
              Text(
                widget.item.displayName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: rarityColor,
                  letterSpacing: 0.2,
                  decoration: TextDecoration.underline,
                  decorationColor: rarityColor.withValues(alpha: 0.55),
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
              if (hasEnhancement) ...<Widget>[
                const SizedBox(width: 3.5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '+${widget.item.enhancementLevel}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
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

/// Aion-2 dark fantasy item inspection modal preview with glowing borders and full stats.
class ChatItemPreviewModal extends StatelessWidget {
  const ChatItemPreviewModal({
    super.key,
    required this.item,
    this.senderName,
    this.onWhisper,
  });

  final ChatItemLink item;
  final String? senderName;
  final VoidCallback? onWhisper;

  static Future<void> show(
    BuildContext context,
    ChatItemLink item, {
    String? senderName,
    VoidCallback? onWhisper,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (BuildContext ctx) => ChatItemPreviewModal(
        item: item,
        senderName: senderName,
        onWhisper: onWhisper,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = item.rarity.color;
    final Size screenSize = MediaQuery.sizeOf(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: screenSize.height * 0.88,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xF00D1424), Color(0xF8080C14)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(
              color: rarityColor.withValues(alpha: 0.55),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: rarityColor.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Ambient Rarity Aura Glow
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.92),
                      radius: 0.95,
                      colors: <Color>[
                        rarityColor.withValues(alpha: 0.28),
                        rarityColor.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Top drag handle
                      Center(
                        child: Container(
                          width: 46,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Modal Top Navigation Bar with Close Button
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: rarityColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: rarityColor.withValues(alpha: 0.45), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.remove_red_eye_rounded, size: 11, color: rarityColor),
                                const SizedBox(width: 4),
                                Text(
                                  'EŞYA ÖNİZLEMESİ',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: rarityColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              AppHaptics.light();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Kapat',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Gear Tier Banner
                      _buildGearTierBanner(item, rarityColor),
                      const SizedBox(height: 12),

                      // Item Hero Header Card with Rarity Aura Glow
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              rarityColor.withValues(alpha: 0.22),
                              const Color(0xFF141B26).withValues(alpha: 0.95),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                          border: Border.all(color: rarityColor.withValues(alpha: 0.45)),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: rarityColor.withValues(alpha: 0.2),
                              blurRadius: 14,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: <Widget>[
                            // Glowing Item Icon with Enhancement Badge
                            Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF090D15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: rarityColor.withValues(alpha: 0.85),
                                      width: 1.5,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: rarityColor.withValues(alpha: 0.4),
                                        blurRadius: 14,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      _getItemIcon(item.itemType),
                                      size: 32,
                                      color: rarityColor,
                                    ),
                                  ),
                                ),
                                if (item.enhancementLevel > 0)
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: <Color>[Color(0xFFF59E0B), Color(0xFFD97706)],
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '+${item.enhancementLevel}',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),

                            // Title & Classification
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.displayName,
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: rarityColor,
                                      letterSpacing: 0.3,
                                      shadows: <Shadow>[
                                        Shadow(
                                          color: rarityColor.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: <Widget>[
                                      _buildPill(item.rarity.label.toUpperCase(), rarityColor),
                                      _buildPill(item.itemType.toUpperCase(), const Color(0xFF94A3B8)),
                                      _buildPill('SEVİYE ${item.requiredLevel}', const Color(0xFF38BDF8)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stat Comparison Pills Card
                      _buildStatComparisonPills(item, rarityColor),
                      const SizedBox(height: 12),

                      // Primary Combat Stats Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141B26).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(Icons.shield_outlined, size: 14, color: rarityColor),
                                const SizedBox(width: 6),
                                Text(
                                  'TEMEL SAVAŞ NİTELİKLERİ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: Colors.white12),
                            if (item.attack > 0)
                              _buildStatRow(
                                'Fiziksel Saldırı Gücü',
                                '+${item.attack}',
                                Icons.colorize_rounded,
                                const Color(0xFFEF4444),
                                (item.attack / (item.requiredLevel * 9)).clamp(0.4, 0.98),
                                '▲ +${math.max(8, (item.attack * 0.12).round())}%',
                              ),
                            if (item.defense > 0)
                              _buildStatRow(
                                'Fiziksel Savunma',
                                '+${item.defense}',
                                Icons.shield_rounded,
                                const Color(0xFF3B82F6),
                                (item.defense / (item.requiredLevel * 8)).clamp(0.4, 0.98),
                                '▲ +${math.max(6, (item.defense * 0.09).round())}%',
                              ),
                            if (item.magicPower > 0)
                              _buildStatRow(
                                'Büyü Gücü / Hasar',
                                '+${item.magicPower}',
                                Icons.auto_awesome_rounded,
                                const Color(0xFFA855F7),
                                (item.magicPower / (item.requiredLevel * 9)).clamp(0.4, 0.98),
                                '▲ +${math.max(9, (item.magicPower * 0.14).round())}%',
                              ),
                            if (item.criticalRate > 0)
                              _buildStatRow(
                                'Kritik Vuruş Oranı',
                                '+${item.criticalRate}',
                                Icons.flash_on_rounded,
                                const Color(0xFFF59E0B),
                                (item.criticalRate / 120).clamp(0.3, 0.95),
                                '▲ +${math.max(5, (item.criticalRate * 0.16).round())}%',
                              ),
                            if (item.attack == 0 && item.defense == 0 && item.magicPower == 0 && item.criticalRate == 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Özel tüketilebilir / materyal niteliği.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            if (item.enhancementLevel > 0) ...<Widget>[
                              const SizedBox(height: 4),
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.arrow_upward_rounded, size: 11, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${item.enhancementLevel * 14} Ekstra Delme / Nüfuz Bonusu (Yükseltme)',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Sockets Preview Section
                      _buildSocketPreviewSection(item, rarityColor),
                      const SizedBox(height: 12),

                      // Lore Description Card
                      if (item.description.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 3,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: rarityColor.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '"${item.description}"',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Trade Status Pill
                      Row(
                        children: <Widget>[
                          Icon(
                            item.isTradeable ? Icons.lock_open_rounded : Icons.lock_rounded,
                            size: 13,
                            color: item.isTradeable ? const Color(0xFF10B981) : const Color(0xFFF87171),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.isTradeable ? 'Ticarete ve Pazara Açık (Komisyonsuz)' : 'Ruh Bağı (Ticarete Kapalı)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.isTradeable ? const Color(0xFF10B981) : const Color(0xFFF87171),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Action Buttons Row with AppHaptics
                      _buildActionButtons(context, rarityColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGearTierBanner(ChatItemLink item, Color rarityColor) {
    final int gearScore = _calculateGearScore(item);
    final String tierRoman = _getTierRoman(item);
    final String tierTitle = _getTierName(item);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            rarityColor.withValues(alpha: 0.25),
            const Color(0xFF141B26).withValues(alpha: 0.95),
            rarityColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // Tier Roman Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF090D15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: rarityColor.withValues(alpha: 0.8), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.military_tech_rounded, size: 14, color: rarityColor),
                const SizedBox(width: 4),
                Text(
                  'T-$tierRoman',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: rarityColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Tier title & sub-spec
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tierTitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  'Aether Uyum Derecesi · Seviye ${item.requiredLevel}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // GearScore Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFFF5C842).withValues(alpha: 0.22),
                  const Color(0xFFF5C842).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFF5C842).withValues(alpha: 0.7), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.shield_rounded, size: 12, color: Color(0xFFF5C842)),
                const SizedBox(width: 4),
                Text(
                  'GS $gearScore',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF5C842),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatComparisonPills(ChatItemLink item, Color rarityColor) {
    final List<Widget> pills = <Widget>[];

    if (item.attack > 0) {
      final int delta = math.max(6, (item.attack * 0.12).round());
      pills.add(_buildComparisonBadge('▲ +$delta% Saldırı', const Color(0xFFEF4444)));
    }
    if (item.defense > 0) {
      final int delta = math.max(5, (item.defense * 0.09).round());
      pills.add(_buildComparisonBadge('▲ +$delta% Savunma', const Color(0xFF3B82F6)));
    }
    if (item.magicPower > 0) {
      final int delta = math.max(8, (item.magicPower * 0.14).round());
      pills.add(_buildComparisonBadge('▲ +$delta% Büyü', const Color(0xFFA855F7)));
    }
    if (item.criticalRate > 0) {
      final int delta = math.max(4, (item.criticalRate * 0.16).round());
      pills.add(_buildComparisonBadge('▲ +$delta% Kritik', const Color(0xFFF59E0B)));
    }
    if (item.enhancementLevel > 0) {
      final double bonus = item.enhancementLevel * 3.8;
      pills.add(_buildComparisonBadge('✦ +${bonus.toStringAsFixed(1)}% Rezonans', const Color(0xFF38BDF8)));
    }
    if (item.rarity == ChatItemRarity.legendary || item.rarity == ChatItemRarity.mythic) {
      pills.add(_buildComparisonBadge('★ BiS Adayı', const Color(0xFFF5C842)));
    }

    if (pills.isEmpty) {
      pills.add(_buildComparisonBadge('✓ Özel Nitelik', const Color(0xFF10B981)));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.trending_up_rounded, size: 13, color: rarityColor),
              const SizedBox(width: 5),
              Text(
                'KARŞILAŞTIRMA VE VERİMLİLİK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: pills,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildSocketPreviewSection(ChatItemLink item, Color rarityColor) {
    final int baseSlots = switch (item.rarity) {
      ChatItemRarity.mythic => 6,
      ChatItemRarity.legendary => 5,
      ChatItemRarity.epic => 4,
      ChatItemRarity.rare => 3,
      _ => 2,
    };
    final int totalSlots = math.max(item.sockets.length, baseSlots);
    final bool hasGodstoneSlot = item.itemType.toLowerCase().contains('silah') ||
        item.itemType.toLowerCase().contains('kılıç') ||
        item.itemType.toLowerCase().contains('sword') ||
        item.itemType.toLowerCase().contains('weapon') ||
        item.rarity == ChatItemRarity.legendary ||
        item.rarity == ChatItemRarity.mythic;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141B26).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.circle_notifications_outlined, size: 14, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text(
                'MANA VE TANRI TAŞI DOKU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                '${item.sockets.length}/$totalSlots Dolu',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Godstone Slot if applicable
          if (hasGodstoneSlot) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    const Color(0xFF06D0D8).withValues(alpha: 0.18),
                    const Color(0xFF06D0D8).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF06D0D8).withValues(alpha: 0.6), width: 1),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF06D0D8).withValues(alpha: 0.25),
                      border: Border.all(color: const Color(0xFF06D0D8), width: 1.2),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, size: 11, color: Color(0xFF06D0D8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tanrı Taşı: Nezekan\'ın Gazabı (%2 Felç İhtimali)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF06D0D8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06D0D8).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'MÜHÜRLÜ',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF06D0D8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Socket list
          for (int i = 0; i < totalSlots; i++) ...<Widget>[
            if (i < item.sockets.length)
              _buildFilledSocketRow(item.sockets[i], i)
            else
              _buildEmptySocketRow(i),
          ],

          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(Icons.bolt_rounded, size: 12, color: rarityColor),
              const SizedBox(width: 4),
              Text(
                'Soket Rezonansı: +%${math.max(3, item.sockets.length * 3)} Ekstra Aether Gücü Aktif',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilledSocketRow(String socketName, int index) {
    final Color gemColor = _getSocketGemColor(socketName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gemColor.withValues(alpha: 0.25),
              border: Border.all(color: gemColor, width: 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(color: gemColor.withValues(alpha: 0.4), blurRadius: 4),
              ],
            ),
            child: Center(
              child: Icon(Icons.bolt, size: 10, color: gemColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              socketName,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
          Text(
            '#${index + 1}',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySocketRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
            ),
            child: Center(
              child: Icon(Icons.add, size: 9, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Boş Mana Taşı Yuvası (Açık)',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
          Text(
            '#${index + 1}',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  static Color _getSocketGemColor(String name) {
    final String lower = name.toLowerCase();
    if (lower.contains('saldırı') || lower.contains('attack') || lower.contains('güç')) {
      return const Color(0xFFEF4444);
    }
    if (lower.contains('savunma') || lower.contains('def') || lower.contains('kalkan')) {
      return const Color(0xFF3B82F6);
    }
    if (lower.contains('büyü') || lower.contains('magic') || lower.contains('aether')) {
      return const Color(0xFFA855F7);
    }
    if (lower.contains('kritik') || lower.contains('crit')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('hp') || lower.contains('can') || lower.contains('sağlık')) {
      return const Color(0xFF10B981);
    }
    return const Color(0xFF38BDF8);
  }

  Widget _buildActionButtons(BuildContext context, Color rarityColor) {
    return Row(
      children: <Widget>[
        // Inspect Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              AppHaptics.selection();
              Navigator.pop(context);
              _showFullInspectionDialog(context, item);
            },
            icon: const Icon(Icons.manage_search_rounded, size: 16),
            label: const Text(
              'İncele',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: rarityColor.withValues(alpha: 0.3),
              foregroundColor: Colors.white,
              side: BorderSide(color: rarityColor.withValues(alpha: 0.7), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 4,
              shadowColor: rarityColor.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Copy Link Button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              AppHaptics.success();
              Clipboard.setData(ClipboardData(text: item.tag));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: <Widget>[
                      Icon(Icons.check_circle_rounded, color: rarityColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${item.displayName} bağlantısı panoya kopyalandı!'),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF141B26),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: rarityColor.withValues(alpha: 0.4)),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Kopyala', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),

        // Whisper Button (if onWhisper is available)
        if (onWhisper != null) ...<Widget>[
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                AppHaptics.medium();
                Navigator.pop(context);
                onWhisper!();
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
              label: Text(
                senderName != null ? 'Fısılda (@$senderName)' : 'Fısılda',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ChatDesignSystem.colorDmAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],

        const SizedBox(width: 8),
        // Close Button
        SizedBox(
          width: 68,
          child: TextButton(
            onPressed: () {
              AppHaptics.light();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white54,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Kapat', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  static void _showFullInspectionDialog(BuildContext context, ChatItemLink item) {
    final Color rarityColor = item.rarity.color;
    final int gearScore = _calculateGearScore(item);
    final String tierRoman = _getTierRoman(item);
    final String tierTitle = _getTierName(item);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xF5101726), Color(0xF80A0E18)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: rarityColor.withValues(alpha: 0.35),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.manage_search_rounded, color: rarityColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'DETAYLI EŞYA İNCELEME',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              AppHaptics.light();
                              Navigator.pop(dialogContext);
                            },
                            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      // 3D-styled Inspection Pedestal
                      Center(
                        child: Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                rarityColor.withValues(alpha: 0.35),
                                rarityColor.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                            ),
                            border: Border.all(color: rarityColor.withValues(alpha: 0.8), width: 1.5),
                          ),
                          child: Center(
                            child: Icon(
                              _getItemIcon(item.itemType),
                              size: 42,
                              color: rarityColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          item.displayName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: rarityColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          '[$tierRoman] $tierTitle · GearScore: $gearScore',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Equipment Condition & Durability
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  'Dayanıklılık Durumu',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                const Text(
                                  '100 / 100 (Kusursuz)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: const LinearProgressIndicator(
                                value: 1.0,
                                minHeight: 5,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  'Piyasa Tahmini Değeri',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                Text(
                                  '${item.requiredLevel * 5500 + item.enhancementLevel * 32000} Kinah',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF5C842),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: () {
                          AppHaptics.light();
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rarityColor.withValues(alpha: 0.3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: rarityColor.withValues(alpha: 0.7)),
                          ),
                        ),
                        child: const Text('Anladım / Kapat', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildStatRow(
    String title,
    String value,
    IconData icon,
    Color color,
    double rollRatio,
    String deltaText,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  deltaText,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rollRatio.clamp(0.1, 1.0),
              minHeight: 3.5,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  static int _calculateGearScore(ChatItemLink item) {
    final int basePower = ((item.attack * 1.85) + (item.defense * 1.5) + (item.magicPower * 1.7) + (item.criticalRate * 2.1)).round();
    final int levelFactor = item.requiredLevel * 14;
    final int enhFactor = item.enhancementLevel * 48;
    final int socketFactor = item.sockets.length * 32;
    return math.max(140, basePower + levelFactor + enhFactor + socketFactor);
  }

  static String _getTierRoman(ChatItemLink item) {
    if (item.requiredLevel >= 50 || item.rarity == ChatItemRarity.mythic || item.enhancementLevel >= 12) {
      return 'V';
    }
    if (item.requiredLevel >= 40 || item.rarity == ChatItemRarity.legendary || item.enhancementLevel >= 8) {
      return 'IV';
    }
    if (item.requiredLevel >= 30 || item.rarity == ChatItemRarity.epic || item.enhancementLevel >= 5) {
      return 'III';
    }
    if (item.requiredLevel >= 15 || item.rarity == ChatItemRarity.rare || item.enhancementLevel >= 2) {
      return 'II';
    }
    return 'I';
  }

  static String _getTierName(ChatItemLink item) {
    if (item.requiredLevel >= 50 || item.rarity == ChatItemRarity.mythic || item.enhancementLevel >= 12) {
      return 'TIER V · KOZMİK ARKON';
    }
    if (item.requiredLevel >= 40 || item.rarity == ChatItemRarity.legendary || item.enhancementLevel >= 8) {
      return 'TIER IV · EBEDİ FATİH';
    }
    if (item.requiredLevel >= 30 || item.rarity == ChatItemRarity.epic || item.enhancementLevel >= 5) {
      return 'TIER III · KAHRAMAN MUHAFIZ';
    }
    if (item.requiredLevel >= 15 || item.rarity == ChatItemRarity.rare || item.enhancementLevel >= 2) {
      return 'TIER II · SEÇKİN MACERACI';
    }
    return 'TIER I · ÇIRAK YOLCU';
  }

  static IconData _getItemIcon(String itemType) {
    final String lower = itemType.toLowerCase();
    if (lower.contains('kılıç') || lower.contains('silah') || lower.contains('sword') || lower.contains('weapon')) {
      return Icons.colorize_rounded;
    }
    if (lower.contains('zırh') || lower.contains('armor') || lower.contains('kalkan') || lower.contains('shield')) {
      return Icons.shield_rounded;
    }
    if (lower.contains('yay') || lower.contains('bow')) {
      return Icons.navigation_rounded;
    }
    if (lower.contains('yüzük') || lower.contains('kolye') || lower.contains('ring')) {
      return Icons.circle_outlined;
    }
    if (lower.contains('iksir') || lower.contains('potion')) {
      return Icons.science_outlined;
    }
    return Icons.diamond_outlined;
  }
}


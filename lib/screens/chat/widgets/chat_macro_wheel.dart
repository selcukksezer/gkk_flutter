import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_design_system.dart';
import '../chat_models.dart';

/// Preset tactical macro items with category and icon.
class TacticalMacroItem {
  const TacticalMacroItem({
    required this.id,
    required this.label,
    required this.text,
    required this.icon,
    required this.category,
  });

  final String id;
  final String label;
  final String text;
  final IconData icon;
  final String category;
}

const List<TacticalMacroItem> kTacticalMacros = <TacticalMacroItem>[
  // Tactical Combat Macros
  TacticalMacroItem(
    id: 'atk',
    label: 'Saldırın',
    text: '⚔️ Saldırın! Hedefe odaklanın!',
    icon: Icons.flash_on_rounded,
    category: 'combat',
  ),
  TacticalMacroItem(
    id: 'def',
    label: 'Savunun',
    text: '🛡️ Savunmaya geçin! Koruma sağlayın!',
    icon: Icons.shield_rounded,
    category: 'combat',
  ),
  TacticalMacroItem(
    id: 'retreat',
    label: 'Geri Çekil',
    text: '🚩 Geri çekilin! Pozisyon alın!',
    icon: Icons.flag_rounded,
    category: 'combat',
  ),
  TacticalMacroItem(
    id: 'ready',
    label: 'Hazırım',
    text: '✅ Hazırım! Başlayalım!',
    icon: Icons.check_circle_rounded,
    category: 'combat',
  ),
  TacticalMacroItem(
    id: 'hold',
    label: 'Bekleyin',
    text: '⏸️ Bekleyin! Mola verelim.',
    icon: Icons.pause_circle_rounded,
    category: 'combat',
  ),
  TacticalMacroItem(
    id: 'boss',
    label: 'Patron',
    text: '👑 Patron belirdi! Buraya toplanın!',
    icon: Icons.coronavirus_rounded,
    category: 'combat',
  ),
  TacticalMacroItem(
    id: 'focus',
    label: 'Şifacıya Odak',
    text: '🎯 Odak: Şifacıyı hedef alın!',
    icon: Icons.gps_fixed_rounded,
    category: 'combat',
  ),
  TacticalMacroItem(
    id: 'mana',
    label: 'Enerji Yok',
    text: '⚡ Mana/Enerji bitti! Bekleyin.',
    icon: Icons.battery_alert_rounded,
    category: 'combat',
  ),

  // Social & MMORPG Quick Phrases
  TacticalMacroItem(
    id: 'hello',
    label: 'Selam',
    text: '👋 Herkese selamlar, iyi oyunlar!',
    icon: Icons.waving_hand_rounded,
    category: 'social',
  ),
  TacticalMacroItem(
    id: 'gg',
    label: 'Tebrikler',
    text: '🏆 Harika savaştı, herkesi tebrik ederim!',
    icon: Icons.emoji_events_rounded,
    category: 'social',
  ),
  TacticalMacroItem(
    id: 'thanks',
    label: 'Teşekkür',
    text: '🙏 Destek ve iyileştirme için teşekkürler!',
    icon: Icons.favorite_rounded,
    category: 'social',
  ),
  TacticalMacroItem(
    id: 'lfg',
    label: 'Grup +1',
    text: '🔥 Zindan ve baskın için +1 aranıyor!',
    icon: Icons.local_fire_department_rounded,
    category: 'social',
  ),
  TacticalMacroItem(
    id: 'guild_invite',
    label: 'Lonca Davet',
    text: '🤝 Aktif loncamıza katılmak ister misiniz?',
    icon: Icons.people_alt_rounded,
    category: 'social',
  ),
  TacticalMacroItem(
    id: 'trade_wts',
    label: 'Ticaret',
    text: '💎 Pazar ve takas tekliflerine açığım.',
    icon: Icons.storefront_rounded,
    category: 'social',
  ),
];

const List<String> kQuickEmotes = <String>[
  '⚔️', '🛡️', '🏹', '🔮', '👑', '🔥',
  '⚡', '💎', '🎯', '💀', '🌟', '💣',
  '🏆', '🙏', '👏', '💪', '✨', '🐺',
];

/// 2027 Aion 2 Mobile Tactical Macro & Quick Emote Radial Wheel / Tray
class ChatMacroWheel extends StatefulWidget {
  const ChatMacroWheel({
    super.key,
    required this.activeChannel,
    required this.onSelectMacro,
    required this.onClose,
  });

  final ChatChannel activeChannel;
  final ValueChanged<String> onSelectMacro;
  final VoidCallback onClose;

  @override
  State<ChatMacroWheel> createState() => _ChatMacroWheelState();
}

class _ChatMacroWheelState extends State<ChatMacroWheel> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isRadialView = false;
  int? _hoveredRadialIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _triggerSelection(String text) {
    HapticFeedback.lightImpact();
    widget.onSelectMacro(text);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.activeChannel.accentColor;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(ChatDesignSystem.radiusXl)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: ChatDesignSystem.blurGlassSigma, sigmaY: ChatDesignSystem.blurGlassSigma),
        child: Container(
          decoration: BoxDecoration(
            color: ChatDesignSystem.colorBgGlassOverlay,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(ChatDesignSystem.radiusXl)),
            border: Border(
              top: BorderSide(color: accent.withValues(alpha: 0.4), width: 1.5),
              left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Header with handle and controls
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.bolt_rounded, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'Taktik Makrolar & İfadeler',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    const Spacer(),
                    // Radial Wheel / Tray view toggle
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isRadialView = !_isRadialView);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isRadialView ? accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
                          border: Border.all(
                            color: _isRadialView ? accent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              _isRadialView ? Icons.radar_rounded : Icons.grid_view_rounded,
                              size: 13,
                              color: _isRadialView ? accent : Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isRadialView ? 'Çark Modu' : 'Tepsi Modu',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _isRadialView ? accent : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              if (_isRadialView)
                _buildRadialWheel(accent)
              else
                _buildTrayView(accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrayView(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Tabs
        TabBar(
          controller: _tabController,
          indicatorColor: accent,
          indicatorWeight: 2.5,
          labelColor: accent,
          unselectedLabelColor: ChatDesignSystem.colorTextTertiary,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const <Widget>[
            Tab(text: '⚔️ Savaş'),
            Tab(text: '💬 Sosyal'),
            Tab(text: '✨ İfadeler'),
          ],
        ),
        SizedBox(
          height: 190,
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildMacroList('combat', accent),
              _buildMacroList('social', accent),
              _buildEmoteGrid(accent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroList(String category, Color accent) {
    final List<TacticalMacroItem> items =
        kTacticalMacros.where((TacticalMacroItem m) => m.category == category).toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 6),
      itemBuilder: (BuildContext context, int index) {
        final TacticalMacroItem macro = items[index];
        return InkWell(
          onTap: () => _triggerSelection(macro.text),
          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusSm),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(macro.icon, size: 14, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        macro.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        macro.text,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ChatDesignSystem.colorTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.send_rounded, size: 13, color: accent.withValues(alpha: 0.6)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmoteGrid(Color accent) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: kQuickEmotes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (BuildContext context, int index) {
        final String emote = kQuickEmotes[index];
        return InkWell(
          onTap: () => _triggerSelection(emote),
          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            alignment: Alignment.center,
            child: Text(emote, style: const TextStyle(fontSize: 20)),
          ),
        );
      },
    );
  }

  /// 2027 Aion 2 Radial Tactical Wheel
  Widget _buildRadialWheel(Color accent) {
    final List<TacticalMacroItem> combatMacros =
        kTacticalMacros.where((TacticalMacroItem m) => m.category == 'combat').take(8).toList();

    const double wheelSize = 210;
    const double radius = 75;

    return Container(
      height: 230,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Outer decorative runic ring
          Container(
            width: wheelSize,
            height: wheelSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
              gradient: RadialGradient(
                colors: <Color>[accent.withValues(alpha: 0.08), Colors.transparent],
                stops: const <double>[0.3, 1.0],
              ),
            ),
          ),
          // Center Core
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ChatDesignSystem.colorBgSecondary,
              border: Border.all(color: accent.withValues(alpha: 0.6), width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 16),
              ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.touch_app_rounded, size: 16, color: accent),
                Text(
                  'SEÇİN',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: accent),
                ),
              ],
            ),
          ),
          // Radial Buttons
          ...List<Widget>.generate(combatMacros.length, (int i) {
            final double angle = (i * 2 * math.pi / combatMacros.length) - (math.pi / 2);
            final double x = radius * math.cos(angle);
            final double y = radius * math.sin(angle);
            final TacticalMacroItem macro = combatMacros[i];
            final bool isHovered = _hoveredRadialIndex == i;

            return Transform.translate(
              offset: Offset(x, y),
              child: GestureDetector(
                onTapDown: (_) => setState(() => _hoveredRadialIndex = i),
                onTapUp: (_) {
                  setState(() => _hoveredRadialIndex = null);
                  _triggerSelection(macro.text);
                },
                onTapCancel: () => setState(() => _hoveredRadialIndex = null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHovered ? accent : ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.95),
                    border: Border.all(
                      color: isHovered ? Colors.white : accent.withValues(alpha: 0.5),
                      width: isHovered ? 2 : 1,
                    ),
                    boxShadow: <BoxShadow>[
                      if (isHovered)
                        BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                  child: Icon(
                    macro.icon,
                    size: 16,
                    color: isHovered ? Colors.black : Colors.white,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

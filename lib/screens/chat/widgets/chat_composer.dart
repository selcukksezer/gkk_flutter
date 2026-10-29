import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/layout/game_chrome.dart';
import '../../../core/services/app_haptics.dart';
import '../../../core/utils/keyboard_dismiss.dart';
import '../chat_design_system.dart';
import '../chat_models.dart';

/// AAA Luxury Chat Composer widget for fantasy/cyberpunk MMO.
///
/// Features:
/// - Robust lifecycle: internal/external FocusNode & reactive TextEditingController management
/// - Frosted glassmorphism background with channel-colored ambient glow
/// - Real-time reactive character counter with warning/error states
/// - Quick emote drawer & attachment triggers with haptic feedback
/// - High-precision keyboard and bottom clearance responsive padding
/// - Animated send button with tactile press feedback and channel accent shaders
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.asPanel,
    required this.activeChannel,
    required this.activeBan,
    required this.messageController,
    required this.isSending,
    required this.maxMessageLength,
    required this.blockedUserCount,
    required this.onSend,
    required this.onOpenBlockedUsers,
    this.onToggleMacroWheel,
    this.isMacroWheelOpen = false,
    this.focusNode,
    this.onAttachItem,
    this.onToggleEmoji,
  });

  final bool asPanel;
  final ChatChannel activeChannel;
  final ChatBan? activeBan;
  final TextEditingController messageController;
  final bool isSending;
  final int maxMessageLength;
  final int blockedUserCount;
  final VoidCallback onSend;
  final VoidCallback onOpenBlockedUsers;
  final VoidCallback? onToggleMacroWheel;
  final bool isMacroWheelOpen;
  final FocusNode? focusNode;
  final VoidCallback? onAttachItem;
  final VoidCallback? onToggleEmoji;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool _isFocused = false;
  bool _isSendPressed = false;
  bool _showQuickEmotes = false;

  static const List<String> _quickEmotes = <String>[
    '⚔️', '🛡️', '💎', '🔥', '⚡', '👑', '💰', '✨', '💀', '🎯', '🤝', '🏆', '🧪', '🚩', '❤️', '👀',
  ];

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_handleFocusChange);
    widget.messageController.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      if (widget.focusNode == null && _internalFocusNode == null) {
        _internalFocusNode = FocusNode();
      }
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
    if (oldWidget.messageController != widget.messageController) {
      oldWidget.messageController.removeListener(_handleTextChange);
      widget.messageController.addListener(_handleTextChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    widget.messageController.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused != _effectiveFocusNode.hasFocus) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  void _handleTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _insertEmote(String emote) {
    AppHaptics.selection();
    final String currentText = widget.messageController.text;
    final TextSelection selection = widget.messageController.selection;
    final String newText;
    final int newOffset;

    if (selection.start >= 0 && selection.end >= 0) {
      newText = currentText.replaceRange(selection.start, selection.end, emote);
      newOffset = selection.start + emote.length;
    } else {
      newText = '$currentText$emote';
      newOffset = newText.length;
    }

    if (newText.length <= widget.maxMessageLength) {
      widget.messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }
  }

  void _toggleEmoteTray() {
    AppHaptics.light();
    if (widget.onToggleEmoji != null) {
      widget.onToggleEmoji!();
    } else {
      setState(() {
        _showQuickEmotes = !_showQuickEmotes;
      });
    }
  }

  void _handleSend() {
    final bool isSystemChannel = widget.activeChannel == ChatChannel.system;
    final bool canSend = !isSystemChannel &&
        !widget.isSending &&
        widget.activeBan == null &&
        widget.messageController.text.trim().isNotEmpty;

    if (!canSend) return;

    AppHaptics.medium();
    dismissKeyboard(context);
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSystemChannel = widget.activeChannel == ChatChannel.system;
    final String trimmedText = widget.messageController.text.trim();
    final bool canSend = !isSystemChannel &&
        !widget.isSending &&
        widget.activeBan == null &&
        trimmedText.isNotEmpty;
    final int charCount = widget.messageController.text.length;

    final double mediaBottom = MediaQuery.paddingOf(context).bottom;
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final double bottomBarPadding = (widget.asPanel || isKeyboardOpen)
        ? 0.0
        : math.max(0.0, gameBottomBarClearance(context) - mediaBottom);

    final String hintText = widget.activeBan != null
        ? 'Sohbete erişiminiz kısıtlı'
        : isSystemChannel
            ? 'Sistem kanalı salt okunurdur'
            : switch (widget.activeChannel) {
                ChatChannel.global => 'Dünya kanalında yaz...',
                ChatChannel.guild => 'Lonca kanalında yaz...',
                ChatChannel.party => 'Grup mesajı yaz...',
                ChatChannel.dm => 'Fısıltı mesajı yaz...',
                ChatChannel.trade => 'Pazar teklifi yaz...',
                _ => '${widget.activeChannel.label} kanalında yaz...',
              };

    final Color accentColor = widget.activeChannel.accentColor;

    return SafeArea(
      top: false,
      bottom: widget.asPanel,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomBarPadding),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: ChatDesignSystem.blurGlassSigma,
              sigmaY: ChatDesignSystem.blurGlassSigma,
            ),
            child: AnimatedContainer(
              duration: ChatDesignSystem.durationBase,
              padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
              decoration: BoxDecoration(
                color: ChatDesignSystem.colorBgGlassOverlay,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    ChatDesignSystem.colorBgGlassOverlay,
                    ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.95),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: _isFocused
                        ? accentColor.withValues(alpha: 0.70)
                        : accentColor.withValues(alpha: 0.24),
                    width: _isFocused ? 1.5 : 1.0,
                  ),
                ),
                boxShadow: <BoxShadow>[
                  if (_isFocused) ...<BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.22),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, -3),
                    ),
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, -1),
                    ),
                  ],
                  const BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 14,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Quick Emotes Tray with Frosted Glass Pills
                  if (_showQuickEmotes && !isSystemChannel) ...<Widget>[
                    Container(
                      height: 42,
                      margin: const EdgeInsets.only(bottom: ChatDesignSystem.spaceSm),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _quickEmotes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (BuildContext context, int index) {
                          final String emote = _quickEmotes[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _insertEmote(emote),
                              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusSm),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Colors.white.withValues(alpha: 0.08),
                                      Colors.white.withValues(alpha: 0.03),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(ChatDesignSystem.radiusSm),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    width: 1.0,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(emote, style: const TextStyle(fontSize: 16)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Real-time character count warning
                  if (charCount > widget.maxMessageLength * 0.75 && !isSystemChannel)
                    Padding(
                      padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceSm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (charCount >= widget.maxMessageLength
                                      ? ChatDesignSystem.colorError
                                      : ChatDesignSystem.colorWarning)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (charCount >= widget.maxMessageLength
                                        ? ChatDesignSystem.colorError
                                        : ChatDesignSystem.colorWarning)
                                    .withValues(alpha: 0.45),
                                width: 0.9,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: (charCount >= widget.maxMessageLength
                                          ? ChatDesignSystem.colorError
                                          : ChatDesignSystem.colorWarning)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              '$charCount/${widget.maxMessageLength}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: charCount >= widget.maxMessageLength
                                    ? ChatDesignSystem.colorError
                                    : ChatDesignSystem.colorWarning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Main Input Row
                  Row(
                    children: <Widget>[
                      // Macro Wheel Button
                      if (widget.onToggleMacroWheel != null && !isSystemChannel) ...<Widget>[
                        Tooltip(
                          message: 'Hızlı Mesajlar',
                          child: GestureDetector(
                            onTap: () {
                              AppHaptics.light();
                              widget.onToggleMacroWheel!();
                            },
                            child: AnimatedContainer(
                              duration: ChatDesignSystem.durationBase,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: widget.isMacroWheelOpen
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          accentColor.withValues(alpha: 0.35),
                                          accentColor.withValues(alpha: 0.18),
                                        ],
                                      )
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          Colors.white.withValues(alpha: 0.07),
                                          Colors.white.withValues(alpha: 0.03),
                                        ],
                                      ),
                                border: Border.all(
                                  color: widget.isMacroWheelOpen
                                      ? accentColor.withValues(alpha: 0.85)
                                      : Colors.white.withValues(alpha: 0.14),
                                  width: widget.isMacroWheelOpen ? 1.2 : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                                boxShadow: widget.isMacroWheelOpen
                                    ? <BoxShadow>[
                                        BoxShadow(
                                          color: accentColor.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.bolt_rounded,
                                size: 18,
                                color: widget.isMacroWheelOpen ? accentColor : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: ChatDesignSystem.spaceSm),
                      ],

                      // Quick Emote Toggle Button
                      if (!isSystemChannel) ...<Widget>[
                        Tooltip(
                          message: 'Hızlı İfadeler',
                          child: GestureDetector(
                            onTap: _toggleEmoteTray,
                            child: AnimatedContainer(
                              duration: ChatDesignSystem.durationBase,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: _showQuickEmotes
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          accentColor.withValues(alpha: 0.35),
                                          accentColor.withValues(alpha: 0.18),
                                        ],
                                      )
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          Colors.white.withValues(alpha: 0.07),
                                          Colors.white.withValues(alpha: 0.03),
                                        ],
                                      ),
                                border: Border.all(
                                  color: _showQuickEmotes
                                      ? accentColor.withValues(alpha: 0.85)
                                      : Colors.white.withValues(alpha: 0.14),
                                  width: _showQuickEmotes ? 1.2 : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                                boxShadow: _showQuickEmotes
                                    ? <BoxShadow>[
                                        BoxShadow(
                                          color: accentColor.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.sentiment_satisfied_alt_rounded,
                                size: 18,
                                color: _showQuickEmotes ? accentColor : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: ChatDesignSystem.spaceSm),
                      ],

                      // Optional Item Attachment Button
                      if (widget.onAttachItem != null && !isSystemChannel) ...<Widget>[
                        Tooltip(
                          message: 'Eşya Bağla',
                          child: GestureDetector(
                            onTap: () {
                              AppHaptics.light();
                              widget.onAttachItem!();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    Colors.white.withValues(alpha: 0.07),
                                    Colors.white.withValues(alpha: 0.03),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: ChatDesignSystem.spaceSm),
                      ],

                      // Text Field Container with Frosted Glass & Glowing Active Focus Border
                      Expanded(
                        child: AnimatedContainer(
                          duration: ChatDesignSystem.durationBase,
                          decoration: BoxDecoration(
                            color: ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.82),
                            gradient: _isFocused
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.88),
                                      accentColor.withValues(alpha: 0.06),
                                    ],
                                  )
                                : null,
                            border: Border.all(
                              color: widget.activeBan != null
                                  ? ChatDesignSystem.colorError.withValues(alpha: 0.5)
                                  : isSystemChannel
                                      ? Colors.white.withValues(alpha: 0.07)
                                      : _isFocused
                                          ? accentColor.withValues(alpha: 0.85)
                                          : accentColor.withValues(alpha: 0.28),
                              width: _isFocused ? 1.5 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                            boxShadow: _isFocused
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.24),
                                      blurRadius: 10,
                                      spreadRadius: 0.5,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: <Widget>[
                              // Channel Icon Indicator with Cyber Glass Aura
                              Padding(
                                padding: const EdgeInsets.only(left: 10, right: 6),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.38),
                                      width: 0.9,
                                    ),
                                    boxShadow: _isFocused
                                        ? <BoxShadow>[
                                            BoxShadow(
                                              color: accentColor.withValues(alpha: 0.25),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    widget.activeChannel.icon,
                                    size: 13,
                                    color: accentColor,
                                  ),
                                ),
                              ),

                              // Actual TextField
                              Expanded(
                                child: TextField(
                                  controller: widget.messageController,
                                  focusNode: _effectiveFocusNode,
                                  enabled: widget.activeBan == null && !isSystemChannel,
                                  maxLength: widget.maxMessageLength,
                                  maxLines: 1,
                                  cursorColor: accentColor,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _handleSend(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: ChatDesignSystem.colorTextPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: hintText,
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.55),
                                    ),
                                    counter: const Offstage(),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: ChatDesignSystem.spaceSm,
                                      vertical: ChatDesignSystem.spaceMd,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),

                              // Clear Button when has text
                              if (widget.messageController.text.isNotEmpty && !widget.isSending)
                                GestureDetector(
                                  onTap: () {
                                    AppHaptics.selection();
                                    widget.messageController.clear();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: ChatDesignSystem.spaceSm),

                      // Options Popup Menu with Glassmorphism
                      PopupMenuButton<String>(
                        tooltip: 'Sohbet seçenekleri',
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.85),
                        ),
                        color: ChatDesignSystem.colorBgSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        elevation: 12,
                        onSelected: (String value) {
                          if (value == 'blocked') {
                            AppHaptics.light();
                            widget.onOpenBlockedUsers();
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'blocked',
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.volume_off_rounded, size: 16, color: Colors.white70),
                                const SizedBox(width: 8),
                                Text(
                                  'Susturulanlar${widget.blockedUserCount == 0 ? '' : ' (${widget.blockedUserCount})'}',
                                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: ChatDesignSystem.spaceSm),

                      // Send Button with Micro-Bounce & Luminous Gradient
                      GestureDetector(
                        onTapDown: canSend ? (_) => setState(() => _isSendPressed = true) : null,
                        onTapUp: canSend
                            ? (_) {
                                setState(() => _isSendPressed = false);
                                _handleSend();
                              }
                            : null,
                        onTapCancel: () {
                          if (_isSendPressed) setState(() => _isSendPressed = false);
                        },
                        child: AnimatedScale(
                          scale: _isSendPressed ? 0.90 : 1.0,
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOutCubic,
                          child: AnimatedContainer(
                            duration: ChatDesignSystem.durationBase,
                            padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                            decoration: BoxDecoration(
                              gradient: canSend
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: <Color>[
                                        accentColor,
                                        accentColor.withValues(alpha: 0.80),
                                      ],
                                    )
                                  : LinearGradient(
                                      colors: <Color>[
                                        Colors.white.withValues(alpha: 0.08),
                                        Colors.white.withValues(alpha: 0.04),
                                      ],
                                    ),
                              border: Border.all(
                                color: canSend
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : Colors.white.withValues(alpha: 0.1),
                                width: canSend ? 1.3 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                              boxShadow: canSend
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.55),
                                        blurRadius: 14,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: widget.isSending
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                    ),
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    size: 16,
                                    color: canSend ? Colors.white : Colors.white.withValues(alpha: 0.3),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../components/common/item_icon_view.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'loot_chest_theme.dart';
import 'loot_models.dart';
import 'loot_reel_controller.dart';

Widget lootOpenInfoChip(String label, String value, LootChestTheme theme) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: Colors.black.withValues(alpha: 0.28),
      border: Border.all(color: theme.borderColor.withValues(alpha: 0.5)),
    ),
    child: RichText(
      text: TextSpan(
        children: <InlineSpan>[
          if (label.isNotEmpty)
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: theme.accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class LootBoxOpenPage extends StatefulWidget {
  const LootBoxOpenPage({
    super.key,
    required this.box,
    required this.theme,
    required this.displayName,
    required this.drops,
    required this.targetIndex,
    required this.resultPayload,
  });

  final LootBoxView box;
  final LootChestTheme theme;
  final String displayName;
  final List<LootDropView> drops;
  final int targetIndex;
  final Map<String, dynamic> resultPayload;

  @override
  State<LootBoxOpenPage> createState() => _LootBoxOpenPageState();
}

class _LootBoxOpenPageState extends State<LootBoxOpenPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _itemWidth = 138;
  static const double _itemGap = 12;

  late final AnimationController _controller;
  late final LootReelController _reel;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _reel = LootReelController(
      source: widget.drops,
      targetIndex: widget.targetIndex,
    );

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _reel.totalSpinMs),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _finished = true);
        }
      });

    _controller.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (_controller.isAnimating) {
          _controller.stop(canceled: false);
        }
      case AppLifecycleState.resumed:
        if (_controller.value >= 1.0) {
          if (!_finished) setState(() => _finished = true);
        } else if (!_controller.isAnimating) {
          _controller.forward();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, dynamic> reward = widget.resultPayload['reward'] is Map
        ? Map<String, dynamic>.from(widget.resultPayload['reward'] as Map)
        : <String, dynamic>{};

    final String resultName = reward['name']?.toString() ?? l10n.loot_odul;
    final String resultItemId = reward['item_id']?.toString() ?? '';
    final int qty = lootToInt(
      reward['quantity'],
      fallback: lootToInt(reward['amount'], fallback: 1),
    );

    final LootChestTheme theme = widget.theme;

    return Scaffold(
      backgroundColor: theme.fullscreenBgEnd,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                theme.fullscreenBgStart,
                theme.fullscreenBgEnd,
              ],
            ),
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.displayName,
                            style: AppTextStyles.h1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _finished
                                ? l10n.loot_open_finished_subtitle
                                : l10n.loot_open_spinning_subtitle,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _finished
                          ? () => Navigator.of(context).pop()
                          : null,
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 150,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: RadialGradient(
                            center: const Alignment(0.5, 0.2),
                            radius: 1.2,
                            colors: <Color>[
                              theme.radialCenter.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Image.asset(
                      theme.assetPath,
                      height: 170,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    lootOpenInfoChip(
                      'D',
                      '${widget.box.dropCount}',
                      theme,
                    ),
                    lootOpenInfoChip(
                      'N',
                      lootJackpotPercentLabel(widget.box.jackpotRate),
                      theme,
                    ),
                    lootOpenInfoChip(
                      '',
                      'x${widget.box.rewardMultiplier.toStringAsFixed(1)}',
                      theme,
                    ),
                    lootOpenInfoChip(
                      widget.box.currencyType == 'gems'
                          ? l10n.loot_elmas
                          : l10n.loot_altin,
                      lootCompactNum(widget.box.price),
                      theme,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double viewportWidth = constraints.maxWidth - 28;
                    final double itemExtent = _itemWidth + _itemGap;
                    final double stripWidth = _reel.items.length * itemExtent;
                    final double rawTargetOffset =
                        (_reel.targetReelIndex * itemExtent) -
                        ((viewportWidth - _itemWidth) / 2);
                    final double maxOffset = math.max(
                      0,
                      (_reel.items.length * itemExtent) - viewportWidth,
                    );
                    final double targetOffset = rawTargetOffset.clamp(
                      0,
                      maxOffset,
                    );

                    final Widget reelStrip = RepaintBoundary(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: stripWidth,
                        maxWidth: stripWidth,
                        child: SizedBox(
                          width: stripWidth,
                          height: 200,
                          child: Row(
                            children: List<Widget>.generate(
                              _reel.items.length,
                              (int index) {
                                final bool hit =
                                    index == _reel.targetReelIndex &&
                                    _finished;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    right: _itemGap,
                                  ),
                                  child: _LootReelCard(
                                    drop: _reel.items[index],
                                    width: _itemWidth,
                                    highlighted: hit,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );

                    return Column(
                      children: <Widget>[
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                const Color(0xFF0F1C3E).withValues(alpha: 0.95),
                                const Color(0xFF050B1A).withValues(alpha: 0.98),
                              ],
                            ),
                            border: Border.all(
                              color: theme.accentColor.withValues(alpha: 0.28),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: theme.accentColor.withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius: 32,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: viewportWidth,
                                height: 214,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    children: <Widget>[
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: <Color>[
                                                Colors.white.withValues(
                                                  alpha: 0.04,
                                                ),
                                                Colors.transparent,
                                                Colors.white.withValues(
                                                  alpha: 0.03,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      AnimatedBuilder(
                                        animation: _controller,
                                        child: reelStrip,
                                        builder: (
                                          BuildContext context,
                                          Widget? child,
                                        ) {
                                          final double eased = _reel.spinProgress(
                                            _controller.value,
                                            targetOffset,
                                            itemExtent,
                                          );
                                          final double currentOffset =
                                              targetOffset * eased;
                                          return Transform.translate(
                                            offset: Offset(-currentOffset, 0),
                                            child: child,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 6,
                                height: 224,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Color(0xFFFFD166),
                                      Color(0xFFFFA726),
                                      Color(0xFFFFD166),
                                    ],
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0xFFFFB300).withValues(
                                        alpha: 0.60,
                                      ),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const Positioned(
                                top: 0,
                                child: Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFFFFD166),
                                  size: 38,
                                ),
                              ),
                              const Positioned(
                                bottom: 0,
                                child: Icon(
                                  Icons.arrow_drop_up,
                                  color: Color(0xFFFFD166),
                                  size: 38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                  ),
                                ),
                                child: ItemIconView(
                                  iconValue: _finished
                                      ? reward['icon']?.toString() ?? ''
                                      : '',
                                  itemId: _finished && resultItemId.isNotEmpty
                                      ? resultItemId
                                      : null,
                                  size: 56,
                                  expand: true,
                                  fallback: '◻',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      _finished
                                          ? l10n.loot_kazandin
                                          : l10n.loot_locking,
                                      style: TextStyle(
                                        color: _finished
                                            ? const Color(0xFF22C55E)
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _finished ? '$resultName  x$qty' : '???',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.h3.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _finished
                                  ? () => Navigator.of(context).pop()
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _finished
                                    ? l10n.loot_odulu_al
                                    : l10n.loot_aciliyor,
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LootReelCard extends StatelessWidget {
  const _LootReelCard({
    required this.drop,
    required this.width,
    required this.highlighted,
  });

  final LootDropView drop;
  final double width;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color rarity = AppColors.forRarity(drop.rarity);

    return Container(
      width: width,
      height: 200,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            rarity.withValues(alpha: highlighted ? 0.40 : 0.24),
            const Color(0xFF0B1328),
          ],
        ),
        border: Border.all(
          color: rarity.withValues(alpha: highlighted ? 0.96 : 0.60),
          width: highlighted ? 1.8 : 1.1,
        ),
        boxShadow: highlighted
            ? <BoxShadow>[
                BoxShadow(
                  color: rarity.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.topRight,
            child: Text(
              drop.rarity.toUpperCase(),
              style: TextStyle(
                color: rarity.withValues(alpha: 0.92),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: ItemIconView(
                iconValue: drop.icon,
                itemId: drop.itemId,
                size: 74,
                expand: true,
                fallback: '◻',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            drop.itemName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '%${drop.dropRate.toStringAsFixed(2)}  x${drop.minQuantity}-${drop.maxQuantity}',
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

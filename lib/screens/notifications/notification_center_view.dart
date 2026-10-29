import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/notification_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'notification_card.dart';
import 'notification_category.dart';
import 'notification_runic_empty_state.dart';

/// Quick sub-filtering chips for high-density mobile inbox management.
enum NotificationSubFilter {
  all,
  highPriority,
  actionable,
  recent,
}

extension NotificationSubFilterX on NotificationSubFilter {
  String get label => switch (this) {
        NotificationSubFilter.all => 'Tümü',
        NotificationSubFilter.highPriority => 'Önemli',
        NotificationSubFilter.actionable => 'Eylemler',
        NotificationSubFilter.recent => 'Son 24s',
      };

  IconData get icon => switch (this) {
        NotificationSubFilter.all => Icons.filter_list_rounded,
        NotificationSubFilter.highPriority => Icons.stars_rounded,
        NotificationSubFilter.actionable => Icons.bolt_rounded,
        NotificationSubFilter.recent => Icons.schedule_rounded,
      };

  bool matches(GameNotificationItem item) => switch (this) {
        NotificationSubFilter.all => true,
        NotificationSubFilter.highPriority => item.priority >= 75,
        NotificationSubFilter.actionable => item.isActionable,
        NotificationSubFilter.recent =>
          DateTime.now().difference(item.createdAt).inHours < 24,
      };
}

/// 2027 Aion 2 Mobile Notification Center View.
///
/// Encapsulates:
/// - Frosted modal bottom sheet & full-screen container support with specular gleams.
/// - Categorized tabs (All, System, Combat, Social, Rewards) with unread count badge pills.
/// - Interactive quick filter chips (All, High Priority, Actionable, Recent).
/// - Action toolbar with category counter, channel accent indicator, refresh, and "Tümünü Oku" button.
/// - Scrollable notification cards list with swipe-to-dismiss gesture and animations.
/// - Procedural animated Aion-2 runic empty state when no notifications match the active filter.
class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({
    super.key,
    required this.items,
    this.isRefreshing = false,
    this.onItemTap,
    this.onItemDismiss,
    this.onMarkAllAsRead,
    this.onRefresh,
    this.padding,
    this.isModal = false,
    this.onClose,
  });

  final List<GameNotificationItem> items;
  final bool isRefreshing;
  final ValueChanged<GameNotificationItem>? onItemTap;
  final ValueChanged<GameNotificationItem>? onItemDismiss;
  final VoidCallback? onMarkAllAsRead;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry? padding;
  final bool isModal;
  final VoidCallback? onClose;

  /// Shows the Notification Center inside a luxury 2027 Aion 2 frosted modal bottom sheet.
  static Future<void> showModalSheet({
    required BuildContext context,
    required List<GameNotificationItem> items,
    bool isRefreshing = false,
    ValueChanged<GameNotificationItem>? onItemTap,
    ValueChanged<GameNotificationItem>? onItemDismiss,
    VoidCallback? onMarkAllAsRead,
    Future<void> Function()? onRefresh,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: NotificationCenterView(
            items: items,
            isRefreshing: isRefreshing,
            isModal: true,
            onClose: () => Navigator.of(sheetContext).pop(),
            onItemTap: onItemTap,
            onItemDismiss: onItemDismiss,
            onMarkAllAsRead: onMarkAllAsRead,
            onRefresh: onRefresh,
          ),
        );
      },
    );
  }

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController = ScrollController();
  late final TabController _tabController = TabController(
    length: NotificationCategory.values.length,
    vsync: this,
  );

  NotificationCategory _currentCategory = NotificationCategory.all;
  NotificationSubFilter _currentSubFilter = NotificationSubFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final NotificationCategory newCategory =
        NotificationCategory.values[_tabController.index];
    if (newCategory != _currentCategory) {
      HapticFeedback.selectionClick();
      setState(() => _currentCategory = newCategory);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<GameNotificationItem> allItems = widget.items;
    final List<GameNotificationItem> categoryItems =
        _currentCategory.filter(allItems);
    final List<GameNotificationItem> filteredItems =
        _currentSubFilter == NotificationSubFilter.all
            ? categoryItems
            : categoryItems
                .where((GameNotificationItem item) =>
                    _currentSubFilter.matches(item))
                .toList(growable: false);

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    // Responsive horizontal padding tuned for 390x844 (standard mobile) vs compact / tablet
    final double horizontalPadding = screenWidth < 360
        ? AppSpacing.md
        : (screenWidth <= 480 ? AppSpacing.base : AppSpacing.lg);

    final EdgeInsetsGeometry effectivePadding = widget.padding ??
        EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.sm,
          horizontalPadding,
          AppSpacing.xl + bottomInset,
        );

    Widget content = Column(
      children: <Widget>[
        if (widget.isModal) _buildModalHeader(),
        // Categorized Tabs Header
        _buildCategoryTabs(allItems),
        // Quick Sub-Filter Chips Row
        _buildFilterChips(categoryItems),
        // Sub-Toolbar: Filter info, Mark All Read & Refresh
        _buildActionToolbar(
          filteredCount: filteredItems.length,
          totalInCat: categoryItems.length,
          hasVisible: allItems.isNotEmpty,
          horizontalPadding: horizontalPadding,
        ),
        // Notification Cards List or Animated Empty / Loading State
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: widget.isRefreshing && allItems.isEmpty
                    ? _NotificationSkeletonList(
                        key: ValueKey<String>('skeleton_${_currentCategory.name}'),
                        padding: effectivePadding,
                        accentColor: _currentCategory.accentColor,
                      )
                    : filteredItems.isEmpty
                        ? NotificationRunicEmptyState(
                            key: ValueKey<String>(
                              'empty_${_currentCategory.name}_${_currentSubFilter.name}',
                            ),
                            category: _currentCategory,
                            onRefresh: widget.onRefresh != null
                                ? () {
                                    HapticFeedback.lightImpact();
                                    widget.onRefresh!();
                                  }
                                : null,
                            onResetCategory: (_currentSubFilter !=
                                        NotificationSubFilter.all ||
                                    _currentCategory != NotificationCategory.all)
                                ? () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _currentSubFilter =
                                          NotificationSubFilter.all;
                                      if (_currentCategory !=
                                          NotificationCategory.all) {
                                        _tabController.animateTo(0);
                                        _currentCategory =
                                            NotificationCategory.all;
                                      }
                                    });
                                  }
                                : null,
                          )
                        : RefreshIndicator(
                            key: const ValueKey<String>('notifications_list'),
                            color: AppColors.liquidGold,
                            backgroundColor: AppColors.spaceNavy,
                            onRefresh: widget.onRefresh ?? () async {},
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: effectivePadding,
                              itemCount: filteredItems.length,
                              itemBuilder: (BuildContext context, int index) {
                                final GameNotificationItem item =
                                    filteredItems[index];
                                return NotificationCard(
                                  key: ValueKey<String>('card_${item.id}'),
                                  item: item,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    widget.onItemTap?.call(item);
                                  },
                                  onDismiss: () {
                                    HapticFeedback.mediumImpact();
                                    widget.onItemDismiss?.call(item);
                                  },
                                );
                              },
                            ),
                          ),
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.isModal) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.bgCardElevated.withValues(alpha: 0.94),
                  AppColors.bgSurface.withValues(alpha: 0.96),
                  AppColors.carbonVoid.withValues(alpha: 0.98),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.liquidGold.withValues(alpha: 0.45),
                  width: 1.4,
                ),
                left: BorderSide(
                  color: AppColors.borderDefault.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                right: BorderSide(
                  color: AppColors.borderDefault.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.12),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, -6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: content,
          ),
        ),
      );
    }

    return content;
  }

  Widget _buildModalHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2.5),
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.liquidGold.withValues(alpha: 0.75),
                  AppColors.liquidGold.withValues(alpha: 0.35),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.liquidGold.withValues(alpha: 0.22),
                      AppColors.spaceNavy.withValues(alpha: 0.5),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.45),
                    width: 1.0,
                  ),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  size: 17,
                  color: AppColors.liquidGold,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'BİLDİRİM MERKEZİ',
                style: GoogleFonts.urbanist(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (widget.onClose != null)
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onClose?.call();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.bgDeep.withValues(alpha: 0.6),
                      border: Border.all(
                        color: AppColors.borderDefault.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.borderDefault.withValues(alpha: 0.35),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs(List<GameNotificationItem> allItems) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.bgCardElevated.withValues(alpha: 0.88),
                AppColors.bgSurface.withValues(alpha: 0.94),
                AppColors.carbonVoid.withValues(alpha: 0.96),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: AppColors.borderDefault.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Specular Top Gleam Line
              Container(
                height: 1.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.15),
                      _currentCategory.accentColor.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                physics: const BouncingScrollPhysics(),
                indicatorColor: _currentCategory.accentColor,
                indicatorWeight: 3.0,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onTap: (int index) {
                  final NotificationCategory cat =
                      NotificationCategory.values[index];
                  if (cat != _currentCategory) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentCategory = cat);
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(0);
                    }
                  }
                },
                tabs: NotificationCategory.values
                    .map((NotificationCategory cat) {
                  final int count = cat.countUnread(allItems);
                  final bool isSelected = cat == _currentCategory;

                  return Tab(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? cat.accentColor.withValues(alpha: 0.10)
                            : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            cat.icon,
                            size: 16,
                            color: isSelected
                                ? cat.accentColor
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.label.toUpperCase(),
                            style: GoogleFonts.urbanist(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              letterSpacing: 0.8,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                          ),
                          if (count > 0) ...<Widget>[
                            const SizedBox(width: 6),
                            _buildUnreadBadge(
                              count,
                              cat.accentColor,
                              isSelected,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<GameNotificationItem> categoryItems) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.50),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderDefault.withValues(alpha: 0.30),
            width: 0.8,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: NotificationSubFilter.values
              .map((NotificationSubFilter filter) {
            final bool isSelected = filter == _currentSubFilter;
            final int matchCount = filter == NotificationSubFilter.all
                ? categoryItems.length
                : categoryItems
                    .where((GameNotificationItem item) => filter.matches(item))
                    .length;
            final Color accent = _currentCategory.accentColor;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _currentSubFilter = filter);
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(0);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4.5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              accent.withValues(alpha: 0.25),
                              accent.withValues(alpha: 0.10),
                            ],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : AppColors.bgCardElevated.withValues(alpha: 0.55),
                    border: Border.all(
                      color: isSelected
                          ? accent.withValues(alpha: 0.70)
                          : AppColors.borderDefault.withValues(alpha: 0.45),
                      width: isSelected ? 1.2 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? <BoxShadow>[
                            BoxShadow(
                              color: accent.withValues(alpha: 0.22),
                              blurRadius: 8,
                              spreadRadius: -1,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        filter.icon,
                        size: 13,
                        color: isSelected ? accent : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        filter.label,
                        style: GoogleFonts.urbanist(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (matchCount > 0) ...<Widget>[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isSelected
                                ? accent.withValues(alpha: 0.35)
                                : AppColors.bgDeep.withValues(alpha: 0.6),
                            border: Border.all(
                              color: isSelected
                                  ? accent.withValues(alpha: 0.6)
                                  : AppColors.borderDefault
                                      .withValues(alpha: 0.4),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            '$matchCount',
                            style: GoogleFonts.urbanist(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? accent
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(int count, Color accent, bool isSelected) {
    final String label = count > 99 ? '99+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: LinearGradient(
          colors: isSelected
              ? <Color>[accent, accent.withValues(alpha: 0.75)]
              : <Color>[
                  AppColors.bgCardElevated,
                  AppColors.bgCard,
                ],
        ),
        border: Border.all(
          color: isSelected ? accent : AppColors.borderBright.withValues(alpha: 0.4),
          width: 0.9,
        ),
        boxShadow: isSelected
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: isSelected ? AppColors.bgDeep : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildActionToolbar({
    required int filteredCount,
    required int totalInCat,
    required bool hasVisible,
    required double horizontalPadding,
  }) {
    final bool hasSubFilter = _currentSubFilter != NotificationSubFilter.all;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.sm,
        horizontalPadding,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          // Filter channel indicator with luminous accent glow
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: _currentCategory.accentColor,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _currentCategory.accentColor.withValues(alpha: 0.65),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              filteredCount == 0
                  ? 'KAYIT BULUNMADI'
                  : hasSubFilter
                      ? '$filteredCount / $totalInCat BİLDİRİM'
                      : '$filteredCount BİLDİRİM',
              key: ValueKey<String>(
                'count_${_currentCategory.name}_${_currentSubFilter.name}_$filteredCount',
              ),
              style: GoogleFonts.urbanist(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (hasSubFilter) ...<Widget>[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _currentSubFilter = NotificationSubFilter.all);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.bgDeep.withValues(alpha: 0.6),
                  border: Border.all(
                    color: AppColors.borderDefault.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.close_rounded,
                      size: 10,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Sıfırla',
                      style: GoogleFonts.urbanist(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          // Refresh Icon Button or Refreshing Spinner with smooth transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.isRefreshing
                ? Container(
                    key: const ValueKey<String>('toolbar_spinner'),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _currentCategory.accentColor,
                      ),
                    ),
                  )
                : widget.onRefresh != null
                    ? _ToolbarIconButton(
                        key: const ValueKey<String>('toolbar_refresh_btn'),
                        icon: Icons.refresh_rounded,
                        tooltip: 'Yenile',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onRefresh?.call();
                        },
                      )
                    : const SizedBox.shrink(key: ValueKey<String>('toolbar_none')),
          ),
          // "Tümünü Oku" / Mark All As Read Button
          if (hasVisible && widget.onMarkAllAsRead != null) ...<Widget>[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onMarkAllAsRead?.call();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.liquidGold.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: AppColors.liquidGold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'TÜMÜNÜ OKU',
                      style: GoogleFonts.urbanist(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.liquidGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColors.bgCardElevated,
            border: Border.all(
              color: AppColors.borderDefault.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Shimmering procedural skeleton loading list matching NotificationCard layout.
class _NotificationSkeletonList extends StatefulWidget {
  const _NotificationSkeletonList({
    super.key,
    required this.padding,
    required this.accentColor,
  });

  final EdgeInsetsGeometry padding;
  final Color accentColor;

  @override
  State<_NotificationSkeletonList> createState() => _NotificationSkeletonListState();
}

class _NotificationSkeletonListState extends State<_NotificationSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (BuildContext context, Widget? child) {
        final double shimmer = _animController.value;
        final double opacity = 0.25 + (shimmer * 0.35);

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: widget.padding,
          itemCount: 4,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.bgCardElevated.withValues(alpha: 0.65),
                          AppColors.bgSurface.withValues(alpha: 0.75),
                        ],
                      ),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.15 + (shimmer * 0.12)),
                        width: 1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.08 + (shimmer * 0.08)),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            color: widget.accentColor.withValues(alpha: 0.08 + (shimmer * 0.08)),
                            border: Border.all(
                              color: widget.accentColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Container(
                                    width: 50,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: widget.accentColor.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    width: 40,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.white.withValues(alpha: opacity * 0.4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: 160,
                                height: 14,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.white.withValues(alpha: opacity * 0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                height: 12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.white.withValues(alpha: opacity * 0.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

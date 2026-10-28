import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/graphics_quality_service.dart';
import '../../providers/graphics_quality_provider.dart';

/// Drop-in replacement for [BackdropFilter] that automatically bypasses GPU
/// offscreen FBO blur passes on `Low` and `Medium` graphics tiers!
class AdaptiveGlassBlur extends StatelessWidget {
  const AdaptiveGlassBlur({
    super.key,
    required this.child,
    this.sigma = 10.0,
  });

  final Widget child;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GraphicsQualityService.instance,
      builder: (BuildContext context, Widget? cachedChild) {
        final GraphicsProfile prof = GraphicsQualityService.instance.profile;
        if (!prof.enableBackdropBlur || sigma <= 0.1) {
          return cachedChild!;
        }
        final double effectiveSigma =
            sigma.clamp(1.0, prof.blurSigma > 0 ? prof.blurSigma : sigma);
        return BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: effectiveSigma,
            sigmaY: effectiveSigma,
          ),
          child: cachedChild,
        );
      },
      child: child,
    );
  }
}

/// Compact 1-tap HUD pill displaying active graphics tier (+ live FPS when enabled)
/// and opening [showGraphicsQuickSheet] directly from Moradon or Dungeon Battle.
class GraphicsQuickPill extends ConsumerWidget {
  const GraphicsQuickPill({
    super.key,
    this.compact = true,
  });

  final bool compact;

  Color _tierAccent(GraphicsQualityTier tier) => switch (tier) {
        GraphicsQualityTier.low => const Color(0xFF4ADE80),
        GraphicsQualityTier.medium => const Color(0xFF38BDF8),
        GraphicsQualityTier.high => const Color(0xFFFBBF24),
        GraphicsQualityTier.ultra => const Color(0xFFF43F5E),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GraphicsQualityState gState = ref.watch(graphicsQualityProvider);
    final GraphicsProfile prof = gState.profile;
    final Color accent = _tierAccent(prof.tier);
    final String label = prof.activeBadgeTr;

    return GestureDetector(
      key: const Key('graphics_quick_pill'),
      onTap: () {
        HapticFeedback.selectionClick();
        showGraphicsQuickSheet(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7.5 : 10.0,
          vertical: compact ? 4.0 : 5.5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xEB090D16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent.withValues(alpha: 0.72),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              prof.isLow
                  ? Icons.bolt_rounded
                  : Icons.tune_rounded,
              size: compact ? 12.5 : 14.0,
              color: accent,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFFF8FAFC),
                fontSize: compact ? 9.8 : 10.8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optional lightweight floating FPS badge shown at top-left when enabled in Settings.
class LiveFpsOverlayBanner extends ConsumerWidget {
  const LiveFpsOverlayBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GraphicsProfile prof = ref.watch(graphicsQualityProvider).profile;
    if (!prof.showFpsOverlay) return const SizedBox.shrink();

    final int fps = prof.estimatedFps;
    final Color fpsColor = fps >= 50
        ? const Color(0xFF4ADE80)
        : (fps >= 30 ? const Color(0xFFFBBF24) : const Color(0xFFF87171));

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.only(left: 14, bottom: 92),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xE0070B12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: fpsColor.withValues(alpha: 0.65),
                width: 0.9,
              ),
            ),
            child: Text(
              '$fps FPS • ${prof.activeBadgeTr}',
              style: TextStyle(
                color: fpsColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showGraphicsQuickSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext ctx) => const _GraphicsQuickSheetBody(),
  );
}

class _GraphicsQuickSheetBody extends ConsumerWidget {
  const _GraphicsQuickSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GraphicsQualityState gState = ref.watch(graphicsQualityProvider);
    final GraphicsQualityNotifier notifier =
        ref.read(graphicsQualityProvider.notifier);
    final GraphicsProfile prof = gState.profile;
    final DeviceHardwareReport hw = gState.hardwareReport;

    const List<(GraphicsPreference, String, String, IconData, Color)> options =
        <(GraphicsPreference, String, String, IconData, Color)>[
      (
        GraphicsPreference.auto,
        'Otomatik (Önerilen)',
        'Telefon RAM, işlemci ve anlık FPS değerine göre kendini otomatik ayarlar.',
        Icons.auto_awesome_rounded,
        Color(0xFFFBBF24),
      ),
      (
        GraphicsPreference.low,
        'Düşük (Maksimum Hız)',
        'En eski / düşük RAM\'li telefonlar için bulanıklık, 3D eğim ve ağır efektleri kapatır.',
        Icons.bolt_rounded,
        Color(0xFF4ADE80),
      ),
      (
        GraphicsPreference.medium,
        'Orta (Dengeli)',
        'Akıcı 3D sahne + düşük pil ve bellek tüketimi.',
        Icons.speed_rounded,
        Color(0xFF38BDF8),
      ),
      (
        GraphicsPreference.high,
        'Yüksek',
        'Zengin ışıklandırma, tam yaratık sürüsü ve 60 FPS animasyon.',
        Icons.high_quality_rounded,
        Color(0xFFC084FC),
      ),
      (
        GraphicsPreference.ultra,
        'Ultra',
        'Tam 4K doku, cam yansımaları ve tüm atmosfer parçacıkları.',
        Icons.diamond_rounded,
        Color(0xFFF43F5E),
      ),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xF80B0F19),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFFFBBF24),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'GRAFİK VE PERFORMANS MODU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Aktif: ${prof.tier.shortLabelTr} • ~${prof.estimatedFps} FPS',
                    style: const TextStyle(
                      color: Color(0xFFFEF08A),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hw.summaryTr,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (prof.autoDowngraded) ...<Widget>[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x28F59E0B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'FPS düşüşü algılandığı için akıcılığı korumak adına otomatik olarak "${prof.tier.shortLabelTr}" kademesine optimize edildi.',
                  style: const TextStyle(
                    color: Color(0xFFFEF08A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (final (
                  GraphicsPreference mode,
                  String title,
                  String desc,
                  IconData icon,
                  Color color,
                ) in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: InkWell(
                  key: Key('graphics_mode_option_${mode.name}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await notifier.setPreference(mode);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: prof.preference == mode
                          ? color.withValues(alpha: 0.16)
                          : const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: prof.preference == mode
                            ? color
                            : Colors.white.withValues(alpha: 0.08),
                        width: prof.preference == mode ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                mode == GraphicsPreference.auto
                                    ? '$title → ${hw.recommendedTier.shortLabelTr}'
                                    : title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                desc,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10.5,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          prof.preference == mode
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: prof.preference == mode
                              ? color
                              : Colors.white38,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Divider(color: Colors.white12, height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: const Color(0xFF4ADE80),
              title: const Text(
                'Canlı FPS Sayacını Göster',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Sol alt kısımda anlık kare hızını ve aktif grafik kademesini gösterir',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
              ),
              value: prof.showFpsOverlay,
              onChanged: (bool v) => notifier.setShowFpsOverlay(v),
            ),
          ],
        ),
      ),
    );
  }
}

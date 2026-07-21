import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../qa/qa_flags.dart';
import '../../theme/app_colors.dart';

/// Reklam izleme sonucu.
enum AdResult { rewarded, dismissed, failed }

/// Rewarded reklam servisi — AdMob arayüzüne uygun sözleşme.
///
/// [MockAdService] yalnızca debug / QA'da ödül verir. Release/profile'da
/// fail-closed: [AdResult.failed] — gerçek AdMob yokken ücretsiz ödül yok.
abstract class AdService {
  static AdService instance = MockAdService();

  /// Rewarded ad göster. Kullanıcı sonuna kadar izlerse [AdResult.rewarded].
  Future<AdResult> showRewardedAd(BuildContext context, {String? placement});

  /// Reklam hazır mı? (Mock: yalnız debug/QA; AdMob'da preload durumu.)
  Future<bool> isAdReady();
}

class MockAdService implements AdService {
  static const Duration _adDuration = Duration(seconds: 3);

  /// Mock reward only in debug builds or explicit QA flag.
  static bool get allowMockReward =>
      kDebugMode || QaFlags.allowMockAds;

  @override
  Future<bool> isAdReady() async => allowMockReward;

  @override
  Future<AdResult> showRewardedAd(
    BuildContext context, {
    String? placement,
  }) async {
    if (!allowMockReward) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Reklam şu an kullanılamıyor.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return AdResult.failed;
    }

    final AdResult? result = await showDialog<AdResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (BuildContext ctx) => _MockAdDialog(duration: _adDuration),
    );
    return result ?? AdResult.dismissed;
  }
}

class _MockAdDialog extends StatefulWidget {
  const _MockAdDialog({required this.duration});

  final Duration duration;

  @override
  State<_MockAdDialog> createState() => _MockAdDialogState();
}

class _MockAdDialogState extends State<_MockAdDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _canSkip = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _canSkip = true);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.carbonVoid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.liquidGold.withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('📺', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              const Text(
                'REKLAM',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _canSkip
                    ? 'Ödülün hazır!'
                    : 'Ödül için reklamın bitmesini bekle...',
                style: const TextStyle(
                  color: AppColors.mutedTitanium,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (BuildContext context, Widget? child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _ctrl.value,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.liquidGold,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSkip
                      ? () => Navigator.of(context).pop(AdResult.rewarded)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.liquidGold,
                    foregroundColor: AppColors.carbonVoid,
                    disabledBackgroundColor:
                        AppColors.liquidGold.withValues(alpha: 0.2),
                  ),
                  child: Text(
                    _canSkip ? 'Ödülü Al' : 'Bekleniyor...',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (!_canSkip)
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(AdResult.dismissed),
                  child: const Text(
                    'Vazgeç (ödül yok)',
                    style: TextStyle(
                      color: AppColors.mutedTitanium,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

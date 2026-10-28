import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/graphics_quality_service.dart';

class GraphicsQualityState {
  const GraphicsQualityState({
    required this.profile,
    required this.hardwareReport,
  });

  final GraphicsProfile profile;
  final DeviceHardwareReport hardwareReport;
}

class GraphicsQualityNotifier extends Notifier<GraphicsQualityState> {
  @override
  GraphicsQualityState build() {
    final GraphicsQualityService svc = GraphicsQualityService.instance;
    void listener() {
      state = GraphicsQualityState(
        profile: svc.profile,
        hardwareReport: svc.hardwareReport,
      );
    }

    svc.addListener(listener);
    ref.onDispose(() => svc.removeListener(listener));
    return GraphicsQualityState(
      profile: svc.profile,
      hardwareReport: svc.hardwareReport,
    );
  }

  Future<void> setPreference(GraphicsPreference next) async {
    await GraphicsQualityService.instance.setPreference(next);
  }

  Future<void> setShowFpsOverlay(bool enabled) async {
    await GraphicsQualityService.instance.setShowFpsOverlay(enabled);
  }
}

final graphicsQualityProvider =
    NotifierProvider<GraphicsQualityNotifier, GraphicsQualityState>(
  GraphicsQualityNotifier.new,
);

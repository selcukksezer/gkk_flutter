import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import 'graphics_settings_service.dart';

/// Riverpod notifier managing [GraphicsConfigData] and interacting directly with
/// [GraphicsSettingsService] and [AdaptiveQualityScaler].
class GraphicsSettingsNotifier extends Notifier<GraphicsConfigData> {
  late final GraphicsSettingsService _service;
  VoidCallback? _serviceListener;

  @override
  GraphicsConfigData build() {
    _service = GraphicsSettingsService.instance;

    _serviceListener = () {
      state = _service.config;
    };
    _service.addListener(_serviceListener!);

    ref.onDispose(() {
      if (_serviceListener != null) {
        _service.removeListener(_serviceListener!);
      }
    });

    if (!_service.isLoaded) {
      Future<void>.microtask(() => _service.load());
    }

    return _service.config;
  }

  Future<void> setTier(GraphicsQualityTier tier) async {
    await _service.setTier(tier);
  }

  Future<void> setTargetFps(double fps) async {
    await _service.setTargetFps(fps);
  }

  Future<void> setResolutionScale(double scale) async {
    await _service.setResolutionScale(scale);
  }

  Future<void> setShadowsEnabled(bool enabled) async {
    await _service.setShadowsEnabled(enabled);
  }

  Future<void> setVolumetricFogEnabled(bool enabled) async {
    await _service.setVolumetricFogEnabled(enabled);
  }

  Future<void> setPostProcessingEnabled(bool enabled) async {
    await _service.setPostProcessingEnabled(enabled);
  }

  Future<void> setSsaoEnabled(bool enabled) async {
    await _service.setSsaoEnabled(enabled);
  }

  Future<void> setBloomEnabled(bool enabled) async {
    await _service.setBloomEnabled(enabled);
  }

  Future<void> setAutoScalerEnabled(bool enabled) async {
    await _service.setAutoScalerEnabled(enabled);
  }

  Future<void> resetToRecommended() async {
    await _service.resetToRecommended();
  }

  /// Feeds simulated frame telemetry to the underlying scaler engine for testing & live preview.
  void recordFrameTelemetry(double frameTimeMs) {
    _service.scaler.recordFrameTime(frameTimeMs);
  }
}

final graphicsSettingsProvider =
    NotifierProvider<GraphicsSettingsNotifier, GraphicsConfigData>(
  GraphicsSettingsNotifier.new,
);

/// Provider exposing real-time telemetry from [AdaptiveQualityScaler].
final scalerTelemetryProvider = Provider.autoDispose<ScalerTelemetry>((ref) {
  final service = GraphicsSettingsService.instance;
  // Re-evaluates whenever graphics config changes
  ref.watch(graphicsSettingsProvider);
  return service.scaler.getTelemetry();
});

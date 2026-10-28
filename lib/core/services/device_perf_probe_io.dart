import 'dart:io' show File, Platform;

import 'package:flutter/services.dart';

import 'device_perf_probe_model.dart';

const MethodChannel _kDevicePerfChannel =
    MethodChannel('gkk/device_performance');

(int totalMb, int availMb) _readProcMeminfoMb() {
  try {
    final File f = File('/proc/meminfo');
    if (!f.existsSync()) return (0, 0);
    int totalKb = 0;
    int availKb = 0;
    for (final String line in f.readAsLinesSync()) {
      if (line.startsWith('MemTotal:')) {
        final Match? m = RegExp(r'(\d+)').firstMatch(line);
        if (m != null) totalKb = int.tryParse(m.group(1)!) ?? 0;
      } else if (line.startsWith('MemAvailable:')) {
        final Match? m = RegExp(r'(\d+)').firstMatch(line);
        if (m != null) availKb = int.tryParse(m.group(1)!) ?? 0;
      }
      if (totalKb > 0 && availKb > 0) break;
    }
    return (totalKb ~/ 1024, availKb ~/ 1024);
  } catch (_) {
    return (0, 0);
  }
}

Future<RawDeviceSpecs> probePlatformDeviceSpecs() async {
  int cores = 4;
  try {
    cores = Platform.numberOfProcessors;
  } catch (_) {}

  final bool isMobile = Platform.isAndroid || Platform.isIOS;
  final (int procTotalMb, int procAvailMb) =
      (Platform.isAndroid || Platform.isLinux) ? _readProcMeminfoMb() : (0, 0);

  if (Platform.isAndroid) {
    try {
      final Map<Object?, Object?>? raw = await _kDevicePerfChannel
          .invokeMapMethod<Object?, Object?>('getDeviceSpecs')
          .timeout(const Duration(milliseconds: 1200));
      if (raw != null && raw.isNotEmpty) {
        final int chTotal = (raw['totalRamMb'] as num?)?.toInt() ?? 0;
        final int chAvail = (raw['availRamMb'] as num?)?.toInt() ?? 0;
        return RawDeviceSpecs(
          totalRamMb: chTotal > 0 ? chTotal : procTotalMb,
          availRamMb: chAvail > 0 ? chAvail : procAvailMb,
          cpuCores: (raw['cpuCores'] as num?)?.toInt() ?? cores,
          isLowRamDevice: (raw['isLowRamDevice'] as bool? ?? false) ||
              (procTotalMb > 0 && procTotalMb <= 2048),
          sdkInt: (raw['sdkInt'] as num?)?.toInt() ?? 0,
          deviceModel: (raw['deviceModel'] ?? '').toString(),
          isMobilePlatform: true,
          isWebPlatform: false,
        );
      }
    } catch (_) {}
  }

  return RawDeviceSpecs(
    totalRamMb: procTotalMb,
    availRamMb: procAvailMb,
    cpuCores: cores,
    isLowRamDevice: procTotalMb > 0 && procTotalMb <= 2048,
    sdkInt: 0,
    deviceModel: Platform.operatingSystem.toUpperCase(),
    isMobilePlatform: isMobile,
    isWebPlatform: false,
  );
}

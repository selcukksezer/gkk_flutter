import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'device_perf_probe_model.dart';

@JS('navigator')
external JSObject? get _jsNavigator;

Future<RawDeviceSpecs> probePlatformDeviceSpecs() async {
  int ramMb = 0;
  int cores = 4;
  bool isMobileUa = false;
  String model = 'Web';

  try {
    final JSObject? nav = _jsNavigator;
    if (nav != null) {
      if (nav.has('deviceMemory')) {
        final JSAny? memVal = nav.getProperty<JSAny?>('deviceMemory'.toJS);
        if (memVal != null && memVal.isA<JSNumber>()) {
          final double gb = (memVal as JSNumber).toDartDouble;
          if (gb > 0) {
            ramMb = (gb * 1024).round();
          }
        }
      }
      if (nav.has('hardwareConcurrency')) {
        final JSAny? coreVal =
            nav.getProperty<JSAny?>('hardwareConcurrency'.toJS);
        if (coreVal != null && coreVal.isA<JSNumber>()) {
          final int c = (coreVal as JSNumber).toDartInt;
          if (c > 0) cores = c;
        }
      }
      if (nav.has('userAgent')) {
        final JSAny? uaVal = nav.getProperty<JSAny?>('userAgent'.toJS);
        if (uaVal != null && uaVal.isA<JSString>()) {
          final String ua = (uaVal as JSString).toDart.toLowerCase();
          isMobileUa = ua.contains('android') ||
              ua.contains('iphone') ||
              ua.contains('ipad') ||
              ua.contains('mobile');
          if (ua.contains('iphone')) {
            model = 'iPhone Web';
          } else if (ua.contains('android')) {
            model = 'Android Web';
          }
        }
      }
    }
  } catch (_) {}

  return RawDeviceSpecs(
    totalRamMb: ramMb,
    availRamMb: 0,
    cpuCores: cores,
    isLowRamDevice: ramMb > 0 && ramMb <= 2048,
    sdkInt: 0,
    deviceModel: model,
    isMobilePlatform: isMobileUa,
    isWebPlatform: true,
  );
}

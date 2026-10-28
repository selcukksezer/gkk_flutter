import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/services/device_session_service.dart';

void main() {
  group('DeviceSessionService login handshake race protection', () {
    test('verifyCurrentDevice short-circuits cleanly while runAuthHandshake is active', () async {
      expect(DeviceSessionService.isHandshakeInFlight, isFalse);

      final Completer<void> gate = Completer<void>();
      final Future<String> loginFlow =
          DeviceSessionService.runAuthHandshake<String>(() async {
        expect(DeviceSessionService.isHandshakeInFlight, isTrue);

        // Simulate SessionEnforcementGate firing onAuthStateChange mid-login
        // before claimActiveDevice() finishes:
        final DeviceSessionVerifyResult midLoginCheck =
            await DeviceSessionService.verifyCurrentDevice();
        expect(midLoginCheck.valid, isTrue);
        expect(midLoginCheck.reason, DeviceSessionReason.ok);

        await gate.future;
        return 'ok';
      });

      expect(DeviceSessionService.isHandshakeInFlight, isTrue);
      gate.complete();
      expect(await loginFlow, 'ok');
      expect(DeviceSessionService.isHandshakeInFlight, isFalse);
    });

    test('isHandshakeInFlight resets even when login throws', () async {
      await expectLater(
        () => DeviceSessionService.runAuthHandshake<void>(() async {
          expect(DeviceSessionService.isHandshakeInFlight, isTrue);
          throw StateError('bad credentials');
        }),
        throwsStateError,
      );
      expect(DeviceSessionService.isHandshakeInFlight, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/system2_restriction_math.dart';

void main() {
  group('System2RestrictionMath', () {
    test('prisonGuardBribeCost floor 25000', () {
      expect(System2RestrictionMath.prisonGuardBribeCost(1), 25000);
      expect(System2RestrictionMath.prisonGuardBribeCost(10), 25000);
      expect(System2RestrictionMath.prisonGuardBribeCost(20), 30000);
    });

    test('prisonGuardSuccessChance softcap 60%', () {
      final double chance = System2RestrictionMath.prisonGuardSuccessChance(
        suspicion: 0,
        isShadow: true,
        lawyerUsedThisStay: true,
      );
      expect(chance, 0.60);
    });

    test('prisonGuardSuccessChance suspicion penalty', () {
      final double chance = System2RestrictionMath.prisonGuardSuccessChance(
        suspicion: 50,
        isShadow: false,
        lawyerUsedThisStay: false,
      );
      expect(chance, closeTo(0.40, 0.0001));
    });

    test('prisonGuardSuccessCutMinutes clamp 10..60', () {
      expect(System2RestrictionMath.prisonGuardSuccessCutMinutes(20), 10);
      expect(System2RestrictionMath.prisonGuardSuccessCutMinutes(100), 20);
      expect(System2RestrictionMath.prisonGuardSuccessCutMinutes(400), 60);
    });

    test('gemBillableMinutes admit floor', () {
      expect(
        System2RestrictionMath.gemBillableMinutes(
          remainingMinutes: 10,
          admitMinutes: 60,
        ),
        30,
      );
      expect(
        System2RestrictionMath.gemBillableMinutes(
          remainingMinutes: 40,
          admitMinutes: 60,
        ),
        40,
      );
    });

    test('clinicCutPct bands 5%→18%', () {
      expect(System2RestrictionMath.clinicCutPct(1), closeTo(0.05, 1e-9));
      expect(System2RestrictionMath.clinicCutPct(100), closeTo(0.18, 1e-9));
      expect(System2RestrictionMath.clinicCutPct(0), 0);
    });

    test('clinicCutMinutes never instant + clamp', () {
      // 8m * 18% → 2, clamp min 5 → cut 5 (leaves 3m)
      expect(
        System2RestrictionMath.clinicCutMinutes(
          remainingMinutes: 8,
          clinicLevel: 100,
          monumentLevel: 0,
        ),
        5,
      );
      // cut would clear → leave 1m
      expect(
        System2RestrictionMath.clinicCutMinutes(
          remainingMinutes: 5,
          clinicLevel: 100,
          monumentLevel: 0,
        ),
        4,
      );
      // 200 * 18% = 36 (under 45 softcap)
      expect(
        System2RestrictionMath.clinicCutMinutes(
          remainingMinutes: 200,
          clinicLevel: 100,
          monumentLevel: 0,
        ),
        36,
      );
      expect(
        System2RestrictionMath.clinicCutMinutes(
          remainingMinutes: 400,
          clinicLevel: 100,
          monumentLevel: 0,
        ),
        45,
      );
    });

    test('doctorOutcomeFromRoll buckets', () {
      expect(System2RestrictionMath.doctorOutcomeFromRoll(0.0), 'cut_20');
      expect(System2RestrictionMath.doctorOutcomeFromRoll(0.44), 'cut_20');
      expect(System2RestrictionMath.doctorOutcomeFromRoll(0.45), 'cut_10');
      expect(System2RestrictionMath.doctorOutcomeFromRoll(0.74), 'cut_10');
      expect(System2RestrictionMath.doctorOutcomeFromRoll(0.75), 'noop');
    });

    test('wardTimeBand broad only', () {
      expect(
        System2RestrictionMath.wardTimeBand(const Duration(minutes: 30)),
        '<1h',
      );
      expect(
        System2RestrictionMath.wardTimeBand(const Duration(hours: 2)),
        '1-3h',
      );
      expect(
        System2RestrictionMath.wardTimeBand(const Duration(hours: 5)),
        '3h+',
      );
    });
  });
}

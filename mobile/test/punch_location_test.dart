// The distance maths behind "1.2 km from Vishram bagh" in the attendance
// log. It is the only real computation in the location feature, and it is
// the one an owner would act on - so it is worth pinning to known values
// rather than trusting a formula transcribed from memory.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/punch_location.dart';

void main() {
  group('metresBetween', () {
    test('is zero for the same point', () {
      expect(
        PunchLocationService.metresBetween(18.5204, 73.8567, 18.5204, 73.8567),
        closeTo(0, 0.001),
      );
    });

    test('matches a known city-to-city distance', () {
      // Pune -> Mumbai, about 119 km great-circle.
      final m = PunchLocationService.metresBetween(18.5204, 73.8567, 19.0760, 72.8777);
      expect(m, closeTo(119000, 3000));
    });

    test('resolves the salon-sized distances the log actually renders', () {
      // ~111 m: one thousandth of a degree of latitude.
      final m = PunchLocationService.metresBetween(18.5204, 73.8567, 18.5214, 73.8567);
      expect(m, closeTo(111, 2));
    });

    test('is symmetric', () {
      final ab = PunchLocationService.metresBetween(18.52, 73.85, 19.07, 72.87);
      final ba = PunchLocationService.metresBetween(19.07, 72.87, 18.52, 73.85);
      expect(ab, closeTo(ba, 0.001));
    });

    test('handles crossing the equator and the meridian', () {
      final m = PunchLocationService.metresBetween(-1.0, -1.0, 1.0, 1.0);
      expect(m, closeTo(314000, 5000));
    });
  });

  group('PunchLocation', () {
    test('a fix reports coordinates and no note', () {
      const loc = PunchLocation(lat: 18.5, lng: 73.8);
      expect(loc.hasFix, isTrue);
      final f = loc.toFields('clockIn');
      expect(f['clockInLat'], 18.5);
      expect(f['clockInLng'], 73.8);
      expect(f['clockInLocationNote'], isNull);
    });

    test('a refusal reports the reason and no coordinates', () {
      const loc = PunchLocation(unavailable: 'denied');
      expect(loc.hasFix, isFalse);
      final f = loc.toFields('clockOut');
      expect(f['clockOutLat'], isNull);
      expect(f['clockOutLng'], isNull);
      expect(f['clockOutLocationNote'], 'denied');
    });
  });
}

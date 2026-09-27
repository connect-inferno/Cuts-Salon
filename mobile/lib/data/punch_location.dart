import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Where a punch was made, or why we don't know.
///
/// Deliberately never an exception. A denied browser permission, a phone
/// with location switched off, a slow fix - none of those are reasons to
/// stop someone clocking in, and an app that refuses attendance because of
/// a permission prompt will be worked around within a day. What we do
/// instead is record what we got, including "we got nothing", and show the
/// owner the difference.
@immutable
class PunchLocation {
  final double? lat;
  final double? lng;

  /// Why there are no coordinates - 'denied', 'disabled', 'timeout',
  /// 'error'. Null when [lat]/[lng] are present.
  final String? unavailable;

  const PunchLocation({this.lat, this.lng, this.unavailable});

  bool get hasFix => lat != null && lng != null;

  Map<String, dynamic> toFields(String prefix) => {
        '${prefix}Lat': lat,
        '${prefix}Lng': lng,
        '${prefix}LocationNote': unavailable,
      };
}

/// What this can and cannot do, so nobody mistakes it for enforcement:
///
/// Firestore rules cannot check a coordinate. They cannot call an API, and
/// they have no idea whether the numbers in a write describe where the
/// device actually was - an edited client can send whatever it likes. So
/// this is an audit trail, not a gate: it makes a punch from five miles
/// away *visible* to the owner, which is what stops it happening, rather
/// than blocking it at the boundary. Real enforcement needs a Cloud
/// Function (see the no-trusted-server note in CLAUDE.md).
class PunchLocationService {
  static Future<PunchLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const PunchLocation(unavailable: 'disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const PunchLocation(unavailable: 'denied');
      }

      // Medium accuracy and a short deadline on purpose: this runs while
      // somebody is standing at the door waiting for the button to respond,
      // and "roughly at the branch" is all the question needs.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return PunchLocation(lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      debugPrint('[Stylux] punch location unavailable: $e');
      return const PunchLocation(unavailable: 'error');
    }
  }

  /// Straight-line metres between two points (haversine).
  ///
  /// Used only to render "1.2 km from Vishram bagh" next to a punch. The
  /// earth is not a sphere and this is not survey-grade, but the question
  /// is "was this person at the salon or across town", where a metre either
  /// way is irrelevant.
  static double metresBetween(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    double toRad(double d) => d * math.pi / 180.0;

    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

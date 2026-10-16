import 'dart:convert';
import 'dart:math';

/// The owner's rotating attendance QR - staff clock in and out only by
/// scanning it (see attendanceQr in firestore.rules, which is what really
/// enforces this).
///
/// How often the owner's screen shows a new code. 30 seconds keeps a
/// photo of the screen useless almost as soon as it is taken, and costs
/// two small writes a minute while the screen is open (~1,200 in a
/// 10-hour day, well inside Firestore's free 20,000 writes/day).
/// The rules accept a code for 45 seconds from when it was issued, so a
/// scan made just before the code changed still goes through - keep that
/// number in firestore.rules above this one.
const attendanceQrRotation = Duration(seconds: 30);

const _prefix = 'stylux-att';
const _version = '1';

/// A fresh random code: 18 bytes from the platform's secure generator,
/// base64url (24 characters) - unguessable, and short enough to keep the
/// QR easy to scan from across a counter.
String newAttendanceQrToken([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(18, (_) => rng.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// What a scanned attendance QR says.
class AttendanceQrCode {
  final String salonId;
  final String branchId;
  final String token;

  const AttendanceQrCode({required this.salonId, required this.branchId, required this.token});

  /// The text inside the QR: `stylux-att:1:<salonId>:<branchId>:<token>`.
  /// The salon id lets the staff app say "this code is for another salon"
  /// instead of a bare permission error.
  String encode() => '$_prefix:$_version:$salonId:$branchId:$token';

  /// Null for anything that isn't one of our attendance codes - a payment
  /// QR, a URL, a code from a newer app version.
  static AttendanceQrCode? tryParse(String? raw) {
    if (raw == null) return null;
    final parts = raw.trim().split(':');
    if (parts.length != 5 || parts[0] != _prefix || parts[1] != _version) return null;
    if (parts.sublist(2).any((p) => p.isEmpty)) return null;
    return AttendanceQrCode(salonId: parts[2], branchId: parts[3], token: parts[4]);
  }

  /// The fields a punch stores alongside its clock time (`prefix` is
  /// `clockIn` or `clockOut`), which firestore.rules checks against the
  /// owner's live code.
  Map<String, dynamic> toPunchFields(String prefix) => {
        '${prefix}QrToken': token,
        '${prefix}QrBranchId': branchId,
      };
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/attendance_qr.dart';

void main() {
  test('a code round-trips through the QR text', () {
    const code = AttendanceQrCode(salonId: 'cuts-salon', branchId: 'br1', token: 'abcDEF123_-xyzabcDEF123_');
    final parsed = AttendanceQrCode.tryParse(code.encode());
    expect(parsed?.salonId, 'cuts-salon');
    expect(parsed?.branchId, 'br1');
    expect(parsed?.token, 'abcDEF123_-xyzabcDEF123_');
  });

  test('anything else is not an attendance code', () {
    for (final raw in [
      null,
      '',
      'upi://pay?pa=salon@upi',
      'https://g.page/r/review',
      'stylux-att:2:cuts-salon:br1:token',
      'stylux-att:1:cuts-salon:br1',
      'stylux-att:1::br1:token',
    ]) {
      expect(AttendanceQrCode.tryParse(raw), isNull, reason: '$raw');
    }
  });

  test('tokens are 24 url-safe characters and differ each time', () {
    final a = newAttendanceQrToken();
    final b = newAttendanceQrToken();
    expect(a.length, 24);
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(a), isTrue);
    expect(a, isNot(b));
    // Long enough for firestore.rules' token.size() >= 16 check.
    expect(newAttendanceQrToken(Random(1)).length, greaterThanOrEqualTo(16));
  });

  test('punch fields name the token and the branch', () {
    const code = AttendanceQrCode(salonId: 's', branchId: 'br1', token: 't');
    expect(code.toPunchFields('clockIn'), {'clockInQrToken': 't', 'clockInQrBranchId': 'br1'});
    expect(code.toPunchFields('clockOut'), {'clockOutQrToken': 't', 'clockOutQrBranchId': 'br1'});
  });
}

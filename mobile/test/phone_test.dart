import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/phone.dart';

void main() {
  test('accepts the ways a mobile number is typed', () {
    expect(indianMobile('9876543210'), '9876543210');
    expect(indianMobile(' 98765 43210 '), '9876543210');
    expect(indianMobile('+91 98765-43210'), '9876543210');
    expect(indianMobile('919876543210'), '9876543210');
    expect(indianMobile('09876543210'), '9876543210');
    expect(indianMobile('(987) 654-3210'), '9876543210');
  });

  test('refuses what is not an Indian mobile', () {
    expect(indianMobile(''), isNull);
    expect(indianMobile('abc'), isNull);
    expect(indianMobile('12345'), isNull);
    expect(indianMobile('1234567890'), isNull); // mobiles start with 6-9
    expect(indianMobile('98765432101'), isNull);
    expect(indianMobile('98765x43210'), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/birthday.dart';

void main() {
  test('birthdayKey pads to the "MM-DD" the WhatsApp function matches on', () {
    expect(birthdayKey(3, 7), '03-07');
    expect(birthdayKey(12, 25), '12-25');
  });

  test('parseBirthday accepts real dates only', () {
    expect(parseBirthday('10-14'), (10, 14));
    expect(parseBirthday('02-29'), (2, 29));
    expect(parseBirthday('02-30'), isNull);
    expect(parseBirthday('13-01'), isNull);
    expect(parseBirthday('1014'), isNull);
    expect(parseBirthday(null), isNull);
  });

  test('formatBirthday reads naturally', () {
    expect(formatBirthday('10-14'), '14 Oct');
    expect(formatBirthday('01-01'), '1 Jan');
    expect(formatBirthday(null), isNull);
  });
}

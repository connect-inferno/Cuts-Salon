import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/csv_export.dart';

void main() {
  test('plain text and numbers pass through', () {
    expect(csvField('Priya Sharma'), 'Priya Sharma');
    expect(csvField(350), '350');
    expect(csvField('-5.00'), '-5.00');
    expect(csvField(null), '');
  });

  test('commas, quotes and newlines are quoted', () {
    expect(csvField('Sharma, A.'), '"Sharma, A."');
    expect(csvField('Say "hi"'), '"Say ""hi"""');
  });

  test('text Excel would run as a formula opens as plain text', () {
    expect(csvField('=HYPERLINK("http://x","Click")'), '"\'=HYPERLINK(""http://x"",""Click"")"');
    expect(csvField('+91 98765'), '"\'+91 98765"');
    expect(csvField('-cut'), '"\'-cut"');
    expect(csvField('@SUM(A1)'), '"\'@SUM(A1)"');
  });

  test('a row with a formula-like name keeps its columns', () {
    expect(toCsv([['INV-1', '=1+1', '350.00']]), 'INV-1,"\'=1+1",350.00');
  });
}

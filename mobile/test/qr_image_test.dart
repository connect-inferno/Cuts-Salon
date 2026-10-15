// QR images are shrunk on the phone before upload: the upload function
// refuses anything that is not a small JPEG (directory-project/functions).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:mobile/data/qr_image.dart';

bool _isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff;

void main() {
  test('a big screenshot comes out as a small JPEG, long side 800', () {
    final big = img.Image(width: 1600, height: 2400);
    img.fill(big, color: img.ColorRgb8(250, 250, 250));
    img.fillRect(big, x1: 300, y1: 600, x2: 1300, y2: 1600, color: img.ColorRgb8(0, 0, 0));

    final out = compressQrImage(Uint8List.fromList(img.encodePng(big)));
    final back = img.decodeJpg(out)!;

    expect(_isJpeg(out), isTrue);
    expect(back.height, kQrMaxSide);
    expect(back.width, 533);
    expect(out.length, lessThan(kQrTargetBytes));
  });

  test('a transparent PNG gets a white background, not black', () {
    final clear = img.Image(width: 200, height: 200, numChannels: 4);
    img.fill(clear, color: img.ColorRgba8(0, 0, 0, 0));

    final back = img.decodeJpg(compressQrImage(Uint8List.fromList(img.encodePng(clear))))!;
    final p = back.getPixel(100, 100);

    expect(p.r, greaterThan(240));
    expect(p.g, greaterThan(240));
    expect(p.b, greaterThan(240));
  });

  test('a small image is not blown up', () {
    final small = img.Image(width: 300, height: 300);
    final back = img.decodeJpg(compressQrImage(Uint8List.fromList(img.encodePng(small))))!;
    expect(back.width, 300);
  });

  test('a file that is not an image is refused', () {
    expect(() => compressQrImage(Uint8List.fromList('hello'.codeUnits)), throwsFormatException);
  });
}

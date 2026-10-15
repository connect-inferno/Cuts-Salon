import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The longest side a QR image is stored at. Plenty for a phone screen and
/// for scanning, and it keeps the file small.
const int kQrMaxSide = 800;

/// Above this the upload is refused by the uploadSalonQr function
/// (directory-project/functions/qr_core.js MAX_BYTES is 400 KB), so the
/// shrinker keeps lowering quality until the image is well under it.
const int kQrTargetBytes = 250 * 1024;

/// Turns whatever the owner picked (a phone screenshot, a PNG from the bank
/// app, a photo of a printed QR) into a small JPEG: upright, at most
/// [kQrMaxSide] pixels on the long side, transparent areas made white -
/// a QR on a transparent background would otherwise turn black as a JPEG
/// and stop scanning.
///
/// Throws [FormatException] when the bytes are not an image.
Uint8List compressQrImage(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) throw const FormatException('That file is not an image.');

  var image = img.bakeOrientation(decoded);

  final longest = math.max(image.width, image.height);
  if (longest > kQrMaxSide) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? kQrMaxSide : null,
      height: image.height > image.width ? kQrMaxSide : null,
      interpolation: img.Interpolation.average,
    );
  }

  if (image.hasAlpha || image.hasPalette) {
    final flat = img.Image(width: image.width, height: image.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, image);
    image = flat;
  }

  var quality = 85;
  var out = img.encodeJpg(image, quality: quality);
  while (out.length > kQrTargetBytes && quality > 40) {
    quality -= 15;
    out = img.encodeJpg(image, quality: quality);
  }
  return Uint8List.fromList(out);
}

/// Opening a phone dialler, WhatsApp chat or email for a client, on
/// whichever platform this build is running: the browser on the web build,
/// url_launcher on the Android app. The stub (any other platform) reports
/// false, so the caller can say it didn't open instead of pretending.
library;

export 'open_link_stub.dart'
    if (dart.library.js_interop) 'open_link_web.dart'
    if (dart.library.io) 'open_link_io.dart';

/// The number as WhatsApp's wa.me links want it: country code + number,
/// digits only. Bare 10-digit Indian mobiles get 91 - the same rule the
/// WhatsApp functions use (functions/whatsapp_core.js normalizePhone).
String? whatsappNumber(String raw) {
  final trimmed = raw.trim();
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (trimmed.startsWith('+')) return digits.length >= 10 ? digits : null;
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length == 10) return '91$digits';
  if (digits.length == 12 && digits.startsWith('91')) return digits;
  return null;
}

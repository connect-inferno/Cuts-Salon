import 'package:url_launcher/url_launcher.dart';

/// Android (and other app builds): hands tel:, mailto: and https links
/// (wa.me included, which opens WhatsApp) to the phone's own apps.
///
/// Returns true once the request is made - launching is asynchronous, and
/// the one real failure (no app can open it) is reported by Android itself.
bool openLink(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  launchUrl(uri, mode: LaunchMode.externalApplication);
  return true;
}

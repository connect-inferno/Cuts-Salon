import 'package:web/web.dart' as web;

/// tel: and mailto: links are handed to the OS (the dialler or mail app)
/// in place; everything else opens in a new tab so the app stays where it
/// was.
bool openLink(String url) {
  if (url.startsWith('tel:') || url.startsWith('mailto:')) {
    web.window.location.href = url;
  } else {
    web.window.open(url, '_blank');
  }
  return true;
}

import 'package:web/web.dart' as web;

/// tel: links are handed to the OS (the dialler on a phone, a calling app
/// on a desktop) in place; everything else opens in a new tab so the app
/// stays where it was.
bool openLink(String url) {
  if (url.startsWith('tel:')) {
    web.window.location.href = url;
  } else {
    web.window.open(url, '_blank');
  }
  return true;
}

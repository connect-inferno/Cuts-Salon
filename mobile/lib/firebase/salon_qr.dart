import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_directory.dart' show directoryApp;
import 'salon_auth.dart';

/// The two QR images an owner can add in their Profile and show from Home.
enum QrKind {
  payment('paymentQrUrl'),
  review('reviewQrUrl');

  /// The settings/main field holding this image's download URL.
  final String settingsField;

  const QrKind(this.settingsField);
}

/// Uploads [jpeg] as this salon's [kind] QR and returns its download URL.
///
/// Goes through the uploadSalonQr Cloud Function in the shared
/// salon-saas-87b6a project, which saves it to that project's Storage at
/// salonQr/{salonId}/{kind}.jpg - but only after checking this sign-in
/// belongs to [salonId]'s project and is its active owner. The owner's ID
/// token is what proves that: owners sign in to their own salon's project,
/// not salon-saas, so Storage rules there can't (see
/// directory-project/functions/index.js).
///
/// Throws an [Exception] with a message fit to show the owner.
Future<String> uploadSalonQr({
  required String salonId,
  required QrKind kind,
  required Uint8List jpeg,
}) async {
  final app = SalonAuth.currentApp(salonId);
  final user = app == null ? null : FirebaseAuth.instanceFor(app: app).currentUser;
  final idToken = await user?.getIdToken();
  if (idToken == null) throw Exception('Please sign in again and retry.');

  try {
    final functions = FirebaseFunctions.instanceFor(app: await directoryApp(), region: 'asia-south1');
    final result = await functions
        .httpsCallable('uploadSalonQr', options: HttpsCallableOptions(timeout: const Duration(seconds: 45)))
        .call<Map<String, dynamic>>({
      'salonId': salonId,
      'kind': kind.name,
      'idToken': idToken,
      'imageBase64': base64Encode(jpeg),
    });
    final url = result.data['url'];
    if (url is! String || url.isEmpty) throw Exception('Upload failed - please try again.');
    return url;
  } on FirebaseFunctionsException catch (e) {
    // The function's own messages are written for the owner; anything else
    // (offline, function not deployed yet) gets a plain retry message.
    const ownMessages = {
      'invalid-argument',
      'failed-precondition',
      'unauthenticated',
      'permission-denied',
    };
    throw Exception(ownMessages.contains(e.code) && (e.message?.isNotEmpty ?? false)
        ? e.message
        : 'Could not upload right now - check your internet and try again.');
  }
}

// Cloud Functions for the shared salon-saas-87b6a project (login directory
// + operator registry + shared Storage). NOT the per-salon WhatsApp
// functions in mobile/functions - deploy this folder only to
// salon-saas-87b6a (see directory-project/README.md).
//
// uploadSalonQr: an owner's payment QR / Google review QR image, saved to
// this project's Storage at salonQr/{salonId}/{payment|review}.jpg.
//
// Why a function and not a direct upload: owners sign in to their own
// salon's Firebase project, not this one, so Storage rules here cannot tell
// who is uploading. Open writes would let anyone replace a salon's payment
// QR with their own and take its customers' money. So uploads are refused
// by storage.rules and come through here instead, where:
//
//   1. the caller's ID token is verified as issued by THAT salon's project
//      (verifyIdToken checks signature, expiry and audience = salonId);
//   2. their employees/{uid} record is read from that salon's Firestore
//      with their own token, so the salon's own security rules apply, and
//      it must say role OWNER and active (same test as isOwner() in
//      mobile/firestore.rules);
//   3. the salon must be listed in ALLOWED_SALON_IDS (.env), so a stranger's
//      own Firebase project can't use this bucket for storage.
//
// The token is never logged or stored.

const { initializeApp, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getStorage } = require('firebase-admin/storage');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineString } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const core = require('./qr_core');

initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 3 });

const ALLOWED_SALON_IDS = defineString('ALLOWED_SALON_IDS', {
  description: 'Comma-separated salon Firebase project ids allowed to upload QR images',
});

/** An Admin app that only knows the salon's project id - enough for
 * verifyIdToken, which checks the token against Google's public keys and
 * needs no credentials for that project. */
function salonAuth(salonId) {
  const name = `salon-${salonId}`;
  const app = getApps().find((a) => a.name === name) || initializeApp({ projectId: salonId }, name);
  return getAuth(app);
}

exports.uploadSalonQr = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (req) => {
  const { salonId, kind, idToken, imageBase64 } = req.data || {};

  if (!core.isValidSalonId(salonId) || !core.KINDS.includes(kind)) {
    throw new HttpsError('invalid-argument', 'Unknown salon or QR type.');
  }
  if (!core.parseAllowedSalons(ALLOWED_SALON_IDS.value()).includes(salonId)) {
    throw new HttpsError('failed-precondition', 'QR upload is not enabled for this salon yet.');
  }
  if (typeof idToken !== 'string' || typeof imageBase64 !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing sign-in or image.');
  }

  // 1. Who is this, according to the salon's own project?
  let uid;
  try {
    uid = (await salonAuth(salonId).verifyIdToken(idToken)).uid;
  } catch (_) {
    throw new HttpsError('unauthenticated', 'Please sign in again and retry.');
  }

  // 2. Are they that salon's active owner? Read with their own token, so
  // the salon's Firestore rules decide what this request may see.
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${salonId}/databases/(default)/documents/employees/${encodeURIComponent(uid)}`,
    { headers: { Authorization: `Bearer ${idToken}` } },
  );
  if (!res.ok || !core.isActiveOwnerDoc(await res.json())) {
    logger.warn('QR upload refused: not an active owner', { salonId, uid, status: res.status });
    throw new HttpsError('permission-denied', 'Only the salon owner can change these QR codes.');
  }

  // 3. A small JPEG, as the app sends.
  const buf = Buffer.from(imageBase64, 'base64');
  if (buf.length === 0 || buf.length > core.MAX_BYTES || !core.isJpeg(buf)) {
    throw new HttpsError('invalid-argument', 'That image could not be used - pick a JPG or PNG photo of the QR.');
  }

  const bucket = getStorage().bucket();
  const path = core.storagePath(salonId, kind);
  await bucket.file(path).save(buf, {
    resumable: false,
    contentType: 'image/jpeg',
    metadata: { cacheControl: 'public, max-age=300' },
  });

  logger.info('QR uploaded', { salonId, kind, bytes: buf.length, uid });
  return { url: core.downloadUrl(bucket.name, path, Date.now()) };
});

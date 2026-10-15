// Pure checks for uploadSalonQr, kept apart from index.js so they can be
// unit tested without Firebase (npm test).

/** The two QR images a salon can have. */
const KINDS = ['payment', 'review'];

/** Upper bound on what the app sends. It shrinks images to well under this
 * before uploading (lib/data/qr_image.dart), so anything bigger was not
 * sent by the app. */
const MAX_BYTES = 400 * 1024;

/** Firebase project ids: 6-30 chars, lowercase letters, digits, hyphens. */
function isValidSalonId(id) {
  return typeof id === 'string' && /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(id);
}

/** "cuts-salon, instyle-salon" -> ['cuts-salon', 'instyle-salon'] */
function parseAllowedSalons(raw) {
  return String(raw || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

/** The app always uploads a JPEG; check the bytes really are one. */
function isJpeg(buf) {
  return Buffer.isBuffer(buf) && buf.length > 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff;
}

/**
 * Whether a Firestore REST document (employees/{uid}) is an active owner.
 * Mirrors isOwner() in mobile/firestore.rules: role OWNER and active == true.
 */
function isActiveOwnerDoc(doc) {
  const f = (doc && doc.fields) || {};
  return f.role?.stringValue === 'OWNER' && f.active?.booleanValue === true;
}

function storagePath(salonId, kind) {
  return `salonQr/${salonId}/${kind}.jpg`;
}

/** A public download URL; [version] changes on every upload so phones
 * never show an old QR from cache. */
function downloadUrl(bucket, path, version) {
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(path)}?alt=media&v=${version}`;
}

module.exports = {
  KINDS,
  MAX_BYTES,
  isValidSalonId,
  parseAllowedSalons,
  isJpeg,
  isActiveOwnerDoc,
  storagePath,
  downloadUrl,
};

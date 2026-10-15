const test = require('node:test');
const assert = require('node:assert');
const core = require('./qr_core');

test('salon ids look like Firebase project ids', () => {
  assert.ok(core.isValidSalonId('cuts-salon'));
  assert.ok(core.isValidSalonId('test-salon-ee06a'));
  assert.ok(!core.isValidSalonId('../etc'));
  assert.ok(!core.isValidSalonId('Cuts-Salon'));
  assert.ok(!core.isValidSalonId('a/b'));
  assert.ok(!core.isValidSalonId(''));
  assert.ok(!core.isValidSalonId(undefined));
});

test('allowed list tolerates spaces and blanks', () => {
  assert.deepStrictEqual(core.parseAllowedSalons(' cuts-salon, instyle-salon ,,'), ['cuts-salon', 'instyle-salon']);
  assert.deepStrictEqual(core.parseAllowedSalons(undefined), []);
});

test('only JPEG bytes pass', () => {
  assert.ok(core.isJpeg(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00])));
  assert.ok(!core.isJpeg(Buffer.from([0x89, 0x50, 0x4e, 0x47])));
  assert.ok(!core.isJpeg(Buffer.from('<svg>')));
});

test('owner check matches isOwner() in firestore.rules', () => {
  const doc = (role, active) => ({ fields: { role: { stringValue: role }, ...(active === undefined ? {} : { active: { booleanValue: active } }) } });
  assert.ok(core.isActiveOwnerDoc(doc('OWNER', true)));
  assert.ok(!core.isActiveOwnerDoc(doc('OWNER', false)));
  // rules require active == true, so a missing flag is not enough
  assert.ok(!core.isActiveOwnerDoc(doc('OWNER', undefined)));
  assert.ok(!core.isActiveOwnerDoc(doc('EMPLOYEE', true)));
  assert.ok(!core.isActiveOwnerDoc({}));
  assert.ok(!core.isActiveOwnerDoc(null));
});

test('paths are per salon and per kind, URLs are cache-busted', () => {
  assert.strictEqual(core.storagePath('cuts-salon', 'payment'), 'salonQr/cuts-salon/payment.jpg');
  assert.strictEqual(
    core.downloadUrl('b.appspot.com', 'salonQr/cuts-salon/review.jpg', 42),
    'https://firebasestorage.googleapis.com/v0/b/b.appspot.com/o/salonQr%2Fcuts-salon%2Freview.jpg?alt=media&v=42',
  );
});

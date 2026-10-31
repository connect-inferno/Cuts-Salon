const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('./whatsapp_core');

test('normalizePhone adds 91 to Indian mobiles and rejects junk', () => {
  assert.equal(core.normalizePhone('9876543210'), '919876543210');
  assert.equal(core.normalizePhone('098765 43210'), '919876543210');
  assert.equal(core.normalizePhone('+91 98765-43210'), '919876543210');
  assert.equal(core.normalizePhone('919876543210'), '919876543210');
  assert.equal(core.normalizePhone('+1 555 667 6568'), '15556676568');
  assert.equal(core.normalizePhone('12345'), null);
  assert.equal(core.normalizePhone('1234567890'), null); // not a mobile prefix
  assert.equal(core.normalizePhone(''), null);
  assert.equal(core.normalizePhone(null), null);
});

test('istDate uses the Indian calendar day, not UTC', () => {
  // 20:00 UTC on 13 Oct is 01:30 IST on 14 Oct.
  assert.deepEqual(core.istDate(new Date('2026-10-13T20:00:00Z')), { y: 2026, m: 10, d: 14 });
  assert.deepEqual(core.istDate(new Date('2026-10-14T10:00:00Z')), { y: 2026, m: 10, d: 14 });
});

test('birthdayKeysFor greets 29 Feb birthdays on 28 Feb in non-leap years', () => {
  assert.deepEqual(core.birthdayKeysFor({ y: 2026, m: 10, d: 4 }), ['10-04']);
  assert.deepEqual(core.birthdayKeysFor({ y: 2027, m: 2, d: 28 }), ['02-28', '02-29']);
  assert.deepEqual(core.birthdayKeysFor({ y: 2028, m: 2, d: 28 }), ['02-28']);
});

test('reminderWindow covers exactly the IST day N days ago', () => {
  const { start, end } = core.reminderWindow({ y: 2026, m: 10, d: 14 }, 21);
  // 23 Sep 00:00 IST = 22 Sep 18:30 UTC.
  assert.equal(start.toISOString(), '2026-09-22T18:30:00.000Z');
  assert.equal(end.toISOString(), '2026-09-23T18:30:00.000Z');
});

test('formatRupees groups the Indian way', () => {
  assert.equal(core.formatRupees(950), '950');
  assert.equal(core.formatRupees(1200), '1,200');
  assert.equal(core.formatRupees(123456.4), '1,23,456');
  assert.equal(core.formatRupees(undefined), '0');
});

test('cleanParam makes values WhatsApp accepts', () => {
  assert.equal(core.cleanParam('a\nb\tc     d'), 'a b c d');
  assert.equal(core.cleanParam('   '), '-');
  assert.equal(core.cleanParam('x'.repeat(300)).length, 200);
});

test('firstName and describeItems', () => {
  assert.equal(core.firstName('Priya Sharma'), 'Priya');
  assert.equal(core.firstName(''), 'there');
  assert.equal(core.describeItems([
    { type: 'SERVICE', serviceName: 'Haircut', quantity: 1 },
    { type: 'PRODUCT', productName: 'Hair Gel', quantity: 2 },
  ]), 'Haircut, Hair Gel x2');
  assert.equal(core.describeItems([]), '-');
});

test('templateMessage builds the Cloud API body', () => {
  assert.deepEqual(core.templateMessage({ to: '919876543210', template: 'birthday_wish', language: 'en', params: ['Priya', 'Cuts'] }), {
    messaging_product: 'whatsapp',
    to: '919876543210',
    type: 'template',
    template: {
      name: 'birthday_wish',
      language: { code: 'en' },
      components: [{ type: 'body', parameters: [{ type: 'text', text: 'Priya' }, { type: 'text', text: 'Cuts' }] }],
    },
  });
  assert.equal(core.templateMessage({ to: '1', template: 'hello_world', language: 'en_US' }).template.components, undefined);
});

test('only a failed log entry is sent again', () => {
  assert.equal(core.canRetryLog({ status: 'failed' }), true);
  assert.equal(core.canRetryLog({ status: 'sent' }), false);
  assert.equal(core.canRetryLog({ status: 'sending' }), false);
  assert.equal(core.canRetryLog(undefined), false);
});

test('the daily result says what happened, including what was skipped', () => {
  assert.equal(core.dailyResultText({ disabled: true }), 'WhatsApp messages are turned off in Settings - nothing was sent.');
  assert.equal(
    core.dailyResultText({ birthdays: 1, reminders: 0, failed: 0, skipped: 0, alreadySent: 0 }),
    'Birthday messages sent: 1. Reminders sent: 0.',
  );
  const all = core.dailyResultText({ birthdays: 0, reminders: 0, failed: 1, skipped: 2, alreadySent: 1 });
  assert.match(all, /Already sent earlier: 1\./);
  assert.match(all, /Skipped 2 - not ticked/);
  assert.match(all, /Failed: 1/);
});

test('istMonthKey uses the IST calendar month', () => {
  // 31 Oct 2026 20:00 UTC is already 1 Nov in India.
  assert.equal(core.istMonthKey(new Date(Date.UTC(2026, 9, 31, 20, 0))), '2026-11');
  assert.equal(core.istMonthKey(new Date(Date.UTC(2026, 9, 31, 10, 0))), '2026-10');
});

test('sendCounterFor counts real sends only', () => {
  assert.equal(core.sendCounterFor('bill'), 'receipts');
  assert.equal(core.sendCounterFor('birthday'), 'birthdays');
  assert.equal(core.sendCounterFor('reminder'), 'reminders');
  assert.equal(core.sendCounterFor('test'), null);
});

test('taskSettings keeps the old behaviour when nothing is set', () => {
  assert.deepEqual(core.taskSettings({}, 21), {
    bill: true, birthday: true, birthdayDaysBefore: 0, reminder: true, reminderDays: 21,
  });
});

test('taskSettings reads the owner switches and clamps the reminder gap', () => {
  const s = core.taskSettings({
    whatsappBillOn: false,
    whatsappBirthdayOn: true,
    whatsappBirthdayDaysBefore: 1,
    whatsappReminderOn: false,
    whatsappReminderDays: 30,
  });
  assert.equal(s.bill, false);
  assert.equal(s.birthdayDaysBefore, 1);
  assert.equal(s.reminder, false);
  assert.equal(s.reminderDays, 30);
  assert.equal(core.taskSettings({ whatsappReminderDays: 0 }).reminderDays, 7);
  assert.equal(core.taskSettings({ whatsappReminderDays: 9999 }).reminderDays, 120);
  assert.equal(core.taskSettings({ whatsappReminderDays: 'x' }, 21).reminderDays, 21);
  assert.equal(core.taskSettings({ whatsappBirthdayDaysBefore: 5 }).birthdayDaysBefore, 0);
});

test('birthdayDayFor is today, or tomorrow across a month or year end', () => {
  assert.deepEqual(core.birthdayDayFor({ y: 2026, m: 10, d: 14 }, 0), { y: 2026, m: 10, d: 14 });
  assert.deepEqual(core.birthdayDayFor({ y: 2026, m: 10, d: 31 }, 1), { y: 2026, m: 11, d: 1 });
  assert.deepEqual(core.birthdayDayFor({ y: 2026, m: 12, d: 31 }, 1), { y: 2027, m: 1, d: 1 });
});

test('dayKey and visitKey name days the same way on both reminder paths', () => {
  assert.equal(core.dayKey({ y: 2026, m: 3, d: 7 }), '2026-03-07');
  // A visit at 23:00 IST on 10 Oct (17:30 UTC) belongs to 10 Oct ...
  const visit = new Date('2026-10-10T17:30:00Z');
  // ... and gets the same key the general path builds from its window.
  const { start } = core.reminderWindow({ y: 2026, m: 10, d: 31 }, 21);
  assert.equal(core.visitKey(visit), start.toISOString().slice(0, 10));
});

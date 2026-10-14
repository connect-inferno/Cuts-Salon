// WhatsApp messages for one salon, sent from that salon's own WhatsApp
// Business number through Meta's WhatsApp Cloud API.
//
// Deployed per salon project, like everything else here (one Firebase
// project per salon), and only to salons that use WhatsApp - see
// functions/whatsapp.md for setup. Each salon's Meta access token lives in
// ITS project's Secret Manager (WHATSAPP_TOKEN), never in Firestore or the
// app: anyone holding it can send messages as the salon.
//
// Everything is gated on settings/main.whatsappEnabled (the owner's switch
// in Settings) and, per customer, on customers/{id}.whatsappOptIn - a client
// who hasn't agreed to WhatsApp messages never gets one.
//
// Every send is recorded in whatsappLog/{key}, created BEFORE the send with
// create() so a retried trigger or a second "run now" can't message the
// same client twice for the same thing. Clients can only read that log
// (owner-only, see firestore.rules); only this code writes it.

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret, defineString, defineInt } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const core = require('./whatsapp_core');

initializeApp();
const db = getFirestore();

// Every salon project's Firestore is in asia-south1 (Mumbai), and a
// Firestore trigger has to run in its database's region.
setGlobalOptions({ region: 'asia-south1', maxInstances: 5 });

const WHATSAPP_TOKEN = defineSecret('WHATSAPP_TOKEN');
// Not secret - set per salon in functions/.env.<projectId>.
const PHONE_NUMBER_ID = defineString('WHATSAPP_PHONE_NUMBER_ID', {
  description: "The salon's WhatsApp 'Phone number ID' from Meta (API Setup page) - not the phone number itself",
});
// Template names as approved in that salon's WhatsApp Manager. The wording
// to submit for each is in whatsapp.md.
const TEMPLATE_BILL = defineString('WHATSAPP_TEMPLATE_BILL', { default: 'bill_receipt' });
const TEMPLATE_BIRTHDAY = defineString('WHATSAPP_TEMPLATE_BIRTHDAY', { default: 'birthday_wish' });
const TEMPLATE_REMINDER = defineString('WHATSAPP_TEMPLATE_REMINDER', { default: 'visit_reminder' });
const TEMPLATE_LANGUAGE = defineString('WHATSAPP_TEMPLATE_LANGUAGE', { default: 'en' });
// Same 21 days as kFollowUpDays in the app's client list.
const REMINDER_DAYS = defineInt('WHATSAPP_REMINDER_DAYS', { default: 21 });

const GRAPH_API = 'https://graph.facebook.com/v25.0';

// --- Sending -----------------------------------------------------------

async function sendToWhatsApp(message) {
  const res = await fetch(`${GRAPH_API}/${PHONE_NUMBER_ID.value()}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${WHATSAPP_TOKEN.value()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(message),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = body.error || {};
    throw new Error(`WhatsApp API ${res.status}: ${err.message || 'unknown error'}${err.code ? ` (code ${err.code})` : ''}`);
  }
  return body.messages?.[0]?.id ?? null;
}

/**
 * Sends one template message at most once per [logKey]. Returns 'sent',
 * 'failed' or 'duplicate' (already sent or in flight under that key).
 */
async function sendOnce(logKey, { kind, customerId, customerName, to, template, params }) {
  const logRef = db.collection('whatsappLog').doc(logKey);
  try {
    await logRef.create({
      kind,
      customerId: customerId ?? null,
      customerName: customerName ?? null,
      to,
      template,
      status: 'sending',
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (err) {
    if (err.code === 6 /* ALREADY_EXISTS */) return 'duplicate';
    throw err;
  }
  try {
    const messageId = await sendToWhatsApp(core.templateMessage({
      to,
      template,
      language: TEMPLATE_LANGUAGE.value(),
      params,
    }));
    await logRef.update({ status: 'sent', messageId, sentAt: FieldValue.serverTimestamp() });
    return 'sent';
  } catch (err) {
    logger.warn(`WhatsApp ${kind} to ${to} failed`, { logKey, error: err.message });
    await logRef.update({ status: 'failed', error: err.message.slice(0, 500) });
    return 'failed';
  }
}

async function getSettings() {
  const snap = await db.collection('settings').doc('main').get();
  return snap.data() || {};
}

/** Null when the client can't be messaged: archived, not opted in, or no usable number. */
function messageableCustomer(snap) {
  if (!snap.exists) return null;
  const c = snap.data();
  if (c.archived || c.whatsappOptIn !== true) return null;
  const to = core.normalizePhone(c.phone);
  return to ? { id: snap.id, name: c.name || '', to } : null;
}

// --- Bill receipt (right after billing) --------------------------------

exports.whatsappBillReceipt = onDocumentCreated(
  { document: 'bills/{billId}', secrets: [WHATSAPP_TOKEN] },
  async (event) => {
    const bill = event.data?.data();
    if (!bill || !bill.customerId) return;
    const settings = await getSettings();
    if (settings.whatsappEnabled !== true) return;

    const customer = messageableCustomer(await db.collection('customers').doc(bill.customerId).get());
    if (!customer) return;

    // createBill writes the bill and its items in one transaction, so the
    // items are already there when this fires.
    const items = await event.data.ref.collection('items').get();
    const total = Number(bill.finalAmount) || 0;
    const paid = Number(bill.amountPaid ?? bill.finalAmount) || 0;

    await sendOnce(`bill_${event.params.billId}`, {
      kind: 'bill',
      customerId: customer.id,
      customerName: customer.name,
      to: customer.to,
      template: TEMPLATE_BILL.value(),
      params: [
        core.firstName(customer.name),
        settings.salonName || 'our salon',
        bill.invoiceNumber || event.params.billId,
        core.describeItems(items.docs.map((d) => d.data())),
        core.formatRupees(total),
        core.formatRupees(paid),
        core.formatRupees(Math.max(0, total - paid)),
      ],
    });
  },
);

// --- Birthdays and come-back reminders (once a day) --------------------

async function runDailyMessages(now = new Date()) {
  const settings = await getSettings();
  if (settings.whatsappEnabled !== true) return { disabled: true };
  const salonName = settings.salonName || 'our salon';
  const today = core.istDate(now);
  const counts = { birthdays: 0, reminders: 0, failed: 0, skipped: 0 };

  const tally = (result, key) => {
    if (result === 'sent') counts[key] += 1;
    else if (result === 'failed') counts.failed += 1;
  };

  // Birthdays: an equality match on the "MM-DD" the app stores, so no index needed.
  const birthdaySnap = await db.collection('customers')
    .where('birthday', 'in', core.birthdayKeysFor(today))
    .get();
  for (const doc of birthdaySnap.docs) {
    const customer = messageableCustomer(doc);
    if (!customer) { counts.skipped += 1; continue; }
    tally(await sendOnce(`birthday_${customer.id}_${today.y}`, {
      kind: 'birthday',
      customerId: customer.id,
      customerName: customer.name,
      to: customer.to,
      template: TEMPLATE_BIRTHDAY.value(),
      params: [core.firstName(customer.name), salonName],
    }), 'birthdays');
  }

  // Reminders: clients whose last visit was exactly N days ago today. One
  // range filter on one field, which Firestore indexes automatically.
  const days = REMINDER_DAYS.value();
  const { start, end } = core.reminderWindow(today, days);
  const reminderSnap = await db.collection('customers')
    .where('lastVisitAt', '>=', start)
    .where('lastVisitAt', '<', end)
    .get();
  for (const doc of reminderSnap.docs) {
    const customer = messageableCustomer(doc);
    if (!customer) { counts.skipped += 1; continue; }
    // Keyed on the visit being followed up, so a client is reminded once
    // per lapse however many times this runs.
    const visitDay = start.toISOString().slice(0, 10);
    tally(await sendOnce(`reminder_${customer.id}_${visitDay}`, {
      kind: 'reminder',
      customerId: customer.id,
      customerName: customer.name,
      to: customer.to,
      template: TEMPLATE_REMINDER.value(),
      params: [core.firstName(customer.name), salonName],
    }), 'reminders');
  }

  logger.info('WhatsApp daily run', counts);
  return counts;
}

exports.whatsappDaily = onSchedule(
  { schedule: 'every day 10:00', timeZone: 'Asia/Kolkata', secrets: [WHATSAPP_TOKEN] },
  async () => {
    await runDailyMessages();
  },
);

// --- Owner's test buttons (Settings > WhatsApp) -------------------------
//
// The app can't call Meta itself (that would put the token in the app), so
// the owner's buttons write a whatsappRequests doc - firestore.rules lets
// only an active OWNER create one - and this picks it up and writes the
// outcome back onto the same doc for the app to show.

exports.whatsappRequest = onDocumentCreated(
  { document: 'whatsappRequests/{requestId}', secrets: [WHATSAPP_TOKEN] },
  async (event) => {
    const req = event.data?.data();
    if (!req || req.status !== 'pending') return;
    const ref = event.data.ref;

    // The rules already check this; re-checked here because this code acts
    // with full access whatever the rules say.
    const owner = await db.collection('employees').doc(req.requestedBy || '-').get();
    if (!owner.exists || owner.data().role !== 'OWNER' || owner.data().active !== true) {
      await ref.update({ status: 'failed', error: 'Only the salon owner can do this.' });
      return;
    }

    try {
      if (req.type === 'test') {
        const to = core.normalizePhone(req.phone);
        if (!to) throw new Error('That phone number does not look valid.');
        // hello_world is the one template every WhatsApp account has
        // pre-approved, so this proves the number and token work before any
        // of the salon's own templates are approved.
        await sendToWhatsApp(core.templateMessage({ to, template: 'hello_world', language: 'en_US' }));
        await ref.update({ status: 'done', result: `Test message sent to +${to}.` });
      } else if (req.type === 'daily') {
        const counts = await runDailyMessages();
        const result = counts.disabled
          ? 'WhatsApp messages are turned off in Settings - nothing was sent.'
          : `Birthday messages sent: ${counts.birthdays}. Reminders sent: ${counts.reminders}.` +
            (counts.failed ? ` Failed: ${counts.failed} (see whatsappLog in Firestore).` : '');
        await ref.update({ status: 'done', result });
      } else {
        await ref.update({ status: 'failed', error: `Unknown request type "${req.type}".` });
      }
    } catch (err) {
      logger.warn('WhatsApp request failed', { requestId: event.params.requestId, error: err.message });
      await ref.update({ status: 'failed', error: err.message.slice(0, 500) });
    }
  },
);

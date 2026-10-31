// Pure helpers for the WhatsApp functions - no Firebase, no network - so
// they can be unit-tested with `npm test` (see whatsapp_core.test.js).

// India has no daylight saving, so IST is always UTC+5:30. Every "today" in
// this file is the salon's calendar day, not the server's (the functions run
// in UTC).
const IST_OFFSET_MS = 330 * 60 * 1000;

/** The IST calendar date of [now] as {y, m (1-12), d}. */
function istDate(now = new Date()) {
  const shifted = new Date(now.getTime() + IST_OFFSET_MS);
  return { y: shifted.getUTCFullYear(), m: shifted.getUTCMonth() + 1, d: shifted.getUTCDate() };
}

/** The instant IST midnight starts on the given calendar day (any d, even 0 or negative, rolls over). */
function istMidnight({ y, m, d }) {
  return new Date(Date.UTC(y, m - 1, d) - IST_OFFSET_MS);
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

function isLeapYear(y) {
  return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
}

/**
 * The `birthday` values ("MM-DD", the shape the app stores on a customer)
 * to greet today. On 28 Feb of a non-leap year, 29 Feb birthdays are
 * included too, so they are still wished once a year.
 */
function birthdayKeysFor({ y, m, d }) {
  const keys = [`${pad2(m)}-${pad2(d)}`];
  if (m === 2 && d === 28 && !isLeapYear(y)) keys.push('02-29');
  return keys;
}

/**
 * The [start, end) window of last-visit times that reach exactly [days]
 * days without a return today, so each client gets one reminder per lapse.
 */
function reminderWindow(today, days) {
  return {
    start: istMidnight({ ...today, d: today.d - days }),
    end: istMidnight({ ...today, d: today.d - days + 1 }),
  };
}

/**
 * A phone number as WhatsApp wants it: country code + number, digits only.
 * The app stores whatever staff typed - usually a bare 10-digit Indian
 * mobile - so 10 digits (or 0 + 10 digits) get +91. Returns null for
 * anything that can't be a real number, so the caller skips that client
 * instead of sending to a wrong one.
 */
function normalizePhone(raw) {
  if (!raw) return null;
  const trimmed = String(raw).trim();
  let digits = trimmed.replace(/\D/g, '');
  if (trimmed.startsWith('+')) return digits.length >= 10 && digits.length <= 15 ? digits : null;
  if (digits.startsWith('00')) digits = digits.slice(2);
  if (digits.length === 11 && digits.startsWith('0')) digits = digits.slice(1);
  if (digits.length === 10) return /^[6-9]/.test(digits) ? `91${digits}` : null;
  if (digits.length === 12 && digits.startsWith('91')) return digits;
  return null;
}

/** Whole rupees with Indian digit grouping (1,23,456) - bills are whole rupees. */
function formatRupees(amount) {
  const whole = String(Math.round(Number(amount) || 0));
  const negative = whole.startsWith('-');
  const digits = negative ? whole.slice(1) : whole;
  if (digits.length <= 3) return (negative ? '-' : '') + digits;
  const last3 = digits.slice(-3);
  const rest = digits.slice(0, -3).replace(/\B(?=(\d{2})+(?!\d))/g, ',');
  return `${negative ? '-' : ''}${rest},${last3}`;
}

/**
 * WhatsApp rejects template parameters that are empty or contain newlines,
 * tabs or more than four spaces in a row - this makes any value safe.
 */
function cleanParam(value, fallback = '-') {
  const text = String(value ?? '')
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/ {2,}/g, ' ')
    .trim();
  if (!text) return fallback;
  return text.length > 200 ? `${text.slice(0, 197)}...` : text;
}

/** First name only - "Hi Priya" reads better than "Hi Priya Sharma". */
function firstName(name) {
  const first = cleanParam(name, '').split(' ')[0];
  return first || 'there';
}

/** "Haircut, Beard Trim, Hair Gel x2" from a bill's item docs. */
function describeItems(items) {
  const names = items.map((it) => {
    const name = it.type === 'PRODUCT' ? it.productName : it.serviceName;
    const qty = Number(it.quantity) || 1;
    return name ? (qty > 1 ? `${name} x${qty}` : name) : null;
  }).filter(Boolean);
  return cleanParam(names.join(', '));
}

/** The JSON body for one template message on the WhatsApp Cloud API. */
function templateMessage({ to, template, language, params }) {
  const message = {
    messaging_product: 'whatsapp',
    to,
    type: 'template',
    template: { name: template, language: { code: language } },
  };
  if (params && params.length) {
    message.template.components = [{
      type: 'body',
      parameters: params.map((p) => ({ type: 'text', text: cleanParam(p) })),
    }];
  }
  return message;
}

/** Whether a whatsappLog entry may be sent again: only a failed one. */
function canRetryLog(log) {
  return !!log && log.status === 'failed';
}

/** What the owner's "send today's messages now" button reports. */
function dailyResultText(counts) {
  if (counts.disabled) return 'WhatsApp messages are turned off in Settings - nothing was sent.';
  const parts = [`Birthday messages sent: ${counts.birthdays}.`, `Reminders sent: ${counts.reminders}.`];
  if (counts.alreadySent) parts.push(`Already sent earlier: ${counts.alreadySent}.`);
  if (counts.skipped) {
    parts.push(`Skipped ${counts.skipped} - not ticked "OK to send WhatsApp messages", archived, or no valid mobile number.`);
  }
  if (counts.failed) parts.push(`Failed: ${counts.failed} - see whatsappLog in Firestore for the reason.`);
  return parts.join(' ');
}

/** 'YYYY-MM' of an instant in IST - the monthlyStats doc a send is counted in. */
function istMonthKey(now = new Date()) {
  const { y, m } = istDate(now);
  return `${y}-${String(m).padStart(2, '0')}`;
}

/** "YYYY-MM-DD" of an IST calendar day - customers/{id}.reminderDueOn. */
function dayKey({ y, m, d }) {
  return `${y}-${pad2(m)}-${pad2(d)}`;
}

/**
 * The key part naming the visit a reminder follows up: the instant its IST
 * day started, as an ISO date. Both reminder paths use it, so a client is
 * reminded once per visit whichever path finds them.
 */
function visitKey(lastVisitAt) {
  return istMidnight(istDate(lastVisitAt)).toISOString().slice(0, 10);
}

/** Shortest and longest come-back gap the owner can pick in the app. */
const MIN_REMINDER_DAYS = 7;
const MAX_REMINDER_DAYS = 120;

/**
 * What the owner's WhatsApp page set in settings/main, with the old
 * behaviour for anything never set: every message on, birthday wishes on
 * the day, reminders after [defaultReminderDays]. Values are clamped, so a
 * hand-edited or corrupt setting can't message every client at once.
 */
function taskSettings(settings = {}, defaultReminderDays = 21) {
  const days = Math.round(Number(settings.whatsappReminderDays));
  return {
    bill: settings.whatsappBillOn !== false,
    birthday: settings.whatsappBirthdayOn !== false,
    birthdayDaysBefore: settings.whatsappBirthdayDaysBefore === 1 ? 1 : 0,
    reminder: settings.whatsappReminderOn !== false,
    reminderDays: Number.isFinite(days)
      ? Math.min(MAX_REMINDER_DAYS, Math.max(MIN_REMINDER_DAYS, days))
      : defaultReminderDays,
  };
}

/**
 * The calendar day whose birthdays are wished today: today, or tomorrow
 * when the owner chose "the day before". Rolls over months and years.
 */
function birthdayDayFor(today, daysBefore) {
  const d = new Date(Date.UTC(today.y, today.m - 1, today.d + daysBefore));
  return { y: d.getUTCFullYear(), m: d.getUTCMonth() + 1, d: d.getUTCDate() };
}

/** The monthlyStats `wa` counter a send of this kind adds to, or null (test sends). */
function sendCounterFor(kind) {
  return { bill: 'receipts', birthday: 'birthdays', reminder: 'reminders' }[kind] ?? null;
}

module.exports = {
  canRetryLog,
  istMonthKey,
  sendCounterFor,
  taskSettings,
  dayKey,
  visitKey,
  birthdayDayFor,
  MIN_REMINDER_DAYS,
  MAX_REMINDER_DAYS,
  dailyResultText,
  istDate,
  istMidnight,
  birthdayKeysFor,
  reminderWindow,
  normalizePhone,
  formatRupees,
  cleanParam,
  firstName,
  describeItems,
  templateMessage,
};

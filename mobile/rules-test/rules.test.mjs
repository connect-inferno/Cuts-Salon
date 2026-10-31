import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs, writeBatch,
  serverTimestamp, Timestamp, getCountFromServer, deleteField, runTransaction, orderBy, startAfter, limit, documentId,
} from 'firebase/firestore';

const rules = readFileSync(process.argv[2] || new URL("../firestore.rules", import.meta.url), "utf8");
const env = await initializeTestEnvironment({
  projectId: 'demo-salon-rules',
  firestore: { rules, host: '127.0.0.1', port: 8080 },
});

let pass = 0, fail = 0;
async function t(name, p) {
  try { await p; pass++; console.log('  ok  ', name); }
  catch (e) { fail++; console.log('  FAIL', name, '-', e.message.split('\n')[0]); }
}

const today = new Date(); const midnight = new Date(today.getFullYear(), today.getMonth(), today.getDate());
const yesterdayMidnight = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);
const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

const LIVE = 'L'.repeat(24), PREV = 'P'.repeat(24), STALE = 'S'.repeat(24), OLDPREV = 'O'.repeat(24);
const punch = (extra) => ({ employeeId: 'emp1', date: Timestamp.fromDate(midnight), clockIn: serverTimestamp(), clockOut: null, status: 'PRESENT', ...extra });

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const emp = (role, active, extra = {}) => ({ role, active, name: role, baseSalary: 20000, ...extra });
    await setDoc(doc(db, 'employees/owner1'), emp('OWNER', true));
    await setDoc(doc(db, 'employees/emp1'), emp('EMPLOYEE', true));
    await setDoc(doc(db, 'employees/emp2'), emp('EMPLOYEE', true));
    await setDoc(doc(db, 'employees/gone'), emp('EMPLOYEE', false));
    await setDoc(doc(db, 'settings/main'), { salonName: 'Test' });
    for (const id of ['emp1', 'emp2']) {
      await setDoc(doc(db, `salaryRecords/s_${id}`), { employeeId: id, month: 9, year: 2026 });
      await setDoc(doc(db, `commissionRecords/c_${id}`), { employeeId: id, status: 'PENDING' });
      await setDoc(doc(db, `attendanceRecords/${id}_2026-10-01`), { employeeId: id, status: 'PRESENT', date: Timestamp.fromDate(new Date(2026, 9, 1)) });
      await setDoc(doc(db, `salesTargets/t_${id}`), { employeeId: id, progressValue: 0, status: 'ACTIVE', targetValue: 1000 });
      await setDoc(doc(db, `paymentRequests/pr_${id}`), { requestedBy: id, status: 'PENDING', amount: 100 });
      await setDoc(doc(db, `employeePay/${id}`), { baseSalary: 20000, serviceCommissionPct: 10, productCommissionPct: 5 });
    }
    await setDoc(doc(db, 'bills/b1'), { customerId: 'cu1', finalAmount: 500 });
    const ago = (s) => Timestamp.fromMillis(Date.now() - s * 1000);
    for (const b of ['br1', 'br2', 'br3', 'brNew']) await setDoc(doc(db, `branches/${b}`), { name: b, active: true });
    // br1: live code issued 5s ago, previous one 35s ago (still in its 45s grace).
    await setDoc(doc(db, 'attendanceQr/br1'), { token: LIVE, issuedAt: ago(5), prevToken: PREV, prevIssuedAt: ago(35) });
    // br2: the owner's screen went off two minutes ago - nothing valid.
    await setDoc(doc(db, 'attendanceQr/br2'), { token: STALE, issuedAt: ago(120) });
    // br3: previous code is 50s old - past its grace.
    await setDoc(doc(db, 'attendanceQr/br3'), { token: 'x'.repeat(24), issuedAt: ago(20), prevToken: OLDPREV, prevIssuedAt: ago(50) });
    // emp1 started a night shift yesterday evening and is still on it.
    await setDoc(doc(db, `attendanceRecords/emp1_${ymd(yesterdayMidnight)}`), {
      employeeId: 'emp1', date: Timestamp.fromDate(yesterdayMidnight), clockIn: ago(4 * 3600), clockOut: null, status: 'PRESENT',
    });
    // emp2's day already has a status-only record (owner confirmed the roster first).
    await setDoc(doc(db, `attendanceRecords/emp2_${ymd(today)}`), { employeeId: 'emp2', status: 'PRESENT', date: Timestamp.fromDate(midnight), confirmed: true });
    await setDoc(doc(db, 'inventoryItems/i1'), { name: 'Gel', stockCount: 5, price: 100 });
    await setDoc(doc(db, 'services/sv1'), { name: 'Cut', price: 200 });
    await setDoc(doc(db, 'counters/invoices'), { last: 5 });
    await setDoc(doc(db, 'dailyStats/2026-10-01'), { revenue: 500 });
    await setDoc(doc(db, 'monthlyStats/2026-10'), { sales: 500 });
    await setDoc(doc(db, 'customers/cu1'), { name: 'Client', phone: '9999999999' });
    await setDoc(doc(db, 'expenses/e1'), { title: 'Rent', amount: 1000 });
    await setDoc(doc(db, 'discountRequests/d1'), { status: 'PENDING' });
  });
}

await seed();

console.log('Stranger (self-signed-up account, no employee record)');
{
  const db = env.authenticatedContext('stranger').firestore();
  await t('cannot list the staff roster', assertFails(getDocs(collection(db, 'employees'))));
  await t('cannot read an employee record', assertFails(getDoc(doc(db, 'employees/emp1'))));
  await t('can ask for its own (missing) record', assertSucceeds(getDoc(doc(db, 'employees/stranger'))));
  await t('cannot read customers', assertFails(getDocs(collection(db, 'customers'))));
  await t("cannot read anyone's pay", assertFails(getDoc(doc(db, 'employeePay/emp1'))));
  await t('cannot make itself an employee', assertFails(setDoc(doc(db, 'employees/stranger'), { role: 'OWNER', active: true })));
}

console.log('Deactivated employee');
{
  const db = env.authenticatedContext('gone').firestore();
  await t('can read own record (to be told why)', assertSucceeds(getDoc(doc(db, 'employees/gone'))));
  await t('cannot list the roster', assertFails(getDocs(collection(db, 'employees'))));
  await t('cannot read settings', assertFails(getDoc(doc(db, 'settings/main'))));
  await t('cannot read own salary', assertFails(getDocs(query(collection(db, 'salaryRecords'), where('employeeId', '==', 'gone')))));
}

console.log('Active employee (emp1)');
{
  const db = env.authenticatedContext('emp1').firestore();
  await t('can list the roster', assertSucceeds(getDocs(collection(db, 'employees'))));
  await t('can read own salary slips', assertSucceeds(getDocs(query(collection(db, 'salaryRecords'), where('employeeId', '==', 'emp1')))));
  await t('cannot read everyone\'s salary slips', assertFails(getDocs(collection(db, 'salaryRecords'))));
  await t('cannot read a coworker\'s slip', assertFails(getDoc(doc(db, 'salaryRecords/s_emp2'))));
  await t('can read own commissions', assertSucceeds(getDocs(query(collection(db, 'commissionRecords'), where('employeeId', '==', 'emp1'), where('status', '==', 'PENDING')))));
  await t('cannot read a coworker\'s commissions', assertFails(getDocs(query(collection(db, 'commissionRecords'), where('employeeId', '==', 'emp2')))));
  await t('cannot create a commission', assertFails(setDoc(doc(db, 'commissionRecords/fake'), { employeeId: 'emp1', amount: 9999, status: 'PENDING' })));
  await t('can read own attendance', assertSucceeds(getDocs(query(collection(db, 'attendanceRecords'), where('employeeId', '==', 'emp1')))));
  await t('cannot read all attendance', assertFails(getDocs(collection(db, 'attendanceRecords'))));
  await t('cannot read a coworker\'s day', assertFails(getDoc(doc(db, 'attendanceRecords/emp2_2026-10-01'))));
  await t('can check today\'s (missing) record before punching', assertSucceeds(getDoc(doc(db, `attendanceRecords/emp1_${ymd(today)}`))));
  const mine = doc(db, `attendanceRecords/emp1_${ymd(today)}`);
  await t('cannot read the attendance QR code', assertFails(getDoc(doc(db, 'attendanceQr/br1'))));
  await t('cannot write the attendance QR code', assertFails(setDoc(doc(db, 'attendanceQr/br1'), { token: 'z'.repeat(24), issuedAt: serverTimestamp() })));
  await t('cannot clock in without scanning', assertFails(setDoc(mine, punch({}))));
  await t('cannot clock in with a made-up code', assertFails(setDoc(mine, punch({ clockInQrToken: 'q'.repeat(24), clockInQrBranchId: 'br1' }))));
  await t('cannot clock in with an expired code', assertFails(setDoc(mine, punch({ clockInQrToken: STALE, clockInQrBranchId: 'br2' }))));
  await t('cannot clock in with a code past its grace', assertFails(setDoc(mine, punch({ clockInQrToken: OLDPREV, clockInQrBranchId: 'br3' }))));
  await t('cannot use a live code with the wrong branch', assertFails(setDoc(mine, punch({ clockInQrToken: LIVE, clockInQrBranchId: 'br3' }))));
  await t('can clock in with the live code', assertSucceeds(setDoc(mine, punch({ clockInQrToken: LIVE, clockInQrBranchId: 'br1' }))));
  await t('cannot clock out without scanning', assertFails(updateDoc(mine, { clockOut: serverTimestamp() })));
  await t('can clock out with the code that just changed', assertSucceeds(updateDoc(mine, { clockOut: serverTimestamp(), clockOutQrToken: PREV, clockOutQrBranchId: 'br1' })));
  const night = doc(db, `attendanceRecords/emp1_${ymd(yesterdayMidnight)}`);
  await t('can clock out a night shift that started yesterday', assertSucceeds(updateDoc(night, { clockOut: serverTimestamp(), clockOutQrToken: LIVE, clockOutQrBranchId: 'br1' })));
  const page = (...extra) => getDocs(query(collection(db, 'attendanceRecords'), ...extra, orderBy('date', 'desc'), orderBy(documentId(), 'desc'), limit(100)));
  await t('can page back through own history', assertSucceeds(page(where('employeeId', '==', 'emp1'))));
  await t('can continue a page from a record', assertSucceeds(getDocs(query(collection(db, 'attendanceRecords'),
    where('employeeId', '==', 'emp1'), orderBy('date', 'desc'), orderBy(documentId(), 'desc'),
    startAfter(Timestamp.fromDate(midnight), `emp1_${ymd(today)}`), limit(100)))));
  await t('cannot page through everyone\'s history', assertFails(page()));
  await t('can read own sales targets', assertSucceeds(getDocs(query(collection(db, 'salesTargets'), where('employeeId', '==', 'emp1')))));
  await t('cannot mark own target as met', assertFails(updateDoc(doc(db, 'salesTargets/t_emp1'), { progressValue: 1000, status: 'COMPLETED' })));
  await t('can read own payment requests', assertSucceeds(getDocs(query(collection(db, 'paymentRequests'), where('requestedBy', '==', 'emp1')))));
  await t('cannot read everyone\'s payment requests', assertFails(getDocs(collection(db, 'paymentRequests'))));
  await t('can file a payment request', assertSucceeds(setDoc(doc(db, 'paymentRequests/new1'), { requestedBy: 'emp1', status: 'PENDING', amount: 250, billId: 'b1' })));
  await t('cannot file a negative payment request', assertFails(setDoc(doc(db, 'paymentRequests/new2'), { requestedBy: 'emp1', status: 'PENDING', amount: -5, billId: 'b1' })));
  await t('can read bills (dues list)', assertSucceeds(getDocs(collection(db, 'bills'))));
  await t('cannot create a bill', assertFails(setDoc(doc(db, 'bills/fake'), { customerId: 'cu1', finalAmount: 1 })));
  await t('cannot record a payment directly', assertFails(setDoc(doc(db, 'bills/b1/payments/p1'), { amount: 500, method: 'CASH' })));
  await t('cannot change stock', assertFails(updateDoc(doc(db, 'inventoryItems/i1'), { stockCount: 0 })));
  await t('cannot bump the invoice counter', assertFails(updateDoc(doc(db, 'counters/invoices'), { last: 6 })));
  await t('cannot read daily takings', assertFails(getDoc(doc(db, 'dailyStats/2026-10-01'))));
  await t('cannot read monthly takings', assertFails(getDoc(doc(db, 'monthlyStats/2026-10'))));
  await t('cannot write monthly takings', assertFails(setDoc(doc(db, 'monthlyStats/2026-11'), { sales: 1 })));
  await t('can read clients', assertSucceeds(getDocs(collection(db, 'customers'))));
  await t('cannot add a client', assertFails(setDoc(doc(db, 'customers/new'), { name: 'X', phone: '1' })));
  await t('cannot edit a client', assertFails(updateDoc(doc(db, 'customers/cu1'), { phone: '0' })));
  await t('cannot file a discount request', assertFails(setDoc(doc(db, 'discountRequests/d2'), { status: 'PENDING' })));
  await t('cannot read expenses', assertFails(getDocs(collection(db, 'expenses'))));
  await t('can read own pay', assertSucceeds(getDoc(doc(db, 'employeePay/emp1'))));
  await t("cannot read a coworker's pay", assertFails(getDoc(doc(db, 'employeePay/emp2'))));
  await t('cannot list pay', assertFails(getDocs(collection(db, 'employeePay'))));
  await t('cannot raise own pay', assertFails(setDoc(doc(db, 'employeePay/emp1'), { baseSalary: 99999, serviceCommissionPct: 10, productCommissionPct: 5 })));
  await t('cannot edit own record', assertFails(updateDoc(doc(db, 'employees/emp1'), { baseSalary: 99999 })));
}

console.log('Active employee (emp2) - day already on the roster');
{
  const db = env.authenticatedContext('emp2').firestore();
  const day = doc(db, `attendanceRecords/emp2_${ymd(today)}`);
  await t('cannot punch in on a rostered day without scanning', assertFails(updateDoc(day, { clockIn: serverTimestamp() })));
  await t('can punch in on a rostered day with the live code', assertSucceeds(updateDoc(day, { clockIn: serverTimestamp(), clockInQrToken: LIVE, clockInQrBranchId: 'br1' })));
}

console.log('Owner');
{
  const db = env.authenticatedContext('owner1').firestore();
  await t('can create a bill', assertSucceeds(setDoc(doc(db, 'bills/b2'), { customerId: 'cu1', finalAmount: 300 })));
  await t('can add a bill item', assertSucceeds(setDoc(doc(db, 'bills/b2/items/it1'), { employeeId: 'emp1', unitPrice: 300 })));
  await t('can record a payment', assertSucceeds(setDoc(doc(db, 'bills/b1/payments/p1'), { amount: 500, method: 'CASH' })));
  await t('cannot edit a bill', assertFails(updateDoc(doc(db, 'bills/b1'), { finalAmount: 1 })));
  await t('can bump the invoice counter by one', assertSucceeds(updateDoc(doc(db, 'counters/invoices'), { last: 6 })));
  await t('cannot skip invoice numbers', assertFails(updateDoc(doc(db, 'counters/invoices'), { last: 50 })));
  await t('can change stock', assertSucceeds(updateDoc(doc(db, 'inventoryItems/i1'), { stockCount: 4 })));
  await t('cannot delete a product', assertFails(deleteDoc(doc(db, 'inventoryItems/i1'))));
  await t('cannot delete a service', assertFails(deleteDoc(doc(db, 'services/sv1'))));
  await t('can archive a service', assertSucceeds(updateDoc(doc(db, 'services/sv1'), { archived: true })));
  await t('can edit own name', assertSucceeds(updateDoc(doc(db, 'employees/owner1'), { name: 'Boss' })));
  await t('cannot deactivate self', assertFails(updateDoc(doc(db, 'employees/owner1'), { active: false })));
  await t('cannot demote self', assertFails(updateDoc(doc(db, 'employees/owner1'), { role: 'EMPLOYEE' })));
  await t('can deactivate an employee', assertSucceeds(updateDoc(doc(db, 'employees/emp2'), { active: false })));
  await t('can hire (create an employee record)', assertSucceeds(setDoc(doc(db, 'employees/emp3'), { role: 'EMPLOYEE', active: true, name: 'New' })));
  await t('cannot delete an employee record', assertFails(deleteDoc(doc(db, 'employees/emp1'))));
  await t("can list everyone's pay", assertSucceeds(getDocs(collection(db, 'employeePay'))));
  await t('can set pay', assertSucceeds(setDoc(doc(db, 'employeePay/emp1'), { baseSalary: 21000, serviceCommissionPct: 12, productCommissionPct: 5 })));
  await t('cannot put other fields in a pay doc', assertFails(setDoc(doc(db, 'employeePay/emp1'), { baseSalary: 1, serviceCommissionPct: 1, productCommissionPct: 1, role: 'OWNER' })));
  await t('cannot delete a pay doc', assertFails(deleteDoc(doc(db, 'employeePay/emp1'))));
  {
    // The app's one-off move: copy pay to employeePay, strip it from the
    // roster doc - including the owner's own doc - in one batch.
    const b = writeBatch(db);
    for (const id of ['owner1', 'emp1']) {
      b.set(doc(db, `employeePay/${id}`), { baseSalary: 20000, serviceCommissionPct: 10, productCommissionPct: 5 });
      b.update(doc(db, `employees/${id}`), { baseSalary: deleteField(), serviceCommissionPct: deleteField(), productCommissionPct: deleteField() });
    }
    await t('can move pay off the roster docs', assertSucceeds(b.commit()));
  }
  await t('can start a branch\'s QR code', assertSucceeds(setDoc(doc(db, 'attendanceQr/brNew'), { token: 'n'.repeat(24), issuedAt: serverTimestamp() })));
  await t('cannot start a QR code with a phone-clock time', assertFails(setDoc(doc(db, 'attendanceQr/br9'), { token: 'n'.repeat(24), issuedAt: Timestamp.now() })));
  await t('cannot start a QR code for a branch that does not exist', assertFails(setDoc(doc(db, 'attendanceQr/nope'), { token: 'n'.repeat(24), issuedAt: serverTimestamp() })));
  await t('cannot use a short QR code', assertFails(setDoc(doc(db, 'attendanceQr/br3'), { token: 'short', issuedAt: serverTimestamp() })));
  await t('can rotate the QR code', assertSucceeds(runTransaction(db, async (tx) => {
    const ref = doc(db, 'attendanceQr/brNew');
    const cur = (await tx.get(ref)).data();
    tx.set(ref, { token: 'r'.repeat(24), issuedAt: serverTimestamp(), prevToken: cur.token, prevIssuedAt: cur.issuedAt });
  })));
  await t('cannot plant a fake previous code', assertFails(runTransaction(db, async (tx) => {
    const ref = doc(db, 'attendanceQr/brNew');
    const cur = (await tx.get(ref)).data();
    tx.set(ref, { token: 's'.repeat(24), issuedAt: serverTimestamp(), prevToken: 'f'.repeat(24), prevIssuedAt: cur.issuedAt });
  })));
  await t('cannot delete a QR code', assertFails(deleteDoc(doc(db, 'attendanceQr/brNew'))));
  await t('can clock in own shift without a QR', assertSucceeds(setDoc(doc(db, `attendanceRecords/owner1_${ymd(today)}`), {
    employeeId: 'owner1', date: Timestamp.fromDate(midnight), clockIn: serverTimestamp(), clockOut: null, status: 'PRESENT',
  })));
  await t('can read every salary slip', assertSucceeds(getDocs(collection(db, 'salaryRecords'))));
  await t('cannot delete a salary slip', assertFails(deleteDoc(doc(db, 'salaryRecords/s_emp1'))));
  await t('can page back through everyone\'s history', assertSucceeds(getDocs(query(collection(db, 'attendanceRecords'),
    orderBy('date', 'desc'), orderBy(documentId(), 'desc'), startAfter(Timestamp.fromDate(midnight), 'zzz'), limit(100)))));
  await t('can read all attendance', assertSucceeds(getDocs(collection(db, 'attendanceRecords'))));
  await t('can mark attendance', assertSucceeds(setDoc(doc(db, 'attendanceRecords/emp1_2026-10-01'), { status: 'LATE', confirmed: true }, { merge: true })));
  await t('can read all payment requests', assertSucceeds(getDocs(collection(db, 'paymentRequests'))));
  await t('can count pending payment requests', assertSucceeds(getCountFromServer(query(collection(db, 'paymentRequests'), where('status', '==', 'PENDING')))));
  await t('can approve a payment request', assertSucceeds(updateDoc(doc(db, 'paymentRequests/pr_emp1'), { status: 'APPROVED' })));
  await t('can read and write daily stats', assertSucceeds(setDoc(doc(db, 'dailyStats/2026-10-02'), { revenue: 1 })));
  await t('can read and write monthly stats', assertSucceeds(setDoc(doc(db, 'monthlyStats/2026-10'), { sales: 1 }, { merge: true })));
  await t('can read monthly stats', assertSucceeds(getDocs(collection(db, 'monthlyStats'))));
  await t('cannot delete monthly stats', assertFails(deleteDoc(doc(db, 'monthlyStats/2026-10'))));
  await t('can add a client', assertSucceeds(setDoc(doc(db, 'customers/cu2'), { name: 'New', phone: '2' })));
  await t('can update settings', assertSucceeds(setDoc(doc(db, 'settings/main'), { gstRate: 18 }, { merge: true })));
  await t('cannot delete settings', assertFails(deleteDoc(doc(db, 'settings/main'))));
  await t('can delete an expense', assertSucceeds(deleteDoc(doc(db, 'expenses/e1'))));
  await t('can read old discount requests', assertSucceeds(getDoc(doc(db, 'discountRequests/d1'))));
  await t('can file a WhatsApp test request', assertSucceeds(setDoc(doc(db, 'whatsappRequests/w1'), { type: 'test', status: 'pending', requestedBy: 'owner1' })));
  await t('cannot write the WhatsApp set-up flag', assertFails(setDoc(doc(db, 'whatsappSetup/status'), { ready: true })));
}

console.log('Deactivated employee 2 (just deactivated by owner)');
{
  const db = env.authenticatedContext('emp2').firestore();
  await t('loses access at once', assertFails(getDocs(query(collection(db, 'salaryRecords'), where('employeeId', '==', 'emp2')))));
}

console.log('New salon bootstrap (Add Salon)');
await env.clearFirestore();
{
  const db = env.authenticatedContext('founder').firestore();
  const b = writeBatch(db);
  b.set(doc(db, 'employees/founder'), { role: 'OWNER', active: true, name: 'Founder' });
  b.set(doc(db, 'settings/main'), { salonName: 'New Salon' });
  await t('first owner can claim an empty salon', assertSucceeds(b.commit()));
  const db2 = env.authenticatedContext('latecomer').firestore();
  const b2 = writeBatch(db2);
  b2.set(doc(db2, 'employees/latecomer'), { role: 'OWNER', active: true });
  b2.set(doc(db2, 'settings/main'), { salonName: 'Hijack' });
  await t('nobody can claim it afterwards', assertFails(b2.commit()));
}

await env.cleanup();
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);

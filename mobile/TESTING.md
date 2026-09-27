# Testing checklist — Firestore caching & state-management work

What to verify after the caching / read-reduction changes. Ordered by how much
it costs to get wrong, not by how long it takes to check.

Nothing here needs a test framework. Every item is something you do in the app
with two accounts on the live test salon.

---

## Before you test anything: deploy per salon

Every salon project needs both the rules and the indexes, or the app breaks in
ways the checks below will blame on the wrong thing:

```bash
The two new `salaryRecords` indexes must reach **every** salon project, not
just the one you test on — the app falls back safely, but a salon without
them keeps paying the old unbounded read forever.

firebase deploy --only firestore:rules,firestore:indexes --project <salonId>
```

- **Rules** add the `dailyStats` collection. Without it the rollup write is
  denied — and because that write sits inside the bill transaction, **every
  bill fails**, not just the dashboard.
- **Indexes** add `commissionRecords (status, createdAt)`. A composite index
  takes minutes to provision. The app falls back safely while it builds, so
  deploy order does not matter, but the faster path does not switch on until
  it is green.

Only `cuts-salon` has had these deployed. Repeat for every entry in
`lib/firebase/salon_directory.dart`, and add it to the onboarding steps in
`CLAUDE.md` for new salons.

---

## P1 — Two staff billing at the same time

**The one real risk.** The app caches bills it has already downloaded and asks
Firestore only for newer ones. The watermark is the newest bill it holds, which
has a hole: your colleague bills at 2:05, you bill at 2:10, your own write lands
in your own cache, and a naive delta of "after 2:10" skips their 2:05 bill
permanently. Every delta therefore re-reads the last 24 hours.

This could not be staged in a single browser, so it is unverified.

**How to check** — two devices (or two browsers, not two tabs; tabs share a
cache), both signed into the same salon:

1. Device A: open Billing → History, note the bill count.
2. Device B: ring up a bill.
3. Device A: ring up a different bill.
4. Device A: reload the page.
5. **Device A must show both new bills.** Today's totals on Home must include
   both.

Repeat once with the order reversed (A bills first, then B).

**If it fails:** a colleague's bill is missing from history and from the day's
totals. Raise it — the overlap window in `SalonFirestore._deltaOverlap` is the
thing to widen.

---

## P2 — Roster save keeps clock times

`markAttendance` no longer reads the record back after writing; it carries the
clock-in/out times forward from the loaded snapshot.

Low stakes — Firestore's `merge: true` means the stored document is untouched
either way, no screen on the roster page displays clock times, and a reload
corrects any local drift. Worth one pass anyway.

**How to check:**

1. Sign in as an employee, Clock In.
2. Sign in as the owner, Team Settings → Attendance, change that employee's
   status, Confirm Daily Roster.
3. Back as the employee: **shift hours / clock-in time must still be there.**
4. Reload and confirm it persists.

---

## P3 — Commission figures after the index goes live

Currently every load takes the fallback path (unfiltered read, filtered in
Dart) because the index is still building. The filtered query has never run.

**How to check, once the index is green in the Firebase console:**

1. Open the owner dashboard with devtools open.
2. **The console must no longer log `pending-commission index unavailable`.**
3. Team → any employee → Projected Payout must be unchanged from before.

Ground truth captured on the fallback path: **Anjali Mehta, Projected Payout
₹25,735** (₹25,000 base + ₹735 pending).

**If the numbers move:** the two paths apply the same `status == 'PENDING'`
filter to the same documents, so a difference means a commission record is
missing its `status` field — possible only if records were imported rather than
written by `createBill`.

---

## Regression pass

Quick sweep for the rest of the work. Both roles.

### Billing
- [ ] Single-service bill: totals, GST, invoice number
- [ ] **Multi-service bill by one stylist** — their sales target must move by
      the **sum** of the lines, not just the last one (this was a real bug)
- [ ] Product sale: stock drops by the quantity sold, and still matches after
      a reload
- [ ] Bill detail shows every line with the right stylist and price
- [ ] Pay Later / part payment, then Collect from Dues

### Dashboard
- [ ] Today's sales / week / bill count / client count move correctly after a
      bill
- [ ] Those figures are identical after a full reload (patch and cold load must
      agree)
- [ ] Payment breakdown totals match Billed Today

### Attendance
- [ ] Confirm Daily Roster saves, snackbar appears
- [ ] Marked statuses show in Recent Attendance Log
- [ ] Tap a status, confirm, then check the roster still reflects the **saved**
      state and not a stale draft
- [ ] Force a failure (offline) — the failed rows keep their edits and the
      error names the staff involved

### Settings
- [ ] Salon Settings hydrates name / phone / address / GST / penalty
- [ ] Change GST on Salon Settings, save, open Billing → gear → Tax: **the new
      rate must be there**
- [ ] Change it back on the Tax page, save, reopen Salon Settings: **same**
- [ ] Type into a field, then let a save land from elsewhere — your unsaved
      typing must not be overwritten

### Auth
- [ ] Logout is immediate, no spinner, no data reload
- [ ] Log back in: salon name appears straight away
- [ ] Auto-login on refresh restores the session
- [ ] Sign in as a different user in a second tab — the first tab drops to login

### Expenses
- [ ] Open Expenses — the list loads when the screen opens, not at sign-in.
      A brief loading spinner on first open is expected and correct.
- [ ] Add an expense — the total and entry count update immediately
- [ ] Leave Expenses and come back — the list reloads (it is `autoDispose`,
      so it deliberately does not hold a snapshot that ages all session)
- [ ] Sign in as an employee — no Expenses screen, and nothing tries to fetch
      expenses (owner-only, same gate as before)

### Payroll and salary
- [ ] Team -> Payroll opens; nobody is shown as paid who has been paid.
      Both AppData and the salary list must be loaded before this renders,
      so a wrong "Pending" here would risk paying someone twice.
- [ ] Open a staff member -> Salary History loads with the card
- [ ] Generate a slip for a past month — it appears without a manual reload
- [ ] Mark Paid — the row flips to a tick straight away
- [ ] Generate a slip for the CURRENT month — that employee's pending
      commissions move to PAID and disappear from Pending Commissions
      (generateSalary settles commissions, so it still refreshes AppData)
- [ ] Employee -> Earnings -> Payout History lists their own slips only
- [ ] **Before the salaryRecords indexes finish building**, Payroll and the
      history cards still work — the query falls back to the old unbounded
      read and logs "salary period index unavailable". Verified; this is the
      expected state between deploying the app and the indexes going live.
- [ ] **After they are live**, that log line stops appearing and slips older
      than roughly two years drop off the history views. Check the console
      to confirm which path you are actually on.

### Catalog freshness
- [ ] Load twice — console logs "served from cache (N docs, 0 reads)" for
      branches, employees, serviceCategories and services
- [ ] **Edit a service, category, branch or staff member on device A, then
      reload device B.** B must show the edit. This is the one that matters:
      if a write path ever forgets `_bumpCatalogVersion`, B serves a stale
      catalog until its cache clears, and nothing else will tell you.
- [ ] A brand-new salon logs no cache lines until its first catalog edit —
      the version is absent on both sides, so the gate stays off. Expected.

### Discount request badges
- [ ] Owner: the bell badge, the Discounts settings row and the dashboard
      tile all show the same pending number
- [ ] Owner -> Team -> Discounts lists pending AND history (loaded with the
      screen, not at sign-in)
- [ ] Approve or reject one — every badge drops by one immediately
- [ ] Raise a bill as an owner — the dashboard's pending-discount figure
      must NOT reset to zero (it is the count now, not a derived list)
- [ ] Staff still see their own requests and their own pending badge

### Live updates (two devices, or two browser tabs)
- [ ] Sign in on both. Raise a bill on A.
- [ ] **B's dashboard updates without a reload**: Today's Sales, Bills Today
      and Today's Customers all move.
- [ ] **B's week and month totals move by exactly the bill's amount.** They
      are carried forward rather than re-read, so if they drift this is
      where it shows.
- [ ] **B's Billing list shows the new bill**, with its item count — the
      items come from a subcollection fetched when the bill arrives, so a
      bill showing "0 items" means that hydration broke.
- [ ] A does NOT double-count its own bill (createBill patches it locally;
      the listener must skip what A already has).
- [ ] Log out and back in — no duplicate rows, no stale figures. Listeners
      are cancelled and reattached on every auth change.
- [ ] Leave B open across midnight: the today-stats listener is bound to the
      date at load, so B keeps watching yesterday until it reloads. Known
      and accepted; reload to roll over.

### Clients
- [ ] Add, edit, archive, restore
- [ ] Archived clients stay out of the billing picker
- [ ] Dues page lists unpaid bills with the right names and phone numbers
- [ ] **After billing a client, reload and check their profile** — Total Spent,
      Visits and Last Visit must reflect the new bill. The directory is now
      delta-synced on an `updatedAt` stamp, so a stale cached client would show
      the old figures here and nowhere else.
- [ ] Archive a client on one device, reload on another — they must move to
      Archived there too (same delta path)

---

## Cache behaviour

Local persistence (IndexedDB) is now on, multi-tab.

- [ ] Second load of the day is visibly faster than the first
- [ ] **Safari, Private Browsing** — no IndexedDB there at all. The app must
      still work, just uncached. Console logs `Firestore local cache
      unavailable`; nothing else should differ.
- [ ] Two tabs open at once, bill in one, reload the other — no cache-lock
      errors in the console
- [ ] Clear site data, reload — full fetch, app correct

---

## Watching the actual numbers

The point of all this was read volume. Confirm it moved:

**Firebase Console → Firestore → Usage**, per project.

Expected for a mid-size salon (≈2,000 clients, 30 bills/day): roughly **11k
reads/day**. A large salon (≈10,000 clients) should land near **37k/day** — both
inside the 50,000/day free quota now that the client directory is delta-synced
rather than read whole.

Writes were never the constraint and should sit near 300/day against a 20,000
free quota.

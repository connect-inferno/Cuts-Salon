# Cuts-Salon — Salon SaaS

Multi-tenant salon management SaaS. Each salon runs on its own Firebase project (Firestore + Firebase Auth) — there is no shared server. Read this before making changes to how the app talks to Firebase — it applies to any AI agent working in this repo, not just this session.

## Project shape

- `mobile/` — Flutter app (salon staff/owner client), deployed to Vercel as a web build. This is the entire app; there is no separate backend service.
- `mobile/lib/firebase/` — everything Firebase-specific: `salon_directory.dart` (the list of provisioned salons and their Firebase project config), `salon_auth.dart` (multi-project sign-in), `login_directory.dart` (fast email -> salonId lookup against `salon-saas-87b6a`, see Multi-tenancy model below), `salon_firestore.dart` (all Firestore reads/writes), `firestore_models.dart` (Firestore document <-> app model conversions), `firestore_app_data.dart` (assembles one salon's full `AppData` snapshot).
- `mobile/lib/data/app_data_provider.dart` — the single source of truth for app state (`AppDataNotifier`). Every mutation (create bill, clock in, confirm a payment request, etc.) lives here as a method that validates input and calls into `SalonFirestore`.
- `mobile/firestore.rules` / `mobile/firestore.indexes.json` — deployed per-project via `firebase deploy --only firestore:rules,firestore:indexes --project <salonId>`.

## Hard rule: business logic and its trust boundary

There is no trusted server here — the Flutter client talks to Firestore directly, so **Firestore Security Rules are the only real access-control boundary**, not the Dart code. Every rule in `firestore.rules` is deliberately commented with what REST-era behavior it's preserving (e.g. the deactivated-employee bypass fix, owner-only writes, immutable bills). When adding a new collection or mutation:

- **Business logic (price resolution, commission %, GST, stock checks) lives in `AppDataNotifier`**, validated client-side before the Firestore write — see `createBill` in `app_data_provider.dart` for the pattern (resolve everything against the already-loaded `AppData` snapshot, fail fast with a clear exception before touching Firestore).
- **Every new collection needs an explicit rule in `firestore.rules`.** Firestore's default is deny-all; forgetting a rule doesn't silently work, it silently 403s — but a rule that's too permissive is a real data leak, since nothing else is checking. Match the authorization shape of the corresponding REST-era route if one existed (the existing rules comment on which route they mirror). **Editing `firestore.rules` is only half the change — deploy it (see Deployment below), or the new collection 403s in production while working fine in the repo.**
- Firestore rules gate *documents*, not fields — there's no per-field redaction. If a field shouldn't be visible to everyone who can read a document, give it its own document with its own rule. That's why **pay lives in `employeePay/{uid}`** (`baseSalary`, `serviceCommissionPct`, `productCommissionPct`; owner and that employee only), not on `employees/{uid}`, which all staff read. Never write pay fields back onto `employees/{uid}`: `SalonFirestore.writeEmployeeProfile` / `updateEmployee` split them out, and `listEmployeesWithPay` merges them back for the app.
- Older roster docs may still carry pay. The owner's app moves it to `employeePay` and removes it from the roster doc on every load where it finds any (`moveLegacyPay`, called from `loadAppData`). Until then the app reads the old fields (`mergePay` in `firestore_models.dart`), so nothing breaks in between.
- Rules only check *who* can write, not that the math is correct. Since staff can no longer write bills, commissions, payments, stock, targets or the invoice counter (all owner-only in the rules), only the owner's own client could write inconsistent values. If that ever needs closing, the fix is moving bill/commission creation into a Cloud Function that validates and writes with elevated privileges, not relaxing the rules.
- **Staff see only their own per-person records** (salary slips, commissions, attendance, sales targets, payment requests): the rules check `employeeId` / `requestedBy` against the caller, so every staff query on those collections **must** filter by the caller's own uid (`selfId` in `loadAppData`) or the whole query is refused. Staff still read the roster, clients, bills, catalog and settings.
- **Deletes are closed** on everything except `expenses` — archive / deactivate instead. An owner cannot deactivate or demote their own `employees/{uid}` (it would lock the salon out); `updateEmployee` refuses it too.
- Owner-only mutations in `AppDataNotifier` call `_requireOwner()` first — only for a clear error message; the rules are the real gate. A deactivated account is signed out at login with a clear message (`auth_provider.dart`).
- **Test rule changes in the emulator before deploying:** `cd mobile/rules-test && npm install && npm test` (local Firestore emulator, demo project, never a real salon; needs Java). Add a case there for every rule you change.

## Multi-tenancy model

- **One Firebase project per salon** — Firestore quotas and Firebase Auth are both per-project, so one salon's usage/users can never affect another's. `mobile/lib/firebase/salon_directory.dart` is the list of provisioned salons (`salonId` -> `FirebaseOptions`).
- **Login has a fast path and a fallback.** Firebase Auth has no cross-project "which project does this email belong to" lookup the way a global `User.email` column used to provide. `login_directory.dart` points at the `salon-saas-87b6a` Firebase project (`directoryConfigured = true`), which holds just `emailDirectory/{email} -> { salonId }` (no passwords, no salon data — see that file's comments and `mobile/firebase-directory.rules` for why unauthenticated `get` is safe there but `write` never is) so `SalonAuth.signIn` can go straight to the right project. Whenever that lookup can't be used — email not in it, lookup fails, directory project unreachable — signIn() falls back to trying every project in `salonFirebaseConfigs` in turn, same as before this existed. Either way, every employee of a listed salon can sign in the moment their account exists in that salon's project.
- An employee document's Firestore ID *is* their Firebase Auth UID (`employees/{uid}`) — this is what lets `firestore.rules` check "is this my own record" with a direct `get()` instead of a query (rules can't run arbitrary queries).
- Firebase web config values (apiKey, appId, etc.) are not secrets by design — see the comment in `salon_directory.dart`. The real access boundary is Firestore Security Rules + Firebase Auth.

## WhatsApp messages (Cloud Functions)

`mobile/functions/` holds the only server-side code: Cloud Functions that
send a salon's bill receipts, birthday wishes and come-back reminders from
that salon's own WhatsApp Business number (Meta WhatsApp Cloud API). Setup,
template wording and troubleshooting: `mobile/functions/whatsapp.md`.

- **Opt-in per salon.** Functions are deployed only to salons that use
  WhatsApp (`firebase deploy --only functions --project <salonId>`, which
  needs the Blaze plan and that salon's `WHATSAPP_TOKEN` secret), and they do
  nothing unless the owner's `settings/main.whatsappEnabled` switch is on and
  the client has `whatsappOptIn: true`. Never run a bare `firebase deploy`
  from `mobile/`: it would try to deploy functions to a salon that has no
  token.
- **The Meta access token is a Secret Manager secret in each salon's own
  project**, never in Firestore, the app, the operator registry or git.
  Non-secret per-salon values (Phone number ID) go in
  `mobile/functions/.env.<salonId>`.
- The app never calls Meta. The owner's test buttons write
  `whatsappRequests` docs that the function answers. Sends are recorded in
  `whatsappLog` (owner-readable, never client-writable, because a fake
  entry would suppress a real send).
- Customer `birthday` is `"MM-DD"` (no year; helpers in
  `mobile/lib/data/birthday.dart`). The daily function matches on that
  exact string.
- What gets sent: the bill right after it is created (`whatsappBillReceipt`,
  Firestore trigger on `bills/{id}`), birthday wishes and a come-back
  reminder 21 days after the last visit (`whatsappDaily`, 10:00 IST,
  Cloud Scheduler). Templates `bill_receipt` (Utility), `birthday_wish` and
  `visit_reminder` (Marketing) must be approved in that salon's WhatsApp
  Manager; their names/language/reminder days are in `functions/.env`
  (defaults, deliberately committed - no secrets) and can be overridden per
  salon in `functions/.env.<salonId>`.
- **Set-up flag:** `whatsappSetup/status { ready: true }`, written by hand in
  the Console when a salon's WhatsApp is configured (step 7 in
  `whatsapp.md`); rules make it readable by staff, writable by nobody. Until
  it's set, Settings shows a "not set up - WhatsApp us / Email us" card
  (contact details in `lib/data/support_contact.dart`) instead of the switch,
  and the bill screen never claims a WhatsApp send.
- In the app: customers have a birthday picker and an "OK to send WhatsApp
  messages" checkbox (Add Customer, and "Birthday & WhatsApp" on a client);
  the owner's switch and test buttons are the WhatsApp card in Settings >
  Business; "Bill Generated" says whether the bill is going out on WhatsApp
  (`widgets/bill_whatsapp_note.dart`).
- Unit tests for the pure helpers: `cd mobile/functions && npm test`.
- First functions deploy to a new project often fails for two functions
  with an Eventarc permission error - wait 3-5 minutes and deploy again.
- Currently deployed to: `test-salon-ee06a` only (test salon, Meta test number; deployed 2026-10-14).

## QR codes (shared Storage + Cloud Function)

The owner adds a payment QR and a Google review QR in Profile; Home's
header has a button for each that shows it full screen for a client.

- Images live in the **shared** `salon-saas-87b6a` Storage at
  `salonQr/{salonId}/{payment|review}.jpg`, shrunk on the phone first
  (`lib/data/qr_image.dart`: max 800px JPEG, under 250 KB). Their URLs are
  saved in that salon's own `settings/main` (`paymentQrUrl`,
  `reviewQrUrl`).
- **Uploads only go through the `uploadSalonQr` function**
  (`directory-project/functions/index.js`), never straight to Storage:
  owners sign in to their own salon project, so salon-saas Storage rules
  can't identify them, and open writes would let anyone swap a salon's
  payment QR. The function verifies the owner's ID token against the
  salon's project and reads their `employees/{uid}` (role OWNER, active)
  with that token. `directory-project/storage.rules` = public read, no
  client writes.
- `directory-project/` is the deploy folder for salon-saas-87b6a only
  (`firebase deploy --only functions,storage --project salon-saas-87b6a`
  from it; needs Blaze). Each salon must be in `ALLOWED_SALON_IDS` in
  `directory-project/functions/.env`, or its owner's upload is refused.

## Billing and catalog data rules

- **Invoice numbers** are sequential per salon (`INV-0001`...), taken from
  `counters/invoices` (`{ last: N }`) inside `createBill`'s transaction.
  `firestore.rules` only lets it be created at 1 and bumped by exactly 1.
  Bills from before this kept their random `INV-XXXXXXXX` numbers.
- **Services and products are never deleted.** "Remove" sets
  `archived: true`; `firestore_app_data.dart` leaves archived entries out of
  `AppData`, so billing, the menu and stock alerts never offer them, while
  every bill line keeps its own copy of name and price. Name/SKU uniqueness
  checks ignore archived entries so a removed name can be reused.
- **A salon fresh from Add Salon has no branch.** Billing and hiring both
  need one, so `AppDataNotifier.build()` creates a "Main Branch" the first
  time an owner opens such a salon (owner-only; rules forbid anyone else).
- Product SKU is optional in the UI; a blank one gets a generated code.
- Stored codes (`CASH`, `UPI`, `PENDING`, `RENT`, `MISC`...) are never shown
  raw - use `paymentMethodLabel()` / `expenseCategoryLabel()` in
  `data/models.dart` ("Cash", "Pay later", "Rent", "Other").

## UI conventions (owner and employee apps)

- **Look:** deep navy brand on cool slate neutrals; colour is flat and
  sparing (buttons, links, current tab, progress, small icon tiles). No
  gradients, no coloured glows, no rainbow icon tiles - those read as
  AI-generated and were removed on purpose. Amber / red (and muted green
  for "Paid") are for status only. All tokens live in `lib/theme.dart`
  (`AppTheme`; `primaryBlue` is the navy - names kept from the old indigo
  design). Cards use `AppTheme.cardShadow` + a `borderSubtle` hairline,
  16 radius.
- **Building blocks** in `lib/widgets/ds.dart`: `DsCard`, `DsSectionLabel`,
  `DsSectionTitle`, `DsStatTile`/`DsStat`, `DsListRow`, `DsAvatar`,
  `DsPill`, `DsValueRow`, `DsProgressBar`. New screens should be built
  from these rather than hand-rolled containers.
- **Staff don't bill.** Only the owner creates bills - `firestore.rules`
  enforces it (bills, items, payments, commissions, counters, dailyStats,
  stock and target progress are owner-only writes). Staff also don't add
  or edit clients. The staff app has a My work tab (their
  services/products) instead, and there are no discount requests any more
  (`discountRequests` is owner-read-only, no writes). Giving staff any of
  these back needs a rules change first.
- **One home per job:** the bell on every tab is the Requests inbox
  (payment requests staff collected); the gear appears only on Home and opens
  Salon Settings (Business incl. GST/penalty/WhatsApp, Branches); Team has
  visible Attendance and Payroll buttons; Clients has Dues. Don't hide daily
  work behind a gear.
- **Navigation:** the Menu tab (last slot, right edge) opens the Scaffold's
  `endDrawer` so it slides from the right; on phones the drawer omits the
  four bottom-bar tabs. Tabs change only from the bar (the PageView does
  not swipe). Billing opens on New Bill.
- **No fake buttons:** Call / WhatsApp use real links via
  `widgets/open_link.dart` (web implementation; stub elsewhere). Never ship
  a button that only shows a "Calling..." snackbar.
- **Client follow-up (Reports > Clients):** green = last visit 30-44
  days ago, yellow = 45-59, red = 60+ (`recencyBandFor` in
  `client_retention_report.dart`), each with Call and a ready-written
  WhatsApp message. Separate from the 21-day dot in the client list,
  which matches the automatic WhatsApp reminder.
- **Attendance roster** only saves rows the owner actually marked; an
  unmarked person is "Not in yet", never auto-saved as Absent.
- Don't run `dart format` over the big screen files - they aren't formatted
  with it, and it rewrites thousands of unrelated lines.

## Rules deploy status

`feature/whatsapp-messages` added rules for `counters/invoices`,
`whatsappLog`, `whatsappRequests` and `whatsappSetup` (additive only). They
were deployed to all three salons (`cuts-salon`, `instyle-salon`,
`test-salon-ee06a`) on 2026-10-14, so the app can be pushed.

**2026-10-15 security tightening - deployed to all three salons on
2026-10-15.** The rules now make billing/payments/stock/clients owner-only,
scope staff to their own pay and attendance records, close deletes, stop
strangers reading the roster and stop an owner locking themselves out (see
the trust-boundary section). The app already did these things only as the
owner and already filtered staff queries by their own uid, so the live app
works with these rules before and after the app push.

**`employeePay` (pay off the roster) - rules NOT deployed yet.** Additive
(a new collection), so it is safe to deploy before the app push. Once
deployed and the new app is live, each salon's pay moves the next time its
owner opens the app; until then staff can still technically read
coworkers' pay on the roster docs. Check by looking in the Console that
`employees/*` docs no longer have `baseSalary`.

## Onboarding a new salon

**Current status: three provisioned projects - `cuts-salon`, `instyle-salon`
(onboarded 2026-10-05) and `test-salon-ee06a` (a test salon added 2026-10-14
for trying the WhatsApp Business API).** Consequences: every per-project
deploy (rules, indexes) has to be run against ALL of them, and it is easy to ship a
change that silently works only on the salon you happened to test. The login
fallback loop now tries every one of them, so keep each salon's people in
`emailDirectory` (see below) to keep sign-in on the fast path.


1. Create a new Firebase project (Console or `firebase projects:create`), enable Firestore + Email/Password Auth.
2. Deploy `mobile/firestore.rules` and `mobile/firestore.indexes.json` to it: `firebase deploy --only firestore:rules,firestore:indexes --project <newSalonId>`.
3. Create the owner's Firebase Auth account and a matching `employees/{uid}` document (role `OWNER`) plus a `settings/main` document. The operator dashboard's **Add Salon** does all three (plus steps 5 and 6) via `operator-dashboard/src/utils/provisionSalon.js`, relying on the one-time `isBootstrappingOwner()` rule in `firestore.rules` — run it right after step 2, and don't hand-create `settings/main` first or the bootstrap is refused. Manual fallback: do it in the Console, see `firestore_models.dart` for the shapes.
4. Add a `SalonFirebaseConfig` entry for it in `mobile/lib/firebase/salon_directory.dart` with that project's web config, **and** its Android config for the Android app: `firebase apps:create ANDROID "Stylux Android" --package-name com.client.salon.mobile --project <newSalonId>`, then `firebase apps:sdkconfig ANDROID <appId> --project <newSalonId>` and copy `mobilesdk_app_id` / `current_key` into the entry's `androidOptions`. Without it the Android app falls back to the web config, which Firebase may refuse.
5. If the login directory (below) is configured, add the owner's `emailDirectory/{email} -> { salonId }` doc for it too — not required (sign-in falls back to trying every project), but skipping it means every login for this salon pays the full fallback-loop cost.
6. Add the salon's id to `ALLOWED_SALON_IDS` in `directory-project/functions/.env` and redeploy that function (see QR codes above), so the owner can upload QR images.
7. If the operator salon registry (below) is set up, add a `salons/{salonId}` doc for it too — purely for your own reference, the app never reads this.

## The login directory (`salon-saas-87b6a`)

`login_directory.dart` is wired to the `salon-saas-87b6a` Firebase project (`directoryConfigured = true`) — this is a project separate from every salon's own, used only for the fast-path lookup described above, plus the unrelated operator registry below. Its Firestore rules (`mobile/firebase-directory.rules`) are deployed there (deploy again after editing that file: see the scratch-`firebase.json` approach below, since `mobile/firebase.json` points at the per-salon `firestore.rules` instead).

- `emailDirectory/{email} -> { salonId }`: one doc per person who logs in, doc id = the lowercase email. Writes are limited to signed-in operator accounts (the operator dashboard's Add Salon writes the owner's entry) or the Console. That is only safe because public sign-up is **disabled** in this project's Firebase Auth (done 2026-10-06) — never turn it back on, or anyone could create an account and repoint someone's login (see the rules file's comment). `cuts-salon`'s test accounts (`owner@cuts-salon.test`, `employee@cuts-salon.test`) still need their entries added by hand for the fast path to actually apply to them — until then they just take the fallback-loop path silently, same as before wiring this up.
- Going forward, every new salon's owner and, optionally, every new employee needs a matching `emailDirectory` doc added the same way.
- **To deploy rules here without touching `mobile/firebase.json`**: copy `mobile/firebase-directory.rules` to a scratch dir as `firestore.rules`, add a minimal `firebase.json` there (`{"firestore": {"rules": "firestore.rules"}}`), then `firebase deploy --only firestore:rules --project salon-saas-87b6a` from that scratch dir. Deploying from `mobile/` would push the *wrong* rules file (the per-salon one) to this project — that happened once already during setup and had to be corrected.

## Operator salon registry (optional)

A second, unrelated collection in the same directory project (see above): `salons/{salonId}`, a plain reference list of every provisioned salon for whoever operates this SaaS — not read by the app, not involved in login at all. Exists so you don't have to grep `salon_directory.dart` to answer "what salons exist and who owns them."

- Reuses the login directory project (`salon-saas-87b6a`, above) — don't stand up a separate project just for this.
- `mobile/firebase-directory.rules` already locks `salons/{salonId}` to `allow read, write: if false;` (Console/Admin SDK only) — there's no client code path that touches it, so it never needs to be more open than that, unlike `emailDirectory` which the app does read.
- Suggested doc shape per salon (add by hand in the Console, no fixed schema is enforced): `salonName` (string), `ownerName` (string), `ownerEmail` (string), `firebaseConfig` (map — the same fields as the `FirebaseOptions` you put in `salon_directory.dart`: `apiKey`, `appId`, `authDomain`, `projectId`, `storageBucket`, `messagingSenderId`), `createdAt` (timestamp).
- Explicitly does **not** store passwords, employee lists, or any salon business data — those stay inside each salon's own isolated project, same as always. This registry is metadata about tenants, not a login mechanism; storing real credentials here would undo the whole point of one-Firebase-project-per-salon (a single leak here would then expose every salon at once instead of one).

## Android app

- Same Flutter code as the web build. Platform-specific pieces use conditional imports: `widgets/open_link*.dart` (url_launcher on Android) and `widgets/csv_export*.dart` (file + share sheet via share_plus on Android).
- Each salon's `SalonFirebaseConfig.androidOptions` (and `_directoryAndroidOptions` in `login_directory.dart`) holds the Android app registered in that project; `platformOptions` picks web or Android.
- `pubspec.yaml` overrides `path_provider_foundation` to 2.4.1: newer versions need Dart native assets (objective_c), which stops `flutter test` running. Web and Android don't use it.
- Building the APK on this machine: the Windows user folder ("Amit's Laptop") has an apostrophe that breaks Java's temp paths. Build with `TEMP`/`TMP` and `-Djdk.net.unixdomain.tmpdir` pointed at a plain folder (e.g. `D:\gradle-tmp`), outside the command sandbox; `android/gradle.properties` already compiles Kotlin in-process. Output: `flutter build apk --release --split-per-abi` -> `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- The release APK is still signed with the debug key - fine for installing directly, not for the Play Store or for updating installs signed with a different key.

## Deployment

- The app is a Flutter web build on Vercel (`mobile/vercel.json` + `mobile/build.sh`). There is no server to deploy or keep alive — Firestore and Firebase Auth are managed services.
- **Rules and indexes do NOT ship with the app.** Vercel auto-deploys the Flutter build on every push to `main`; `firestore.rules` and `firestore.indexes.json` only reach Firebase when someone runs the deploy below by hand. So a push can leave the app expecting rules that production doesn't have yet — the repo looks right, production 403s.

  After any change to `firestore.rules` or `firestore.indexes.json`, from `mobile/`:

  ```bash
  firebase deploy --only firestore:rules,firestore:indexes --project cuts-salon
  firebase deploy --only firestore:rules,firestore:indexes --project instyle-salon
  firebase deploy --only firestore:rules,firestore:indexes --project test-salon-ee06a
  ```

  Repeat for every provisioned salon (see Onboarding a new salon). The deploy replaces the live ruleset wholesale, so any edit made directly in the Firebase Console is overwritten — change rules in the repo, never in the Console.
- **How this fails when it is missed:** Firestore denies the read and the client logs `permission-denied` / HTTP 403 on `runQuery`/`runAggregationQuery`. Call sites that degrade gracefully (e.g. `countPendingPaymentRequests` in `salon_firestore.dart`, which catches and returns 0) swallow it, so nothing visibly breaks — a badge just silently reads 0. This happened for real: the `paymentRequests` rules landed with the feature on 2026-09-30 but weren't deployed until 2026-10-02, and the owner's pending-settlement badge read 0 the whole time. When one collection 403s in production while an identically-ruled one works, suspect an undeployed ruleset first.

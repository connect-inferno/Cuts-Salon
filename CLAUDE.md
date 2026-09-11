# Cuts-Salon — Salon SaaS

Multi-tenant salon management SaaS. Each salon runs on its own Firebase project (Firestore + Firebase Auth) — there is no shared server. Read this before making changes to how the app talks to Firebase — it applies to any AI agent working in this repo, not just this session.

## Project shape

- `mobile/` — Flutter app (salon staff/owner client), deployed to Vercel as a web build. This is the entire app; there is no separate backend service.
- `mobile/lib/firebase/` — everything Firebase-specific: `salon_directory.dart` (the list of provisioned salons and their Firebase project config), `salon_auth.dart` (multi-project sign-in), `login_directory.dart` (fast email -> salonId lookup against `salon-saas-87b6a`, see Multi-tenancy model below), `salon_firestore.dart` (all Firestore reads/writes), `firestore_models.dart` (Firestore document <-> app model conversions), `firestore_app_data.dart` (assembles one salon's full `AppData` snapshot).
- `mobile/lib/data/app_data_provider.dart` — the single source of truth for app state (`AppDataNotifier`). Every mutation (create bill, clock in, approve a discount request, etc.) lives here as a method that validates input and calls into `SalonFirestore`.
- `mobile/firestore.rules` / `mobile/firestore.indexes.json` — deployed per-project via `firebase deploy --only firestore:rules,firestore:indexes --project <salonId>`.

## Hard rule: business logic and its trust boundary

There is no trusted server here — the Flutter client talks to Firestore directly, so **Firestore Security Rules are the only real access-control boundary**, not the Dart code. Every rule in `firestore.rules` is deliberately commented with what REST-era behavior it's preserving (e.g. the deactivated-employee bypass fix, owner-only writes, immutable bills). When adding a new collection or mutation:

- **Business logic (price resolution, commission %, GST, stock checks) lives in `AppDataNotifier`**, validated client-side before the Firestore write — see `createBill` in `app_data_provider.dart` for the pattern (resolve everything against the already-loaded `AppData` snapshot, fail fast with a clear exception before touching Firestore).
- **Every new collection needs an explicit rule in `firestore.rules`.** Firestore's default is deny-all; forgetting a rule doesn't silently work, it silently 403s — but a rule that's too permissive is a real data leak, since nothing else is checking. Match the authorization shape of the corresponding REST-era route if one existed (the existing rules comment on which route they mirror).
- Firestore rules gate *documents*, not fields — there's no per-field redaction (see the comment atop `firestore.rules` re: salary visibility). If a field shouldn't be visible to someone who can read the document, that has to be enforced in the app layer (`firestore_app_data.dart`) instead.
- A single active employee (or a tampered client) can, in principle, write internally-inconsistent values (e.g. a fabricated commission %) since rules only check *who* can write, not that the math is correct. This is a known, accepted trade-off of the no-server architecture — if that ever needs closing, the fix is moving bill/commission creation into a Cloud Function that validates and writes with elevated privileges, not relaxing this note.

## Multi-tenancy model

- **One Firebase project per salon** — Firestore quotas and Firebase Auth are both per-project, so one salon's usage/users can never affect another's. `mobile/lib/firebase/salon_directory.dart` is the list of provisioned salons (`salonId` -> `FirebaseOptions`).
- **Login has a fast path and a fallback.** Firebase Auth has no cross-project "which project does this email belong to" lookup the way a global `User.email` column used to provide. `login_directory.dart` points at the `salon-saas-87b6a` Firebase project (`directoryConfigured = true`), which holds just `emailDirectory/{email} -> { salonId }` (no passwords, no salon data — see that file's comments and `mobile/firebase-directory.rules` for why unauthenticated `get` is safe there but `write` never is) so `SalonAuth.signIn` can go straight to the right project. Whenever that lookup can't be used — email not in it, lookup fails, directory project unreachable — signIn() falls back to trying every project in `salonFirebaseConfigs` in turn, same as before this existed. Either way, every employee of a listed salon can sign in the moment their account exists in that salon's project.
- An employee document's Firestore ID *is* their Firebase Auth UID (`employees/{uid}`) — this is what lets `firestore.rules` check "is this my own record" with a direct `get()` instead of a query (rules can't run arbitrary queries).
- Firebase web config values (apiKey, appId, etc.) are not secrets by design — see the comment in `salon_directory.dart`. The real access boundary is Firestore Security Rules + Firebase Auth.

## Onboarding a new salon

1. Create a new Firebase project (Console or `firebase projects:create`), enable Firestore + Email/Password Auth.
2. Deploy `mobile/firestore.rules` and `mobile/firestore.indexes.json` to it: `firebase deploy --only firestore:rules,firestore:indexes --project <newSalonId>`.
3. Create the owner's Firebase Auth account and a matching `employees/{uid}` document (role `OWNER`) plus a `settings` document — see `firestore_models.dart` for the expected shape.
4. Add a `SalonFirebaseConfig` entry for it in `mobile/lib/firebase/salon_directory.dart` with that project's web config.
5. If the login directory (below) is configured, add the owner's `emailDirectory/{email} -> { salonId }` doc for it too — not required (sign-in falls back to trying every project), but skipping it means every login for this salon pays the full fallback-loop cost.
6. If the operator salon registry (below) is set up, add a `salons/{salonId}` doc for it too — purely for your own reference, the app never reads this.

## The login directory (`salon-saas-87b6a`)

`login_directory.dart` is wired to the `salon-saas-87b6a` Firebase project (`directoryConfigured = true`) — this is a project separate from every salon's own, used only for the fast-path lookup described above, plus the unrelated operator registry below. Its Firestore rules (`mobile/firebase-directory.rules`) are deployed there (deploy again after editing that file: see the scratch-`firebase.json` approach below, since `mobile/firebase.json` points at the per-salon `firestore.rules` instead).

- `emailDirectory/{email} -> { salonId }`: one doc per person who logs in, doc id = the lowercase email. Writes are Console-only by design (see the rules file's comment on why). `cuts-salon`'s test accounts (`owner@cuts-salon.test`, `employee@cuts-salon.test`) still need their entries added by hand for the fast path to actually apply to them — until then they just take the fallback-loop path silently, same as before wiring this up.
- Going forward, every new salon's owner and, optionally, every new employee needs a matching `emailDirectory` doc added the same way.
- **To deploy rules here without touching `mobile/firebase.json`**: copy `mobile/firebase-directory.rules` to a scratch dir as `firestore.rules`, add a minimal `firebase.json` there (`{"firestore": {"rules": "firestore.rules"}}`), then `firebase deploy --only firestore:rules --project salon-saas-87b6a` from that scratch dir. Deploying from `mobile/` would push the *wrong* rules file (the per-salon one) to this project — that happened once already during setup and had to be corrected.

## Operator salon registry (optional)

A second, unrelated collection in the same directory project (see above): `salons/{salonId}`, a plain reference list of every provisioned salon for whoever operates this SaaS — not read by the app, not involved in login at all. Exists so you don't have to grep `salon_directory.dart` to answer "what salons exist and who owns them."

- Reuses the login directory project (`salon-saas-87b6a`, above) — don't stand up a separate project just for this.
- `mobile/firebase-directory.rules` already locks `salons/{salonId}` to `allow read, write: if false;` (Console/Admin SDK only) — there's no client code path that touches it, so it never needs to be more open than that, unlike `emailDirectory` which the app does read.
- Suggested doc shape per salon (add by hand in the Console, no fixed schema is enforced): `salonName` (string), `ownerName` (string), `ownerEmail` (string), `firebaseConfig` (map — the same fields as the `FirebaseOptions` you put in `salon_directory.dart`: `apiKey`, `appId`, `authDomain`, `projectId`, `storageBucket`, `messagingSenderId`), `createdAt` (timestamp).
- Explicitly does **not** store passwords, employee lists, or any salon business data — those stay inside each salon's own isolated project, same as always. This registry is metadata about tenants, not a login mechanism; storing real credentials here would undo the whole point of one-Firebase-project-per-salon (a single leak here would then expose every salon at once instead of one).

## Deployment

- The app is a Flutter web build on Vercel (`mobile/vercel.json` + `mobile/build.sh`). There is no server to deploy or keep alive — Firestore and Firebase Auth are managed services.

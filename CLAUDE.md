# Cuts-Salon — Salon SaaS

Multi-tenant salon management SaaS. Each salon runs on its own Firebase project (Firestore + Firebase Auth) — there is no shared server. Read this before making changes to how the app talks to Firebase — it applies to any AI agent working in this repo, not just this session.

## Project shape

- `mobile/` — Flutter app (salon staff/owner client), deployed to Vercel as a web build. This is the entire app; there is no separate backend service.
- `mobile/lib/firebase/` — everything Firebase-specific: `salon_directory.dart` (the list of provisioned salons and their Firebase project config), `salon_auth.dart` (multi-project sign-in), `salon_firestore.dart` (all Firestore reads/writes), `firestore_models.dart` (Firestore document <-> app model conversions), `firestore_app_data.dart` (assembles one salon's full `AppData` snapshot).
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
- **Login tries every configured project in turn** (`SalonAuth.signIn`, called from `auth_provider.dart`) since Firebase Auth has no cross-project "which project does this email belong to" lookup the way a global `User.email` column used to provide. This means every employee of a listed salon can sign in the moment their account exists in that salon's project — nothing to configure per employee, only a new salon needs a new `salonFirebaseConfigs` entry.
- An employee document's Firestore ID *is* their Firebase Auth UID (`employees/{uid}`) — this is what lets `firestore.rules` check "is this my own record" with a direct `get()` instead of a query (rules can't run arbitrary queries).
- Firebase web config values (apiKey, appId, etc.) are not secrets by design — see the comment in `salon_directory.dart`. The real access boundary is Firestore Security Rules + Firebase Auth.

## Onboarding a new salon

1. Create a new Firebase project (Console or `firebase projects:create`), enable Firestore + Email/Password Auth.
2. Deploy `mobile/firestore.rules` and `mobile/firestore.indexes.json` to it: `firebase deploy --only firestore:rules,firestore:indexes --project <newSalonId>`.
3. Create the owner's Firebase Auth account and a matching `employees/{uid}` document (role `OWNER`) plus a `settings` document — see `firestore_models.dart` for the expected shape.
4. Add a `SalonFirebaseConfig` entry for it in `mobile/lib/firebase/salon_directory.dart` with that project's web config.

## Deployment

- The app is a Flutter web build on Vercel (`mobile/vercel.json` + `mobile/build.sh`). There is no server to deploy or keep alive — Firestore and Firebase Auth are managed services.

## What and why

<!-- One or two sentences: what changes for the owner or staff, and why. -->

## Checks

- [ ] CI is green (app analyze + tests, functions tests, rules emulator tests)
- [ ] Tried on the **test salon** (`test-salon-ee06a`) via the Vercel preview link - never a real salon's login on a preview
- [ ] Screenshots attached for anything that looks different (phone and laptop width)

## Does it change Firestore rules or indexes? (`mobile/firestore.rules`, `mobile/firestore.indexes.json`)

- [ ] No
- [ ] Yes, and the new rules only **allow more** (new collection, new field) -> deploy **before** merging:
      `scripts/deploy-salons.sh rules`
- [ ] Yes, and the new rules **restrict** something -> merge, wait for Vercel to finish, then deploy **straight away**:
      `scripts/deploy-salons.sh rules`

## Does it change Cloud Functions? (`mobile/functions/`)

- [ ] No
- [ ] Yes -> after the rules, `scripts/deploy-salons.sh functions` (WhatsApp salons only)

## After merging

- [ ] Vercel production deploy finished
- [ ] Quick look at a real salon's affected screen (as the owner, read-only)
- [ ] Deployed outside salon opening hours, or the change is safe mid-day

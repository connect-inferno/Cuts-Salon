# salon-saas-87b6a (shared project)

Deploy target for the shared project only: Storage rules and the
`uploadSalonQr` Cloud Function (owners' payment QR / Google review QR
images). Never deploy this folder to a salon project, and never deploy
`mobile/` to this one.

```bash
cd directory-project/functions && npm install && npm test
cd .. && firebase deploy --only functions,storage --project salon-saas-87b6a
```

Needs the Blaze plan on salon-saas-87b6a (Cloud Functions).

**Onboarding a salon:** add its project id to `ALLOWED_SALON_IDS` in
`functions/.env` and deploy the function again, or its owner's QR upload is
refused with "not enabled for this salon yet".

How the upload is secured is explained at the top of `functions/index.js`
and `storage.rules`.

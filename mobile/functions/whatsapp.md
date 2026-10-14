# WhatsApp messages: setting up a salon

Each salon sends from **its own** WhatsApp Business number, with **its own**
Meta account and key. Nothing is shared between salons. Only salons that want
WhatsApp need any of this; the rest never deploy these functions.

What gets sent (only to clients marked "OK to send WhatsApp messages", and
only while the owner's switch in **Settings → WhatsApp Messages** is on):

| Message | When | Function |
|---|---|---|
| Bill receipt | right after a bill is created | `whatsappBillReceipt` |
| Birthday wish | 10:00 AM IST on the client's birthday | `whatsappDaily` |
| Come-back reminder | 10:00 AM IST, 21 days after the last visit | `whatsappDaily` |

Every send (or failure, with Meta's error) is recorded in the salon's
`whatsappLog` collection in Firestore.

## One-time setup per salon

`<projectId>` below is the salon's Firebase project ID, e.g. `test-salon-ee06a`.

1. **Firebase Blaze plan** on that project (Console → Upgrade). Set a budget alert.
2. **Meta app** for the salon: developers.facebook.com → Create App →
   "Connect with customers through WhatsApp". For testing, Meta's free test
   number is enough (it can message up to 5 verified numbers). For real use,
   add the salon's own number in "Production setup".
3. **Phone number ID**: copy it from the API Setup page and create
   `functions/.env.<projectId>` containing:
   ```
   WHATSAPP_PHONE_NUMBER_ID=<the Phone number ID>
   ```
   Not secret, so it's committed.
4. **Message templates**: create the three below in WhatsApp Manager
   (business.facebook.com → WhatsApp Manager → Message templates → Create)
   and wait for "Active / Approved".
5. **The key (access token)**: never in a file, in chat or in the app.
   ```bash
   firebase functions:secrets:set WHATSAPP_TOKEN --project <projectId>
   ```
   Paste the token when asked. The 24-hour token from API Setup works for a
   quick test. For real use, make a permanent one: Meta Business settings →
   Users → System users → Add (Admin) → Assign assets (the app, full control)
   → Generate token with `whatsapp_business_messaging` and
   `whatsapp_business_management`, expiry "Never". Then run the command again.
6. **Deploy** (from `mobile/`):
   ```bash
   firebase deploy --only functions --project <projectId>
   ```
   The **first** deploy to a new project often fails for two of the three
   functions with "Permission denied while using the Eventarc Service
   Agent". Google is still switching things on. Wait 3-5 minutes and run
   the same command again.
   After changing the token in step 5, deploy again so the functions pick
   up the new version.
7. In the app, as the owner: **Settings → WhatsApp Messages**, then
   **Send test** to your own number (sends Meta's `hello_world`) and switch
   **Send automatic WhatsApp messages** on.

## The three templates

Language: **English** (code `en`). Names must match exactly, or override them
(defaults are in `functions/.env`) in `.env.<projectId>` with `WHATSAPP_TEMPLATE_BILL`, `WHATSAPP_TEMPLATE_BIRTHDAY`,
`WHATSAPP_TEMPLATE_REMINDER` and `WHATSAPP_TEMPLATE_LANGUAGE`.

### `bill_receipt`, category **Utility**

```
Hi {{1}}, thank you for visiting {{2}}!

Bill no: {{3}}
Services: {{4}}
Total: ₹{{5}}
Paid: ₹{{6}}
Balance due: ₹{{7}}

We look forward to seeing you again.
```
Sample values: `Priya`, `Cuts Salon`, `INV-0042`, `Haircut, Beard Trim`, `1,200`, `1,200`, `0`

### `birthday_wish`, category **Marketing**

```
Happy Birthday, {{1}}! 🎂

Everyone at {{2}} wishes you a wonderful year ahead. Treat yourself to a fresh new look this birthday month, we would love to see you!
```
Sample values: `Priya`, `Cuts Salon`

### `visit_reminder`, category **Marketing**

```
Hi {{1}}, it has been a few weeks since your last visit to {{2}}. Time for a refresh? Reply to this message to book your next appointment. We would love to see you again!
```
Sample values: `Priya`, `Cuts Salon`

Meta may suggest adding a "Stop promotions" button to the two Marketing
templates. That's fine to accept, since it doesn't change the variables.

## Cost

Firebase: within Blaze's free allowance at salon volumes. Meta charges per
message: Utility (bills) is cheap and Marketing (birthday, reminder) costs
more. Check Meta's current India rates.

## When something doesn't arrive

- Firestore → `whatsappLog`: each attempt's `status` and Meta's `error`.
- Firebase Console → Functions → Logs.
- Common causes: the client isn't opted in; the switch is off; a template
  isn't approved yet or its name/language differs; the token expired (the
  24-hour one); on the test number, the recipient isn't one of the 5
  verified numbers.

// Generated from mobile/lib/features/legal/legal_pages.dart - keep the two in step.
const legal = {
  "effective": "14 October 2026",
  "privacy": [
    {
      "heading": "Who this covers",
      "paragraphs": [
        "Stylux is software that salons use to run billing, client records, staff attendance and pay. This policy covers salon owners, staff who sign in, and the salon clients whose details a salon records.",
        "Each salon decides what it records about its own clients and staff and is responsible for that information. Stylux stores and processes it on the salon's behalf, to provide the app."
      ]
    },
    {
      "heading": "What is stored",
      "paragraphs": [
        "Owner and staff accounts: name, email address, phone number, role, branch, base salary, commission rates, attendance (clock-in and clock-out times), salary slips and commission earned. Passwords are handled by Google Firebase Authentication - Stylux never sees or stores them.",
        "Location at clock-in and clock-out: when the phone or browser allows it, the place a shift was started and ended is saved with that day's attendance, so the owner can see it. If location is turned off or refused, attendance still works and the record says the location was unavailable.",
        "Salon clients: name, phone number, and optionally email, birthday (day and month only - no year), whether they agreed to WhatsApp messages, visits, bills, payments and anything still owed.",
        "Salon business records: services, products and stock, expenses, discounts, branches, and settings such as GST."
      ]
    },
    {
      "heading": "How it is used",
      "paragraphs": [
        "Only to run the salon: making bills, keeping client history, tracking attendance and stock, and working out pay and commission.",
        "WhatsApp messages (bill receipts, birthday wishes, visit reminders) are sent only when the salon has switched WhatsApp on and the client has agreed to receive them. They come from the salon's own WhatsApp Business number.",
        "Stylux does not sell personal information, does not show advertising, and does not use salon data to profile anyone."
      ]
    },
    {
      "heading": "Where it is kept",
      "paragraphs": [
        "Every salon has its own separate Google Firebase project (a database and a sign-in system), so one salon's data is kept apart from every other salon's.",
        "A small shared directory stores only each person's email address and which salon they belong to, so sign-in goes straight to the right salon. It holds no passwords and no salon data.",
        "Information travels over encrypted connections (HTTPS) and Google encrypts it where it is stored."
      ]
    },
    {
      "heading": "Who it is shared with",
      "paragraphs": [
        "Inside the salon: the owner can see all of the salon's records. Staff see what they need for their work - clients and bills, and their own attendance and pay.",
        "Service providers that make the app work: Google (Firebase hosting, database and sign-in), Vercel (which delivers the app to your browser), and Meta (WhatsApp Business), which receives a client's phone number and the message text only for messages that client agreed to.",
        "Authorities, only where the law requires it."
      ]
    },
    {
      "heading": "How long it is kept",
      "paragraphs": [
        "Records are kept while the salon uses Stylux. Bills are kept as business records and are never edited after they are made. Services and products that are removed are archived rather than erased, so old bills still show what was sold.",
        "When a salon stops using Stylux, it can ask for its data to be deleted, except where it must be kept by law."
      ]
    },
    {
      "heading": "Your choices and rights",
      "paragraphs": [
        "You can ask to see, correct or delete information about you, and you can withdraw consent - for example, to stop WhatsApp messages. Salon clients should ask their salon, which can update or remove the record. Staff and owners can ask the salon owner or the Stylux team.",
        "Under India's Digital Personal Data Protection Act, 2023, you may also raise a complaint with the Data Protection Board of India."
      ]
    },
    {
      "heading": "Security",
      "paragraphs": [
        "Each salon's data is isolated, and access rules decide who can read or change each record. Keep your password private and sign out on shared devices. No system can be made perfectly secure, so please tell the salon owner straight away if you think an account has been misused."
      ]
    },
    {
      "heading": "Children",
      "paragraphs": [
        "Owner and staff accounts are for adults. A salon may record a child as a client; in that case the salon should have a parent or guardian's agreement."
      ]
    },
    {
      "heading": "Changes to this policy",
      "paragraphs": [
        "If this policy changes, the effective date at the top will change and the new version will appear here."
      ]
    }
  ],
  "disclaimer": [
    {
      "heading": "Provided as is",
      "paragraphs": [
        "Stylux is a tool for running day-to-day salon work. We work to keep it accurate, secure and available, but we cannot promise it will always be uninterrupted or free of errors."
      ]
    },
    {
      "heading": "Numbers you rely on",
      "paragraphs": [
        "Bills, GST, discounts, commission, salary, dues and reports are calculated from what the salon enters - prices, rates, attendance and so on. The salon is responsible for checking them.",
        "GST is added at the rate the owner sets. Stylux does not decide whether a salon must charge GST, and nothing in the app is tax, legal or financial advice. Please confirm tax filings and payroll with an accountant."
      ]
    },
    {
      "heading": "WhatsApp messages",
      "paragraphs": [
        "The salon is responsible for having each client's agreement before messages are sent and for following Meta's WhatsApp Business rules. Delivery depends on Meta; Stylux is not responsible for messages Meta delays, blocks or charges for."
      ]
    },
    {
      "heading": "Attendance and location",
      "paragraphs": [
        "Clock-in times and locations are a record to help the owner, not proof. A phone may report its location inaccurately or not at all."
      ]
    },
    {
      "heading": "Accounts and access",
      "paragraphs": [
        "Keep your password private. The owner decides who gets an account and should remove access for anyone who leaves. Actions taken while signed in to an account are treated as that account's."
      ]
    },
    {
      "heading": "Keep your own copy",
      "paragraphs": [
        "Data is stored with Google Firebase. We recommend downloading your bills from Reports (Download bills) regularly so you always have your own copy."
      ]
    },
    {
      "heading": "Limits of responsibility",
      "paragraphs": [
        "As far as the law allows, Stylux is not responsible for indirect losses - such as lost business, lost profit or lost data - arising from using the app or from it being unavailable."
      ]
    },
    {
      "heading": "Other services",
      "paragraphs": [
        "Google, Vercel and Meta provide parts of the service and have their own terms and privacy policies."
      ]
    },
    {
      "heading": "Changes",
      "paragraphs": [
        "This disclaimer may be updated. The effective date at the top shows when it last changed."
      ]
    }
  ]
};

export default legal;

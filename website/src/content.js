// Site copy, written from what the app actually does (see CLAUDE.md and
// mobile/lib/features). Don't promise anything here the app doesn't do.

export const TOUR = [
  {
    screen: 'home',
    title: 'Your whole day on one screen',
    text: "Today's takings against yesterday, bills made, who's in and what needs you, the moment you open the app.",
    points: ['Revenue trend for the week', 'Requests from staff waiting for you', 'Low-stock count at a glance'],
  },
  {
    screen: 'billing',
    title: 'Bill a client in seconds',
    text: 'Pick the client and the stylist, tap the services and products. Prices, commission and GST are worked out for you.',
    points: ['Cash, UPI / QR, Card or Pay later', 'GST added at the rate you set', 'Stock comes off automatically'],
  },
  {
    screen: 'invoices',
    title: 'Every invoice numbered, in order',
    text: 'INV-0001, INV-0002, INV-0003. Sequential numbers per salon, and a bill can never be edited after it is made.',
    points: ['Search by invoice number or client', 'Paid and unpaid at a glance', "Today's cash and UPI split"],
  },
  {
    screen: 'clients',
    title: 'Know every client by name',
    text: 'Search by name or phone, see their visits and what they spent, and what they still owe.',
    points: ['Dues collected in one tap', 'Birthdays this week', 'Who is due for a visit'],
  },
  {
    screen: 'attendance',
    title: 'Attendance without the register',
    text: 'Staff clock in and out from their own phone, with the location saved when the phone allows it. You mark the roster in one tap.',
    points: ['Present, Late or Absent', 'Late fine per day, if you use one', 'Unmarked staff are never auto-marked absent'],
  },
  {
    screen: 'payroll',
    title: 'Payroll that adds itself up',
    text: 'Base salary plus service and product commission, earned bill by bill. Make the salary slip when you pay.',
    points: ['Separate service and product commission %', 'Payout history per person', 'Sales targets for your team'],
  },
  {
    screen: 'reports',
    title: 'Reports that answer real questions',
    text: 'Revenue over time, popular services, staff performance, payment methods and how many clients come back.',
    points: ['Filter by branch and period', 'Repeat rate and visit frequency', 'Download your bills any time'],
  },
];

// icon names map to lucide-react components in Features.jsx
export const FEATURES = [
  { icon: 'ReceiptText', title: 'GST billing', text: 'Services and products on one bill. GST at your rate, commission worked out per line, stock updated as you sell.', tag: 'Billing' },
  { icon: 'Hash', title: 'Numbered invoices', text: 'INV-0001 onwards, in strict order for each salon. Bills are never edited after they are made.', tag: 'Billing' },
  { icon: 'Users', title: 'Client book', text: 'Search by name or phone. Visits, total spent, birthdays and WhatsApp consent on every client.', tag: 'Clients' },
  { icon: 'Wallet', title: 'Dues and pay later', text: 'Let a client pay later and see exactly who owes what. Clear a balance in one tap.', tag: 'Clients' },
  { icon: 'MapPin', title: 'Attendance with location', text: 'Clock in and out from the staff app, with where the shift started saved when the phone allows it.', tag: 'Team' },
  { icon: 'BadgeIndianRupee', title: 'Payroll and commission', text: 'Base salary, service and product commission, salary slips and payout history per person.', tag: 'Team' },
  { icon: 'PackageSearch', title: 'Inventory', text: 'Products with SKU, cost and selling price. Low-stock alerts before a shelf runs empty.', tag: 'Stock' },
  { icon: 'Receipt', title: 'Expenses', text: 'Rent, supplies and everything else, logged against the day so profit is never a guess.', tag: 'Money' },
  { icon: 'ChartNoAxesCombined', title: 'Reports', text: 'Revenue trends, top services, staff performance, payment methods and client retention.', tag: 'Insight' },
  { icon: 'HandCoins', title: 'Payment requests', text: 'When staff collect a payment, it lands in your Requests inbox for you to confirm. Nothing slips through.', tag: 'Money' },
  { icon: 'QrCode', title: 'Payment and review QR', text: 'Show your UPI QR or Google-review QR full screen to a client, straight from the Home screen.', tag: 'Front desk' },
  { icon: 'WhatsApp', title: 'WhatsApp, automatically', text: "Bill receipts, birthday wishes and come-back reminders from your salon's own WhatsApp Business number.", tag: 'WhatsApp' },
  { icon: 'Building2', title: 'Branches', text: 'Run more than one outlet. Staff and bills belong to a branch, and every report can filter by branch.', tag: 'Growth' },
  { icon: 'Target', title: 'Sales targets', text: 'Set targets for your team and watch progress fill up as they bill services and products.', tag: 'Team' },
  { icon: 'Smartphone', title: 'Android, iOS and web', text: 'An Android app for the counter, iPhone and iPad from the Home Screen, and the same app in any browser on a computer.', tag: 'Anywhere' },
];

export const GALLERY = [
  { src: 'home', title: 'Home', sub: "Today's revenue and alerts" },
  { src: 'home-today', title: 'Today', sub: 'Clients, bills, staff in, stock' },
  { src: 'billing', title: 'New bill', sub: 'Client, stylist, services' },
  { src: 'invoices', title: 'Bill history', sub: 'Numbered invoices, paid / unpaid' },
  { src: 'clients', title: 'Clients', sub: 'Dues, birthdays, due a visit' },
  { src: 'team', title: 'Team', sub: "Who's in today" },
  { src: 'attendance', title: 'Attendance', sub: 'Shift and roster' },
  { src: 'payroll', title: 'Payroll', sub: 'Salary and commission' },
  { src: 'services', title: 'Services & stock', sub: 'Menu, prices, products' },
  { src: 'reports', title: 'Reports', sub: 'Revenue trend, top services' },
  { src: 'retention', title: 'Client retention', sub: 'Repeat rate, visit frequency' },
  { src: 'branches', title: 'Branches', sub: 'Revenue per outlet' },
  { src: 'settings', title: 'Salon settings', sub: 'GST, late fine, WhatsApp' },
  { src: 'login', title: 'Sign in', sub: 'Owner and staff accounts' },
];

export const FAQ = [
  {
    q: 'Do I need to install anything?',
    a: 'No. There is an Android app, and on iPhone and iPad you open Stylux in Safari and add it to your Home Screen, where it opens full screen like any other app. On a computer it runs in any modern browser.',
  },
  {
    q: 'Can other salons see my data?',
    a: "No. Every salon gets its own separate database and its own sign-in system. Your clients, bills and staff records are never stored alongside another salon's.",
  },
  {
    q: 'Can my staff see each other’s salaries?',
    a: 'No. Staff see the clients, bills and menu they need for work, and only their own attendance, commission and pay. Money actions such as billing, stock and payroll are for the owner only.',
  },
  {
    q: 'Does it handle GST?',
    a: 'Yes. Switch GST on, set your rate, and it is added to every bill. Invoices are numbered in order (INV-0001, INV-0002 and so on). Please confirm your tax filings with your accountant.',
  },
  {
    q: 'How do the WhatsApp messages work?',
    a: "Messages go from your salon's own WhatsApp Business number, only to clients who agreed to receive them. The bill receipt goes out right after billing, birthday wishes at 10 AM on the day, and a come-back reminder 21 days after a visit. We help you set it up with Meta.",
  },
  {
    q: 'I have more than one branch. Will it work?',
    a: 'Yes. Add as many branches as you run. Staff and bills belong to a branch, and Home, Billing and Reports can show one branch or all of them together.',
  },
  {
    q: 'Does attendance need GPS?',
    a: 'Location is saved with the clock-in when the phone or browser allows it. If location is off, attendance still works and the record simply says the location was unavailable.',
  },
  {
    q: 'Can I get my data out?',
    a: 'Yes. Download your bills from Reports whenever you like, so you always have your own copy.',
  },
  {
    q: 'What does it cost?',
    a: 'Pricing depends on your salon’s size and number of branches. Message us on WhatsApp and we will send you a quote.',
  },
];

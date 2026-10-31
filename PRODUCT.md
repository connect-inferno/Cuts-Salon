# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

(Flutter app, shipped as a web build on Vercel and as an Android APK. One custom design language on both; it does not switch to native per-OS styling.)

## Users

- **Salon owner** (primary): runs the salon day to day, on a phone between clients and on a laptop at the front desk, about equally. Bills clients, runs payroll and attendance, reads reports, manages clients and staff, and controls automatic WhatsApp messages.
- **Staff** (stylists, reception): sign in to the same app with a smaller view: clock in/out by scanning the owner's QR, see their own work, commission, attendance and salary slips. They don't bill or edit clients.

## Product Purpose

Stylux is salon management for Indian salons: billing with GST and sequential invoices, client records and dues, staff attendance, commission and payroll, stock, expenses, reports, and automatic WhatsApp messages to clients. Success is an owner who runs the whole salon from it without paper, a spreadsheet or a second app.

## Positioning

Each salon gets its own isolated Firebase project, so one salon's data, logins and quotas never touch another's. WhatsApp messages go out from the salon's own WhatsApp Business number.

## Operating Context

- Used inside a working salon: short glances between clients, often one-handed on a phone; longer sessions on a laptop for payroll and reports.
- Money is in rupees (formatInr: ₹1,25,000); times are IST.
- WhatsApp messages (bill receipt, birthday wish, come-back reminder) are sent by Cloud Functions, only to clients who said OK to WhatsApp, and only once the Stylux team has set WhatsApp up for that salon.

## Capabilities and Constraints

- No trusted server: Firestore Security Rules are the access boundary (see CLAUDE.md).
- Rules and Cloud Functions are deployed by hand, per salon; the app deploys on push to main.
- Reports read monthly/daily rollup documents, never raw bills.
- Deletes are closed: clients, services and staff are archived/removed, never deleted.

## Brand Commitments

- Name: Stylux. Deep navy brand on cool slate neutrals; colour flat and sparing. No gradients, coloured glows or rainbow icon tiles (removed on purpose). Amber/red/muted green are for status only. Tokens in mobile/lib/theme.dart; building blocks in mobile/lib/widgets/ds.dart.
- Plain, friendly English wording ("Pay later", "Not in yet"); stored codes are never shown raw.

## Evidence on Hand

- Marketing site screenshots come from the test salon only (website/README.md). No customer testimonials or usage numbers exist; don't invent any.

## Product Principles

1. One home per job: daily work is on a visible screen, not behind a gear.
2. Say what happened in plain words: every number and status explains itself.
3. Never claim something that didn't happen (no fake buttons, no "sent" before a send).
4. History is never lost: archive and deactivate rather than delete.

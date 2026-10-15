import 'package:flutter/material.dart';

import '../../data/support_contact.dart';
import '../../theme.dart';
import '../../widgets/app_sub_page.dart';

/// The Privacy Policy and Disclaimer, shown from the owner's and staff's
/// profile pages (see widgets/account_security.dart).
///
/// Plain-language drafts written from what this app actually does - one
/// Firebase project per salon, WhatsApp only on opt-in, location on clock-in
/// when the phone allows it. Have them reviewed before relying on them
/// legally, and update [kLegalEffectiveDate] whenever the text changes.

const kLegalEffectiveDate = '14 October 2026';

/// Where people write to about privacy. If this is ever emptied, the pages
/// point people to their salon owner instead of printing a blank address.
const kLegalContactEmail = kSupportEmail;

class LegalSection {
  final String heading;
  final List<String> paragraphs;
  const LegalSection(this.heading, this.paragraphs);
}

void openPrivacyPolicy(BuildContext context) => openAppSubPage(
      context,
      title: 'Privacy policy',
      subtitle: 'Effective $kLegalEffectiveDate',
      child: const LegalDocumentView(
        intro: 'How Stylux handles the information your salon keeps in it.',
        sections: privacyPolicySections,
      ),
    );

void openDisclaimer(BuildContext context) => openAppSubPage(
      context,
      title: 'Disclaimer',
      subtitle: 'Effective $kLegalEffectiveDate',
      child: const LegalDocumentView(
        intro: 'What Stylux does and does not promise.',
        sections: disclaimerSections,
      ),
    );

String get _contactLine => kLegalContactEmail.isEmpty
    ? 'Questions or requests: speak to your salon owner, who can reach the Stylux team on your behalf.'
    : 'Questions or requests: write to $kLegalContactEmail. If you are a salon client, you can also ask the salon directly.';

const privacyPolicySections = [
  LegalSection('Who this covers', [
    'Stylux is software that salons use to run billing, client records, staff attendance and pay. This policy covers salon owners, staff who sign in, and the salon clients whose details a salon records.',
    'Each salon decides what it records about its own clients and staff and is responsible for that information. Stylux stores and processes it on the salon\'s behalf, to provide the app.',
  ]),
  LegalSection('What is stored', [
    'Owner and staff accounts: name, email address, phone number, role, branch, base salary, commission rates, attendance (clock-in and clock-out times), salary slips and commission earned. Passwords are handled by Google Firebase Authentication - Stylux never sees or stores them.',
    'Location at clock-in and clock-out: when the phone or browser allows it, the place a shift was started and ended is saved with that day\'s attendance, so the owner can see it. If location is turned off or refused, attendance still works and the record says the location was unavailable.',
    'Salon clients: name, phone number, and optionally email, birthday (day and month only - no year), whether they agreed to WhatsApp messages, visits, bills, payments and anything still owed.',
    'Salon business records: services, products and stock, expenses, discounts, branches, and settings such as GST.',
  ]),
  LegalSection('How it is used', [
    'Only to run the salon: making bills, keeping client history, tracking attendance and stock, and working out pay and commission.',
    'WhatsApp messages (bill receipts, birthday wishes, visit reminders) are sent only when the salon has switched WhatsApp on and the client has agreed to receive them. They come from the salon\'s own WhatsApp Business number.',
    'Stylux does not sell personal information, does not show advertising, and does not use salon data to profile anyone.',
  ]),
  LegalSection('Where it is kept', [
    'Every salon has its own separate Google Firebase project (a database and a sign-in system), so one salon\'s data is kept apart from every other salon\'s.',
    'A small shared directory stores only each person\'s email address and which salon they belong to, so sign-in goes straight to the right salon. It holds no passwords and no salon data.',
    'Information travels over encrypted connections (HTTPS) and Google encrypts it where it is stored.',
  ]),
  LegalSection('Who it is shared with', [
    'Inside the salon: the owner can see all of the salon\'s records. Staff see what they need for their work - clients and bills, and their own attendance and pay.',
    'Service providers that make the app work: Google (Firebase hosting, database and sign-in), Vercel (which delivers the app to your browser), and Meta (WhatsApp Business), which receives a client\'s phone number and the message text only for messages that client agreed to.',
    'Authorities, only where the law requires it.',
  ]),
  LegalSection('How long it is kept', [
    'Records are kept while the salon uses Stylux. Bills are kept as business records and are never edited after they are made. Services and products that are removed are archived rather than erased, so old bills still show what was sold.',
    'When a salon stops using Stylux, it can ask for its data to be deleted, except where it must be kept by law.',
  ]),
  LegalSection('Your choices and rights', [
    'You can ask to see, correct or delete information about you, and you can withdraw consent - for example, to stop WhatsApp messages. Salon clients should ask their salon, which can update or remove the record. Staff and owners can ask the salon owner or the Stylux team.',
    'Under India\'s Digital Personal Data Protection Act, 2023, you may also raise a complaint with the Data Protection Board of India.',
  ]),
  LegalSection('Security', [
    'Each salon\'s data is isolated, and access rules decide who can read or change each record. Keep your password private and sign out on shared devices. No system can be made perfectly secure, so please tell the salon owner straight away if you think an account has been misused.',
  ]),
  LegalSection('Children', [
    'Owner and staff accounts are for adults. A salon may record a child as a client; in that case the salon should have a parent or guardian\'s agreement.',
  ]),
  LegalSection('Changes to this policy', [
    'If this policy changes, the effective date at the top will change and the new version will appear here.',
  ]),
];

const disclaimerSections = [
  LegalSection('Provided as is', [
    'Stylux is a tool for running day-to-day salon work. We work to keep it accurate, secure and available, but we cannot promise it will always be uninterrupted or free of errors.',
  ]),
  LegalSection('Numbers you rely on', [
    'Bills, GST, discounts, commission, salary, dues and reports are calculated from what the salon enters - prices, rates, attendance and so on. The salon is responsible for checking them.',
    'GST is added at the rate the owner sets. Stylux does not decide whether a salon must charge GST, and nothing in the app is tax, legal or financial advice. Please confirm tax filings and payroll with an accountant.',
  ]),
  LegalSection('WhatsApp messages', [
    'The salon is responsible for having each client\'s agreement before messages are sent and for following Meta\'s WhatsApp Business rules. Delivery depends on Meta; Stylux is not responsible for messages Meta delays, blocks or charges for.',
  ]),
  LegalSection('Attendance and location', [
    'Clock-in times and locations are a record to help the owner, not proof. A phone may report its location inaccurately or not at all.',
  ]),
  LegalSection('Accounts and access', [
    'Keep your password private. The owner decides who gets an account and should remove access for anyone who leaves. Actions taken while signed in to an account are treated as that account\'s.',
  ]),
  LegalSection('Keep your own copy', [
    'Data is stored with Google Firebase. We recommend downloading your bills from Reports (Download bills) regularly so you always have your own copy.',
  ]),
  LegalSection('Limits of responsibility', [
    'As far as the law allows, Stylux is not responsible for indirect losses - such as lost business, lost profit or lost data - arising from using the app or from it being unavailable.',
  ]),
  LegalSection('Other services', [
    'Google, Vercel and Meta provide parts of the service and have their own terms and privacy policies.',
  ]),
  LegalSection('Changes', [
    'This disclaimer may be updated. The effective date at the top shows when it last changed.',
  ]),
];

class LegalDocumentView extends StatelessWidget {
  final String intro;
  final List<LegalSection> sections;

  const LegalDocumentView({super.key, required this.intro, required this.sections});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intro,
                  style: const TextStyle(fontSize: 14.5, height: 1.5, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                ),
                const SizedBox(height: 4),
                for (final section in sections) ...[
                  const SizedBox(height: 18),
                  Text(
                    section.heading,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
                  ),
                  for (final p in section.paragraphs) ...[
                    const SizedBox(height: 8),
                    Text(p, style: const TextStyle(fontSize: 13.5, height: 1.55, color: AppTheme.slateMedium)),
                  ],
                ],
                const SizedBox(height: 18),
                const Divider(height: 1, color: AppTheme.borderSubtle),
                const SizedBox(height: 14),
                Text(_contactLine, style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.slateMedium)),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

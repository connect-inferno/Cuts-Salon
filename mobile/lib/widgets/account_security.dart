import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../features/auth/auth_provider.dart';
import '../features/legal/legal_pages.dart';
import '../firebase/salon_auth.dart';
import '../theme.dart';
import 'app_dialog.dart';

/// Password and legal links for whoever is signed in - the same card on the
/// owner's profile and on staff's My Account > Profile, so both roles find
/// these in the same place.
class AccountAndLegalCard extends ConsumerWidget {
  const AccountAndLegalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider).email;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Password'),
          _row(
            icon: PhosphorIconsRegular.lockKey,
            tint: AppTheme.accentBlue,
            tintBg: AppTheme.accentBlueBg,
            title: 'Change password',
            subtitle: 'Enter your current password and a new one',
            onTap: () => showChangePasswordDialog(context, ref),
          ),
          _divider(),
          _row(
            icon: PhosphorIconsRegular.envelopeSimple,
            tint: AppTheme.accentViolet,
            tintBg: AppTheme.accentVioletBg,
            title: 'Forgot it? Get a reset link',
            subtitle: email == null || email.isEmpty ? 'Sent to your sign-in email' : 'Sent to $email',
            onTap: () => confirmSendMyResetEmail(context, ref),
          ),
          _label('Legal'),
          _row(
            icon: PhosphorIconsRegular.shieldCheck,
            tint: AppTheme.accentGreen,
            tintBg: AppTheme.accentGreenBg,
            title: 'Privacy policy',
            subtitle: 'What is stored and who can see it',
            onTap: () => openPrivacyPolicy(context),
          ),
          _divider(),
          _row(
            icon: PhosphorIconsRegular.info,
            tint: AppTheme.accentOrange,
            tintBg: AppTheme.accentOrangeBg,
            title: 'Disclaimer',
            subtitle: 'What the app does and does not promise',
            onTap: () => openDisclaimer(context),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  static Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF94A3B8)),
        ),
      );

  static Widget _divider() => const Padding(
        padding: EdgeInsets.only(left: 64),
        child: Divider(height: 1, color: AppTheme.borderSubtle),
      );

  static Widget _row({
    required IconData icon,
    required Color tint,
    required Color tintBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: tintBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.slateLight),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String text, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? AppTheme.accentRed : null,
  ));
}

/// Current password + new password (twice). Firebase checks the current
/// one by re-signing in before it accepts the change - see
/// SalonAuth.changeOwnPassword.
void showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  final current = TextEditingController();
  final next = TextEditingController();
  final again = TextEditingController();
  bool submitting = false;
  String? error;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AppDialog(
        icon: PhosphorIconsRegular.lockKey,
        title: 'Change password',
        subtitle: 'At least 8 characters',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: appDialogFieldDecoration(label: 'Current password', icon: PhosphorIconsRegular.lockKey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: appDialogFieldDecoration(label: 'New password', icon: PhosphorIconsRegular.lockSimple),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: again,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: appDialogFieldDecoration(label: 'New password again', icon: PhosphorIconsRegular.lockSimple),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(fontSize: 12.5, color: AppTheme.accentRed)),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: submitting
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      confirmSendMyResetEmail(context, ref);
                    },
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text("Don't know your current password?"),
            ),
          ],
        ),
        actions: AppDialogActions(
          submitLabel: 'Save password',
          submitting: submitting,
          onCancel: () => Navigator.pop(ctx),
          onSubmit: () async {
            // Errors show inside the dialog - a snackbar lands behind it.
            if (current.text.isEmpty) {
              setDialogState(() => error = 'Enter your current password.');
              return;
            }
            if (next.text.length < 8) {
              setDialogState(() => error = 'The new password needs at least 8 characters.');
              return;
            }
            if (next.text != again.text) {
              setDialogState(() => error = 'The two new passwords do not match.');
              return;
            }
            if (next.text == current.text) {
              setDialogState(() => error = 'The new password is the same as the current one.');
              return;
            }
            setDialogState(() {
              submitting = true;
              error = null;
            });
            try {
              final salonId = ref.read(authControllerProvider).salonId;
              final app = salonId == null ? null : SalonAuth.currentApp(salonId);
              if (app == null) throw SalonAuthException('You are signed out. Sign in again and retry.');
              await SalonAuth.changeOwnPassword(app, currentPassword: current.text, newPassword: next.text);
              if (ctx.mounted) Navigator.pop(ctx);
              _toast(context, 'Password changed. Use the new one next time you sign in.');
            } catch (e) {
              setDialogState(() {
                submitting = false;
                error = e.toString();
              });
            }
          },
        ),
      ),
    ),
  );
}

/// Sends Firebase's reset-link email to the signed-in account, after a
/// confirm - so a stray tap doesn't fire off an email.
void confirmSendMyResetEmail(BuildContext context, WidgetRef ref) {
  final auth = ref.read(authControllerProvider);
  final email = auth.email;
  if (email == null || email.isEmpty || auth.salonId == null) {
    _toast(context, 'No email on this account. Ask your salon owner to reset your password.', error: true);
    return;
  }
  bool sending = false;
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AppDialog(
        icon: PhosphorIconsRegular.envelopeSimple,
        title: 'Email a reset link?',
        child: Text(
          "We'll send a link to $email. Open it to choose a new password, then sign in with that. "
          "If it doesn't arrive in a few minutes, check your spam folder.",
          style: const TextStyle(fontSize: 14, height: 1.45, color: AppTheme.slateMedium),
        ),
        actions: AppDialogActions(
          submitLabel: 'Send link',
          submitting: sending,
          onCancel: () => Navigator.pop(ctx),
          onSubmit: () async {
            setDialogState(() => sending = true);
            try {
              final app = SalonAuth.currentApp(auth.salonId!);
              if (app == null) throw SalonAuthException('You are signed out. Sign in again and retry.');
              await SalonAuth.sendPasswordResetEmail(app, email);
              if (ctx.mounted) Navigator.pop(ctx);
              _toast(context, 'Reset link sent to $email.');
            } catch (e) {
              if (ctx.mounted) Navigator.pop(ctx);
              _toast(context, e.toString(), error: true);
            }
          },
        ),
      ),
    ),
  );
}

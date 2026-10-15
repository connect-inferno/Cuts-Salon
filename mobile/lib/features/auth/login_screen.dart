import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/salon_auth.dart';
import '../../theme.dart';
import '../../widgets/app_dialog.dart';
import '../legal/legal_pages.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

const _devLoginEmail = String.fromEnvironment('DEV_LOGIN_EMAIL');
const _devLoginPassword = String.fromEnvironment('DEV_LOGIN_PASSWORD');

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Empty, not pre-filled: this same build ships to every salon, so the
  // cuts-salon test account that used to sit here was visible to real
  // customers - along with the demo password the submit handler fell back to.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Safari caps script-writable storage at 7 days without a visit, so a
  // stylist who doesn't open the app for a week gets signed out. Nothing in
  // a serverless app can extend that - but adding the app to the Home Screen
  // takes it out of the cap entirely, so tell them once, on the screen where
  // it matters.
  bool get _showSafariTip =>
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    // Saves re-typing after a session expires. Cleared on explicit logout,
    // so this only ever pre-fills for someone who didn't choose to sign out.
    SalonAuth.lastSignedInEmail().then((email) {
      if (!mounted || email == null || email.isEmpty) return;
      if (_emailController.text.isNotEmpty) return;
      setState(() => _emailController.text = email);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    final email = TextEditingController(text: _emailController.text.trim());
    bool sending = false;
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.envelopeSimple,
          title: 'Reset your password',
          subtitle: "We'll email you a link to choose a new one",
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: appDialogFieldDecoration(label: 'Your sign-in email', icon: PhosphorIconsRegular.envelopeSimple),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(fontSize: 12.5, color: AppTheme.accentRed)),
              ],
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Send link',
            submitting: sending,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final value = email.text.trim();
              if (!value.contains('@') || !value.contains('.')) {
                setDialogState(() => error = 'Enter the email you sign in with.');
                return;
              }
              setDialogState(() {
                sending = true;
                error = null;
              });
              try {
                await SalonAuth.sendResetEmailForLogin(value);
                if (ctx.mounted) Navigator.pop(ctx);
                // The same words whether or not the account exists, so this
                // can't be used to find out who has one.
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('If $value has an account, a reset link is on its way. Check spam if it doesn\'t arrive.'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 6),
                  ));
                }
              } catch (e) {
                setDialogState(() {
                  sending = false;
                  error = e.toString();
                });
              }
            },
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authControllerProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error ?? 'Authentication failed'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),

                      // Logo Squircle Badge with Stylux Logo & Soft Purple Shadow
                      Container(
                        width: 76,
                        height: 76,
                        // Flat brand tile - the glow, gradient and the
                        // ambient background blob were decoration only.
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/stylux_mark.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              PhosphorIconsFill.scissors,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Brand Name & Subtitle
                      const Text(
                        'Stylux',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Salon management',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Main Sign In Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE4E8EF)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 26.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Sign in to your salon dashboard',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Local development only. The login comes from
                              // mobile/dev_login.json (git-ignored) via the
                              // "flutter-web-login" launch entry's
                              // --dart-define-from-file, so no password is ever
                              // in the source or git history; kDebugMode keeps
                              // the chip out of the release build entirely.
                              if (kDebugMode && _devLoginEmail.isNotEmpty) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ActionChip(
                                    avatar: const Icon(PhosphorIconsRegular.user, size: 15),
                                    label: const Text('Owner (test salon)', style: TextStyle(fontSize: 12)),
                                    onPressed: () => setState(() {
                                      _emailController.text = _devLoginEmail;
                                      _passwordController.text = _devLoginPassword;
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Email Label & Pill Input
                              const Text(
                                'Email Address',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'you@yoursalon.com',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(
                                    PhosphorIconsRegular.envelopeSimple,
                                    size: 19,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Password Label & Forgot Password Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Password',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  // Sends a real reset link - it used to only say
                                  // "Contact your Salon Superadmin".
                                  GestureDetector(
                                    onTap: _showForgotPasswordDialog,
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E3A5F),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Password Pill Input
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(
                                    PhosphorIconsRegular.lock,
                                    size: 19,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
                                      size: 19,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // "Log In" - solid brand teal, like every
                              // primary button in the app.
                              Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3A5F),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: state.isLoading ? null : _submit,
                                    child: Center(
                                      child: state.isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Log In',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  PhosphorIconsBold.arrowRight,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Shield Security Note
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PhosphorIconsFill.shieldCheck,
                                    size: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Secure access for authorized personnel only.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Readable before signing in, as app stores expect.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => openPrivacyPolicy(context),
                            child: const Text('Privacy policy', style: TextStyle(fontSize: 12.5)),
                          ),
                          const Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
                          TextButton(
                            onPressed: () => openDisclaimer(context),
                            child: const Text('Disclaimer', style: TextStyle(fontSize: 12.5)),
                          ),
                        ],
                      ),

                      if (_showSafariTip) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(PhosphorIconsRegular.info, size: 15, color: Color(0xFF64748B)),
                              const SizedBox(width: 9),
                              Expanded(
                                child: RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Using Safari? ',
                                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                      ),
                                      TextSpan(
                                        text: 'Add Stylux to your Home Screen to stay signed in. '
                                            'Otherwise Safari ends the session after about a week without opening it.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
